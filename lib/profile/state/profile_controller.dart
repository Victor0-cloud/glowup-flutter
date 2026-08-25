import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/state/auth_controller.dart';
import '../../onboarding/state/onboarding_controller.dart';
import '../../workout/state/workout_history_controller.dart'
    show sharedPreferencesProvider;
import '../data/profile_repository.dart';
import '../models/profile_models.dart';

class ProfileState {
  const ProfileState({required this.details, required this.settings});

  final ProfileDetails details;
  final AppSettings settings;

  /// A real, honest fraction over fields the user can actually fill in —
  /// never a fabricated number. Counts: name, date of birth, gender,
  /// height, weight, at least one goal is intentionally NOT counted here
  /// (goals live in onboarding and are surfaced on their own row), so this
  /// reflects Edit Profile completion specifically.
  double get completionFraction {
    final fields = [
      details.name,
      details.dateOfBirth,
      details.gender,
      details.heightCm,
      details.weightKg,
    ];
    final filled = fields.where((f) => f != null).length;
    return filled / fields.length;
  }

  int get completionPercent => (completionFraction * 100).round();

  ProfileState copyWith({ProfileDetails? details, AppSettings? settings}) =>
      ProfileState(
        details: details ?? this.details,
        settings: settings ?? this.settings,
      );
}

/// Durable Profile state. Entirely local-only — nothing here ever makes a
/// network call, and opening Profile never calls an AI provider. The one
/// exception is reading the signed-in account's id/name off the existing
/// auth session (already held in memory by [authControllerProvider], not a
/// new network call) — purely to namespace local storage per account and
/// to seed a real display name; see [_init].
class ProfileController extends StateNotifier<AsyncValue<ProfileState>> {
  ProfileController(this._ref) : super(const AsyncLoading()) {
    _init();
    // Re-loads for whichever account is now signed in whenever the
    // authenticated user id actually changes (fresh sign-in mid-session,
    // account switch, or sign-out), not just at app startup — without
    // this, a user who signs in after this controller was already
    // constructed would keep reading/writing the previous (often
    // unscoped) account's local record.
    _ref.listen(authControllerProvider, (previous, next) {
      final previousId = previous?.valueOrNull?.user.id;
      final nextId = next.valueOrNull?.user.id;
      if (previousId != nextId) _init();
    });
  }

  final Ref _ref;
  ProfileRepository? _repo;
  SharedPreferences? _prefs;

  Future<void> get ready => _readyCompleter.future;
  Completer<void> _readyCompleter = Completer<void>();

  /// Synchronous readiness check — lets a router-level reactor bail out
  /// instead of acting on a not-yet-loaded default state (see
  /// `AuthRouterReactor`, which must never navigate based on data that
  /// hasn't finished loading from disk yet).
  bool get isReady => _readyCompleter.isCompleted;

  Future<void> _init() async {
    if (_readyCompleter.isCompleted) _readyCompleter = Completer<void>();
    try {
      final prefs = await _ref.read(sharedPreferencesProvider.future);
      _prefs = prefs;
      // Namespacing storage by the signed-in account's id means two
      // different accounts signed into this app on the same device never
      // inherit each other's local profile data (name, DOB, etc.).
      final authUser = _ref.read(authControllerProvider).valueOrNull?.user;
      final repo = ProfileRepository(prefs, userId: authUser?.id);
      _repo = repo;
      var details = repo.loadDetails();
      if (!repo.hasSavedDetails) {
        // First load ever for this account — seed name/birthday. A real
        // display name from the account's own auth provider (e.g. Google's
        // full_name) always wins over the in-progress onboarding session
        // (which has no persistence of its own and, for an auth-first
        // sign-up, was never even visited). This repository becomes the
        // durable source of truth going forward; this seed never re-runs
        // once a details record exists for this account.
        final onboarding = _ref.read(onboardingControllerProvider);
        final metadata = authUser?.userMetadata;
        final providerName =
            metadata?['full_name'] as String? ?? metadata?['name'] as String?;
        details = ProfileDetails(
          name: providerName ?? onboarding.firstName,
          dateOfBirth: onboarding.dateOfBirth,
        );
        await repo.saveDetails(details);
      }
      // Completing readiness BEFORE the state assignment matters: a
      // StateNotifier's `state =` setter notifies listeners
      // SYNCHRONOUSLY, before this function runs anything after it — a
      // listener (e.g. AuthRouterReactor) that checks `isReady` in
      // reaction to that exact notification must already see it as true,
      // or it bails out and never gets another chance to react.
      if (!_readyCompleter.isCompleted) _readyCompleter.complete();
      state = AsyncValue.data(
        ProfileState(details: details, settings: repo.loadSettings()),
      );
    } catch (e, st) {
      if (!_readyCompleter.isCompleted) _readyCompleter.complete();
      state = AsyncValue.error(e, st);
    } finally {
      if (!_readyCompleter.isCompleted) _readyCompleter.complete();
    }
  }

