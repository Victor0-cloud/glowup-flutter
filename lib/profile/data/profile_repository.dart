import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/profile_models.dart';

/// Durable on-device storage for Profile — same [SharedPreferences]-backed
/// pattern as every other module. Entirely local: never sends this data
/// to any network endpoint.
///
/// When [userId] is supplied (the signed-in account's id), details are
/// stored under a per-account key so two different accounts signed into
/// this app on the same device never see or inherit each other's profile
/// data. [userId] is never itself the account's email/name — just an
/// opaque id used purely to namespace local storage keys.
class ProfileRepository {
  ProfileRepository(this._prefs, {String? userId})
    : _detailsKey = userId == null
          ? 'profile_details_v1'
          : 'profile_details_v1_$userId',
      _settingsKey = 'profile_settings_v1';

  final SharedPreferences _prefs;
  final String _detailsKey;
  final String _settingsKey;

  ProfileDetails loadDetails() {
    final raw = _prefs.getString(_detailsKey);
    if (raw == null) return const ProfileDetails();
    return ProfileDetails.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveDetails(ProfileDetails details) {
    return _prefs.setString(_detailsKey, jsonEncode(details.toJson()));
  }

  AppSettings loadSettings() {
    final raw = _prefs.getString(_settingsKey);
    if (raw == null) return const AppSettings();
    return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveSettings(AppSettings settings) {
    return _prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  /// Whether [loadDetails] has ever been saved before — used once, by
  /// [ProfileController._init], to decide whether to seed name/birthday
  /// from the in-progress onboarding session (only on a genuinely first
  /// load, never overwriting an edit the user already made here).
  bool get hasSavedDetails => _prefs.containsKey(_detailsKey);
}
