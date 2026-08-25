// Widget-level QA for the RoutinePlayer Phase 1 screens: confirms the
// Section E "duplicate Up Next title / empty image" bug is fixed, that the
// exercise-index header no longer reads as a pose counter (Section B/17),
// that real verified images render (never emoji/icon), and that the
// desktop-width layout centers rather than clipping (Section 35).
//
// The controller runs a real Timer.periodic, same as the legacy workout
// module — pumpAndSettle() is unsafe while it's ticking, so every step
// uses bounded tester.pump(Duration) calls instead, and every test ends by
// calling endSession() explicitly (synchronously, before the test body
// returns) rather than relying on addTearDown — addTearDown callbacks
// weren't reliably running before flutter_test's own pending-timer
// invariant check in this Flutter version, matching the same explicit
// pattern already used at the end of workout_flow_test.dart's session test.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:glow_up/routine_player/data/routine_player_registry.dart';
import 'package:glow_up/routine_player/models/routine_player_state.dart';
import 'package:glow_up/routine_player/screens/routine_player_screen.dart';
import 'package:glow_up/routine_player/state/routine_player_controller.dart';
import 'package:glow_up/routine_player/widgets/routine_player_scaffold.dart';

/// Pumps RoutinePlayerQaEntry directly under a fresh ProviderContainer,
/// bypassing the global `appRouter`/full app shell entirely. appRouter is
/// a top-level singleton shared across every test in the process — go()ing
/// to the same QA route location a previous test already left it at is a
/// same-location no-op for GoRouter, so the route never rebuilds and
/// RoutinePlayerQaEntry.initState never re-fires against a fresh test's
/// container. Testing the screen directly, the same way an isolated
/// component test would, avoids that shared-singleton coupling entirely.
Future<ProviderContainer> _bootAtQa(
  WidgetTester tester, {
  Size size = const Size(402, 874),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final container = ProviderContainer();
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: RoutinePlayerQaEntry(onExit: () {})),
    ),
  );
  await tester.pump(); // process the post-frame startRoutine() callback
  await tester.pump();
  return container;
}

bool hasAssetImageContaining(WidgetTester tester, String needle) {
  final images = tester.widgetList<Image>(find.byType(Image));
  for (final image in images) {
    final provider = image.image;
    if (provider is AssetImage && provider.assetName.contains(needle)) {
      return true;
    }
  }
  return false;
}

