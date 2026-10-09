unit CardioType;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs;

type
  TWorkoutPhase = (wpStart, wpEnd);

  TCardioSession = record
    ID: Integer;
    Date: TDateTime;
    DurationSeconds: Integer;
    Level: Integer;
    Calories: Integer;
    ExerciseType: string;
    WorkoutPhase: TWorkoutPhase;
  end;

  TCardio = class(TForm)
  private
    FCardioSession: TCardioSession;
  public
    { Public declarations }
  end;

var
  Cardio: TCardio;

implementation

{$R *.dfm}

end.
