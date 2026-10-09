unit CardioMainForm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, CardioTypes;

type
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
