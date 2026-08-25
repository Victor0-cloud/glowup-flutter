/// A short-lived fact about "right now" — soreness, mood, energy, hydration
/// stress, sleep quality, illness, schedule conflict. One entry per
/// [userId]+[key]: a new value for the same key *replaces* the old one
/// (this is a snapshot, not a log — the raw history already lives in
/// [LearningEvent]s). [expiresAt] is what makes this genuinely temporary:
/// [CurrentStateRepository.liveEntries] filters out anything past its
/// expiry, so nothing here can silently masquerade as a durable pattern.
class CurrentStateEntry {
  const CurrentStateEntry({
    required this.userId,
    required this.key,
    required this.value,
    required this.recordedAt,
    required this.expiresAt,
    this.sourceEventId,
  });

  final String userId;

  /// e.g. `'soreness:EX021'`, `'mood'`, `'energy'`.
  final String key;

  /// Short structured value — e.g. `'tight'`, `'3'` — never free text.
  final String value;
  final DateTime recordedAt;
  final DateTime expiresAt;
  final String? sourceEventId;

  bool isLiveAt(DateTime now) => now.isBefore(expiresAt);

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'key': key,
    'value': value,
    'recordedAt': recordedAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
    if (sourceEventId != null) 'sourceEventId': sourceEventId,
  };

  factory CurrentStateEntry.fromJson(Map<String, dynamic> j) =>
      CurrentStateEntry(
        userId: j['userId'] as String,
        key: j['key'] as String,
        value: j['value'] as String,
        recordedAt: DateTime.parse(j['recordedAt'] as String),
        expiresAt: DateTime.parse(j['expiresAt'] as String),
        sourceEventId: j['sourceEventId'] as String?,
      );
}
