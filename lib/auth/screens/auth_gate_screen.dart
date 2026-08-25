import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/gradient_background.dart';
import '../../onboarding/state/onboarding_controller.dart';
import '../../profile/state/profile_controller.dart';
import '../state/auth_controller.dart';

/// Whether [ProfileDetails] carries the minimum AU05 requires
/// (date of birth, gender, height — weight stays genuinely optional).
/// This is deliberately a SEPARATE concept from onboarding completeness
/// (see [OnboardingProfile.onboardingComplete]) — a fully authenticated
/// user with a complete basic profile can still have incomplete
/// onboarding (07-13), and this function never claims otherwise.
bool profileSetupComplete(WidgetRef ref) {
  final details = ref.read(profileControllerProvider).valueOrNull?.details;
  if (details == null) return false;
  return details.dateOfBirth != null &&
      details.gender != null &&
      details.heightCm != null;
}

/// The single source of truth for "where should an authenticated session
/// land" — used identically by [AuthGateScreen] (cold start) and
/// `AuthRouterReactor` (every subsequent auth/profile/onboarding change).
/// Only ever called once a session is known to exist. Returns one of:
/// 'profileSetup', 'today', or an [OnboardingStep.name] value naming the
/// 07-13 screen to resume at.
String resolveAuthenticatedDestination(WidgetRef ref) {
  if (!profileSetupComplete(ref)) return 'profileSetup';
  final onboarding = ref.read(onboardingControllerProvider);
  if (onboarding.onboardingComplete) return 'today';
  return onboarding.currentStep.name;
}

/// The real startup gate. Renders nothing but a neutral loading state
/// itself — every destination (AU01 Welcome, AU05 Profile Setup, or the
/// real Today screen) is reached only via [onResolved], so a protected
/// screen is never built/shown before both the Supabase session and the
/// local profile-completion state have actually resolved.
class AuthGateScreen extends ConsumerStatefulWidget {
  const AuthGateScreen({super.key, required this.onResolved});

  /// Called exactly once, the first time a definitive destination is
  /// known — 'welcome', 'profileSetup', or 'today'.
  final ValueChanged<String> onResolved;

  @override
  ConsumerState<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends ConsumerState<AuthGateScreen> {
  bool _resolved = false;
  bool _onboardingReady = false;

  @override
  void initState() {
    super.initState();
    ref.read(onboardingControllerProvider.notifier).ready.then((_) {
      if (!mounted) return;
      setState(() => _onboardingReady = true);
    });
  }

  void _resolve(String destination) {
    if (_resolved) return;
    _resolved = true;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => widget.onResolved(destination),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authControllerProvider);
    final profileAsync = ref.watch(profileControllerProvider);
    ref.watch(onboardingControllerProvider);

    authAsync.whenData((session) {
      if (session == null) {
        _resolve('welcome');
        return;
      }
      // Session exists — still need the real local profile-completion AND
      // onboarding-progress state before deciding between AU05, a 07-13
      // resume step, or Today.
      if (!_onboardingReady) return;
      profileAsync.whenData((_) {
        _resolve(resolveAuthenticatedDestination(ref));
      });
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.purple),
        ),
      ),
    );
  }
}
