/// Self-reported flow level for one day — never inferred, always exactly
/// what the user selected.
enum FlowLevel { spotting, light, medium, heavy }

extension FlowLevelLabel on FlowLevel {
  String get label => switch (this) {
    FlowLevel.spotting => 'Spotting',
    FlowLevel.light => 'Light',
    FlowLevel.medium => 'Medium',
    FlowLevel.heavy => 'Heavy',
  };
}

/// Fixed-vocabulary symptom chips — never free text, so this can never
/// become a place personal narrative accidentally leaks into a Brain
/// event (the day entry's optional [CycleDayEntry.note] stays local-only
/// and is never placed in any event payload).
const kCycleSymptoms = [
  'Cramps',
  'Bloating',
  'Headache',
  'Fatigue',
  'Breast tenderness',
  'Back pain',
  'Acne',
  'Nausea',
  'Cravings',
];

const kCycleMoods = [
  'Calm',
  'Happy',
  'Irritable',
  'Anxious',
  'Sad',
  'Energized',
];

/// One period's real boundary — [endDate] is null while the period is
/// still ongoing (the user hasn't logged an end date yet).
class PeriodEntry {
  const PeriodEntry({required this.id, required this.startDate, this.endDate});

  final String id;
  final DateTime startDate;
  final DateTime? endDate;

  bool get isOngoing => endDate == null;
  int? get lengthInDays =>
      endDate == null ? null : endDate!.difference(startDate).inDays + 1;

  PeriodEntry copyWith({DateTime? endDate, bool clearEndDate = false}) =>
      PeriodEntry(
        id: id,
        startDate: startDate,
        endDate: clearEndDate ? null : (endDate ?? this.endDate),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'startDate': startDate.toIso8601String(),
    if (endDate != null) 'endDate': endDate!.toIso8601String(),
  };

  factory PeriodEntry.fromJson(Map<String, dynamic> j) => PeriodEntry(
    id: j['id'] as String,
    startDate: DateTime.parse(j['startDate'] as String),
    endDate: j['endDate'] == null
        ? null
        : DateTime.parse(j['endDate'] as String),
  );
}

/// One calendar day's optional self-reported entry — flow/symptoms/mood/
/// energy/sleep/note. At most one entry per calendar day (upserted by
/// date, matching the rest of this app's daily-log conventions).
class CycleDayEntry {
  const CycleDayEntry({
    required this.date,
    this.flow,
    this.symptoms = const {},
    this.mood,
    this.energyLevel,
    this.sleepQuality,
    this.painIntensity,
    this.note,
  });

  final DateTime date;
  final FlowLevel? flow;
  final Set<String> symptoms;
  final String? mood;

  /// 1 (lowest) - 5 (highest), self-reported.
  final int? energyLevel;

  /// 1 (poor) - 5 (great), self-reported.
  final int? sleepQuality;

  /// 0 (mild) - 10 (severe), self-reported — approved Daily Check-In
  /// (PC05) pain-intensity slider. Never inferred from symptoms.
  final int? painIntensity;

  /// Private, local-only note — never placed in a Brain event payload.
  final String? note;

  String get dateKey =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  CycleDayEntry copyWith({
    FlowLevel? flow,
    bool clearFlow = false,
    Set<String>? symptoms,
    String? mood,
    bool clearMood = false,
    int? energyLevel,
    bool clearEnergyLevel = false,
    int? sleepQuality,
    bool clearSleepQuality = false,
    int? painIntensity,
    bool clearPainIntensity = false,
    String? note,
    bool clearNote = false,
  }) => CycleDayEntry(
    date: date,
    flow: clearFlow ? null : (flow ?? this.flow),
    symptoms: symptoms ?? this.symptoms,
    mood: clearMood ? null : (mood ?? this.mood),
    energyLevel: clearEnergyLevel ? null : (energyLevel ?? this.energyLevel),
    sleepQuality: clearSleepQuality
        ? null
        : (sleepQuality ?? this.sleepQuality),
    painIntensity: clearPainIntensity
        ? null
        : (painIntensity ?? this.painIntensity),
    note: clearNote ? null : (note ?? this.note),
  );

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    if (flow != null) 'flow': flow!.name,
    if (symptoms.isNotEmpty) 'symptoms': symptoms.toList(),
    if (mood != null) 'mood': mood,
    if (energyLevel != null) 'energyLevel': energyLevel,
    if (sleepQuality != null) 'sleepQuality': sleepQuality,
    if (painIntensity != null) 'painIntensity': painIntensity,
    if (note != null) 'note': note,
  };

  factory CycleDayEntry.fromJson(Map<String, dynamic> j) => CycleDayEntry(
    date: DateTime.parse(j['date'] as String),
    flow: j['flow'] == null
        ? null
        : FlowLevel.values.byName(j['flow'] as String),
    symptoms: ((j['symptoms'] as List?)?.cast<String>() ?? const []).toSet(),
    mood: j['mood'] as String?,
    energyLevel: j['energyLevel'] as int?,
    sleepQuality: j['sleepQuality'] as int?,
    painIntensity: j['painIntensity'] as int?,
    note: j['note'] as String?,
  );
}

