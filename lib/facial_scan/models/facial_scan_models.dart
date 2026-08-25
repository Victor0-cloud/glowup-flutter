/// One confirmed Facial Scan wellness check-in. Never a diagnosis, never a
/// generated score — [selfReportedAreas] are the user's *own* selected
/// observations, not an AI assessment (there is no facial analysis
/// provider connected in this build). [imagePath] is a [PrivateImageStore]
/// path, kept in its own `facial` subdirectory, separate from Food Scan's
/// images — null when the user saved a check-in with no photo.
class FacialCheckIn {
  const FacialCheckIn({
    required this.id,
    this.imagePath,
    required this.selfReportedAreas,
    this.note,
    required this.confirmedAt,
  });

  final String id;
  final String? imagePath;

  /// Plain, non-diagnostic, self-reported focus areas (e.g. "Feeling
  /// dry", "Redness") — never a clinical/diagnostic label.
  final List<String> selfReportedAreas;
  final String? note;
  final DateTime confirmedAt;

  bool get hadPhoto => imagePath != null;

  FacialCheckIn copyWith({
    List<String>? selfReportedAreas,
    String? imagePath,
    bool clearImagePath = false,
    String? note,
  }) => FacialCheckIn(
    id: id,
    imagePath: clearImagePath ? null : (imagePath ?? this.imagePath),
    selfReportedAreas: selfReportedAreas ?? this.selfReportedAreas,
    note: note ?? this.note,
    confirmedAt: confirmedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    if (imagePath != null) 'imagePath': imagePath,
    'selfReportedAreas': selfReportedAreas,
    if (note != null) 'note': note,
    'confirmedAt': confirmedAt.toIso8601String(),
  };

  factory FacialCheckIn.fromJson(Map<String, dynamic> j) => FacialCheckIn(
    id: j['id'] as String,
    imagePath: j['imagePath'] as String?,
    selfReportedAreas: (j['selfReportedAreas'] as List).cast<String>(),
    note: j['note'] as String?,
    confirmedAt: DateTime.parse(j['confirmedAt'] as String),
  );
}
