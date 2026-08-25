/// Optional, never required — see [ProfileDetails.gender].
enum Gender { female, male, nonBinary, preferNotToSay }

extension GenderLabel on Gender {
  String get label => switch (this) {
    Gender.female => 'Female',
    Gender.male => 'Male',
    Gender.nonBinary => 'Non-binary',
    Gender.preferNotToSay => 'Prefer not to say',
  };
}

enum AppUnits { imperial, metric }

extension AppUnitsLabel on AppUnits {
  String get label => switch (this) {
    AppUnits.imperial => 'lbs, in, oz',
    AppUnits.metric => 'kg, cm, ml',
  };
}

/// Editable profile details — additive to [OnboardingProfile], not a
/// duplicate of it. Onboarding has no persistence of its own (its
/// [StateNotifier] is in-memory only), so this is the first durable home
/// this data gets; [name]/[dateOfBirth] are seeded once from the
/// in-progress onboarding session the first time this loads (see
/// `ProfileController._init`), never re-synced afterward — editing here
/// is the source of truth from that point on. [gender]/[heightCm]/
/// [weightKg] have no other home anywhere in the app; all fields here are
/// optional, matching the "do not require optional demographic fields"
/// rule.
class ProfileDetails {
  const ProfileDetails({
    this.name,
    this.dateOfBirth,
    this.gender,
    this.heightCm,
    this.weightKg,
    this.photoPath,
  });

  final String? name;
  final DateTime? dateOfBirth;
  final Gender? gender;

  /// Always stored in metric internally; [AppUnits] only controls display.
  final double? heightCm;
  final double? weightKg;

  /// Local file path under this device's private image store (see
  /// `PrivateImageStore.forCategory('profile')`), same pattern as Food/
  /// Facial Scan photos — never a network upload, never a second photo
  /// storage mechanism.
  final String? photoPath;

  ProfileDetails copyWith({
    String? name,
    bool clearName = false,
    DateTime? dateOfBirth,
    Gender? gender,
    bool clearGender = false,
    double? heightCm,
    bool clearHeight = false,
    double? weightKg,
    bool clearWeight = false,
    String? photoPath,
    bool clearPhotoPath = false,
  }) => ProfileDetails(
    name: clearName ? null : (name ?? this.name),
    dateOfBirth: dateOfBirth ?? this.dateOfBirth,
    gender: clearGender ? null : (gender ?? this.gender),
    heightCm: clearHeight ? null : (heightCm ?? this.heightCm),
    weightKg: clearWeight ? null : (weightKg ?? this.weightKg),
    photoPath: clearPhotoPath ? null : (photoPath ?? this.photoPath),
  );

  Map<String, dynamic> toJson() => {
    if (name != null) 'name': name,
    if (dateOfBirth != null) 'dateOfBirth': dateOfBirth!.toIso8601String(),
    if (gender != null) 'gender': gender!.name,
    if (heightCm != null) 'heightCm': heightCm,
    if (weightKg != null) 'weightKg': weightKg,
    if (photoPath != null) 'photoPath': photoPath,
  };

  factory ProfileDetails.fromJson(Map<String, dynamic> j) => ProfileDetails(
    name: j['name'] as String?,
    dateOfBirth: j['dateOfBirth'] == null
        ? null
        : DateTime.parse(j['dateOfBirth'] as String),
    gender: j['gender'] == null
        ? null
        : Gender.values.byName(j['gender'] as String),
    heightCm: (j['heightCm'] as num?)?.toDouble(),
    weightKg: (j['weightKg'] as num?)?.toDouble(),
    photoPath: j['photoPath'] as String?,
  );
}

/// Local app preferences — one shared source read by both the Settings
/// screen and Privacy & Data (never two competing stores for the same
/// toggle). Every field here is a genuine local preference: nothing in
/// this app currently sends push/email notifications or personalized ads,
/// so these toggles govern real stored consent/preference state rather
/// than a live delivery pipeline — same honesty standard as
/// [NotificationPrefs] already applies in onboarding.
class AppSettings {
  const AppSettings({
    this.units = AppUnits.imperial,
    this.remindersEnabled = true,
    this.pushNotificationsEnabled = true,
    this.analyticsEnabled = true,
    this.personalizedAdsEnabled = false,
    this.aiPersonalizationEnabled = true,
  });

  final AppUnits units;
  final bool remindersEnabled;
  final bool pushNotificationsEnabled;
  final bool analyticsEnabled;
  final bool personalizedAdsEnabled;

  /// Consent for the (not-yet-connected, see [[AI Coach]]) Brain to use
  /// stored profile/activity data once it exists — a real, stored consent
  /// flag, not a claim that personalization is already happening.
  final bool aiPersonalizationEnabled;

  AppSettings copyWith({
    AppUnits? units,
    bool? remindersEnabled,
    bool? pushNotificationsEnabled,
    bool? analyticsEnabled,
    bool? personalizedAdsEnabled,
    bool? aiPersonalizationEnabled,
  }) => AppSettings(
    units: units ?? this.units,
    remindersEnabled: remindersEnabled ?? this.remindersEnabled,
    pushNotificationsEnabled:
        pushNotificationsEnabled ?? this.pushNotificationsEnabled,
    analyticsEnabled: analyticsEnabled ?? this.analyticsEnabled,
    personalizedAdsEnabled:
        personalizedAdsEnabled ?? this.personalizedAdsEnabled,
    aiPersonalizationEnabled:
        aiPersonalizationEnabled ?? this.aiPersonalizationEnabled,
  );

  Map<String, dynamic> toJson() => {
    'units': units.name,
    'remindersEnabled': remindersEnabled,
    'pushNotificationsEnabled': pushNotificationsEnabled,
    'analyticsEnabled': analyticsEnabled,
    'personalizedAdsEnabled': personalizedAdsEnabled,
    'aiPersonalizationEnabled': aiPersonalizationEnabled,
  };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
    units: j['units'] == null
        ? AppUnits.imperial
        : AppUnits.values.byName(j['units'] as String),
    remindersEnabled: j['remindersEnabled'] as bool? ?? true,
    pushNotificationsEnabled: j['pushNotificationsEnabled'] as bool? ?? true,
    analyticsEnabled: j['analyticsEnabled'] as bool? ?? true,
    personalizedAdsEnabled: j['personalizedAdsEnabled'] as bool? ?? false,
    aiPersonalizationEnabled: j['aiPersonalizationEnabled'] as bool? ?? true,
  );
}
