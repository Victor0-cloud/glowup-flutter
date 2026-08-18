import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../brain/workout_brain.dart';
import '../models/workout_models.dart';

/// Drives the whole 32b -> 32c -> 32d -> 32e -> ... -> 33a session, one
/// exercise at a time. `exerciseIndex` always refers to the exercise the
/// *current phase is about* — during `active` that's the one running;
/// during `resting`/`upNext` it has already advanced to the next one, so
/// those screens' "Up Next: (name)" content is just `currentExercise`
/// (matches 32d's mock showing "sun salutation completed" + "Up Next:
/// Downward Dog" simultaneously).
class WorkoutSessionController extends StateNotifier<WorkoutSessionState?> {
  WorkoutSessionController(this._log) : super(null);

  final WorkoutSignalLog _log;
  Timer? _timer;
  final Map<String, int> _elapsedOverride = {};
  final Map<String, String> _exerciseNotes = {};

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void startSession(Workout workout) {
    _timer?.cancel();
    _elapsedOverride.clear();
    _exerciseNotes.clear();
    _log.log(WorkoutSignalType.categorySelected, detail: workout.category.name);
    _log.log(WorkoutSignalType.workoutSelected, detail: workout.id);
    _log.log(WorkoutSignalType.workoutStarted, detail: workout.id);
    state = WorkoutSessionState(
      workout: workout,
      phase: WorkoutPhase.getReady,
      exerciseIndex: 0,
      remainingSeconds: kGetReadySeconds,
      isPaused: false,
      startedAt: DateTime.now(),
    );
    _resumeTicking();
  }

