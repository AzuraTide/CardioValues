program CardioProject;

uses
  Vcl.Forms,
  CardioMainForm in 'CardioMainForm.pas' {Cardio},
  CardioTypes in 'CardioTypes.pas',
  CardioRepository in 'CardioRepository.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TCardio, Cardio);
  Application.Run;
end.
