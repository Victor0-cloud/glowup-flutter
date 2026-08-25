import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/onboarding_profile.dart';

/// Local cache/fallback for onboarding progress — same [SharedPreferences]
/// pattern and per-account key namespacing as `ProfileRepository`, so two
/// different accounts signed into this app on the same device never
/// inherit each other's onboarding progress. The authenticated source of
/// truth is `OnboardingRemoteRepository`; this repository is what lets the
/// app keep working (and resuming correctly) even when that remote call
/// fails or hasn't synced yet.
class OnboardingRepository {
  OnboardingRepository(this._prefs, {String? userId})
    : _key = userId == null
          ? 'onboarding_profile_v1'
          : 'onboarding_profile_v1_$userId';

  final SharedPreferences _prefs;
  final String _key;

  OnboardingProfile? load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return null;
    return OnboardingProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> save(OnboardingProfile profile) {
    return _prefs.setString(_key, jsonEncode(profile.toJson()));
  }

  Future<void> clear() => _prefs.remove(_key);
}
