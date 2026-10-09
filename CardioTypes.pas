unit CardioTypes;

interface

type
  TWorkoutPhase = (wpStart, wpEnd);

  TCardioSession = record
    ID: Integer;
    Date: TDateTime;
    DurationSeconds: Integer;
    Level: Integer;
    Calories: Double;
    ExerciseType: string;
    WorkoutPhase: TWorkoutPhase;
  end;

implementation

end.
