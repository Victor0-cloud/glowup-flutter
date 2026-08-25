// Regression test for a launch-tooling bug (NOT an app bug): a dev-only
// `flutter run --dart-define=QA_ROUTE=/workout/core-crusher` invoked
// through Git Bash on Windows had its leading-slash argument silently
// rewritten by MSYS path conversion into `C:/Program Files/Git/workout/
// core-crusher` before it ever reached the Flutter app, producing
// `GoException: no routes for location: ...`. The app's own routing code
// was never involved — every real in-app navigation call builds its
// target path from `AppRoutes` string constants/functions alone, with no
// filesystem, `Uri.base`, or working-directory logic anywhere in the
// routing layer (confirmed by inspection). This file locks that in.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:glow_up/app/glow_up_app.dart';
import 'package:glow_up/onboarding/state/onboarding_controller.dart';
import 'package:glow_up/routing/app_router.dart';

void main() {
  group('AppRoutes produces canonical app paths, never a filesystem path', () {
    test(
      'workoutDetail(\'core-crusher\') is exactly /workout/core-crusher',
      () {
        expect(
          AppRoutes.workoutDetail('core-crusher'),
          '/workout/core-crusher',
        );
      },
    );

    test(
      'every AppRoutes path/path-function starts with / and never contains a Windows drive letter or "Program Files"',
      () {
        final staticPaths = <String>[
          AppRoutes.splash,
          AppRoutes.today,
          AppRoutes.workout,
          AppRoutes.workoutSession,
          AppRoutes.routinePlayerSession,
          AppRoutes.routinePlayerQa,
        ];
        final dynamicPaths = <String>[
          AppRoutes.workoutDetail('core-crusher'),
          AppRoutes.workoutCategory('core'),
          AppRoutes.routineDetail('some-id'),
        ];
        for (final path in [...staticPaths, ...dynamicPaths]) {
          expect(
            path,
            startsWith('/'),
            reason: '"$path" must be a canonical app path starting with /',
          );
          expect(
            path,
            isNot(contains('Program Files')),
            reason: '"$path" must never be a mangled filesystem path',
          );
          expect(
            path,
            isNot(matches(RegExp(r'^[a-zA-Z]:'))),
            reason:
                '"$path" must never look like a Windows drive path (e.g. C:/...)',
          );
        }
      },
    );
  });

  testWidgets(
    'real navigation: Workout -> Core -> Core Crusher resolves the live GoRouter location to exactly /workout/core-crusher',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(402, 874));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(onboardingControllerProvider.notifier)
          .completeOnboarding();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const GlowUpApp(),
        ),
      );
      appRouter.go(AppRoutes.workout);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Core'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Core'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Core Crusher'));
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason:
            'a mangled/unmatched location would surface as a GoException here',
      );

      // GoRoute '/workout/:id' only matches and builds WorkoutDetailScreen
      // for a clean, exact '/workout/core-crusher' — if the location were
      // ever mangled into a filesystem-style path (e.g. the Git-Bash
      // dev-tooling artifact this test guards against), no route would
      // match and this content would never render.
      expect(find.text('Core Crusher'), findsWidgets);
      expect(
        find.text('Build core strength and stability from every angle.'),
        findsOneWidget,
        reason:
            'proves the real /workout/core-crusher route matched and rendered',
      );
    },
  );
}
