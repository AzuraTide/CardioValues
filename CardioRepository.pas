unit CardioRepository;

interface

uses
  System.SysUtils, FireDAC.Comp.Client, CardioTypes;

type
  TCardioRepository = class
  private
    FConnection: TFDConnection;
    function NewQuery(const ASQL: string): TFDQuery;
    function ReadSession(AQuery: TFDQuery): TCardioSession;
    procedure BindSession(AQuery: TFDQuery; const ASession: TCardioSession);
    procedure ValidateSession(const ASession: TCardioSession);
  public
    constructor Create(const ADatabasePath: string);
    destructor Destroy; override;
    function GetAll: TArray<TCardioSession>;
    function TryGetByID(AID: Integer; out ASession: TCardioSession): Boolean;
    function Insert(const ASession: TCardioSession): TCardioSession;
    function Update(const ASession: TCardioSession): Boolean;
    function Delete(AID: Integer): Boolean;
  end;

implementation

uses
  System.Math, System.DateUtils, System.Generics.Collections, Data.DB,
  FireDAC.Stan.Param, FireDAC.Phys.SQLite, FireDAC.Phys.SQLiteWrapper.Stat,
  FireDAC.DApt;

const
  SessionColumns = 'ID, Date, DurationSeconds, Level, Calories, ExerciseType, WorkoutPhase';

constructor TCardioRepository.Create(const ADatabasePath: string);
var
  DatabasePath: string;
begin
  inherited Create;
  DatabasePath := ExpandFileName(ADatabasePath);
  if not FileExists(DatabasePath) then
    raise Exception.CreateFmt('Database file not found: %s', [DatabasePath]);
  FConnection := TFDConnection.Create(nil);
  FConnection.LoginPrompt := False;
  FConnection.Params.Values['DriverID'] := 'SQLite';
  FConnection.Params.Values['Database'] := DatabasePath;
  // Fail rather than silently creating a new, empty database.
  FConnection.Params.Values['OpenMode'] := 'ReadWrite';
  FConnection.Connected := True;
end;

destructor TCardioRepository.Destroy;
begin
  FConnection.Free;
  inherited;
end;

function TCardioRepository.NewQuery(const ASQL: string): TFDQuery;
begin
  Result := TFDQuery.Create(nil);
  try
    Result.Connection := FConnection;
    Result.SQL.Text := ASQL;
  except
    Result.Free;
    raise;
  end;
end;

procedure TCardioRepository.ValidateSession(const ASession: TCardioSession);
var
  Year, Month, Day: Word;
begin
  // Verify if it is a valid date range
  if IsNan(ASession.Date) or IsInfinite(ASession.Date) or
    (ASession.Date < -693593) or (ASession.Date >= 2958466) then
    raise EArgumentException.Create('Invalid session date.');
  DecodeDate(ASession.Date, Year, Month, Day);

  if Year = 0 then
    raise EArgumentException.Create('Invalid session date.');

  if ASession.DurationSeconds <= 0 then
    raise EArgumentException.Create('Duration must be greater than zero.');

  if ASession.Level < 0 then
    raise EArgumentException.Create('Level cannot be negative.');

  if IsNan(ASession.Calories) or IsInfinite(ASession.Calories) or
    (ASession.Calories < 0) then
    raise EArgumentException.Create('Calories must be a finite, non-negative number.');

  if Trim(ASession.ExerciseType) = '' then
    raise EArgumentException.Create('Exercise type is required.');

  if not (ASession.WorkoutPhase in [wpStart, wpEnd]) then
    raise EArgumentException.Create('Invalid workout phase.');
end;

procedure TCardioRepository.BindSession(AQuery: TFDQuery;
  const ASession: TCardioSession);
begin
  AQuery.ParamByName('Date').AsString := FormatDateTime('yyyy-mm-dd', ASession.Date);
  AQuery.ParamByName('DurationSeconds').AsInteger := ASession.DurationSeconds;
  AQuery.ParamByName('Level').AsInteger := ASession.Level;
  AQuery.ParamByName('Calories').AsFloat := ASession.Calories;
  AQuery.ParamByName('ExerciseType').AsString := ASession.ExerciseType;
  case ASession.WorkoutPhase of
    wpStart: AQuery.ParamByName('WorkoutPhase').AsString := 'Start';
    wpEnd: AQuery.ParamByName('WorkoutPhase').AsString := 'End';
  end;
end;

function TCardioRepository.ReadSession(AQuery: TFDQuery): TCardioSession;
var
  DateText, Phase: string;
  ParsedDate: TDateTime;
  SessionID: Int64;
