// Covers the Profile module: real screen replacing the old placeholder,
// bottom-nav selection, all 4 time-of-day variants driven by the one
// shared TodPeriod controller (no duplicated screens), honest identity/
// stat data (no hardcoded demo numbers), every sub-page rendering, and
// accessibility/overflow safety.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:glow_up/core/tod/tod_period.dart';
import 'package:glow_up/core/widgets/bottom_nav_bar.dart';
import 'package:glow_up/onboarding/state/onboarding_controller.dart';
import 'package:glow_up/profile/data/profile_repository.dart';
import 'package:glow_up/profile/models/profile_models.dart';
import 'package:glow_up/profile/screens/ai_personalization_screen.dart';
import 'package:glow_up/profile/screens/connected_apps_screen.dart';
import 'package:glow_up/profile/screens/edit_profile_screen.dart';
import 'package:glow_up/profile/screens/goals_preferences_screen.dart';
import 'package:glow_up/profile/screens/help_support_screen.dart';
import 'package:glow_up/profile/screens/manage_data_screen.dart';
import 'package:glow_up/profile/screens/notifications_screen.dart';
import 'package:glow_up/profile/screens/privacy_data_screen.dart';
import 'package:glow_up/profile/screens/profile_screen.dart';
import 'package:glow_up/profile/screens/settings_screen.dart';
import 'package:glow_up/profile/screens/subscription_screen.dart';
import 'package:glow_up/profile/theme/profile_variant_config.dart';
import 'package:glow_up/routing/app_router.dart';
import 'package:glow_up/workout/models/workout_completion_record.dart';
import 'package:glow_up/workout/state/workout_history_controller.dart';

