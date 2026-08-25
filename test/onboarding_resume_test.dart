// Covers the restored 07-13 onboarding sequence (Option C, per the owner-
// approved canonical-flow audit): AU06 -> 07 -> ... -> 13 -> Today, resume
// from the correct step after closing the app mid-flow, back navigation
// without loops or lost answers, onboarding-completion staying a concept
// separate from AU05's "basic profile" completeness, and an existing
// authenticated test account never getting corrupted by these changes.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:glow_up/app/glow_up_app.dart';
import 'package:glow_up/auth/state/auth_controller.dart';
import 'package:glow_up/onboarding/data/onboarding_repository.dart';
import 'package:glow_up/onboarding/models/onboarding_profile.dart';
import 'package:glow_up/onboarding/state/onboarding_controller.dart';
import 'package:glow_up/profile/models/profile_models.dart';
import 'package:glow_up/profile/state/profile_controller.dart';
import 'package:glow_up/routing/app_router.dart';

User _fakeUser() => User(
  id: 'fake-user-id',
  appMetadata: const {},
  userMetadata: const {'full_name': 'Riley Test'},
  aud: 'authenticated',
  createdAt: DateTime.now().toIso8601String(),
);

Session _fakeSession() => Session(
  accessToken: 'fake-access-token',
  tokenType: 'bearer',
  user: _fakeUser(),
);

/// Sets the auth session BEFORE ever reading [profileControllerProvider]/
/// [onboardingControllerProvider] — matching the real app's actual causal
/// order (a real account is always authenticated first; onboarding data
/// for that account is built up afterward). Both controllers re-init
/// whenever the authenticated user id changes (see their `ref.listen` in
/// each controller), so mutating state and only THEN authenticating would
/// have the second init silently reload/clobber those mutations — doing
/// it in the real order avoids that entirely.
ProviderContainer _authenticatedContainer() {
  final container = ProviderContainer(
    overrides: [authControllerProvider.overrideWith((ref) => AuthController())],
  );
  container.read(authControllerProvider.notifier).state = AsyncValue.data(
    _fakeSession(),
  );
  return container;
}

