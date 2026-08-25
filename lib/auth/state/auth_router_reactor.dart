import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../onboarding/state/onboarding_controller.dart';
import '../../profile/state/profile_controller.dart';
import '../../routing/app_router.dart';
import '../screens/auth_gate_screen.dart' show resolveAuthenticatedDestination;
import 'auth_controller.dart';

/// The real fix for "stuck on AU02 after a genuine session exists":
/// [AuthGateScreen] only ever resolves ONCE, at cold start, and — because
/// `context.go` replaces the navigation stack — is disposed the moment it
/// redirects away. It never sees a session that becomes authenticated
/// LATER, e.g. mid Google sign-in while the user is several screens deep
/// in `/auth/method` -> loopback callback. This widget is embedded once,
/// near the root of the tree (in [GlowUpApp]'s `builder`, never per
/// screen), so it is never disposed by auth-flow navigation and keeps
/// reacting for the app's whole lifetime.
///
/// It only ever redirects OUT of the `/auth/*` flow once a real session
/// resolves — it is deliberately not a blanket route guard (it never
/// touches navigation outside `/auth/*`), so it can't interfere with
/// existing tests that navigate directly to protected routes without
/// going through auth.
class AuthRouterReactor extends ConsumerStatefulWidget {
  const AuthRouterReactor({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<AuthRouterReactor> createState() => _AuthRouterReactorState();
}

class _AuthRouterReactorState extends ConsumerState<AuthRouterReactor> {
  @override
  void initState() {
    super.initState();
    // Covers the case where a session already exists by the time this
    // widget first mounts (e.g. a real Windows-loopback exchange that
    // completed while AuthGateScreen itself was mid-resolution).
    WidgetsBinding.instance.addPostFrameCallback((_) => _react());
  }

  static const _stepRoutes = {
    'goals': AppRoutes.goals,
    'fitnessLevel': AppRoutes.fitnessLevel,
    'schedule': AppRoutes.schedule,
    'notifications': AppRoutes.notifications,
    'healthConnections': AppRoutes.healthConnections,
    'personalization': AppRoutes.personalization,
    'finishSetup': AppRoutes.finishSetup,
  };

  /// Guards against scheduling more than one pending ready-retry at a time
  /// (each `_react()` call while not-ready would otherwise queue its own
  /// `.then`, firing this reactor redundantly many times in a row once
  /// both controllers finish loading).
  bool _retryScheduled = false;

  void _react() {
    if (!mounted) return;
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null) return;

    final profileNotifier = ref.read(profileControllerProvider.notifier);
    final onboardingNotifier = ref.read(onboardingControllerProvider.notifier);
    // Never decide a destination from a not-yet-loaded default state — a
    // real device can take a moment to load profile/onboarding data from
    // disk. A completed load that happens to resolve to the same default
    // value it started from never fires a state-change listener (nothing
    // actually changed), so — unlike the rest of this reactor — readiness
    // is not something `ref.listen` alone can be trusted to re-trigger on.
    // Explicitly wait on the `ready` futures and retry once instead.
    if (!profileNotifier.isReady || !onboardingNotifier.isReady) {
      if (!_retryScheduled) {
        _retryScheduled = true;
        Future.wait([profileNotifier.ready, onboardingNotifier.ready]).then((
          _,
        ) {
          _retryScheduled = false;
          _react();
        });
      }
      return;
    }

    final location = appRouter.state.matchedLocation;
    if (!location.startsWith('/auth')) return;
    // AU06 (Welcome to Glow Up) is a deliberate, user-acknowledged
    // interstitial shown exactly once right after AU05 saves — its own
    // "Go to Dashboard" button is what moves on to 07_goals. Without this
    // exclusion, this reactor would bounce the user away from AU06 the
    // instant the profile becomes complete (the same save that puts them
    // on AU06 in the first place), so AU06 could never actually be seen.
    if (location == AppRoutes.authSuccess) return;

    final destinationToken = resolveAuthenticatedDestination(ref);
    final destination = switch (destinationToken) {
      'profileSetup' => AppRoutes.authProfileSetup,
      'today' => AppRoutes.today,
      _ => _stepRoutes[destinationToken] ?? AppRoutes.today,
    };
    if (location != destination) {
      appRouter.go(destination);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (previous, next) => _react());
    ref.listen(profileControllerProvider, (previous, next) => _react());
    ref.listen(onboardingControllerProvider, (previous, next) => _react());
    return widget.child;
  }
}
