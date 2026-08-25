/// The 7 primary categories from the Exercise Sequence Library handoff
/// table (357:4818) — the authoritative taxonomy for all 52 exercises,
/// confirmed by summing primary-category counts to exactly 52.
enum ExerciseCategory {
  core,
  strength,
  flexibility,
  bedtime,
  mobility,
  cardio,
  recovery,
}

extension ExerciseCategoryData on ExerciseCategory {
  String get label => switch (this) {
    ExerciseCategory.core => 'Core',
    ExerciseCategory.strength => 'Strength',
    ExerciseCategory.flexibility => 'Flexibility',
    ExerciseCategory.bedtime => 'Bedtime',
    ExerciseCategory.mobility => 'Mobility',
    ExerciseCategory.cardio => 'Cardio',
    ExerciseCategory.recovery => 'Recovery',
  };

  String get emoji => switch (this) {
    ExerciseCategory.core => '🎯',
    ExerciseCategory.strength => '💪',
    ExerciseCategory.flexibility => '🤸',
    ExerciseCategory.bedtime => '🌙',
    ExerciseCategory.mobility => '🔄',
    ExerciseCategory.cardio => '🏃',
    ExerciseCategory.recovery => '🧘',
  };

  int get gradientStartHex => switch (this) {
    ExerciseCategory.core => 0xFF1F2068,
    ExerciseCategory.strength => 0xFF1F4068,
    ExerciseCategory.flexibility => 0xFF682049,
    ExerciseCategory.bedtime => 0xFF4F2A68,
    ExerciseCategory.mobility => 0xFF15523C,
    ExerciseCategory.cardio => 0xFF7C3120,
    ExerciseCategory.recovery => 0xFF0D3B4F,
  };

  int get gradientEndHex => switch (this) {
    ExerciseCategory.core => 0xFF0B0C24,
    ExerciseCategory.strength => 0xFF161D33,
    ExerciseCategory.flexibility => 0xFF330A24,
    ExerciseCategory.bedtime => 0xFF1E1236,
    ExerciseCategory.mobility => 0xFF0D2214,
    ExerciseCategory.cardio => 0xFF33120A,
    ExerciseCategory.recovery => 0xFF08222C,
  };
}

/// The 6 playback types from the handoff table's PLAYBACK TYPE column
/// (values there use spaces — "SEQUENCE LOOP"/"SIDE SEQUENCE" — normalized
/// to camelCase enum members here).
enum ExercisePlaybackType {
  reps,
  timer,
  hold,
  sequenceLoop,
  sideSequence,
  breathing,
}

extension ExercisePlaybackTypeLabel on ExercisePlaybackType {
  String get label => switch (this) {
    ExercisePlaybackType.reps => 'Reps',
    ExercisePlaybackType.timer => 'Timer',
    ExercisePlaybackType.hold => 'Hold',
    ExercisePlaybackType.sequenceLoop => 'Sequence Loop',
    ExercisePlaybackType.sideSequence => 'Side Sequence',
    ExercisePlaybackType.breathing => 'Breathing',
  };
}

/// One step in an exercise's real 6-step pose sequence (Figma's
/// "SEQ_EX0XX_F" frames — step label + instruction sentence). Real for the
/// 6 priority exercises this pass pulled directly from Figma (Squat,
/// Jumping Jacks, Push-Ups, Lunges, Plank, Deep Breathing — one per
/// distinct playback type: REPS, TIMER, REPS, SIDE_SEQUENCE, HOLD,
/// BREATHING). Every other exercise gets a single reasonable placeholder
/// step derived from its name — Figma has real 6-step sequences for all
/// 52, but pulling all 312 individually was outside this pass's budget;
/// this is flagged, not hidden.
class ExerciseStep {
  const ExerciseStep({required this.label, required this.instruction});
  final String label;
  final String instruction;
}

/// One exercise from the Exercise Sequence Library (EX001-EX052).
///
/// Pose imagery hard rule (per explicit product override): only the
/// approved, audited Figma pose images may represent an exercise pose —
/// no emoji, icons, or invented art, ever. [hasVerifiedImages] is true
/// only for exercises whose real Figma "Exercise_Image" PNGs (all 6 steps,
/// Women) have been individually fetched from Figma and downloaded to
/// `assets/glow_up/exercises/EX0XX/female/01.png`..`06.png` in this pass —
/// currently EX001, EX007, EX008, EX009, EX010, EX011. Every other
/// exercise has real catalog data (name/category/playback/steps) but no
/// verified image yet; UI must show a clean text treatment for those, not
/// a substitute image or icon. See [exercisePoseAssetPath].
class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.primaryCategory,
    this.secondaryTags = const [],
    required this.playbackType,
    this.hasSixStepSequence = true,
    this.hasSwitchSide = false,
    this.hasRepeat = true,
    this.hasVerifiedImages = false,
    required this.steps,
    this.reps = 12,
    this.durationSeconds = 40,
  });

  final String id;
  final String name;
  final ExerciseCategory primaryCategory;
  final List<ExerciseCategory> secondaryTags;
  final ExercisePlaybackType playbackType;
  final bool hasSixStepSequence;
  final bool hasSwitchSide;
  final bool hasRepeat;
  final bool hasVerifiedImages;
  final List<ExerciseStep> steps;
  final int reps;
  final int durationSeconds;
}

/// Real, locally-downloaded Figma pose-image path for [exercise] at
/// 1-indexed [step] (1-6), or null if no verified image exists for this
/// exercise/step — callers MUST fall back to a clean text treatment
/// (exercise name, no icon/emoji) when this returns null. Glow Up is a
/// women-only app: the approved female pose set is the only exercise
/// asset set that exists or is ever resolved — there is no gender
/// parameter and no other model to fall back to. A missing/unverified
/// asset always surfaces as a clean text treatment (or, in debug builds,
/// the assertion below), never a substitute image.
String? exercisePoseAssetPath(Exercise exercise, {required int step}) {
  if (!exercise.hasVerifiedImages) return null;
  if (step < 1 || step > 6) return null;
  final stepStr = step.toString().padLeft(2, '0');
  final path = 'assets/glow_up/exercises/${exercise.id}/female/$stepStr.png';
  assert(
    path.contains('/female/'),
    'exercisePoseAssetPath must only ever resolve a female asset path — '
    'got "$path" for exercise "${exercise.id}"',
  );
  return path;
}