Future<ProviderContainer> _bootAuthenticatedCompleteProfile(
  WidgetTester tester,
) async {
  await tester.binding.setSurfaceSize(const Size(402, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final container = _authenticatedContainer();
  addTearDown(container.dispose);
  await container.read(profileControllerProvider.notifier).ready;
  await container.read(onboardingControllerProvider.notifier).ready;
  await container
      .read(profileControllerProvider.notifier)
      .updateDetails(
        ProfileDetails(
          dateOfBirth: DateTime(1995, 5, 12),
          gender: Gender.female,
          heightCm: 165,
        ),
      );
  // appRouter is a top-level singleton shared across every test in this
  // file/isolate — reset it before pumping so a previous test's leftover
  // location (e.g. /today, which would otherwise render the real, heavy
  // TodayScreen and its controllers underneath a container that hasn't
  // initialized them) never leaks into this test.
  appRouter.go(AppRoutes.authGate);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const GlowUpApp()),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'A/B. AU06 -> 07 -> 08 -> 09 -> 10 -> 11 -> 12 -> 13 -> Today: the full restored sequence works end to end, with real back navigation along the way',
    (tester) async {
      final container = await _bootAuthenticatedCompleteProfile(tester);
      appRouter.go(AppRoutes.authSuccess);
      await tester.pumpAndSettle();
      expect(find.text('Welcome to Glow Up! ✨'), findsOneWidget);

      await tester.tap(find.text('Go to Dashboard'));
      await tester.pumpAndSettle();
      expect(
        find.text('Your Goals ✨'),
        findsOneWidget,
        reason: 'AU06 must lead into 07_goals, never straight to Today',
      );

      // G. back navigation: 07 -> AU06 works without a loop.
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Welcome to Glow Up! ✨'), findsOneWidget);
      await tester.tap(find.text('Go to Dashboard'));
      await tester.pumpAndSettle();
      expect(find.text('Your Goals ✨'), findsOneWidget);

      await tester.tap(find.text('Lose Weight'));
      await tester.pump();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Fitness Level 💪'), findsOneWidget);
      expect(
        container.read(onboardingControllerProvider).goals,
        contains(Goal.loseWeight),
        reason: 'H: the real goal choice is stored',
      );

      await tester.tap(find.text('Beginner'));
      await tester.pump();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Your Schedule 📅'), findsOneWidget);

      await tester.tap(find.text('Morning'));
      await tester.pump();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Stay on Track 🔔'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Health Data 📊'), findsOneWidget);

      await tester.tap(find.text('Next'));
      // Pump the push transition forward (but nowhere near pumpAndSettle) —
      // 12_personalization auto-advances itself via a real 1800ms delayed
      // callback, and pumpAndSettle fast-forwards straight through that,
      // skipping this intermediate screen entirely.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Almost There! ⚡'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 2000));
      await tester.pumpAndSettle();
      expect(find.text("You're All Set! ✨"), findsOneWidget);

      expect(
        container.read(onboardingControllerProvider).onboardingComplete,
        isFalse,
        reason:
            '6: only 13_finish_setup itself may set onboardingComplete, not reaching it',
      );

      await tester.tap(find.text('Start My Glow Up'));
      await tester.pumpAndSettle();

      expect(
        container.read(onboardingControllerProvider).onboardingComplete,
        isTrue,
      );
      // Onboarding finish leads into the once-only Premium soft offer
      // (PW01), never straight to Today — see paywall_test.dart for the
      // full "Maybe later -> Today" / "Unlock Premium -> PW02" coverage.
      expect(appRouter.state.matchedLocation, AppRoutes.paywallEntry);
    },
  );

  testWidgets(
    'C/D. closing mid-flow and truly relaunching (a fresh container reading the same persisted SharedPreferences) resumes at the real saved step, not the start and not Today',
    (tester) async {
      // First "session": reach 09_schedule, then the app is "closed" —
      // the container is disposed without ever pumping a widget tree.
      final firstRun = _authenticatedContainer();
      await firstRun.read(profileControllerProvider.notifier).ready;
      await firstRun.read(onboardingControllerProvider.notifier).ready;
      await firstRun
          .read(profileControllerProvider.notifier)
          .updateDetails(
            ProfileDetails(
              dateOfBirth: DateTime(1995, 5, 12),
              gender: Gender.female,
              heightCm: 165,
            ),
          );
      firstRun
          .read(onboardingControllerProvider.notifier)
          .toggleGoal(Goal.sleepBetter);
      firstRun
          .read(onboardingControllerProvider.notifier)
          .advanceStep(OnboardingStep.schedule);
      // Give the fire-and-forget persistence writes a turn to complete
      // before "closing" — mirrors real save-then-close timing. A plain
      // `Future.delayed` never resolves inside testWidgets' fake-async
      // zone without a pump driving it forward, so use `tester.pump()`.
      await tester.pump();
      firstRun.dispose();

      // Second "session": a brand-new container/provider tree, reading the
      // same underlying SharedPreferences mock — this is a genuine
      // relaunch, not just re-reading the same live objects.
      await tester.binding.setSurfaceSize(const Size(402, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final secondRun = _authenticatedContainer();
      addTearDown(secondRun.dispose);
      appRouter.go(AppRoutes.authGate);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: secondRun,
          child: const GlowUpApp(),
        ),
      );
      // Bounded pumps (not pumpAndSettle) through the async auth/profile/
      // onboarding-ready gates AuthGateScreen awaits before redirecting.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(
        find.text('Your Schedule 📅'),
        findsOneWidget,
        reason:
            'C/D: a real relaunch resumes at the saved step, not 07 and not Today',
      );
      expect(find.text('Your Goals ✨'), findsNothing);
      expect(
        secondRun.read(onboardingControllerProvider).goals,
        contains(Goal.sleepBetter),
        reason: 'H: the goal chosen before closing survived the relaunch',
      );
    },
  );

  testWidgets('E. a fully completed account relaunches straight to Today', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(402, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = _authenticatedContainer();
    addTearDown(container.dispose);
    await container.read(profileControllerProvider.notifier).ready;
    await container.read(onboardingControllerProvider.notifier).ready;
    await container
        .read(profileControllerProvider.notifier)
        .updateDetails(
          ProfileDetails(
            dateOfBirth: DateTime(1995, 5, 12),
            gender: Gender.female,
            heightCm: 165,
          ),
        );
    container.read(onboardingControllerProvider.notifier).completeOnboarding();

    appRouter.go(AppRoutes.authGate);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const GlowUpApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your Schedule 📅'), findsNothing);
    expect(find.text('Almost there!'), findsNothing);
    expect(
      appRouter.state.matchedLocation,
      AppRoutes.today,
      reason: 'a completed user must never be forced through onboarding again',
    );
  });

  test(
    'I. the onboarding_profile_v1 legacy unscoped key still loads correctly (an existing authenticated test user is never corrupted by per-account namespacing)',
    () async {
      SharedPreferences.setMockInitialValues({
        'onboarding_profile_v1': '{"firstName":"Angel","goals":["loseWeight"]}',
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = OnboardingRepository(prefs); // userId: null == legacy key
      final loaded = repo.load();
      expect(loaded, isNotNull);
      expect(loaded!.firstName, 'Angel');
      expect(loaded.goals, contains(Goal.loseWeight));
    },
  );

  group('onboarding profile JSON round-trips (persistence correctness)', () {
    test('a fully populated profile survives toJson/fromJson unchanged', () {
      final profile = OnboardingProfile(
        authProvider: AuthProvider.google,
        accountCreatedAt: DateTime(2026, 1, 1),
        firstName: 'Riley',
        dateOfBirth: DateTime(1998, 5, 12),
        goals: {Goal.loseWeight, Goal.buildHabits},
        fitnessLevel: FitnessLevel.intermediate,
        scheduleWindow: ScheduleWindow.evening,
        notifications: const NotificationPrefs(hydrationNudges: true),
        healthConnections: const HealthConnections(googleFitConnected: true),
        currentStep: OnboardingStep.healthConnections,
        onboardingComplete: true,
        completedAt: DateTime(2026, 1, 2),
      );
      final restored = OnboardingProfile.fromJson(profile.toJson());
      expect(restored.firstName, profile.firstName);
      expect(restored.goals, profile.goals);
      expect(restored.fitnessLevel, profile.fitnessLevel);
      expect(restored.scheduleWindow, profile.scheduleWindow);
      expect(restored.notifications.hydrationNudges, isTrue);
      expect(restored.healthConnections.googleFitConnected, isTrue);
      expect(restored.currentStep, OnboardingStep.healthConnections);
      expect(restored.onboardingComplete, isTrue);
    });

    test('an empty/default profile round-trips without throwing', () {
      const profile = OnboardingProfile();
      final restored = OnboardingProfile.fromJson(profile.toJson());
      expect(restored.onboardingComplete, isFalse);
      expect(restored.currentStep, OnboardingStep.goals);
    });
  });

  group('separation of auth/profile-basics/onboarding state (item 1)', () {
    test(
      'a session existing does not by itself imply onboarding is complete',
      () async {
        final container = ProviderContainer(
          overrides: [
            authControllerProvider.overrideWith((ref) => AuthController()),
          ],
        );
        addTearDown(container.dispose);
        container.read(authControllerProvider.notifier).state = AsyncValue.data(
          _fakeSession(),
        );
        await container.read(onboardingControllerProvider.notifier).ready;
        expect(
          container.read(onboardingControllerProvider).onboardingComplete,
          isFalse,
        );
      },
    );

    test(
      'profile-basics-complete and onboarding-complete are independently toggleable',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        await container.read(profileControllerProvider.notifier).ready;
        await container.read(onboardingControllerProvider.notifier).ready;
        // Profile basics complete, onboarding not.
        await container
            .read(profileControllerProvider.notifier)
            .updateDetails(
              ProfileDetails(
                dateOfBirth: DateTime(1995, 5, 12),
                gender: Gender.female,
                heightCm: 165,
              ),
            );
        expect(
          container.read(onboardingControllerProvider).onboardingComplete,
          isFalse,
        );
        // Now onboarding complete too — both are real, distinct flags.
        container
            .read(onboardingControllerProvider.notifier)
            .completeOnboarding();
        expect(
          container.read(onboardingControllerProvider).onboardingComplete,
          isTrue,
        );
        expect(
          container.read(profileControllerProvider).value!.details.dateOfBirth,
          isNotNull,
        );
      },
    );
  });
}