  void _resumeTicking() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final s = state;
    if (s == null || s.isPaused) return;
    if (s.phase != WorkoutPhase.getReady && s.phase != WorkoutPhase.active && s.phase != WorkoutPhase.resting) {
      return; // upNext/complete aren't timer-driven
    }
    if (s.remainingSeconds > 1) {
      state = s.copyWith(remainingSeconds: s.remainingSeconds - 1);
      return;
    }
    _onPhaseTimerElapsed();
  }

  void _onPhaseTimerElapsed() {
    final s = state!;
    switch (s.phase) {
      case WorkoutPhase.getReady:
        state = s.copyWith(phase: WorkoutPhase.active, remainingSeconds: s.currentExercise.durationSeconds);
      case WorkoutPhase.active:
        _finishCurrentExercise(skipped: false, elapsedSeconds: s.currentExercise.durationSeconds);
      case WorkoutPhase.resting:
        state = s.copyWith(phase: WorkoutPhase.upNext, remainingSeconds: 0);
      case WorkoutPhase.upNext:
      case WorkoutPhase.complete:
        break;
    }
  }

  void _finishCurrentExercise({required bool skipped, required int elapsedSeconds}) {
    final s = state!;
    final exercise = s.currentExercise;
    _elapsedOverride[exercise.id] = elapsedSeconds;
    final elapsedMap = {...s.exerciseElapsedSeconds, exercise.id: elapsedSeconds};
    final skippedSet = skipped ? {...s.skippedExerciseIds, exercise.id} : s.skippedExerciseIds;
    _log.log(skipped ? WorkoutSignalType.exerciseSkipped : WorkoutSignalType.exerciseCompleted, detail: exercise.id);

    if (s.isLastExercise) {
      _log.log(WorkoutSignalType.workoutCompleted, detail: s.workout.id);
      state = s.copyWith(phase: WorkoutPhase.complete, exerciseElapsedSeconds: elapsedMap, skippedExerciseIds: skippedSet);
      return;
    }
    state = s.copyWith(
      phase: WorkoutPhase.resting,
      exerciseIndex: s.exerciseIndex + 1,
      remainingSeconds: kRestSeconds,
      exerciseElapsedSeconds: elapsedMap,
      skippedExerciseIds: skippedSet,
    );
  }

  /// 32b's "Skip" button — skips the 3-2-1 countdown straight into the
  /// first exercise (not the whole workout).
  void skipGetReady() {
    final s = state;
    if (s == null || s.phase != WorkoutPhase.getReady) return;
    state = s.copyWith(phase: WorkoutPhase.active, remainingSeconds: s.currentExercise.durationSeconds);
  }

  void togglePause() {
    final s = state;
    if (s == null || s.phase != WorkoutPhase.active) return;
    state = s.copyWith(isPaused: !s.isPaused);
  }

  /// 32c's Prev chevron — restarts the previous exercise's timer.
  void previousExercise() {
    final s = state;
    if (s == null || s.phase != WorkoutPhase.active || s.exerciseIndex == 0) return;
    final newIndex = s.exerciseIndex - 1;
    state = s.copyWith(exerciseIndex: newIndex, remainingSeconds: s.workout.exercises[newIndex].durationSeconds, isPaused: false);
  }

  /// 32c's Next chevron — moves on early without marking the exercise
  /// skipped (distinct from "Skip Exercise").
  void nextExercise() {
    final s = state;
    if (s == null || s.phase != WorkoutPhase.active) return;
    final elapsed = s.currentExercise.durationSeconds - s.remainingSeconds;
    _finishCurrentExercise(skipped: false, elapsedSeconds: elapsed);
  }

  /// 32c's "Skip Exercise" text link.
  void skipCurrentExercise() {
    final s = state;
    if (s == null || s.phase != WorkoutPhase.active) return;
    final elapsed = s.currentExercise.durationSeconds - s.remainingSeconds;
    _finishCurrentExercise(skipped: true, elapsedSeconds: elapsed);
  }

  /// 32d's "Skip Rest (+0:30)" button.
  void skipRest() {
    final s = state;
    if (s == null || s.phase != WorkoutPhase.resting) return;
    state = s.copyWith(phase: WorkoutPhase.upNext, remainingSeconds: 0);
  }

  /// 32e's "I'm Ready" button.
  void confirmReadyForNext() {
    final s = state;
    if (s == null || s.phase != WorkoutPhase.upNext) return;
    state = s.copyWith(phase: WorkoutPhase.active, remainingSeconds: s.currentExercise.durationSeconds, isPaused: false);
  }

  /// 32e's own "Skip Exercise" link — skips the previewed exercise before
  /// it ever starts.
  void skipUpNextExercise() {
    final s = state;
    if (s == null || s.phase != WorkoutPhase.upNext) return;
    _log.log(WorkoutSignalType.exerciseSkipped, detail: s.currentExercise.id);
    final skippedSet = {...s.skippedExerciseIds, s.currentExercise.id};
    if (s.isLastExercise) {
      _log.log(WorkoutSignalType.workoutCompleted, detail: s.workout.id);
      state = s.copyWith(phase: WorkoutPhase.complete, skippedExerciseIds: skippedSet);
      return;
    }
    state = s.copyWith(exerciseIndex: s.exerciseIndex + 1, skippedExerciseIds: skippedSet);
  }

  /// Saves an optional post-exercise AI Coach reflection (see
  /// `ExerciseReflectionCard`) for [exerciseId] — logged through the real
  /// [WorkoutSignalLog] seam (same as every other workout signal, no
  /// fabricated AI processing) and attached to this exercise's eventual
  /// [ExerciseResult.note] in [buildResult]. Never required: not calling
  /// this for a given exercise simply leaves its `note` null, and never
  /// affects whether that exercise counts as completed.
  void saveExerciseNote(String exerciseId, String summary) {
    _exerciseNotes[exerciseId] = summary;
    _log.log(WorkoutSignalType.exerciseNoteSaved, detail: '$exerciseId: $summary');
  }

  WorkoutSessionResult? buildResult() {
    final s = state;
    if (s == null) return null;
    final results = <ExerciseResult>[
      for (final exercise in s.workout.exercises)
        if (s.exerciseElapsedSeconds.containsKey(exercise.id))
          ExerciseResult(
            exercise: exercise,
            elapsedSeconds: s.exerciseElapsedSeconds[exercise.id]!,
            skipped: s.skippedExerciseIds.contains(exercise.id),
            note: _exerciseNotes[exercise.id],
          ),
    ];
    return WorkoutSessionResult(workout: s.workout, startedAt: s.startedAt, finishedAt: DateTime.now(), exerciseResults: results);
  }

  void endSession() {
    _timer?.cancel();
    _timer = null;
    state = null;
  }
}

final workoutSessionControllerProvider = StateNotifierProvider<WorkoutSessionController, WorkoutSessionState?>((ref) {
  return WorkoutSessionController(ref.watch(workoutSignalLogProvider.notifier));
});
