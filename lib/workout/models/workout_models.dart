import 'exercise_models.dart';

/// 31_workout_categories (368:2999-3040) originally showed 6 discipline
/// categories (Yoga/HIIT/Strength/Cardio/Stretch/Meditation) with no real
/// exercise data behind them. Per explicit direction, browsing now uses
/// [ExerciseCategory] instead — the 7-category taxonomy the real 52-
/// exercise library is actually organized by (`exercise_models.dart`) —
/// so every category card opens routines built from real EX001-EX052
/// content rather than a category with nothing real underneath it.
/// Figma's own "Frame" container for the original 6 cards also has a
/// layout bug — all cards export at the identical position (x:0,y:0),
/// stacked on top of each other instead of listed — confirmed by
/// cross-checking get_metadata's raw positions; not relevant to the new
/// 7-category list, which is a real vertical Column, but documented here
/// since it's the reason the original list was never a literal 1:1 port.

/// One exercise inside a [Workout] (368:3094 "Exercise-Row" / 368:3185
/// "Pose-Display"). `poseAssetPath` is a fixed, step-invariant image and
/// is only set for the two legacy yoga exercises Figma exports unique
/// static art for (Sun Salutation, Downward Dog). Real 52-exercise-library
/// exercises instead carry [catalogId] + [hasVerifiedImages] so the pose
/// display can look up the real per-step Figma pose image via
/// [exercisePoseAssetPath] — see that function's doc for the hard rule:
/// no emoji/icon may ever substitute for a missing pose image.
class WorkoutExercise {
  const WorkoutExercise({
    required this.id,
    required this.title,
    required this.durationSeconds,
    this.poseAssetPath,
    this.catalogId,
    this.hasVerifiedImages = false,
    this.playbackType,
    this.reps,
    this.steps = const [],
    this.hasSwitchSide = false,
    this.thumbnailAssetPath,
  });

  /// Builds a session-ready [WorkoutExercise] from a real catalog
  /// [Exercise] (see `exercise_catalog.dart`) — the real bridge between
  /// the 52-exercise library and the workout player, so every routine
  /// exercise carries its actual category-sourced playback type, rep/hold
  /// target, real step captions, switch-side behavior, and (for the 6
  /// verified exercises) real per-step Figma pose images.
  factory WorkoutExercise.fromCatalog(
    Exercise exercise, {
    String? instanceId,
    String? thumbnailAssetPath,
  }) {
    return WorkoutExercise(
      id: instanceId ?? exercise.id,
      catalogId: exercise.id,
      hasVerifiedImages: exercise.hasVerifiedImages,
      title: exercise.name,
      durationSeconds: exercise.durationSeconds,
      playbackType: exercise.playbackType,
      reps: exercise.playbackType == ExercisePlaybackType.reps
          ? exercise.reps
          : null,
      steps: exercise.steps,
      hasSwitchSide: exercise.hasSwitchSide,
      thumbnailAssetPath: thumbnailAssetPath,
    );
  }

  final String id;
  final String title;
  final int durationSeconds;
  final String? poseAssetPath;
  final String? catalogId;
  final bool hasVerifiedImages;
  final ExercisePlaybackType? playbackType;
  final int? reps;
  final List<ExerciseStep> steps;
  final bool hasSwitchSide;

  /// A dedicated routine-detail-thumbnail image, distinct from the
  /// per-step pose sequence (e.g. a wide filmstrip "sequence preview"
  /// composite, not any single approved pose frame) — takes priority over
  /// [resolvePoseAssetPath]'s per-step lookup in [_ExerciseThumbnail]
  /// only; the ACTIVE-phase [PoseDisplayBox] never reads this, so the
  /// live exercise still animates through its real per-step frames. Null
  /// for every exercise whose thumbnail is just its own first/held pose
  /// frame (the default, existing behavior).
  final String? thumbnailAssetPath;

  String get formattedDuration {
    if (durationSeconds < 60) return '$durationSeconds sec';
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return seconds == 0
        ? '$minutes min'
        : '$minutes:${seconds.toString().padLeft(2, '0')} min';
  }
}

enum WorkoutDifficulty { beginner, intermediate, advanced }

extension WorkoutDifficultyLabel on WorkoutDifficulty {
  String get label => switch (this) {
    WorkoutDifficulty.beginner => 'Beginner',
    WorkoutDifficulty.intermediate => 'Intermediate',
    WorkoutDifficulty.advanced => 'Advanced',
  };
}

/// A single workout template (368:3059 "32_workout_detail"). Only
/// [id] == 'morning-yoga-flow' has every field sourced directly from the
/// approved frame (title, description, stats, equipment, all 6 exercise
/// names/durations) — the other 5 (one per remaining category) are
/// reasonable placeholders assembled from real Exercise Sequence Library
/// entries (357:4818), never invented exercise names, matching the same
/// pattern used for Routines' non-Figma-detailed seed routines.
class Workout {
  const Workout({
    required this.id,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.heroAssetPath,
    required this.difficulty,
    required this.calories,
    required this.equipment,
    required this.exercises,
    this.restSecondsOverride,
    this.useCatalogDurations = false,
  });

  final String id;
  final ExerciseCategory category;
  final String title;
  final String subtitle;
  final String heroAssetPath;
  final WorkoutDifficulty difficulty;
  final int calories;
  final String equipment;
  final List<WorkoutExercise> exercises;

