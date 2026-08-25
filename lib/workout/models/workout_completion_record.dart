/// A single completed (or genuinely-interrupted, see [WorkoutCompletionStatus])
/// workout session, durably saved by [WorkoutHistoryRepository] and read by
/// both the Workout Module's own history screens and the AI Coach (see
/// `CoachBrainContext`).
///
/// There is no authentication system anywhere in this app yet (confirmed by
/// audit — no `lib/auth`, no login screen, no user model beyond the single
/// on-device [OnboardingProfile]). [profileId] is therefore always
/// [WorkoutCompletionRecord.localProfileId], a fixed placeholder standing in
/// for "this device's one profile" — not a fabricated multi-user system.
/// Once real auth exists, every stored record can be migrated by setting
/// this field to the real user id; the repository/model shape doesn't need
/// to change.
library;

enum WorkoutCompletionStatus { completed, partial }

/// [challenging] was added additively (no exhaustive `switch` over this
/// enum exists anywhere in the codebase — every call site is either a
/// `.byName()` round-trip or a literal option list) to back the
/// standardized 5-option per-exercise feedback scale (Easy/Good/
/// Challenging/Too Difficult/Pain or Discomfort) without inventing a
/// second, parallel rating enum.
enum WorkoutFeeling { tooEasy, justRight, challenging, tooHard, painDiscomfort }

enum PainSeverity { mild, moderate, severe }

class PainDetails {
  const PainDetails({this.bodyArea, this.severity, this.note});

  final String? bodyArea;
  final PainSeverity? severity;
  final String? note;

  bool get isEmpty => bodyArea == null && severity == null && note == null;

  Map<String, dynamic> toJson() => {
    'bodyArea': bodyArea,
    'severity': severity?.name,
    'note': note,
  };

  factory PainDetails.fromJson(Map<String, dynamic> json) => PainDetails(
    bodyArea: json['bodyArea'] as String?,
    severity: (json['severity'] as String?) == null
        ? null
        : PainSeverity.values.byName(json['severity'] as String),
    note: json['note'] as String?,
  );
}

class WorkoutCompletionRecord {
  const WorkoutCompletionRecord({
    required this.id,
    required this.profileId,
    required this.workoutId,
    required this.workoutName,
    required this.startedAt,
    required this.completedAt,
    required this.totalDurationSeconds,
    required this.completedExerciseIds,
    required this.skippedExerciseIds,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.calories,
    this.feeling,
    this.painDetails,
    this.note,
  });

  /// Stand-in for a real authenticated user id — see the library doc above.
  static const localProfileId = 'local-device-profile';

  final String id;
  final String profileId;
  final String workoutId;
  final String workoutName;
  final DateTime startedAt;
  final DateTime completedAt;
  final int totalDurationSeconds;
  final List<String> completedExerciseIds;
  final List<String> skippedExerciseIds;
  final WorkoutCompletionStatus status;
  final int? calories;
  final WorkoutFeeling? feeling;
  final PainDetails? painDetails;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasFeedback => feeling != null;
  bool get hasPainFlag =>
      feeling == WorkoutFeeling.painDiscomfort &&
      painDetails != null &&
      !painDetails!.isEmpty;

  WorkoutCompletionRecord copyWith({
    WorkoutFeeling? feeling,
    PainDetails? painDetails,
    String? note,
    DateTime? updatedAt,
  }) => WorkoutCompletionRecord(
    id: id,
    profileId: profileId,
    workoutId: workoutId,
    workoutName: workoutName,
    startedAt: startedAt,
    completedAt: completedAt,
    totalDurationSeconds: totalDurationSeconds,
    completedExerciseIds: completedExerciseIds,
    skippedExerciseIds: skippedExerciseIds,
    status: status,
    calories: calories,
    feeling: feeling ?? this.feeling,
    painDetails: painDetails ?? this.painDetails,
    note: note ?? this.note,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'profileId': profileId,
    'workoutId': workoutId,
    'workoutName': workoutName,
    'startedAt': startedAt.toIso8601String(),
    'completedAt': completedAt.toIso8601String(),
    'totalDurationSeconds': totalDurationSeconds,
    'completedExerciseIds': completedExerciseIds,
    'skippedExerciseIds': skippedExerciseIds,
    'status': status.name,
    'calories': calories,
    'feeling': feeling?.name,
    'painDetails': painDetails?.toJson(),
    'note': note,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory WorkoutCompletionRecord.fromJson(Map<String, dynamic> json) =>
      WorkoutCompletionRecord(
        id: json['id'] as String,
        profileId: json['profileId'] as String? ?? localProfileId,
        workoutId: json['workoutId'] as String,
        workoutName: json['workoutName'] as String,
        startedAt: DateTime.parse(json['startedAt'] as String),
        completedAt: DateTime.parse(json['completedAt'] as String),
        totalDurationSeconds: json['totalDurationSeconds'] as int,
        completedExerciseIds: List<String>.from(
          json['completedExerciseIds'] as List,
        ),
        skippedExerciseIds: List<String>.from(
          json['skippedExerciseIds'] as List,
        ),
        status: WorkoutCompletionStatus.values.byName(json['status'] as String),
        calories: json['calories'] as int?,
        feeling: (json['feeling'] as String?) == null
            ? null
            : WorkoutFeeling.values.byName(json['feeling'] as String),
        painDetails: (json['painDetails'] as Map<String, dynamic>?) == null
            ? null
            : PainDetails.fromJson(json['painDetails'] as Map<String, dynamic>),
        note: json['note'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}