/// Per-module opt-in/setup state (approved design family "47 Period
/// Tracker", PC02/PC09) — additive to the existing [CycleDayEntry]/
/// [PeriodEntry] records, never a replacement. [trackingEnabled] gates
/// whether Cycle Home (vs the awareness opt-in) is shown; [trackingDeclined]
/// records "Not applicable to me" so that choice isn't re-asked every
/// visit, while still leaving the door open (Profile/Settings can always
/// re-enable). `aiMemoryConsent` defaults false, matching the approved
/// PC09 screen's default-off toggle — cycle data never reaches the Brain
/// without this being explicitly turned on.
class CycleSettings {
  const CycleSettings({
    this.trackingEnabled = false,
    this.trackingDeclined = false,
    this.typicalCycleDays,
    this.typicalPeriodDays,
    this.cycleAwareSuggestions = true,
    this.remindersEnabled = true,
    this.aiMemoryConsent = false,
  });

  final bool trackingEnabled;
  final bool trackingDeclined;

  /// 15-60 per the approved data contract; null until the user enters one.
  final int? typicalCycleDays;

  /// 1-15 per the approved data contract; null until the user enters one.
  final int? typicalPeriodDays;

  final bool cycleAwareSuggestions;
  final bool remindersEnabled;
  final bool aiMemoryConsent;

  CycleSettings copyWith({
    bool? trackingEnabled,
    bool? trackingDeclined,
    int? typicalCycleDays,
    bool clearTypicalCycleDays = false,
    int? typicalPeriodDays,
    bool clearTypicalPeriodDays = false,
    bool? cycleAwareSuggestions,
    bool? remindersEnabled,
    bool? aiMemoryConsent,
  }) => CycleSettings(
    trackingEnabled: trackingEnabled ?? this.trackingEnabled,
    trackingDeclined: trackingDeclined ?? this.trackingDeclined,
    typicalCycleDays: clearTypicalCycleDays
        ? null
        : (typicalCycleDays ?? this.typicalCycleDays),
    typicalPeriodDays: clearTypicalPeriodDays
        ? null
        : (typicalPeriodDays ?? this.typicalPeriodDays),
    cycleAwareSuggestions: cycleAwareSuggestions ?? this.cycleAwareSuggestions,
    remindersEnabled: remindersEnabled ?? this.remindersEnabled,
    aiMemoryConsent: aiMemoryConsent ?? this.aiMemoryConsent,
  );

  Map<String, dynamic> toJson() => {
    'trackingEnabled': trackingEnabled,
    'trackingDeclined': trackingDeclined,
    if (typicalCycleDays != null) 'typicalCycleDays': typicalCycleDays,
    if (typicalPeriodDays != null) 'typicalPeriodDays': typicalPeriodDays,
    'cycleAwareSuggestions': cycleAwareSuggestions,
    'remindersEnabled': remindersEnabled,
    'aiMemoryConsent': aiMemoryConsent,
  };

  factory CycleSettings.fromJson(Map<String, dynamic> j) => CycleSettings(
    trackingEnabled: j['trackingEnabled'] as bool? ?? false,
    trackingDeclined: j['trackingDeclined'] as bool? ?? false,
    typicalCycleDays: j['typicalCycleDays'] as int?,
    typicalPeriodDays: j['typicalPeriodDays'] as int?,
    cycleAwareSuggestions: j['cycleAwareSuggestions'] as bool? ?? true,
    remindersEnabled: j['remindersEnabled'] as bool? ?? true,
    aiMemoryConsent: j['aiMemoryConsent'] as bool? ?? false,
  );
}