  /// Seconds of REST/transition [RoutinePlayerController] inserts between
  /// exercises for this routine specifically — null (the default, every
  /// existing routine) keeps the shared 30-second default exactly as
  /// before. Set only by routines with their own approved transition
  /// timing (e.g. Pre-Swim's 5-second transition) — never a blanket
  /// change to every other routine's rest period.
  final int? restSecondsOverride;

  /// When true, [WorkoutExercise.durationSeconds] on each entry below
  /// (this routine's own catalog-declared duration) overrides the shared
  /// registry [ExerciseDefinition]'s duration for the RoutinePlayer
  /// session — see `_routinePlayerRoutineFor` in app_router.dart. False
  /// (the default, every existing routine) keeps using each exercise's
  /// one shared registry duration exactly as before, so a routine that
  /// reuses another routine's exercise (e.g. Pre-Swim reusing Recovery's
  /// EX049 Figure Four Stretch) can play it at its own approved duration
  /// without changing Recovery's.
  final bool useCatalogDurations;

  /// Raw exercise time, plus (only when [restSecondsOverride] is set)
  /// this routine's own transition time between exercises — for every
  /// other routine this is identical to the old exercises-only sum, since
  /// [restSecondsOverride] is null and adds nothing.
  int get totalSeconds {
    final exerciseSum = exercises.fold(0, (sum, e) => sum + e.durationSeconds);
    final override = restSecondsOverride;
    if (override == null || exercises.length < 2) return exerciseSum;
    return exerciseSum + override * (exercises.length - 1);
  }

  int get totalMinutes => (totalSeconds / 60).round();
}

/// Which of the flow's screens is currently showing — drives navigation
/// inside the active-session sub-flow without re-pushing routes for every
/// exercise transition (32B -> 32C -> 32D -> 32E -> 32C... -> 33A -> 33B).
enum WorkoutPhase { getReady, active, resting, upNext, complete }

const int kRestSeconds = 30;
const int kGetReadySeconds = 3;

/// Per-exercise result captured once a session finishes, backing the real
/// exercise-breakdown list on 33B. Heart-rate/form-score fields Figma
/// shows on that screen (127 BPM, 9.5/10 Form) have no real sensor behind
/// them in this app — those are NOT reproduced here since nothing
/// measures them; only what was actually tracked (name, real elapsed
/// time) is real.
class ExerciseResult {
  const ExerciseResult({
    required this.exercise,
    required this.elapsedSeconds,
    required this.skipped,
    this.note,
  });

  final WorkoutExercise exercise;
  final int elapsedSeconds;
  final bool skipped;

  /// Optional AI Coach reflection saved right after this exercise (see
  /// `ExerciseReflectionCard`) — a human-readable summary of the selected
  /// signals plus any free-text note. Null for every exercise without a
  /// reflection prompt, and null when the prompt was shown but skipped —
  /// skipping a note never removes exercise completion.
  final String? note;
}

class WorkoutSessionResult {
  const WorkoutSessionResult({
    required this.workout,
    required this.startedAt,
    required this.finishedAt,
    required this.exerciseResults,
  });

  final Workout workout;
  final DateTime startedAt;
  final DateTime finishedAt;
  final List<ExerciseResult> exerciseResults;

  Duration get totalDuration => finishedAt.difference(startedAt);
  int get completedCount => exerciseResults.where((r) => !r.skipped).length;
}

/// Live state for an in-progress session. Null when no workout is active
/// — screens that need it (Get Ready/Active/Rest/Up Next) require a
/// non-null session, same guard pattern as [TodayScreen]'s null-BrainContext
/// check.
class WorkoutSessionState {
  const WorkoutSessionState({
    required this.workout,
    required this.phase,
    required this.exerciseIndex,
    required this.remainingSeconds,
    required this.isPaused,
    required this.startedAt,
    this.exerciseElapsedSeconds = const {},
    this.skippedExerciseIds = const {},
  });

  final Workout workout;
  final WorkoutPhase phase;
  final int exerciseIndex;
  final int remainingSeconds;
  final bool isPaused;
  final DateTime startedAt;
  final Map<String, int> exerciseElapsedSeconds;
  final Set<String> skippedExerciseIds;

  WorkoutExercise get currentExercise => workout.exercises[exerciseIndex];
  WorkoutExercise? get nextExercise =>
      exerciseIndex + 1 < workout.exercises.length
      ? workout.exercises[exerciseIndex + 1]
      : null;
  bool get isLastExercise => exerciseIndex == workout.exercises.length - 1;
  double get workoutProgress => (exerciseIndex + 1) / workout.exercises.length;

  WorkoutSessionState copyWith({
    WorkoutPhase? phase,
    int? exerciseIndex,
    int? remainingSeconds,
    bool? isPaused,
    Map<String, int>? exerciseElapsedSeconds,
    Set<String>? skippedExerciseIds,
  }) {
    return WorkoutSessionState(
      workout: workout,
      phase: phase ?? this.phase,
      exerciseIndex: exerciseIndex ?? this.exerciseIndex,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isPaused: isPaused ?? this.isPaused,
      startedAt: startedAt,
      exerciseElapsedSeconds:
          exerciseElapsedSeconds ?? this.exerciseElapsedSeconds,
      skippedExerciseIds: skippedExerciseIds ?? this.skippedExerciseIds,
    );
  }
}
