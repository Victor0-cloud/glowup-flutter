import '../../workout/models/workout_models.dart';
import 'exercise_definition.dart';

/// The RoutinePlayer's single authoritative state machine. Every screen
/// renders purely from this — no screen keeps its own timer or phase flag.
enum RoutinePlayerPhase {
  loading,
  prepare,
  countdown,
  active,
  paused,
  rest,
  restPaused,
  complete,
  exitConfirmation,
  error,
}

enum VoiceMode { coachOn, cuesOnly, silent }

class RoutinePlayerState {
  const RoutinePlayerState({
    required this.routine,
    required this.exerciseIndex,
    required this.phase,
    this.phaseBeforeExit,
    this.countdownSecondsLeft = 3,
    this.activeElapsedMs = 0,
    this.restElapsedMs = 0,
    this.restTotalSeconds = 30,
    this.voiceMode = VoiceMode.coachOn,
    this.musicOn = true,
    this.firedVoiceEvents = const {},
    this.skippedIds = const {},
    this.completedIds = const {},
    required this.startedAt,
    this.finishedAt,
    this.errorMessage,
    this.debugFrameDurationMs,
    this.lastAnnouncedPoseId,
    this.sourceWorkout,
  });

  final List<ExerciseDefinition> routine;

  /// The originating [Workout] (routine name, category, static calorie
  /// estimate) — null for the dev-only QA entry point, which has no real
  /// source workout. Used for the completion summary and workout-history
  /// save; never used for animation/playback (that's driven purely by
  /// [routine]).
  final Workout? sourceWorkout;
  final int exerciseIndex;
  final RoutinePlayerPhase phase;

  /// The phase to return to if [exitConfirmation] is cancelled.
  final RoutinePlayerPhase? phaseBeforeExit;

  final int countdownSecondsLeft;
  final int activeElapsedMs;
  final int restElapsedMs;
  final int restTotalSeconds;
  final VoiceMode voiceMode;
  final bool musicOn;

  /// "$exerciseIndex:$eventName" — every voice event fires at most once per
  /// exercise occurrence, surviving pause/resume, cleared implicitly by
  /// simply never being checked again once exerciseIndex moves on.
  final Set<String> firedVoiceEvents;

  final Set<String> skippedIds;
  final Set<String> completedIds;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final String? errorMessage;

  /// QA-only slow-motion override for bilateral frame animation (Section
  /// 15 — "temporary developer/debug method to slow the animation");
  /// production/normal play always leaves this null.
  final int? debugFrameDurationMs;

  /// The poseId of the last [phaseSyncedVoice] cue spoken during the
  /// current ACTIVE occurrence — lets the controller detect "the current
  /// pose just changed" and speak its cue exactly once per pose-entry
  /// (repeating every cycle), rather than once per exercise like
  /// [firedVoiceEvents]. Reset to null exactly when ACTIVE begins.
  final String? lastAnnouncedPoseId;

  ExerciseDefinition get currentExercise => routine[exerciseIndex];
  ExerciseDefinition? get nextExercise =>
      exerciseIndex + 1 < routine.length ? routine[exerciseIndex + 1] : null;
  bool get isLastExercise => exerciseIndex == routine.length - 1;

  double get activeElapsedSeconds => activeElapsedMs / 1000;
  double get activeRemainingSeconds =>
      (currentExercise.durationSeconds - activeElapsedSeconds).clamp(
        0,
        currentExercise.durationSeconds.toDouble(),
      );
  double get activeProgress => currentExercise.durationSeconds == 0
      ? 1
      : (activeElapsedSeconds / currentExercise.durationSeconds).clamp(0, 1);

  double get restElapsedSeconds => restElapsedMs / 1000;
  double get restRemainingSeconds => (restTotalSeconds - restElapsedSeconds)
      .clamp(0, restTotalSeconds.toDouble());
  double get restProgress => restTotalSeconds == 0
      ? 1
      : (restElapsedSeconds / restTotalSeconds).clamp(0, 1);

  bool eventFired(String eventName) =>
      firedVoiceEvents.contains('$exerciseIndex:$eventName');

  RoutinePlayerState copyWith({
    int? exerciseIndex,
    RoutinePlayerPhase? phase,
    RoutinePlayerPhase? phaseBeforeExit,
    bool clearPhaseBeforeExit = false,
    int? countdownSecondsLeft,
    int? activeElapsedMs,
    int? restElapsedMs,
    int? restTotalSeconds,
    VoiceMode? voiceMode,
    bool? musicOn,
    Set<String>? firedVoiceEvents,
    Set<String>? skippedIds,
    Set<String>? completedIds,
    DateTime? finishedAt,
    String? errorMessage,
    int? debugFrameDurationMs,
    bool clearDebugFrameDurationMs = false,
    String? lastAnnouncedPoseId,
    bool clearLastAnnouncedPoseId = false,
    Workout? sourceWorkout,
  }) {
    return RoutinePlayerState(
      routine: routine,
      sourceWorkout: sourceWorkout ?? this.sourceWorkout,
      exerciseIndex: exerciseIndex ?? this.exerciseIndex,
      phase: phase ?? this.phase,
      phaseBeforeExit: clearPhaseBeforeExit
          ? null
          : (phaseBeforeExit ?? this.phaseBeforeExit),
      countdownSecondsLeft: countdownSecondsLeft ?? this.countdownSecondsLeft,
      activeElapsedMs: activeElapsedMs ?? this.activeElapsedMs,
      restElapsedMs: restElapsedMs ?? this.restElapsedMs,
      restTotalSeconds: restTotalSeconds ?? this.restTotalSeconds,
      voiceMode: voiceMode ?? this.voiceMode,
      musicOn: musicOn ?? this.musicOn,
      firedVoiceEvents: firedVoiceEvents ?? this.firedVoiceEvents,
      skippedIds: skippedIds ?? this.skippedIds,
      completedIds: completedIds ?? this.completedIds,
      startedAt: startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      errorMessage: errorMessage ?? this.errorMessage,
      debugFrameDurationMs: clearDebugFrameDurationMs
          ? null
          : (debugFrameDurationMs ?? this.debugFrameDurationMs),
      lastAnnouncedPoseId: clearLastAnnouncedPoseId
          ? null
          : (lastAnnouncedPoseId ?? this.lastAnnouncedPoseId),
    );
  }
}
