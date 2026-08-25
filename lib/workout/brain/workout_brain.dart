import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../brain/brain_context.dart';
import '../../core/tod/tod_period.dart';
import '../../onboarding/models/onboarding_profile.dart';

/// What the AI Brain knows about the user's fitness profile going into a
/// workout — matches 31/32c/33's "AI Brain Data Flow" **RECEIVES ←** side
/// (fitness level, time of day, recent activity). Nothing here is
/// fabricated: [fitnessLevel] comes straight from onboarding, [period]
/// from the existing TOD resolver.
class WorkoutBrainContext {
  const WorkoutBrainContext({required this.fitnessLevel, required this.period});

  final FitnessLevel? fitnessLevel;
  final TodPeriod period;
}

final workoutBrainContextProvider = Provider<WorkoutBrainContext?>((ref) {
  final brain = ref.watch(brainContextProvider);
  if (brain == null) return null;
  final period = ref.watch(currentTodPeriodProvider);
  return WorkoutBrainContext(
    fitnessLevel: brain.profile.fitnessLevel,
    period: period,
  );
});

/// The **SENDS →** side of 31/32c/33's annotations: category selections,
/// workout start/completion, exercise completion/skips, duration,
/// adherence. No external AI service is connected yet (explicitly out of
/// scope for this pass) — [WorkoutSignalLog] is the seam a real
/// analytics/personalization pipeline will read from later, so the UI
/// layer never talks to that pipeline directly.
enum WorkoutSignalType {
  categorySelected,
  workoutSelected,
  workoutStarted,
  exerciseCompleted,
  exerciseSkipped,
  workoutCompleted,

  /// An optional post-exercise AI Coach reflection was saved (currently
  /// only offered after Legs Up Wall/Reclined Butterfly — see
  /// `ExerciseReflectionCard`). [WorkoutSignal.detail] carries the
  /// exercise id and selected signals as a compact `key=value;...` string,
  /// the same "real seam, no external AI service" model as every other
  /// signal here — never fabricated adaptive-memory processing.
  exerciseNoteSaved,
}

class WorkoutSignal {
  const WorkoutSignal({required this.type, required this.at, this.detail});

  final WorkoutSignalType type;
  final DateTime at;
  final String? detail;
}

class WorkoutSignalLog extends StateNotifier<List<WorkoutSignal>> {
  WorkoutSignalLog() : super(const []);

  void log(WorkoutSignalType type, {String? detail}) {
    state = [
      ...state,
      WorkoutSignal(type: type, at: DateTime.now(), detail: detail),
    ];
  }
}

final workoutSignalLogProvider =
    StateNotifierProvider<WorkoutSignalLog, List<WorkoutSignal>>(
      (ref) => WorkoutSignalLog(),
    );