void main() {
  testWidgets('Prepare screen shows Squat with a real image and no crash', (
    tester,
  ) async {
    final container = await _bootAtQa(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Squat'), findsWidgets);
    expect(
      hasAssetImageContaining(tester, 'exercises/squat/female/v2/F_01.png'),
      isTrue,
    );
    expect(
      hasAssetImageContaining(tester, 'exercises/squat/female/v1/'),
      isFalse,
      reason: 'the old real-room V1 set must never appear anymore',
    );

    container.read(routinePlayerControllerProvider.notifier).endSession();
  });

  testWidgets(
    'Squat Active shows the full body (real portrait aspect ratio, BoxFit.contain, no crop) with a controlled cadence',
    (tester) async {
      final container = await _bootAtQa(tester, size: const Size(1280, 800));
      final controller = container.read(
        routinePlayerControllerProvider.notifier,
      );

      controller.skipPrepare();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      expect(find.text('Squat'), findsWidgets);
      expect(
        hasAssetImageContaining(tester, 'exercises/squat/female/v2/'),
        isTrue,
      );
      expect(
        hasAssetImageContaining(tester, 'exercises/squat/female/v1/'),
        isFalse,
        reason: 'the old real-room V1 set must never appear anymore',
      );

      // Full-body-safe: Squat's own real portrait ratio (326x804), and every
      // rendered Squat frame uses BoxFit.contain (never cover/crop).
      final squatAspectRatios = tester
          .widgetList<AspectRatio>(find.byType(AspectRatio))
          .map((w) => w.aspectRatio);
      expect(squatAspectRatios, contains(closeTo(326 / 804, 0.001)));
      final squatImages = tester.widgetList<Image>(find.byType(Image)).where((
        img,
      ) {
        final provider = img.image;
        return provider is AssetImage &&
            provider.assetName.contains('exercises/squat/female/v2/');
      });
      expect(squatImages, isNotEmpty);
      for (final img in squatImages) {
        expect(
          img.fit,
          BoxFit.contain,
          reason: 'Squat frames must never be cropped via BoxFit.cover',
        );
      }

      // Controlled cadence: the STEP label must still be on an early frame
      // shortly after Start (not already several frames deep, which would
      // indicate a too-fast/slideshow rate).
      expect(
        find.textContaining('STEP 1 OF 6'),
        findsOneWidget,
        reason:
            'animation must not race ahead of a beginner reading the first step',
      );

      controller.endSession();
    },
  );

  testWidgets(
    'Active screen header reads as exercise index, not a pose counter, and the pose step label updates',
    (tester) async {
      final container = await _bootAtQa(tester);
      final controller = container.read(
        routinePlayerControllerProvider.notifier,
      );

      controller.skipPrepare();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('EXERCISE 1 OF 9'), findsOneWidget);
      expect(
        find.textContaining('Pose 1 of 7'),
        findsNothing,
      ); // the exact old mislabel

      // A STEP x OF 6 indicator must exist and must change as the movement
      // demonstration advances (Section B/17's real bug: the counter was
      // static while the image changed).
      final firstStepFinder = find.textContaining('STEP 1 OF 6');
      expect(firstStepFinder, findsOneWidget);

      await tester.pump(
        const Duration(milliseconds: 1500),
      ); // half of one Squat V2 loop cycle (3.0s), safely clear of the cycle boundary
      expect(
        find.textContaining('STEP 1 OF 6'),
        findsNothing,
        reason: 'step indicator must advance, not stay frozen',
      );

      controller.endSession();
    },
  );

  testWidgets(
    'Rest screen shows exactly ONE Up Next title and a real image — no duplicate, no empty box',
    (tester) async {
      final container = await _bootAtQa(tester);
      final controller = container.read(
        routinePlayerControllerProvider.notifier,
      );

      controller.skipPrepare();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 200));
      controller.skipExercise(); // Squat -> Rest, next = Lunges
      await tester.pump();

      expect(find.text('REST'), findsOneWidget);
      expect(
        find.text('Lunges'),
        findsOneWidget,
        reason: 'exactly one Up Next title, not duplicated',
      );
      expect(
        hasAssetImageContaining(
          tester,
          'exercises/lunges/female/v2/sequence_preview.png',
        ),
        isTrue,
        reason:
            'Up Next must show the real Lunges V2 preview, not an empty box',
      );

      controller.endSession();
    },
  );

  testWidgets(
    'Full-screen: workout fills the viewport, not a small centered card, on both phone and wide desktop widths',
    (tester) async {
      // Phone width: content should use the FULL width, no cap at all.
      final phoneContainer = await _bootAtQa(
        tester,
      ); // default Size(402, 874), the project's established mobile test size
      expect(tester.takeException(), isNull);
      final phoneScaffoldSize = tester.getSize(
        find.byType(RoutinePlayerScaffold).first,
      );
      expect(phoneScaffoldSize.width, 402);
      phoneContainer
          .read(routinePlayerControllerProvider.notifier)
          .endSession();

      // Wide desktop width: content must use dramatically more than the old
      // 460px "centered card" cap, while still not stretching edge-to-edge
      // on an ultra-wide monitor (a generous but bounded cap keeps text and
      // controls readable).
      final desktopContainer = await _bootAtQa(
        tester,
        size: const Size(1280, 800),
      );
      expect(tester.takeException(), isNull);
      final scaffoldSize = tester.getSize(
        find.byType(RoutinePlayerScaffold).first,
      );
      expect(scaffoldSize.width, 1280); // scaffold fills the window...
      final constrainedBoxFinder = find.byWidgetPredicate(
        (w) => w is ConstrainedBox && w.constraints.maxWidth < double.infinity,
      );
      expect(constrainedBoxFinder, findsWidgets);
      final contentWidth = tester.getSize(constrainedBoxFinder.first).width;
      expect(
        contentWidth,
        greaterThan(800),
        reason:
            'full-screen workout must use far more than the old 460px card width',
      );
      expect(
        contentWidth,
        lessThanOrEqualTo(1280),
        reason: 'still bounded by the actual viewport',
      );

      desktopContainer
          .read(routinePlayerControllerProvider.notifier)
          .endSession();
    },
  );

  testWidgets(
    'Lunges V2 Active shows the real six frames, correct name, full body, no crop, never the old bilateral left/right set',
    (tester) async {
      final container = await _bootAtQa(tester);
      final controller = container.read(
        routinePlayerControllerProvider.notifier,
      );

      // Squat (exercise 1) -> Rest -> Lunges (exercise 2).
      controller.skipPrepare();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 200));
      controller.skipExercise();
      await tester.pump();
      controller.skipRest();
      await tester.pump();
      controller.skipPrepare();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      expect(find.text('Lunges'), findsWidgets);
      expect(
        hasAssetImageContaining(tester, 'exercises/lunges/female/v2/'),
        isTrue,
        reason: 'Lunges must show its real verified V2 pose image',
      );
      expect(
        hasAssetImageContaining(tester, 'exercise_animations/lunges/'),
        isFalse,
        reason: 'the old bilateral left/right V1 set must never appear anymore',
      );

      // Full-body-safe: Lunges' own real portrait ratio (326x804), and every
      // rendered Lunges frame uses BoxFit.contain (never cover/crop).
      final lungeAspectRatios = tester
          .widgetList<AspectRatio>(find.byType(AspectRatio))
          .map((w) => w.aspectRatio);
      expect(
        lungeAspectRatios,
        contains(closeTo(326 / 804, 0.001)),
        reason:
            'Lunges must use its real portrait aspect ratio, so the full frame (including feet) stays visible with no crop',
      );
      final lungeImages = tester.widgetList<Image>(find.byType(Image)).where((
        img,
      ) {
        final provider = img.image;
        return provider is AssetImage &&
            provider.assetName.contains('exercises/lunges/female/v2/');
      });
      expect(lungeImages, isNotEmpty);
      for (final img in lungeImages) {
        expect(
          img.fit,
          BoxFit.contain,
          reason: 'Lunges frames must never be cropped via BoxFit.cover',
        );
      }

      controller.endSession();
    },
  );

  testWidgets(
    'Plank Active shows a real V2 landscape frame with BoxFit.contain (no crop), in a full-screen (not 460px-capped) layout',
    (tester) async {
      final container = await _bootAtQa(tester, size: const Size(1280, 800));
      final controller = container.read(
        routinePlayerControllerProvider.notifier,
      );

      // Skip through Squat, Lunges, Pushups, Deep Breathing to reach Plank
      // (exercise 5 of 7).
      for (var i = 0; i < 4; i++) {
        controller.skipPrepare();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(milliseconds: 200));
        controller.skipExercise();
        await tester.pump();
        controller.skipRest();
        await tester.pump();
      }
      controller.skipPrepare();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      expect(find.text('Plank'), findsWidgets);
      expect(
        hasAssetImageContaining(tester, 'exercises/plank/female/v2/'),
        isTrue,
        reason: 'Plank must show a real V2 landscape frame',
      );

      final images = tester.widgetList<Image>(find.byType(Image)).where((img) {
        final provider = img.image;
        return provider is AssetImage &&
            provider.assetName.contains('exercises/plank/female/v2/');
      });
      expect(images, isNotEmpty);
      for (final img in images) {
        expect(
          img.fit,
          BoxFit.contain,
          reason:
              'landscape Plank frames must never be cropped via BoxFit.cover',
        );
      }

      // Full-screen: the workout must not be squeezed into the old 460px card.
      final constrainedBoxFinder = find.byWidgetPredicate(
        (w) => w is ConstrainedBox && w.constraints.maxWidth < double.infinity,
      );
      final contentWidth = tester.getSize(constrainedBoxFinder.first).width;
      expect(contentWidth, greaterThan(800));

      // Bug 2 regression: Plank must render inside a LANDSCAPE container
      // (its own real 3:2 aspect ratio), using most of the available width —
      // not letterboxed inside a tall box designed for another orientation.
      final plankAspectRatios = tester
          .widgetList<AspectRatio>(find.byType(AspectRatio))
          .map((w) => w.aspectRatio);
      expect(
        plankAspectRatios,
        contains(closeTo(1.5, 0.001)),
        reason: 'Plank must use its real landscape aspect ratio',
      );
      final plankImageSize = tester.getSize(
        find
            .byWidgetPredicate(
              (w) =>
                  w is Image &&
                  w.image is AssetImage &&
                  (w.image as AssetImage).assetName.contains(
                    'exercises/plank/female/v2/',
                  ),
            )
            .first,
      );
      expect(
        plankImageSize.width,
        greaterThan(400),
        reason:
            'the landscape Plank visual must use substantial width, not a small letterboxed image inside a tall empty box',
      );

      controller.endSession();
    },
  );

  testWidgets(
    'Pushups V2 Active shows the real six frames, correct name, full body, no crop, controlled cadence, never a Plank frame or the old V1 set',
    (tester) async {
      final container = await _bootAtQa(tester, size: const Size(1280, 800));
      final controller = container.read(
        routinePlayerControllerProvider.notifier,
      );

      // Squat -> Rest -> Lunges -> Rest -> Pushups (exercise 3 of 5).
      for (var i = 0; i < 2; i++) {
        controller.skipPrepare();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(milliseconds: 200));
        controller.skipExercise();
        await tester.pump();
        controller.skipRest();
        await tester.pump();
      }
      controller.skipPrepare();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      // A. Heading says "Pushups" — never the old hyphenated "Push-Ups".
      expect(find.text('Pushups'), findsWidgets);
      expect(find.text('Push-Ups'), findsNothing);

      // B+C. Real V2 frame shown; no old EX010 static image, no old V1 set, no Plank frame.
      expect(
        hasAssetImageContaining(tester, 'exercises/pushups/female/v2/'),
        isTrue,
        reason: 'Pushups must show its own real V2 frame',
      );
      expect(
        hasAssetImageContaining(tester, 'exercises/pushups/female/v1/'),
        isFalse,
        reason: 'the old real-room V1 set must never appear anymore',
      );
      expect(
        hasAssetImageContaining(tester, 'exercises/EX010/female/'),
        isFalse,
        reason: 'must not show the old static Push-Ups image',
      );
      expect(
        hasAssetImageContaining(tester, 'exercises/plank/female/v2/'),
        isFalse,
        reason: 'Pushups must NEVER show a Plank V2 frame',
      );

      // F+G. Full body visible: real portrait ratio, BoxFit.contain (never stretched/cropped).
      final pushupsAspectRatios = tester
          .widgetList<AspectRatio>(find.byType(AspectRatio))
          .map((w) => w.aspectRatio);
      expect(pushupsAspectRatios, contains(closeTo(326 / 804, 0.001)));
      final pushupsImages = tester.widgetList<Image>(find.byType(Image)).where((
        img,
      ) {
        final provider = img.image;
        return provider is AssetImage &&
            provider.assetName.contains('exercises/pushups/female/v2/');
      });
      expect(pushupsImages, isNotEmpty);
      for (final img in pushupsImages) {
        expect(
          img.fit,
          BoxFit.contain,
          reason:
              'Pushups frames must never be cropped or stretched via BoxFit.cover',
        );
      }

      // H. Controlled cadence — still on an early step shortly after Start.
      expect(find.textContaining('STEP 1 OF 6'), findsOneWidget);

      controller.endSession();
    },
  );

  testWidgets(
    'Deep Breathing V2 Active shows the real six frames, correct name, full body, no crop, slow breathing cadence, never the old V1 or legacy EX001 frame',
    (tester) async {
      final container = await _bootAtQa(tester, size: const Size(1280, 800));
      final controller = container.read(
        routinePlayerControllerProvider.notifier,
      );

      // Squat -> Rest -> Lunges -> Rest -> Pushups -> Rest -> Deep Breathing (exercise 4 of 5).
      for (var i = 0; i < 3; i++) {
        controller.skipPrepare();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(milliseconds: 200));
        controller.skipExercise();
        await tester.pump();
        controller.skipRest();
        await tester.pump();
      }
      controller.skipPrepare();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      expect(find.text('Deep Breathing'), findsWidgets);

      // Real V2 frame shown; no old V1 or legacy EX001 static image, no other exercise's frame.
      expect(
        hasAssetImageContaining(tester, 'exercises/deep_breathing/female/v2/'),
        isTrue,
        reason: 'Deep Breathing must show its own real V2 frame',
      );
      expect(
        hasAssetImageContaining(tester, 'exercises/deep_breathing/female/v1/'),
        isFalse,
        reason: 'must not show the retired V1 illustrated frame',
      );
      expect(
        hasAssetImageContaining(tester, 'exercises/EX001/female/'),
        isFalse,
        reason: 'must not show the old legacy Exercise Sequence Library image',
      );
      expect(
        hasAssetImageContaining(tester, 'exercises/plank/female/v2/'),
        isFalse,
      );
      expect(
        hasAssetImageContaining(tester, 'exercises/pushups/female/v2/'),
        isFalse,
      );

      // Full body visible: real square ratio, BoxFit.contain (never stretched/cropped).
      final breathingAspectRatios = tester
          .widgetList<AspectRatio>(find.byType(AspectRatio))
          .map((w) => w.aspectRatio);
      expect(breathingAspectRatios, contains(closeTo(277 / 265, 0.001)));
      final breathingImages = tester
          .widgetList<Image>(find.byType(Image))
          .where((img) {
            final provider = img.image;
            return provider is AssetImage &&
                provider.assetName.contains(
                  'exercises/deep_breathing/female/v2/',
                );
          });
      expect(breathingImages, isNotEmpty);
      for (final img in breathingImages) {
        expect(
          img.fit,
          BoxFit.contain,
          reason:
              'Deep Breathing frames must never be cropped or stretched via BoxFit.cover',
        );
      }

      // Slow breathing cadence — still on frame 01 (SETTLE, [0,1.2)) shortly after Start.
      expect(find.textContaining('STEP 1 OF 6'), findsOneWidget);

      controller.endSession();
    },
  );

  testWidgets(
    'Jumping Jacks V2 Active shows the real six frames, correct name, full body, no crop, no crossfade, never another exercise\'s frame, never the old V1 real-room set',
    (tester) async {
      final container = await _bootAtQa(tester, size: const Size(1280, 800));
      final controller = container.read(
        routinePlayerControllerProvider.notifier,
      );

      // Squat -> Rest -> Lunges -> Rest -> Pushups -> Rest -> Deep Breathing ->
      // Rest -> Plank -> Rest -> Jumping Jacks (exercise 6 of 8).
      for (var i = 0; i < 5; i++) {
        controller.skipPrepare();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(milliseconds: 200));
        controller.skipExercise();
        await tester.pump();
        controller.skipRest();
        await tester.pump();
      }
      controller.skipPrepare();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      expect(find.text('Jumping Jacks'), findsWidgets);

      // Real V2 frame shown; never another exercise's frame, never the old V1 set.
      expect(
        hasAssetImageContaining(tester, 'exercises/jumping_jack/female/v2/'),
        isTrue,
        reason: 'Jumping Jacks must show its own real V2 frame',
      );
      expect(
        hasAssetImageContaining(tester, 'exercises/jumping_jack/female/v1/'),
        isFalse,
        reason: 'the old real-room V1 set must never appear anymore',
      );
      expect(
        hasAssetImageContaining(tester, 'exercises/plank/female/v2/'),
        isFalse,
      );
      expect(
        hasAssetImageContaining(tester, 'exercises/pushups/female/v2/'),
        isFalse,
      );
      expect(
        hasAssetImageContaining(tester, 'exercises/squat/female/v2/'),
        isFalse,
      );
      expect(
        hasAssetImageContaining(tester, 'exercises/lunges/female/v2/'),
        isFalse,
      );
      expect(
        hasAssetImageContaining(tester, 'exercises/deep_breathing/female/v2/'),
        isFalse,
      );

      // Full body visible: real portrait ratio, BoxFit.contain (never stretched/cropped).
      final jjAspectRatios = tester
          .widgetList<AspectRatio>(find.byType(AspectRatio))
          .map((w) => w.aspectRatio);
      expect(jjAspectRatios, contains(closeTo(362 / 724, 0.001)));
      final jjImages = tester.widgetList<Image>(find.byType(Image)).where((
        img,
      ) {
        final provider = img.image;
        return provider is AssetImage &&
            provider.assetName.contains('exercises/jumping_jack/female/v2/');
      });
      expect(jjImages, isNotEmpty);
      for (final img in jjImages) {
        expect(
          img.fit,
          BoxFit.contain,
          reason:
              'Jumping Jacks frames must never be cropped or stretched via BoxFit.cover',
        );
      }

      // No crossfade/ghosting — the AnimatedSwitcher driving this frame must
      // use a zero-duration (instant) transition, unlike every other exercise.
      final switchers = tester.widgetList<AnimatedSwitcher>(
        find.byType(AnimatedSwitcher),
      );
      expect(switchers, isNotEmpty);
      for (final s in switchers) {
        expect(
          s.duration,
          Duration.zero,
          reason:
              'Jumping Jacks must replace frames instantly, never fade through two overlapping semi-transparent bodies',
        );
      }

      controller.endSession();
    },
  );

  testWidgets(
    'Glute Bridge Active shows the real six frames, correct name, full body, no crop, controlled cadence, never another exercise\'s frame',
    (tester) async {
      final container = await _bootAtQa(tester, size: const Size(1280, 800));
      final controller = container.read(
        routinePlayerControllerProvider.notifier,
      );

      // Squat -> Rest -> Lunges -> Rest -> Pushups -> Rest -> Deep Breathing ->
      // Rest -> Plank -> Rest -> Jumping Jacks -> Rest -> Glute Bridge (exercise 7 of 9).
      for (var i = 0; i < 6; i++) {
        controller.skipPrepare();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(milliseconds: 200));
        controller.skipExercise();
        await tester.pump();
        controller.skipRest();
        await tester.pump();
      }
      controller.skipPrepare();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      expect(find.text('Glute Bridge'), findsWidgets);

      // Real frame shown; never another exercise's frame.
      expect(
        hasAssetImageContaining(tester, 'exercises/glute_bridge/female/v1/'),
        isTrue,
        reason: 'Glute Bridge must show its own real frame',
      );
      expect(
        hasAssetImageContaining(tester, 'exercises/plank/female/v2/'),
        isFalse,
      );
      expect(
        hasAssetImageContaining(tester, 'exercises/pushups/female/v2/'),
        isFalse,
      );
      expect(
        hasAssetImageContaining(tester, 'exercises/squat/female/v2/'),
        isFalse,
      );
      expect(
        hasAssetImageContaining(tester, 'exercises/lunges/female/v2/'),
        isFalse,
      );
      expect(
        hasAssetImageContaining(tester, 'exercises/deep_breathing/female/v2/'),
        isFalse,
      );
      expect(
        hasAssetImageContaining(tester, 'exercises/jumping_jack/female/v1/'),
        isFalse,
      );

      // Full body visible: real portrait ratio, BoxFit.contain (never stretched/cropped).
      final bridgeAspectRatios = tester
          .widgetList<AspectRatio>(find.byType(AspectRatio))
          .map((w) => w.aspectRatio);
      expect(bridgeAspectRatios, contains(closeTo(326 / 804, 0.001)));
      final bridgeImages = tester.widgetList<Image>(find.byType(Image)).where((
        img,
      ) {
        final provider = img.image;
        return provider is AssetImage &&
            provider.assetName.contains('exercises/glute_bridge/female/v1/');
      });
      expect(bridgeImages, isNotEmpty);
      for (final img in bridgeImages) {
        expect(
          img.fit,
          BoxFit.contain,
          reason:
              'Glute Bridge frames must never be cropped or stretched via BoxFit.cover',
        );
      }

      // Controlled cadence — still on an early step shortly after Start.
      expect(find.textContaining('STEP 1 OF 6'), findsOneWidget);

      controller.endSession();
    },
  );

  testWidgets(
    'Mountain Climbers V1 Active shows the real six frames, correct name, full body, no crop, no crossfade, never another exercise\'s frame',
    (tester) async {
      final container = await _bootAtQa(tester, size: const Size(1280, 800));
      final controller = container.read(
        routinePlayerControllerProvider.notifier,
      );

      // Squat -> Rest -> Lunges -> Rest -> Pushups -> Rest -> Deep Breathing ->
      // Rest -> Plank -> Rest -> Jumping Jacks -> Rest -> Glute Bridge -> Rest
      // -> Mountain Climbers (exercise 8 of 9).
      for (var i = 0; i < 7; i++) {
        controller.skipPrepare();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(milliseconds: 200));
        controller.skipExercise();
        await tester.pump();
        controller.skipRest();
        await tester.pump();
      }
      controller.skipPrepare();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      expect(find.text('Mountain Climbers'), findsWidgets);

      // Real V1 frame shown; never another exercise's frame.
      expect(
        hasAssetImageContaining(
          tester,
          'exercises/mountain_climbers/female/v1/',
        ),
        isTrue,
        reason: 'Mountain Climbers must show its own real V1 frame',
      );
      expect(
        hasAssetImageContaining(tester, 'exercises/plank/female/v2/'),
        isFalse,
      );
      expect(
        hasAssetImageContaining(tester, 'exercises/pushups/female/v2/'),
        isFalse,
      );
      expect(
        hasAssetImageContaining(tester, 'exercises/squat/female/v2/'),
        isFalse,
      );
      expect(
        hasAssetImageContaining(tester, 'exercises/lunges/female/v2/'),
        isFalse,
      );
      expect(
        hasAssetImageContaining(tester, 'exercises/deep_breathing/female/v2/'),
        isFalse,
      );
      expect(
        hasAssetImageContaining(tester, 'exercises/jumping_jack/female/v1/'),
        isFalse,
      );
      expect(
        hasAssetImageContaining(tester, 'exercises/glute_bridge/female/v1/'),
        isFalse,
      );

      // Full body visible: real landscape ratio, BoxFit.contain (never stretched/cropped).
      final mcAspectRatios = tester
          .widgetList<AspectRatio>(find.byType(AspectRatio))
          .map((w) => w.aspectRatio);
      expect(mcAspectRatios, contains(closeTo(600 / 400, 0.001)));
      final mcImages = tester.widgetList<Image>(find.byType(Image)).where((
        img,
      ) {
        final provider = img.image;
        return provider is AssetImage &&
            provider.assetName.contains(
              'exercises/mountain_climbers/female/v1/',
            );
      });
      expect(mcImages, isNotEmpty);
      for (final img in mcImages) {
        expect(
          img.fit,
          BoxFit.contain,
          reason:
              'Mountain Climbers frames must never be cropped or stretched via BoxFit.cover',
        );
      }

      // No crossfade/ghosting — clean sequential frame replacement.
      final switchers = tester.widgetList<AnimatedSwitcher>(
        find.byType(AnimatedSwitcher),
      );
      expect(switchers, isNotEmpty);
      for (final s in switchers) {
        expect(
          s.duration,
          Duration.zero,
          reason:
              'Mountain Climbers must replace frames instantly, never fade through two overlapping semi-transparent bodies',
        );
      }

      controller.endSession();
    },
  );

  testWidgets(
    'Dead Bug V2 Active shows the real six frames, correct name, full body, no crop, no crossfade, never another exercise\'s frame',
    (tester) async {
      final container = await _bootAtQa(tester, size: const Size(1280, 800));
      final controller = container.read(
        routinePlayerControllerProvider.notifier,
      );

      // Squat -> Rest -> Lunges -> Rest -> Pushups -> Rest -> Deep Breathing ->
      // Rest -> Plank -> Rest -> Jumping Jacks -> Rest -> Glute Bridge -> Rest
      // -> Mountain Climbers -> Rest -> Dead Bug (exercise 9 of 9).
      for (var i = 0; i < 8; i++) {
        controller.skipPrepare();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(milliseconds: 200));
        controller.skipExercise();
        await tester.pump();
        controller.skipRest();
        await tester.pump();
      }
      controller.skipPrepare();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      expect(find.text('Dead Bug'), findsWidgets);

      // Real V2 frame shown; never another exercise's frame, never the retired V1 assets.
      expect(
        hasAssetImageContaining(tester, 'exercises/dead_bug/female/v2/'),
        isTrue,
        reason: 'Dead Bug must show its own real V2 frame',
      );
      expect(
        hasAssetImageContaining(tester, 'exercises/dead_bug/female/v1/'),
        isFalse,
        reason: 'must never fall back to the retired V1 assets',
      );
      expect(
        hasAssetImageContaining(tester, 'exercises/plank/female/v2/'),
        isFalse,
      );
      expect(
        hasAssetImageContaining(tester, 'exercises/pushups/female/v2/'),
        isFalse,
      );
      expect(
        hasAssetImageContaining(tester, 'exercises/squat/female/v2/'),
        isFalse,
      );
      expect(
        hasAssetImageContaining(tester, 'exercises/lunges/female/v2/'),
        isFalse,
      );
      expect(
        hasAssetImageContaining(tester, 'exercises/deep_breathing/female/v2/'),
        isFalse,
      );
      expect(
        hasAssetImageContaining(tester, 'exercises/jumping_jack/female/v1/'),
        isFalse,
      );
      expect(
        hasAssetImageContaining(tester, 'exercises/glute_bridge/female/v1/'),
        isFalse,
      );
      expect(
        hasAssetImageContaining(
          tester,
          'exercises/mountain_climbers/female/v1/',
        ),
        isFalse,
      );

      // Full body visible: real landscape ratio, BoxFit.contain (never stretched/cropped).
      final dbAspectRatios = tester
          .widgetList<AspectRatio>(find.byType(AspectRatio))
          .map((w) => w.aspectRatio);
      expect(dbAspectRatios, contains(closeTo(600 / 400, 0.001)));
      final dbImages = tester.widgetList<Image>(find.byType(Image)).where((
        img,
      ) {
        final provider = img.image;
        return provider is AssetImage &&
            provider.assetName.contains('exercises/dead_bug/female/v2/');
      });
      expect(dbImages, isNotEmpty);
      for (final img in dbImages) {
        expect(
          img.fit,
          BoxFit.contain,
          reason:
              'Dead Bug frames must never be cropped or stretched via BoxFit.cover',
        );
      }

      // No crossfade/ghosting — clean sequential frame replacement.
      final switchers = tester.widgetList<AnimatedSwitcher>(
        find.byType(AnimatedSwitcher),
      );
      expect(switchers, isNotEmpty);
      for (final s in switchers) {
        expect(
          s.duration,
          Duration.zero,
          reason:
              'Dead Bug must replace frames instantly, never fade through two overlapping semi-transparent bodies',
        );
      }

      controller.endSession();
    },
  );

  testWidgets(
    'Full 9-exercise QA routine reaches Complete with real session data, no overflow anywhere',
    (tester) async {
      final container = await _bootAtQa(tester);
      final controller = container.read(
        routinePlayerControllerProvider.notifier,
      );

      for (var i = 0; i < 9; i++) {
        controller.skipPrepare();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(milliseconds: 200));
        expect(
          tester.takeException(),
          isNull,
          reason: 'exercise index $i active screen must not overflow',
        );
        controller.skipExercise();
        await tester.pump();
        if (i < 8) {
          expect(find.text('REST'), findsOneWidget);
          controller.skipRest();
          await tester.pump();
        }
      }

      expect(find.text('🎉 Routine Complete!'), findsOneWidget);
      expect(find.text('Exercises: 9'), findsOneWidget);
      expect(tester.takeException(), isNull);
      // Complete phase has no ticking timer, but end explicitly for symmetry.
      controller.endSession();
    },
  );

  testWidgets(
    '7. voice mode controls (COACH ON / CUES ONLY / SILENT) render in RoutinePlayer and actually switch the live voice mode',
    (tester) async {
      final container = await _bootAtQa(tester);
      final controller = container.read(
        routinePlayerControllerProvider.notifier,
      );

      expect(find.text('COACH ON'), findsOneWidget);
      expect(find.text('CUES ONLY'), findsOneWidget);
      expect(find.text('SILENT'), findsOneWidget);
      expect(
        container.read(routinePlayerControllerProvider)!.voiceMode,
        VoiceMode.coachOn,
        reason: 'default mode',
      );

      await tester.tap(find.text('CUES ONLY'));
      await tester.pump();
      expect(
        container.read(routinePlayerControllerProvider)!.voiceMode,
        VoiceMode.cuesOnly,
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('SILENT'));
      await tester.pump();
      expect(
        container.read(routinePlayerControllerProvider)!.voiceMode,
        VoiceMode.silent,
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('COACH ON'));
      await tester.pump();
      expect(
        container.read(routinePlayerControllerProvider)!.voiceMode,
        VoiceMode.coachOn,
      );

      controller.endSession();
    },
  );

  testWidgets(
    'shared safe-content padding: Dead Bug, Fire Hydrant, and Mountain Climbers frames all render with the MovementDisplay safety margin, never edge-to-edge',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.binding.setSurfaceSize(const Size(402, 874));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final routine = [
        kRoutinePlayerExercisesById['EX012']!,
        kRoutinePlayerExercisesById['EX054']!,
        kRoutinePlayerExercisesById['EX017']!,
      ];
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: RoutinePlayerQaEntry(routine: routine, onExit: () {}),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      for (final exercise in routine) {
        final controller = container.read(
          routinePlayerControllerProvider.notifier,
        );
        controller.startRoutine([exercise]);
        await tester.pump();
        expect(
          tester.takeException(),
          isNull,
          reason:
              '${exercise.displayName} prepare view must render without error',
        );

        final imageFinder = find.byType(Image);
        expect(
          imageFinder,
          findsWidgets,
          reason: '${exercise.displayName} must show a real frame image',
        );
        final paddingAncestor = find
            .ancestor(of: imageFinder.first, matching: find.byType(Padding))
            .first;
        final padding = tester.widget<Padding>(paddingAncestor).padding;
        expect(
          padding,
          const EdgeInsets.all(18),
          reason:
              '${exercise.displayName}\'s frame must use the shared safe-content margin, not render edge-to-edge',
        );

        controller.endSession();
      }
    },
  );
}