/// PC07 Daily Notebook's own "how did this day feel" state — distinct from
/// [CycleDayEntry.mood] (energy/mood/symptoms tracking): this is the
/// broader daily-wellness feeling captured from any Glow Up module, per
/// the approved data contract's separate `dailyWellnessRecord` type.
enum Feeling { happy, sad, pain, menstrualPain }

extension FeelingLabel on Feeling {
  String get label => switch (this) {
    Feeling.happy => 'Happy',
    Feeling.sad => 'Sad',
    Feeling.pain => 'Pain',
    Feeling.menstrualPain => 'Menstrual pain',
  };

  String get emoji => switch (this) {
    Feeling.happy => '😊',
    Feeling.sad => '😞',
    Feeling.pain => '😣',
    Feeling.menstrualPain => '🩸',
  };
}

/// One calendar day's Daily Notebook entry (PC07) — a private free-text
/// note plus which existing modules' same-day real records the woman
/// chose to link, and separate, revocable AI-memory consent for just this
/// note. `linkedX` flags reference real same-day data from each module's
/// own controller (Water/Workout/Food/Facial Scan/Cycle) — they are never
/// a second copy of that data, only a boolean "include this in my
/// ecosystem summary" flag. At most one entry per calendar day, same
/// upsert-by-date convention as [CycleDayEntry].
class DailyNotebookEntry {
  const DailyNotebookEntry({
    required this.date,
    this.feeling,
    this.note,
    this.aiMemoryConsent = false,
    this.linkedWorkout = false,
    this.linkedFood = false,
    this.linkedWater = false,
    this.linkedSkin = false,
    this.linkedCycle = false,
  });

  final DateTime date;
  final Feeling? feeling;

  /// Private, local-only note — never placed in a Brain event payload
  /// unless [aiMemoryConsent] is explicitly true for this entry.
  final String? note;
  final bool aiMemoryConsent;
  final bool linkedWorkout;
  final bool linkedFood;
  final bool linkedWater;
  final bool linkedSkin;
  final bool linkedCycle;

  String get dateKey =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  DailyNotebookEntry copyWith({
    Feeling? feeling,
    bool clearFeeling = false,
    String? note,
    bool clearNote = false,
    bool? aiMemoryConsent,
    bool? linkedWorkout,
    bool? linkedFood,
    bool? linkedWater,
    bool? linkedSkin,
    bool? linkedCycle,
  }) => DailyNotebookEntry(
    date: date,
    feeling: clearFeeling ? null : (feeling ?? this.feeling),
    note: clearNote ? null : (note ?? this.note),
    aiMemoryConsent: aiMemoryConsent ?? this.aiMemoryConsent,
    linkedWorkout: linkedWorkout ?? this.linkedWorkout,
    linkedFood: linkedFood ?? this.linkedFood,
    linkedWater: linkedWater ?? this.linkedWater,
    linkedSkin: linkedSkin ?? this.linkedSkin,
    linkedCycle: linkedCycle ?? this.linkedCycle,
  );

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    if (feeling != null) 'feeling': feeling!.name,
    if (note != null) 'note': note,
    'aiMemoryConsent': aiMemoryConsent,
    'linkedWorkout': linkedWorkout,
    'linkedFood': linkedFood,
    'linkedWater': linkedWater,
    'linkedSkin': linkedSkin,
    'linkedCycle': linkedCycle,
  };

  factory DailyNotebookEntry.fromJson(Map<String, dynamic> j) =>
      DailyNotebookEntry(
        date: DateTime.parse(j['date'] as String),
        feeling: j['feeling'] == null
            ? null
            : Feeling.values.byName(j['feeling'] as String),
        note: j['note'] as String?,
        aiMemoryConsent: j['aiMemoryConsent'] as bool? ?? false,
        linkedWorkout: j['linkedWorkout'] as bool? ?? false,
        linkedFood: j['linkedFood'] as bool? ?? false,
        linkedWater: j['linkedWater'] as bool? ?? false,
        linkedSkin: j['linkedSkin'] as bool? ?? false,
        linkedCycle: j['linkedCycle'] as bool? ?? false,
      );
}
