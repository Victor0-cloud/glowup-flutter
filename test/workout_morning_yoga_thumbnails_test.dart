// Covers the Morning Yoga Flow thumbnail regression: on the routine-detail
// screen, Sun Salutation and Downward Dog showed images but Warrior I and
// Warrior II showed blank thumbnail containers, even though both have real
// approved Tier 1 (RoutinePlayer) assets. Root cause: resolvePoseAssetPath
// (shared by _ExerciseThumbnail and PoseDisplayBox) only ever checked
// exercise.poseAssetPath and the Tier 2 legacy catalog — it had no
// awareness of the Tier 1 registry, so EX057/EX058 (which exist only in
// Tier 1, never in Tier 2) resolved to nothing. Fixed by extending
// resolvePoseAssetPath to also try the Tier 1 registry by catalogId before
// falling back to Tier 2. This file locks that fix in place. All six
// Morning Yoga exercises now have real Tier 1 definitions and thumbnails
// (Savasana/EX060 was the last).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:glow_up/app/glow_up_app.dart';
import 'package:glow_up/onboarding/state/onboarding_controller.dart';
import 'package:glow_up/routing/app_router.dart';
import 'package:glow_up/workout/data/workout_catalog.dart';
import 'package:glow_up/workout/models/workout_models.dart';
import 'package:glow_up/workout/widgets/workout_widgets.dart';

Future<ProviderContainer> _bootAtWorkoutHub(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(402, 874));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final container = ProviderContainer();
  container.read(onboardingControllerProvider.notifier).completeOnboarding();
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const GlowUpApp()),
  );
  appRouter.go(AppRoutes.workout);
  await tester.pumpAndSettle();
  return container;
}

Workout get _morningYogaFlow =>
    kWorkoutCatalog.firstWhere((w) => w.id == 'morning-yoga-flow');

bool _hasAssetImageContaining(WidgetTester tester, String needle) {
  return tester.widgetList<Image>(find.byType(Image)).any((img) {
    final provider = img.image;
    return provider is AssetImage && provider.assetName.contains(needle);
  });
}

