import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/state/auth_controller.dart';
import '../../workout/state/workout_history_controller.dart'
    show sharedPreferencesProvider;
import '../data/onboarding_remote_repository.dart';
import '../data/onboarding_repository.dart';
import '../models/onboarding_profile.dart';

/// Holds the in-progress (and, after 13_finish_setup, completed)
/// [OnboardingProfile] for the whole onboarding flow. Persisted per
/// account — see [OnboardingRepository] (local cache) and
/// [OnboardingRemoteRepository] (the authenticated source of truth) — so
/// a user who closes the app mid-flow resumes at [OnboardingProfile.
/// currentStep] instead of restarting or being silently dropped onto
/// Today. Living in a provider (not per-screen state) is what makes "back
/// preserves what you entered" free: a route can be popped and re-pushed
/// and this survives.
class OnboardingController extends StateNotifier<OnboardingProfile> {
  OnboardingController(this._ref) : super(const OnboardingProfile()) {
    _init();
    // Re-loads for whichever account is now signed in whenever the
    // authenticated user id actually changes (fresh sign-in mid-session,
    // account switch, or sign-out) — not just at app startup. Without
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
  OnboardingRepository? _repo;
  String? _userId;
  final _remote = OnboardingRemoteRepository();

  Future<void> get ready => _readyCompleter.future;
  Completer<void> _readyCompleter = Completer<void>();

  /// Synchronous readiness check — lets a router-level reactor bail out
  /// instead of acting on a not-yet-loaded default state (see
  /// `AuthRouterReactor`, which must never navigate based on data that
  /// hasn't finished loading from disk yet).
  bool get isReady => _readyCompleter.isCompleted;

  /// True whenever a mutator runs while a load started by [_init] is still
  /// in flight — reset at the start of every [_init] call. Guards against
  /// a real, newer in-memory change (e.g. a caller that mutates state
  /// immediately after construction, before the async load has had a
  /// chance to resolve) being silently overwritten the moment that load
  /// finishes.
  bool _dirtySinceInitStarted = false;

  Future<void> _init() async {
    if (_readyCompleter.isCompleted) _readyCompleter = Completer<void>();
    _dirtySinceInitStarted = false;
    try {
      final prefs = await _ref.read(sharedPreferencesProvider.future);
      final userId = _ref.read(authControllerProvider).valueOrNull?.user.id;
      _userId = userId;
      final repo = OnboardingRepository(prefs, userId: userId);
      _repo = repo;

      // Supabase is the source of truth for an authenticated user when
      // reachable; the local cache is what keeps this working the rest of
      // the time (offline, migration not yet applied, or unauthenticated).
      OnboardingProfile? loaded;
      if (userId != null) {
        loaded = await _remote.load(userId);
      }
      loaded ??= repo.load();
      if (!_dirtySinceInitStarted) {
        state = loaded ?? const OnboardingProfile();
      }
    } finally {
      // Completing readiness happens regardless of whether `state` above
      // actually changed value (e.g. a load that resolves back to the same
      // default never fires a state-change listener) — callers that need
      // to react to "loading finished" must await/chain off `ready`
      // itself (see AuthRouterReactor), never assume a listener firing on
      // the state alone.
      if (!_readyCompleter.isCompleted) _readyCompleter.complete();
    }
  }

  Future<void> _persist() async {
    _dirtySinceInitStarted = true;
    await _repo?.save(state);
    final userId = _userId;
    if (userId != null) {
      // Fire-and-forget: never blocks the UI on network latency, and a
      // failure here is silently absorbed by the local cache above.
      unawaited(_remote.save(userId, state));
    }
  }

  void setAuthProvider(AuthProvider provider) {
    state = state.copyWith(
      authProvider: provider,
      accountCreatedAt: DateTime.now(),
    );
    _persist();
  }

  void setPersonalInfo({
    required String firstName,
    required DateTime dateOfBirth,
  }) {
    state = state.copyWith(firstName: firstName, dateOfBirth: dateOfBirth);
    _persist();
  }

  /// Updates only the first name, never touching [OnboardingProfile.
  /// dateOfBirth] — used while the user is still typing their name and
  /// hasn't chosen a birth date yet, so a real birth date is never
  /// fabricated just because the name field changed.
  void setFirstName(String firstName) {
    state = state.copyWith(firstName: firstName);
    _persist();
  }

  void toggleGoal(Goal goal) {
    final goals = {...state.goals};
    if (!goals.remove(goal)) goals.add(goal);
    state = state.copyWith(goals: goals);
    _persist();
  }

  void setFitnessLevel(FitnessLevel level) {
    state = state.copyWith(fitnessLevel: level);
    _persist();
  }

  void setScheduleWindow(ScheduleWindow window) {
    state = state.copyWith(scheduleWindow: window);
    _persist();
  }

  void updateNotifications(NotificationPrefs prefs) {
    state = state.copyWith(notifications: prefs);
    _persist();
  }

  void updateHealthConnections(HealthConnections connections) {
    state = state.copyWith(healthConnections: connections);
    _persist();
  }

  /// Called when the user taps "Next"/"Continue" on a 07-12 screen — marks
  /// [next] as where to resume if the app closes before finishing. Never
  /// called by back navigation, so backing up never regresses progress.
  void advanceStep(OnboardingStep next) {
    state = state.copyWith(currentStep: next);
    _persist();
  }

  /// Called from 13_finish_setup — this is what creates the initialized
  /// user state the Today experience (and the Brain) require to exist.
  /// The ONLY place [OnboardingProfile.onboardingComplete] is ever set
  /// true — AU06 must never call this.
  void completeOnboarding() {
    state = state.copyWith(
      onboardingComplete: true,
      completedAt: DateTime.now(),
    );
    _persist();
  }

  /// Profile → Help & Support "Log Out" / "Delete Account" — clears the
  /// in-memory view back to a fresh, empty [OnboardingProfile] so a
  /// different account signing in next never sees this account's
  /// progress. The signed-out account's own persisted record (local +
  /// remote) is left intact so it resumes correctly if they sign back in.
  void reset() {
    state = const OnboardingProfile();
  }
}

final onboardingControllerProvider =
    StateNotifierProvider<OnboardingController, OnboardingProfile>((ref) {
      return OnboardingController(ref);
    });