  Future<void> updateDetails(ProfileDetails details) async {
    final repo = _repo;
    if (repo == null) return;
    await repo.saveDetails(details);
    final current = state.valueOrNull;
    state = AsyncValue.data(
      ProfileState(
        details: details,
        settings: current?.settings ?? repo.loadSettings(),
      ),
    );
  }

  Future<void> updateSettings(AppSettings settings) async {
    final repo = _repo;
    if (repo == null) return;
    await repo.saveSettings(settings);
    final current = state.valueOrNull;
    state = AsyncValue.data(
      ProfileState(
        details: current?.details ?? repo.loadDetails(),
        settings: settings,
      ),
    );
  }

  /// A real, deterministic plain-text export built only from stored data
  /// — never a network upload, same pattern as `CycleController.
  /// exportSummaryText`.
  String exportDataText() {
    final s = state.valueOrNull;
    if (s == null) return '';
    final buffer = StringBuffer('Glow Up — My Data export\n\n');
    buffer.writeln('Profile:');
    if (s.details.name != null) buffer.writeln('  Name: ${s.details.name}');
    if (s.details.dateOfBirth != null) {
      buffer.writeln(
        '  Date of birth: ${s.details.dateOfBirth!.toIso8601String().split('T').first}',
      );
    }
    if (s.details.gender != null) {
      buffer.writeln('  Gender: ${s.details.gender!.label}');
    }
    if (s.details.heightCm != null) {
      buffer.writeln('  Height: ${s.details.heightCm!.toStringAsFixed(1)} cm');
    }
    if (s.details.weightKg != null) {
      buffer.writeln('  Weight: ${s.details.weightKg!.toStringAsFixed(1)} kg');
    }
    buffer.writeln('\nSettings:');
    buffer.writeln('  Units: ${s.settings.units.name}');
    buffer.writeln('  Reminders: ${s.settings.remindersEnabled}');
    buffer.writeln(
      '  Push notifications: ${s.settings.pushNotificationsEnabled}',
    );
    buffer.writeln('  Analytics: ${s.settings.analyticsEnabled}');
    buffer.writeln('  Personalized ads: ${s.settings.personalizedAdsEnabled}');
    buffer.writeln(
      '  AI personalization consent: ${s.settings.aiPersonalizationEnabled}',
    );
    return buffer.toString();
  }

  /// Development-only test reset: clears just this account's local
  /// [ProfileDetails] (name/DOB/gender/height/weight/photo) so a developer
  /// can re-run the fresh-signup flow (AU05 onward) after signing out.
  /// Deliberately narrower than [clearAllLocalData] — it never touches
  /// [AppSettings] or any other module's local history. Callers must gate
  /// this behind a debug-only build check (see Help & Support); it must
  /// never be reachable in a release build.
  Future<void> resetOnboardingTestState() async {
    final repo = _repo;
    if (repo == null) return;
    const empty = ProfileDetails();
    await repo.saveDetails(empty);
    final current = state.valueOrNull;
    state = AsyncValue.data(
      ProfileState(
        details: empty,
        settings: current?.settings ?? repo.loadSettings(),
      ),
    );
  }

  /// "Clear Local Data" / "Delete My Data" — this app has no remote
  /// backend for any of this data (see the module doc comments throughout
  /// `lib/`), so a full local wipe genuinely is the complete, honest
  /// equivalent of "delete my data." Never touches any remote/production
  /// system, because none exists for this data.
  Future<void> clearAllLocalData() async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.clear();
    final repo = ProfileRepository(prefs);
    _repo = repo;
    state = AsyncValue.data(
      const ProfileState(details: ProfileDetails(), settings: AppSettings()),
    );
  }
}

final profileControllerProvider =
    StateNotifierProvider<ProfileController, AsyncValue<ProfileState>>((ref) {
      return ProfileController(ref);
    });