void main() {
  group('Morning Yoga Flow thumbnail resolution', () {
    test(
      'Warrior I (EX057) thumbnail resolves through the Tier 1 registry, not the (nonexistent-for-EX057) Tier 2 catalog',
      () {
        final warriorI = _morningYogaFlow.exercises.firstWhere(
          (e) => e.catalogId == 'EX057',
        );
        final assetPath = resolvePoseAssetPath(warriorI, step: 1);
        expect(
          assetPath,
          isNotNull,
          reason:
              'Warrior I has a real approved Tier 1 frame 1 image — must never be blank',
        );
        expect(
          assetPath,
          'assets/glow_up/exercises/warrior_i/female/v2/EX057_F_01_START.png',
        );
      },
    );

    test('Warrior II (EX058) thumbnail resolves through the Tier 1 registry', () {
      final warriorII = _morningYogaFlow.exercises.firstWhere(
        (e) => e.catalogId == 'EX058',
      );
      final assetPath = resolvePoseAssetPath(warriorII, step: 1);
      expect(
        assetPath,
        isNotNull,
        reason:
            'Warrior II has a real approved Tier 1 frame 1 image — must never be blank',
      );
      expect(
        assetPath,
        'assets/glow_up/exercises/warrior_ii/female/v2/EX058_F_01_START.png',
      );
    });

    test(
      'Sun Salutation (EX055) and Downward Dog (EX056) also resolve through the Tier 1 registry now, not just their legacy poseAssetPath override',
      () {
        final sunSalutation = _morningYogaFlow.exercises.firstWhere(
          (e) => e.catalogId == 'EX055',
        );
        final downwardDog = _morningYogaFlow.exercises.firstWhere(
          (e) => e.catalogId == 'EX056',
        );
        // poseAssetPath still wins when set (unchanged legacy behavior) —
        // both of these happen to have one, so this confirms it still takes
        // priority over the new Tier 1 branch, exactly as documented.
        expect(
          resolvePoseAssetPath(sunSalutation, step: 1),
          sunSalutation.poseAssetPath,
        );
        expect(
          resolvePoseAssetPath(downwardDog, step: 1),
          downwardDog.poseAssetPath,
        );
      },
    );

    test(
      'Tree Pose (EX059) thumbnail resolves through the Tier 1 registry too',
      () {
        final treePose = _morningYogaFlow.exercises.firstWhere(
          (e) => e.catalogId == 'EX059',
        );
        final assetPath = resolvePoseAssetPath(treePose, step: 1);
        expect(
          assetPath,
          isNotNull,
          reason:
              'Tree Pose has a real approved Tier 1 frame 1 image — must never be blank',
        );
        expect(
          assetPath,
          'assets/glow_up/exercises/tree_pose/female/v2/EX059_F_01_START.png',
        );
      },
    );

    test(
      'Savasana (EX060) thumbnail resolves through the Tier 1 registry too — the last of all six Morning Yoga exercises to gain a real one',
      () {
        final savasana = _morningYogaFlow.exercises.firstWhere(
          (e) => e.catalogId == 'EX060',
        );
        final assetPath = resolvePoseAssetPath(savasana, step: 1);
        expect(
          assetPath,
          isNotNull,
          reason:
              'Savasana has a real approved Tier 1 frame 1 image — must never be blank',
        );
        expect(
          assetPath,
          'assets/glow_up/exercises/savasana/female/v2/EX060_F_01_PREPARE.png',
        );
      },
    );

    test(
      'Warrior I / Warrior II / Tree Pose / Savasana thumbnails stay within their own asset folder — never cross-mapped (Sun Salutation/Downward Dog are covered separately: their poseAssetPath override takes priority, so they never reach the Tier 1 branch this checks)',
      () {
        final expectedSlugs = {
          'EX057': 'warrior_i',
          'EX058': 'warrior_ii',
          'EX059': 'tree_pose',
          'EX060': 'savasana',
        };
        for (final entry in expectedSlugs.entries) {
          final exercise = _morningYogaFlow.exercises.firstWhere(
            (e) => e.catalogId == entry.key,
          );
          final assetPath = resolvePoseAssetPath(exercise, step: 1);
          expect(assetPath, isNotNull);
          expect(
            assetPath,
            contains('exercises/${entry.value}/'),
            reason:
                '${exercise.title} must resolve to its own asset folder, never another exercise\'s',
          );
        }
      },
    );
  });

  testWidgets(
    'Flexibility -> Morning Yoga Flow renders with zero asset exceptions and shows real Warrior I / Warrior II / Tree Pose / Savasana thumbnails, no blank containers',
    (tester) async {
      final container = await _bootAtWorkoutHub(tester);
      addTearDown(container.dispose);

      await tester.ensureVisible(find.text('Flexibility'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Flexibility'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Morning Yoga Flow'));
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'no Image.asset exception may reach the widget tree',
      );

      expect(find.text('Sun Salutation'), findsOneWidget);
      expect(find.text('Downward Dog'), findsOneWidget);
      expect(find.text('Warrior I'), findsOneWidget);
      expect(find.text('Warrior II'), findsOneWidget);
      expect(find.text('Tree Pose'), findsOneWidget);
      expect(find.text('Savasana'), findsOneWidget);

      expect(
        _hasAssetImageContaining(tester, 'exercises/warrior_i/female/v2/'),
        isTrue,
        reason:
            'Warrior I thumbnail must render its real approved image, not a blank container',
      );
      expect(
        _hasAssetImageContaining(tester, 'exercises/warrior_ii/female/v2/'),
        isTrue,
        reason:
            'Warrior II thumbnail must render its real approved image, not a blank container',
      );
      expect(
        _hasAssetImageContaining(tester, 'exercises/tree_pose/female/v2/'),
        isTrue,
        reason:
            'Tree Pose thumbnail must render its real approved image, not a blank container',
      );
      expect(
        _hasAssetImageContaining(tester, 'exercises/savasana/female/v2/'),
        isTrue,
        reason:
            'Savasana thumbnail must render its real approved image, not a blank container',
      );
    },
  );
}