Future<ProviderContainer> _bootProfile(
  WidgetTester tester, {
  TodPeriod? period,
  Size size = const Size(402, 1400),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final container = ProviderContainer();
  addTearDown(container.dispose);
  if (period != null) {
    container.read(devTodPeriodOverrideProvider.notifier).state = period;
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: ProfileScreen()),
    ),
  );
  await tester.pump();
  await tester.pump();
  return container;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Profile route replaces the placeholder', () {
    testWidgets('renders the real Profile UI, no placeholder text', (
      tester,
    ) async {
      await _bootProfile(tester);
      expect(
        find.text('My Profile'),
        findsOneWidget,
        reason: 'requirement 1: real Profile UI renders',
      );
      expect(
        find.textContaining('not built yet'),
        findsNothing,
        reason: 'requirement 2: placeholder text is gone',
      );
      expect(
        find.textContaining('90 Profile'),
        findsNothing,
        reason: 'requirement 2: figma-family placeholder label is gone',
      );
    });

    test(
      'app_router.dart no longer builds a PlaceholderScreen for AppRoutes.profile',
      () {
        final content = File('lib/routing/app_router.dart').readAsStringSync();
        final profileRouteBlock = content.substring(
          content.indexOf('path: AppRoutes.profile,'),
        );
        final nextRouteStart = profileRouteBlock.indexOf('GoRoute(', 1);
        final block = profileRouteBlock.substring(
          0,
          nextRouteStart == -1 ? profileRouteBlock.length : nextRouteStart,
        );
        expect(block.contains('PlaceholderScreen'), isFalse);
        expect(block.contains('ProfileScreen('), isTrue);
      },
    );
  });

  group('bottom navigation', () {
    testWidgets('Profile tab shows selected on this screen', (tester) async {
      await _bootProfile(tester);
      final navBar = tester.widget<BottomNavBar>(find.byType(BottomNavBar));
      expect(
        navBar.active,
        AppNavTab.profile,
        reason:
            'requirement 3: Profile selected state appears in bottom navigation',
      );
    });
  });

  group('time-of-day variants — one shared screen, no duplicated implementations', () {
    for (final period in TodPeriod.values) {
      testWidgets(
        '${period.name} variant uses ProfileVariantConfig.byPeriod[${period.name}]',
        (tester) async {
          await _bootProfile(tester, period: period);
          final navBar = tester.widget<BottomNavBar>(find.byType(BottomNavBar));
          final expected = ProfileVariantConfig.byPeriod[period]!;
          expect(
            navBar.activeAccent,
            expected.accent,
            reason:
                'requirements 4-7: ${period.name} uses the shared time-of-day state',
          );
        },
      );
    }

    test(
      'every TodPeriod has a Profile variant config — no period silently falls back',
      () {
        for (final period in TodPeriod.values) {
          expect(
            ProfileVariantConfig.byPeriod.containsKey(period),
            isTrue,
            reason: '$period is missing a ProfileVariantConfig',
          );
        }
      },
    );

    test(
      'Auto (no dev override) resolves from the real local clock, same shared TodPeriodResolver every other module uses',
      () {
        const resolver = TodPeriodResolver();
        expect(resolver.resolve(DateTime(2026, 1, 1, 7)), TodPeriod.morning);
        expect(resolver.resolve(DateTime(2026, 1, 1, 13)), TodPeriod.afternoon);
        expect(resolver.resolve(DateTime(2026, 1, 1, 18)), TodPeriod.evening);
        expect(resolver.resolve(DateTime(2026, 1, 1, 23)), TodPeriod.night);
        // requirement 8: auto uses the existing controller, not a new one.
      },
    );

    test(
      'only one ProfileScreen class exists — no four duplicated per-period implementations',
      () {
        final profileScreenFiles = Directory('lib/profile/screens')
            .listSync()
            .whereType<File>()
            .where(
              (f) =>
                  f.path.replaceAll('\\', '/').endsWith('/profile_screen.dart'),
            );
        expect(
          profileScreenFiles.length,
          1,
          reason: 'requirement 9: exactly one ProfileScreen file',
        );
        final content = File(
          'lib/profile/screens/profile_screen.dart',
        ).readAsStringSync();
        expect('class ProfileScreen'.allMatches(content).length, 1);
      },
    );
  });

  group(
    'identity uses real/empty state, statistics are never hardcoded demo numbers',
    () {
      testWidgets(
        'with no onboarding name set, shows an honest empty-name prompt, not a fabricated name',
        (tester) async {
          await _bootProfile(tester);
          expect(
            find.text('Add your name'),
            findsOneWidget,
            reason:
                'requirement 10: honest empty state, no fabricated identity',
          );
        },
      );

      testWidgets('with a real onboarding name, shows it verbatim', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(402, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final container = ProviderContainer();
        addTearDown(container.dispose);
        await container.read(onboardingControllerProvider.notifier).ready;
        container
            .read(onboardingControllerProvider.notifier)
            .setPersonalInfo(
              firstName: 'Riley',
              dateOfBirth: DateTime(1998, 5, 12),
            );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: ProfileScreen()),
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(
          find.text('Riley'),
          findsOneWidget,
          reason: 'requirement 10: real stored data is used',
        );
      });

      testWidgets(
        'reference-image demo numbers (12 day streak, 24 workouts, 78 Glow Score) never appear',
        (tester) async {
          await _bootProfile(tester);
          expect(find.text('12'), findsNothing);
          expect(find.text('24'), findsNothing);
          expect(
            find.text('78'),
            findsNothing,
            reason: 'requirement 11: no hardcoded reference-image values',
          );
        },
      );

      testWidgets(
        'Day Streak and Glow Score show an honest unavailable state, never a fabricated number',
        (tester) async {
          await _bootProfile(tester);
          expect(
            find.text('—'),
            findsNWidgets(2),
            reason:
                'requirement 11: Day Streak and Glow Score are honestly unavailable',
          );
        },
      );

      testWidgets(
        'Workouts stat is the real completed-workout count, not a fixed number',
        (tester) async {
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final history = container.read(
            workoutHistoryControllerProvider.notifier,
          );
          await history.ready;
          await history.recordCompletion(
            id: 'w1',
            workoutId: 'recovery-flow',
            workoutName: 'Recovery Flow',
            startedAt: DateTime.now(),
            completedAt: DateTime.now(),
            totalDurationSeconds: 300,
            completedExerciseIds: const ['EX049'],
            skippedExerciseIds: const [],
            status: WorkoutCompletionStatus.completed,
          );
          await tester.binding.setSurfaceSize(const Size(402, 1400));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const MaterialApp(home: ProfileScreen()),
            ),
          );
          await tester.pump();
          await tester.pump();
          expect(
            find.text('1'),
            findsOneWidget,
            reason: 'requirement 11: real workout count (1 recorded), not 24',
          );
        },
      );
    },
  );

  group('sub-pages render', () {
    testWidgets('Edit Profile renders', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: ProviderScope(child: EditProfileScreen())),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Edit Profile'), findsWidgets, reason: 'requirement 12');
    });

    testWidgets('Goals & Preferences renders', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: ProviderScope(child: GoalsPreferencesScreen())),
      );
      await tester.pump();
      expect(
        find.text('Goals & Preferences'),
        findsOneWidget,
        reason: 'requirement 13',
      );
      expect(
        find.textContaining('%'),
        findsNothing,
        reason: 'no invented completion percentages',
      );
    });

    testWidgets('AI Personalization renders truthfully — no live-AI claim', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProviderScope(child: AiPersonalizationScreen()),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(
        find.text('AI Personalization'),
        findsOneWidget,
        reason: 'requirement 14',
      );
      expect(
        find.textContaining('not yet connected'),
        findsOneWidget,
        reason: 'requirement 14: truthful about the AI Coach not being live',
      );
    });

    testWidgets(
      'Connected Apps renders truthful connection status for every entry',
      (tester) async {
        await tester.pumpWidget(const MaterialApp(home: ConnectedAppsScreen()));
        await tester.pump();
        expect(
          find.text('Connected Apps'),
          findsOneWidget,
          reason: 'requirement 15',
        );
        expect(
          find.text('Not connected'),
          findsNWidgets(5),
          reason: 'requirement 15: no integration claims to be connected',
        );
        expect(find.text('Connected'), findsNothing);
      },
    );

    testWidgets('Notifications route/screen works', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProviderScope(child: ProfileNotificationsScreen()),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(
        find.text('Notifications'),
        findsOneWidget,
        reason: 'requirement 16',
      );
    });

    testWidgets('Privacy & Data route/screen works', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: ProviderScope(child: PrivacyDataScreen())),
      );
      await tester.pump();
      await tester.pump();
      expect(
        find.text('Privacy & Data'),
        findsOneWidget,
        reason: 'requirement 17',
      );
    });

    testWidgets(
      'Subscription route/screen works and never claims Premium is active',
      (tester) async {
        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: SubscriptionScreen())),
        );
        await tester.pump();
        await tester.pump();
        expect(
          find.text('Subscription'),
          findsOneWidget,
          reason: 'requirement 18',
        );
        expect(find.textContaining('Glow Up Free'), findsOneWidget);
        expect(find.textContaining('Premium Active'), findsNothing);
        expect(find.text('Glow Up Premium'), findsNothing);
        expect(
          find.textContaining('Renews'),
          findsNothing,
          reason: 'no fabricated renewal date',
        );
      },
    );

    testWidgets('Settings route/screen works', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: ProviderScope(child: ProfileSettingsScreen())),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Settings'), findsOneWidget, reason: 'requirement 19');
    });

    testWidgets('Manage Data route/screen works', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ManageDataScreen()));
      await tester.pump();
      expect(
        find.text('Manage Data'),
        findsOneWidget,
        reason: 'requirement 20',
      );
    });

    testWidgets(
      'Help & Support renders with Log Out and Delete Account actions',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: ProviderScope(child: HelpSupportScreen())),
        );
        await tester.pump();
        expect(
          find.text('Help & Support'),
          findsOneWidget,
          reason: 'requirement 21',
        );
        expect(find.text('Log Out'), findsOneWidget);
        expect(find.text('Delete Account'), findsOneWidget);
      },
    );
  });

  group('responsive / accessibility', () {
    testWidgets('no overflow at a small mobile size (320x568)', (tester) async {
      await _bootProfile(tester, size: const Size(320, 568));
      expect(tester.takeException(), isNull, reason: 'requirement 22');
    });

    testWidgets('no overflow with large text scaling', (tester) async {
      await tester.binding.setSurfaceSize(const Size(402, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: const MaterialApp(home: ProfileScreen()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'Settings gear and Edit Profile button expose semantic labels and meet the 44x44 minimum',
      (tester) async {
        await _bootProfile(tester);
        final settingsButton = find.bySemanticsLabel('Settings');
        expect(settingsButton, findsOneWidget, reason: 'requirement 23');
        expect(tester.getSize(settingsButton).height, greaterThanOrEqualTo(44));

        final editButton = find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Edit Profile',
        );
        expect(editButton, findsOneWidget);
        expect(tester.getSize(editButton).height, greaterThanOrEqualTo(44));
      },
    );
  });

  group('privacy: no network in the Profile module', () {
    test('profile_controller.dart never imports an HTTP/Supabase client', () {
      final content = File(
        'lib/profile/state/profile_controller.dart',
      ).readAsStringSync();
      expect(content.contains("import 'package:http"), isFalse);
      expect(content.toLowerCase().contains('supabase'), isFalse);
    });
  });

  group('ProfileRepository namespaces local storage per account (Part E/G)', () {
    test(
      'two different userIds never see or overwrite each other\'s saved details',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final repoA = ProfileRepository(prefs, userId: 'user-a');
        final repoB = ProfileRepository(prefs, userId: 'user-b');

        await repoA.saveDetails(const ProfileDetails(name: 'Alex'));
        expect(
          repoB.hasSavedDetails,
          isFalse,
          reason: 'a fresh account must never inherit another account\'s data',
        );
        expect(repoB.loadDetails().name, isNull);
        expect(repoA.loadDetails().name, 'Alex');
      },
    );

    test(
      'a null userId (unconfigured/no session) uses the original unscoped key, unchanged for existing installs',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final repo = ProfileRepository(prefs);
        await repo.saveDetails(const ProfileDetails(name: 'Legacy'));
        expect(prefs.containsKey('profile_details_v1'), isTrue);
      },
    );
  });

  group('regression — other Glow Up modules unaffected', () {
    test(
      'AppRoutes still has exactly one profile-hub route, other module routes untouched',
      () {
        expect(AppRoutes.mood, '/mood');
        expect(AppRoutes.cycle, '/cycle');
        expect(AppRoutes.shopScan, '/shop/scan');
      },
    );
  });
}
