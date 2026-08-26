/// One completed walk session — every field is a real, measured value
/// (never invented). [steps]/[distanceMeters]/[averagePaceSecondsPerKm]
/// are null when the underlying sensor/GPS genuinely wasn't available for
/// that session, an honest partial record rather than a guessed number.
class WalkSession {
  const WalkSession({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.durationSeconds,
    this.steps,
    this.distanceMeters,
    this.averagePaceSecondsPerKm,
    this.routineId,
  });

  final String id;
  final DateTime startedAt;
  final DateTime endedAt;
  final int durationSeconds;
  final int? steps;
  final double? distanceMeters;
  final double? averagePaceSecondsPerKm;

  /// One of [kWalkRoutines]' ids, or null for an open-ended walk.
  final String? routineId;

  factory WalkSession.fromJson(Map<String, dynamic> j) => WalkSession(
    id: j['id'] as String,
    startedAt: DateTime.parse(j['startedAt'] as String),
    endedAt: DateTime.parse(j['endedAt'] as String),
    durationSeconds: j['durationSeconds'] as int,
    steps: j['steps'] as int?,
    distanceMeters: (j['distanceMeters'] as num?)?.toDouble(),
    averagePaceSecondsPerKm: (j['averagePaceSecondsPerKm'] as num?)
        ?.toDouble(),
    routineId: j['routineId'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'startedAt': startedAt.toIso8601String(),
    'endedAt': endedAt.toIso8601String(),
    'durationSeconds': durationSeconds,
    if (steps != null) 'steps': steps,
    if (distanceMeters != null) 'distanceMeters': distanceMeters,
    if (averagePaceSecondsPerKm != null)
      'averagePaceSecondsPerKm': averagePaceSecondsPerKm,
    if (routineId != null) 'routineId': routineId,
  };
}

/// A fixed duration-preset walk — a target time only, never a promised
/// step count (Section 11's own rule: "do not promise a specific number
/// of steps in advance").
class WalkRoutine {
  const WalkRoutine({
    required this.id,
    required this.title,
    required this.durationMinutes,
  });

  final String id;
  final String title;
  final int durationMinutes;
}

const kWalkRoutines = [
  WalkRoutine(id: 'walk_5min', title: '5-Minute Reset Walk', durationMinutes: 5),
  WalkRoutine(id: 'walk_10min', title: '10-Minute Easy Walk', durationMinutes: 10),
  WalkRoutine(id: 'walk_20min', title: '20-Minute Daily Walk', durationMinutes: 20),
  WalkRoutine(id: 'walk_30min', title: '30-Minute Brisk Walk', durationMinutes: 30),
  WalkRoutine(id: 'walk_recovery', title: 'Recovery Walk', durationMinutes: 15),
  WalkRoutine(
    id: 'walk_evening',
    title: 'Evening Wind-Down Walk',
    durationMinutes: 15,
  ),
];

/// The live state of an in-progress (or just-finished) walk session — a
/// pure UI/session model, never persisted directly (a finished session is
/// converted into a [WalkSession] and saved via `WalkingRepository`).
enum WalkSessionStatus { idle, active, paused, finished }