begin
  SessionID := AQuery.FieldByName('ID').AsLargeInt;
  // Check supported integer range
  if (SessionID < Low(Integer)) or (SessionID > High(Integer)) then
    raise ERangeError.Create('Session ID exceeds the supported Integer range.');

  Result.ID := Integer(SessionID);

  DateText := AQuery.FieldByName('Date').AsString;
  // Validate date
  if not TryISO8601ToDate(DateText, ParsedDate, False) then
    raise EConvertError.CreateFmt('Invalid database date: %s', [DateText]);
  if FormatDateTime('yyyy-mm-dd', ParsedDate) <> DateText then
    raise EConvertError.CreateFmt('Expected a YYYY-MM-DD date: %s', [DateText]);
  Result.Date := ParsedDate;

  Result.DurationSeconds := AQuery.FieldByName('DurationSeconds').AsInteger;

  Result.Level := AQuery.FieldByName('Level').AsInteger;

  Result.Calories := AQuery.FieldByName('Calories').AsFloat;

  Result.ExerciseType := AQuery.FieldByName('ExerciseType').AsString;

  // Workout Phase Distinction
  Phase := AQuery.FieldByName('WorkoutPhase').AsString;
  if Phase = 'Start' then
    Result.WorkoutPhase := wpStart
  else if Phase = 'End' then
    Result.WorkoutPhase := wpEnd
  else
    raise EConvertError.CreateFmt('Invalid database workout phase: %s', [Phase]);
end;

function TCardioRepository.GetAll: TArray<TCardioSession>;
var
  Query: TFDQuery;
  Sessions: TList<TCardioSession>;
begin
  Sessions := TList<TCardioSession>.Create;
  try
    Query := NewQuery('SELECT ' + SessionColumns +
      ' FROM CardioSessions ORDER BY Date DESC, ID DESC');
    try
      Query.Open;
      while not Query.Eof do
      begin
        Sessions.Add(ReadSession(Query));
        Query.Next;
      end;
      Result := Sessions.ToArray;
    finally
      Query.Free;
    end;
  finally
    Sessions.Free;
  end;
end;

function TCardioRepository.TryGetByID(AID: Integer; out ASession: TCardioSession): Boolean;
var
  Query: TFDQuery;
begin
  ASession := Default(TCardioSession);
  Query := NewQuery('SELECT ' + SessionColumns + ' FROM CardioSessions WHERE ID = :ID');
  try
    Query.ParamByName('ID').AsInteger := AID;
    Query.Open;
    Result := not Query.IsEmpty;
    if Result then
      ASession := ReadSession(Query);
  finally
    Query.Free;
  end;
end;

function TCardioRepository.Insert(const ASession: TCardioSession): TCardioSession;
var
  Query: TFDQuery;
  NewID: Int64;
begin
  ValidateSession(ASession);
  Query := NewQuery('INSERT INTO CardioSessions ' +
    '(Date, DurationSeconds, Level, Calories, ExerciseType, WorkoutPhase) ' +
    'VALUES (:Date, :DurationSeconds, :Level, :Calories, :ExerciseType, :WorkoutPhase)');
  try
    BindSession(Query, ASession);
    FConnection.StartTransaction;
    try
      Query.ExecSQL;
      Query.SQL.Text := 'SELECT last_insert_rowid() AS ID';
      Query.Open;
      NewID := Query.FieldByName('ID').AsLargeInt;
      Query.Close;
      if (NewID < Low(Integer)) or (NewID > High(Integer)) then
        raise ERangeError.Create('Generated ID exceeds the supported Integer range.');
      if not TryGetByID(Integer(NewID), Result) then
        raise Exception.Create('Inserted session could not be read back.');
      FConnection.Commit;
    except
      FConnection.Rollback;
      raise;
    end;
  finally
    Query.Free;
  end;
end;

function TCardioRepository.Update(const ASession: TCardioSession): Boolean;
var
  Query: TFDQuery;
begin
  ValidateSession(ASession);
  Query := NewQuery('UPDATE CardioSessions SET Date = :Date, ' +
    'DurationSeconds = :DurationSeconds, Level = :Level, Calories = :Calories, ' +
    'ExerciseType = :ExerciseType, WorkoutPhase = :WorkoutPhase WHERE ID = :ID');
  try
    BindSession(Query, ASession);
    Query.ParamByName('ID').AsInteger := ASession.ID;
    Query.ExecSQL;
    Result := Query.RowsAffected > 0;
  finally
    Query.Free;
  end;
end;

function TCardioRepository.Delete(AID: Integer): Boolean;
var
  Query: TFDQuery;
begin
  Query := NewQuery('DELETE FROM CardioSessions WHERE ID = :ID');
  try
    Query.ParamByName('ID').AsInteger := AID;
    Query.ExecSQL;
    Result := Query.RowsAffected > 0;
  finally
    Query.Free;
  end;
end;

end.
