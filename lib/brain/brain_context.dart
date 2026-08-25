import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../onboarding/models/onboarding_profile.dart';
import '../onboarding/state/onboarding_controller.dart';

/// The Glow Up Brain's initialized context — a pure, computed view over the
/// completed [OnboardingProfile]. This is intentionally NOT a chatbot and
/// contains no hardcoded AI responses: it is the typed data foundation the
/// real recommendation/coaching engine will read from in a later pass
/// (see the architecture report's "Glow Up Brain Architecture" section).
class BrainContext {
  const BrainContext({required this.profile, required this.initializedAt});

  final OnboardingProfile profile;
  final DateTime initializedAt;

  String get greetingName => (profile.firstName?.trim().isNotEmpty ?? false)
      ? profile.firstName!.trim()
      : 'there';

  /// Primary goal drives the first recommendation surfaced on Today —
  /// deterministic ordering by enum declaration, no model call involved.
  Goal? get primaryGoal => profile.goals.isEmpty ? null : profile.goals.first;

  int get goalCount => profile.goals.length;
}

/// Null until 13_finish_setup calls [OnboardingController.completeOnboarding];
/// this is the "Brain initialization complete" signal the Today Dashboard
/// (and eventually Routines/Coach) watch for.
final brainContextProvider = Provider<BrainContext?>((ref) {
  final profile = ref.watch(onboardingControllerProvider);
  if (!profile.onboardingComplete || profile.completedAt == null) return null;
  return BrainContext(profile: profile, initializedAt: profile.completedAt!);
});
