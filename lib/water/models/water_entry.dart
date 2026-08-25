/// Display/input unit for water amounts. Every entry is stored canonically
/// in [WaterEntry.amountMl] regardless of the unit the user typed it in —
/// [WaterUnit] only affects how a value is entered/displayed, never how
/// it's persisted, so switching units never rewrites history.
enum WaterUnit { ml, flOz }

/// 1 US fluid ounce in milliliters (standard conversion factor).
const kMlPerFlOz = 29.5735;

extension WaterUnitConversion on WaterUnit {
  double toMl(double amount) => switch (this) {
    WaterUnit.ml => amount,
    WaterUnit.flOz => amount * kMlPerFlOz,
  };

  double fromMl(double ml) => switch (this) {
    WaterUnit.ml => ml,
    WaterUnit.flOz => ml / kMlPerFlOz,
  };

  String get label => switch (this) {
    WaterUnit.ml => 'ml',
    WaterUnit.flOz => 'fl oz',
  };
}

/// One logged water intake entry — canonically stored in milliliters
/// (previously glasses; migrated so the app has a real, unit-agnostic
/// source of truth that both ml and fl oz displays convert from, per the
/// approved Water Tracker spec's quick-add amounts being ml-denominated).
/// [label] is optional free text the user may attach (e.g. "with lunch").
class WaterEntry {
  const WaterEntry({
    required this.id,
    required this.amountMl,
    required this.at,
    this.label,
  });

  final String id;
  final double amountMl;
  final DateTime at;
  final String? label;

  bool isOnDate(DateTime date) =>
      at.year == date.year && at.month == date.month && at.day == date.day;

  WaterEntry copyWith({
    String? id,
    double? amountMl,
    DateTime? at,
    String? label,
  }) => WaterEntry(
    id: id ?? this.id,
    amountMl: amountMl ?? this.amountMl,
    at: at ?? this.at,
    label: label ?? this.label,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'amountMl': amountMl,
    'at': at.toIso8601String(),
    if (label != null) 'label': label,
  };

  factory WaterEntry.fromJson(Map<String, dynamic> json) => WaterEntry(
    id: json['id'] as String,
    amountMl: (json['amountMl'] as num).toDouble(),
    at: DateTime.parse(json['at'] as String),
    label: json['label'] as String?,
  );
}
