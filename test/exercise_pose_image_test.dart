// Verifies the hard rule from the "APPROVED FIGMA IMAGES ONLY" directive:
// verified exercises show a real Image.asset for their pose art — never
// emoji/icon/text standing in for a pose that has a verified image — while
// a genuinely unverified exercise correctly falls back to clean text
// rather than any invented substitute. EX011 Plank remains verified
// through the Tier 2 legacy catalog; EX001 Deep Breathing, EX007 Squat,
// EX008 Lunges, EX009 Jumping Jacks, EX010 Push-Ups, and EX061 Full Body
// Stretch are all verified through the Tier 1 RoutinePlayer registry
// instead, each after its own V2 asset replacement (see
// resolvePoseAssetPath's Tier 1 fallback in workout_widgets.dart).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:glow_up/app/glow_up_app.dart';
import 'package:glow_up/onboarding/state/onboarding_controller.dart';
import 'package:glow_up/routing/app_router.dart';

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

Future<void> _tapCategory(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

/// True if any rendered Image widget's AssetImage path contains [needle] —
/// the real signal that a verified Figma pose PNG is on screen, not just
/// that some Image widget exists.
bool _hasAssetImageContaining(WidgetTester tester, String needle) {
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
  testWidgets(
    'Strength Foundations detail shows real Figma images for Squat (approved V2), Lunges, Push-Ups',
    (tester) async {
      final container = await _bootAtWorkoutHub(tester);
      addTearDown(container.dispose);

      await _tapCategory(tester, 'Strength');
      await tester.tap(find.text('Strength Foundations'));
      await tester.pumpAndSettle();

      // Squat's Tier 2 legacy `hasVerifiedImages` was flipped off as part
      // of its V2 asset replacement (same fix as EX001 Deep Breathing and
      // EX009 Jumping Jacks), so this now resolves via resolvePoseAssetPath's
      // Tier 1 fallback instead of the old legacy exercises/EX007/female/01.png photo.
      expect(
        _hasAssetImageContaining(tester, 'exercises/squat/female/v2/'),
        isTrue,
        reason: 'Squat should show its real verified V2 pose image',
      );
      expect(
        _hasAssetImageContaining(tester, 'exercises/EX007/female/'),
        isFalse,
        reason: 'must never show the old legacy Tier 2 photo anymore',
      );
      expect(
        _hasAssetImageContaining(tester, 'exercises/lunges/female/v2/'),
        isTrue,
        reason: 'Lunges should show its real verified V2 pose image',
      );
      expect(
        _hasAssetImageContaining(tester, 'exercises/EX008/female/'),
        isFalse,
        reason: 'must never show the old legacy Tier 2 photo anymore',
      );
      expect(
        _hasAssetImageContaining(tester, 'exercises/pushups/female/v2/'),
        isTrue,
        reason: 'Push-Ups should show its real verified V2 pose image',
      );
      expect(
        _hasAssetImageContaining(tester, 'exercises/EX010/female/'),
        isFalse,
        reason: 'must never show the old legacy Tier 2 photo anymore',
      );
    },
  );

  testWidgets('Core Crusher detail shows a real Figma image for Plank', (
    tester,
  ) async {
    final container = await _bootAtWorkoutHub(tester);
    addTearDown(container.dispose);

    await _tapCategory(tester, 'Core');
    await tester.tap(find.text('Core Crusher'));
    await tester.pumpAndSettle();

    expect(
      _hasAssetImageContaining(tester, 'exercises/EX011/female/01.png'),
      isTrue,
      reason: 'Plank should show its real verified pose image',
    );
  });

  testWidgets(
    'Bedtime Meditation shows the approved V2 images for both Deep Breathing (EX001) and Full Body Stretch (EX061) — neither the old legacy EX001 photo nor an emoji ever reappears',
    (tester) async {
      final container = await _bootAtWorkoutHub(tester);
      addTearDown(container.dispose);

      await _tapCategory(tester, 'Bedtime');
      await tester.tap(find.text('Bedtime Meditation'));
      await tester.pumpAndSettle();

      // Deep Breathing's legacy Tier 2 image was replaced by its approved
      // Tier 1 V2 set (hasVerifiedImages flipped to false for EX001 in the
      // legacy catalog) — the routine-detail thumbnail must show the new
      // approved image, never the old legacy photo.
      expect(
        _hasAssetImageContaining(tester, 'exercises/deep_breathing/female/v2/'),
        isTrue,
        reason: 'Deep Breathing should show its real approved V2 pose image',
      );
      expect(
        _hasAssetImageContaining(tester, 'exercises/EX001/female/01.png'),
        isFalse,
        reason: 'must never show the retired legacy Tier 2 photo anymore',
      );
      // Bedtime Meditation's Full Body Stretch is EX061 — a separate exercise
      // from EX002 ("Full Body Stretch (Cardio)", now approved for Full Body
      // Burn, see full_body_burn_next_four_v2_test.dart); EX002 is never
      // referenced by this routine, so no exercises/EX002 asset should ever
      // appear here.
      expect(
        _hasAssetImageContaining(
          tester,
          'exercises/full_body_stretch/female/v2/',
        ),
        isTrue,
        reason: 'Full Body Stretch should show its real approved V2 pose image',
      );
      expect(_hasAssetImageContaining(tester, 'exercises/EX002'), isFalse);
      expect(
        find.text('🙆'),
        findsNothing,
      ); // former Full Body Stretch emoji, must never reappear
    },
  );

  testWidgets(
    'HIIT Cardio Blast detail shows the real Jumping Jacks V2 pose image (list-row level, same pattern as every other test above)',
    (tester) async {
      // Since EX076 March In Place gave Cardio a second real Tier 1
      // exercise, `canUsePerExerciseResolution` (app_router.dart) now
      // covers Cardio too — "Start Workout" on HIIT Cardio Blast opens
      // RoutinePlayer, not the legacy WorkoutGetReadyScreen/
      // WorkoutActiveScreen this test used to drive through. Scoped down
      // to the detail-list check instead (exactly what "Strength
      // Foundations"/"Core Crusher"/"Bedtime Meditation" above already
      // do, and always did) — still real coverage of the same hard rule
      // (a verified exercise shows its real Figma image, never an emoji),
      // just no longer coupled to which tier currently handles the full
      // session. RoutinePlayer's own real-Jumping-Jacks-frame coverage
      // lives in routine_player_widget_test.dart/routine_player_engine_
      // test.dart.
      //
      // Asset path is the new V2 Tier 1 set: EX009's Tier 2 catalog
      // `hasVerifiedImages` was flipped off as part of its V2 asset
      // replacement (same fix as EX001 Deep Breathing's own V2 pass), so
      // this now resolves via resolvePoseAssetPath's Tier 1 fallback
      // instead of the old legacy exercises/EX009/female/01.png photo.
      final container = await _bootAtWorkoutHub(tester);
      addTearDown(container.dispose);

      await _tapCategory(tester, 'Cardio');
      await tester.tap(find.text('HIIT Cardio Blast'));
      await tester.pumpAndSettle();

      expect(find.text('Jumping Jacks'), findsOneWidget);
      expect(
        _hasAssetImageContaining(tester, 'exercises/jumping_jack/female/v2/'),
        isTrue,
        reason: 'Jumping Jacks should show its real verified V2 pose image',
      );
      expect(
        _hasAssetImageContaining(tester, 'exercises/EX009/female/'),
        isFalse,
        reason: 'must never show the old legacy Tier 2 photo anymore',
      );
      expect(
        find.textContaining('🤸'),
        findsNothing,
      ); // former Jumping Jacks emoji, must never reappear
    },
  );
}
