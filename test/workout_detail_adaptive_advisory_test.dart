// Covers closing the Tier 2/4 live-application connection gap: opening
// WorkoutDetailScreen is the real Tier 2 "adaptive surface" trigger — with
// an active safety flag on the workout's first resolvable exercise, the
// screen surfaces a real AdaptiveAdvisoryCard (Tier 3 template text), and
// "Start Workout" is never blocked by it. Accept/Dismiss both record a
// real recommendation-outcome event.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:glow_up/brain/recommendations/coach_recommendation_controller.dart';
import 'package:glow_up/brain/safety/safety_flag_controller.dart';
import 'package:glow_up/workout/data/workout_catalog.dart';
import 'package:glow_up/workout/models/workout_completion_record.dart'
    show PainSeverity;
import 'package:glow_up/workout/screens/workout_detail_screen.dart';

final _strengthFoundations = workoutById('strength-foundations')!;

/// Seeds a safety flag through a real, throwaway [SafetyFlagController]
/// instance — writing to the same shared mock [SharedPreferences] store
/// every subsequent `SharedPreferences.getInstance()` call in this test
/// resolves to (the same "durability across a fresh repository instance"
/// guarantee already proven in `water_tracker_persistence_test.dart`).
/// The widget tree's own container constructs its own controller
/// independently and reloads this same durable data — no `Ref` mocking.
Future<void> _seedSafetyFlag({
  required String exerciseId,
  required PainSeverity severity,
  required String sourceEventId,
}) async {
  final seedContainer = ProviderContainer();
  final controller = seedContainer.read(safetyFlagControllerProvider.notifier);
  await controller.ready;
  await controller.registerPainReport(
    exerciseId: exerciseId,
    severity: severity,
    sourceEventId: sourceEventId,
  );
  seedContainer.dispose();
}

Future<ProviderContainer> _boot(
  WidgetTester tester, {
  VoidCallback? onStart,
}) async {
  await tester.binding.setSurfaceSize(const Size(402, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final container = ProviderContainer();
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: WorkoutDetailScreen(
          workout: _strengthFoundations,
          onBack: () {},
          onStart: onStart ?? () {},
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return container;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'no active safety flag -> no advisory card, Start Workout still present',
    (tester) async {
      await _boot(tester);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('AI COACH'), findsNothing);
      expect(find.text('Got It'), findsNothing);
      expect(find.text('Start Workout'), findsOneWidget);
    },
  );

  testWidgets(
    'an active severe safety flag on the first exercise surfaces a real advisory with template text',
    (tester) async {
      await _seedSafetyFlag(
        exerciseId: 'EX007',
        severity: PainSeverity.severe,
        sourceEventId: 'seed-pain-1',
      );

      final container = await _boot(tester);
      // Give the post-frame Tier 2/3 check a moment to resolve.
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('AI COACH'), findsOneWidget);
      expect(find.textContaining('pain or discomfort'), findsOneWidget);
      expect(find.text('Got It'), findsOneWidget);
      // Never blocked.
      expect(find.text('Start Workout'), findsOneWidget);

      final recs =
          container.read(coachRecommendationControllerProvider).value ??
          const [];
      expect(
        recs,
        isNotEmpty,
        reason: 'the Tier 2 decision must actually be stored, not just shown',
      );
      expect(recs.first.targetEntityId, 'EX007');
    },
  );

  testWidgets(
    'tapping Got It records an accepted outcome and hides the advisory',
    (tester) async {
      await _seedSafetyFlag(
        exerciseId: 'EX007',
        severity: PainSeverity.moderate,
        sourceEventId: 'seed-pain-2',
      );

      final container = await _boot(tester);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Got It'), findsOneWidget);

      await tester.ensureVisible(find.text('Got It'));
      await tester.tap(find.text('Got It'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        find.text('Got It'),
        findsNothing,
        reason: 'the advisory must hide once acknowledged',
      );
      final recs = container.read(coachRecommendationControllerProvider).value!;
      expect(recs.first.outcomeStatus.toString(), contains('accepted'));
    },
  );

  testWidgets(
    'tapping Dismiss records a dismissed outcome and hides the advisory, Start Workout still works',
    (tester) async {
      var started = false;
      await _seedSafetyFlag(
        exerciseId: 'EX007',
        severity: PainSeverity.mild,
        sourceEventId: 'seed-pain-3',
      );

      final container = await _boot(tester, onStart: () => started = true);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Dismiss'), findsOneWidget);

      await tester.ensureVisible(find.text('Dismiss'));
      await tester.tap(find.text('Dismiss'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Dismiss'), findsNothing);

      final recs = container.read(coachRecommendationControllerProvider).value!;
      expect(recs.first.outcomeStatus.toString(), contains('dismissed'));

      await tester.tap(find.text('Start Workout'));
      expect(
        started,
        isTrue,
        reason: 'the advisory must never block starting the workout',
      );
    },
  );
}
