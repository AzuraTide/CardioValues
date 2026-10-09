program CardioProject;

uses
  Vcl.Forms,
  CardioType in 'CardioType.pas' {Cardio};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TCardio, Cardio);
  Application.Run;
end.
