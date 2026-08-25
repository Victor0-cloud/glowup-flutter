/// One user-entered/edited food item — never a model's raw guess, since
/// there is no automatic detection connected in this build (and even once
/// one exists, this type stores only the *confirmed* result, per the
/// approved spec's "store the confirmed result, not only the model's
/// original detection").
class MealItem {
  const MealItem({
    required this.id,
    required this.name,
    this.portion,
    this.calories,
  });

  final String id;
  final String name;

  /// Free-text portion description (e.g. "1 cup", "2 slices").
  final String? portion;

  /// User-entered estimate only — always presented to the user as an
  /// estimate, never inferred or computed by this app.
  final int? calories;

  MealItem copyWith({
    String? name,
    String? portion,
    bool clearPortion = false,
    int? calories,
    bool clearCalories = false,
  }) => MealItem(
    id: id,
    name: name ?? this.name,
    portion: clearPortion ? null : (portion ?? this.portion),
    calories: clearCalories ? null : (calories ?? this.calories),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (portion != null) 'portion': portion,
    if (calories != null) 'calories': calories,
  };

  factory MealItem.fromJson(Map<String, dynamic> j) => MealItem(
    id: j['id'] as String,
    name: j['name'] as String,
    portion: j['portion'] as String?,
    calories: j['calories'] as int?,
  );
}

/// One confirmed Food Scan / manual meal entry. [imagePath] is a
/// [PrivateImageStore] path (never a public asset path, never the
/// original picked filename) — null for a pure manual entry with no
/// photo at all.
class FoodScanEntry {
  const FoodScanEntry({
    required this.id,
    required this.items,
    this.imagePath,
    this.note,
    required this.confirmedAt,
  });

  final String id;
  final List<MealItem> items;
  final String? imagePath;
  final String? note;
  final DateTime confirmedAt;

  bool get hadPhoto => imagePath != null;

  /// Null (not zero) unless every item has its own estimate — never
  /// invents a total from partial data.
  int? get totalEstimatedCalories {
    if (items.isEmpty || items.any((i) => i.calories == null)) return null;
    return items.fold<int>(0, (sum, i) => sum + i.calories!);
  }

  FoodScanEntry copyWith({
    List<MealItem>? items,
    String? imagePath,
    bool clearImagePath = false,
    String? note,
  }) => FoodScanEntry(
    id: id,
    items: items ?? this.items,
    imagePath: clearImagePath ? null : (imagePath ?? this.imagePath),
    note: note ?? this.note,
    confirmedAt: confirmedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'items': items.map((i) => i.toJson()).toList(),
    if (imagePath != null) 'imagePath': imagePath,
    if (note != null) 'note': note,
    'confirmedAt': confirmedAt.toIso8601String(),
  };

  factory FoodScanEntry.fromJson(Map<String, dynamic> j) => FoodScanEntry(
    id: j['id'] as String,
    items: (j['items'] as List)
        .map((e) => MealItem.fromJson(e as Map<String, dynamic>))
        .toList(),
    imagePath: j['imagePath'] as String?,
    note: j['note'] as String?,
    confirmedAt: DateTime.parse(j['confirmedAt'] as String),
  );
}
