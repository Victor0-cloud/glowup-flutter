/// Shared capability vocabulary for the real analysis provider — the UI
/// always reads this rather than guessing, per the approved provider
/// contract.
enum ScanProviderCapability {
  available,
  unavailable,
  offline,
  providerFailure,
  permissionDenied,
  unsupportedPlatform,
}

/// Thrown when a server response doesn't match the expected typed shape —
/// caught by the calling provider and turned into an honest
/// [ScanProviderCapability.providerFailure] state, never partially
/// trusted or silently coerced.
class ScanAnalysisFormatException implements Exception {
  ScanAnalysisFormatException(this.message);
  final String message;
  @override
  String toString() => 'ScanAnalysisFormatException: $message';
}

/// One food item as returned by analysis — every numeric field is an
/// *estimate*; [confidence] (0.0-1.0, nullable) is the provider's own
/// reported confidence, never invented client-side.
class FoodAnalysisItem {
  const FoodAnalysisItem({
    required this.name,
    this.portion,
    this.calories,
    this.proteinGrams,
    this.carbsGrams,
    this.fatGrams,
    this.confidence,
  });

  final String name;
  final String? portion;
  final int? calories;
  final double? proteinGrams;
  final double? carbsGrams;
  final double? fatGrams;
  final double? confidence;

  static FoodAnalysisItem fromJson(Map<String, dynamic> j) {
    final name = j['name'];
    if (name is! String || name.trim().isEmpty) {
      throw ScanAnalysisFormatException('food item missing a valid name');
    }
    return FoodAnalysisItem(
      name: name.trim(),
      portion: j['portion'] as String?,
      calories: (j['calories'] as num?)?.round(),
      proteinGrams: (j['proteinGrams'] as num?)?.toDouble(),
      carbsGrams: (j['carbsGrams'] as num?)?.toDouble(),
      fatGrams: (j['fatGrams'] as num?)?.toDouble(),
      confidence: (j['confidence'] as num?)?.toDouble(),
    );
  }
}

/// The full result of one Food Scan analysis call — always presented to
/// the user as editable/removable suggestions, never auto-saved (see
/// `FoodScanController.confirmMeal`, unchanged: it is still the only save
/// path, and it still only ever persists the user's *confirmed* items).
class FoodAnalysisResult {
  const FoodAnalysisResult({required this.items, this.qualityNote});

  final List<FoodAnalysisItem> items;
  final String? qualityNote;

  static FoodAnalysisResult fromJson(Map<String, dynamic> j) {
    final rawItems = j['items'];
    if (rawItems is! List) {
      throw ScanAnalysisFormatException('food result missing an items array');
    }
    return FoodAnalysisResult(
      items: rawItems
          .map((e) => FoodAnalysisItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      qualityNote: j['qualityNote'] as String?,
    );
  }
}

/// One plain, non-diagnostic wellness observation. [area] is a fixed
/// short code (e.g. `'hydration'`), [observation] is short, hedged,
/// non-diagnostic wording (server-side prompt/post-filter enforced — see
/// the Edge Function) such as "skin may appear slightly dry."
class FacialObservation {
  const FacialObservation({
    required this.area,
    required this.observation,
    this.confidence,
  });

  final String area;
  final String observation;
  final double? confidence;

  static FacialObservation fromJson(Map<String, dynamic> j) {
    final area = j['area'];
    final observation = j['observation'];
    if (area is! String || area.trim().isEmpty) {
      throw ScanAnalysisFormatException(
        'facial observation missing a valid area',
      );
    }
    if (observation is! String || observation.trim().isEmpty) {
      throw ScanAnalysisFormatException('facial observation missing text');
    }
    return FacialObservation(
      area: area.trim(),
      observation: observation.trim(),
      confidence: (j['confidence'] as num?)?.toDouble(),
    );
  }
}

/// The full result of one Facial Scan analysis call — always non-
/// diagnostic wellness observations plus an image-quality note (lighting/
/// blur/framing), never a score, never a diagnostic label.
class FacialAnalysisResult {
  const FacialAnalysisResult({required this.observations, this.qualityNote});

  final List<FacialObservation> observations;
  final String? qualityNote;

  static FacialAnalysisResult fromJson(Map<String, dynamic> j) {
    final rawObservations = j['observations'];
    if (rawObservations is! List) {
      throw ScanAnalysisFormatException(
        'facial result missing an observations array',
      );
    }
    return FacialAnalysisResult(
      observations: rawObservations
          .map((e) => FacialObservation.fromJson(e as Map<String, dynamic>))
          .toList(),
      qualityNote: j['qualityNote'] as String?,
    );
  }
}
