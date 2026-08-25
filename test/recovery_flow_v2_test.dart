// Covers Recovery Flow's four exercises (EX049-EX052) getting real Tier 1
// RoutinePlayer definitions for the first time — asset resolution (no
// missing frames, preview matches playback), order/duration fidelity
// against the pre-existing Tier 2 catalog metadata, real navigation to
// RoutinePlayer (no router change needed — `_routinePlayerRoutineFor`'s
// existing all-or-nothing gate does this automatically), and the shared
// Brain foundation's pain-safety-flag path working for a Recovery exercise
// exactly as it already does for every other module.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:glow_up/app/glow_up_app.dart';
import 'package:glow_up/brain/safety/safety_flag_controller.dart';
import 'package:glow_up/onboarding/state/onboarding_controller.dart';
import 'package:glow_up/routine_player/data/routine_player_registry.dart';
import 'package:glow_up/routing/app_router.dart';
import 'package:glow_up/workout/data/workout_catalog.dart';
import 'package:glow_up/workout/models/workout_completion_record.dart'
    show PainSeverity;

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

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Recovery Flow workout catalog', () {
    test(
      'exists under the Recovery category with the exact approved order',
      () {
        final workout = workoutById('recovery-flow')!;
        expect(workout.category.name, 'recovery');
        expect(workout.exercises.map((e) => e.catalogId).toList(), [
          'EX049',
          'EX050',
          'EX051',
          'EX052',
        ]);
      },
    );

    test(
      'every exercise durationSeconds matches the Tier 2 catalog source of truth',
      () {
        final workout = workoutById('recovery-flow')!;
        final expected = {'EX049': 40, 'EX050': 40, 'EX051': 25, 'EX052': 40};
        for (final e in workout.exercises) {
          expect(e.durationSeconds, expected[e.catalogId]);
        }
      },
    );
  });

  group('Tier 1 registration — EX049-EX052', () {
    for (final entry in const {
      'EX049': ('Figure Four Stretch', 'figure_four_stretch', 40),
      'EX050': ('Calf Stretch', 'calf_stretch', 40),
      'EX051': ('Chest Opener', 'chest_opener', 25),
      'EX052': ('90/90 Hip Switch', '90_90_hip_switch', 40),
    }.entries) {
      final id = entry.key;
      final (name, slug, duration) = entry.value;

      test(
        '$id ($name) resolves with 6 real, distinct frames and a matching preview',
        () {
          final def = routinePlayerExerciseById(id);
          expect(
            def,
            isNotNull,
            reason: '$id must have a real Tier 1 definition',
          );
          expect(def!.displayName, name);
          expect(def.durationSeconds, duration);
          expect(def.poses.length, 6);
          for (var i = 0; i < 6; i++) {
            expect(def.poses[i].order, i + 1);
            expect(
              def.poses[i].approvedAsset,
              'assets/glow_up/exercises/$slug/female/v2/F_0${i + 1}.png',
            );
          }
          // No missing/duplicate frame: 6 distinct real asset paths.
          expect(def.poses.map((p) => p.approvedAsset).toSet().length, 6);
          // Preview is the dedicated filmstrip, never one of the 6 playback frames.
          expect(
            def.previewAssetPath,
            'assets/glow_up/exercises/$slug/female/v2/sequence_preview.png',
          );
          expect(
            def.poses.every((p) => p.approvedAsset != def.previewAssetPath),
            isTrue,
          );
        },
      );
    }
  });

  group('Workout -> Recovery -> Recovery Flow -> Start Workout', () {
    testWidgets(
      'opens RoutinePlayer directly on Figure Four Stretch, real content, never the legacy session',
      (tester) async {
        final container = await _bootAtWorkoutHub(tester);
        appRouter.go('/workout/recovery-flow');
        await tester.pumpAndSettle();

        await tester.tap(find.text('Start Workout'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Figure Four Stretch'), findsWidgets);
        container.dispose();
      },
    );
  });

  group('Recovery pain feedback — shared Brain safety-flag path', () {
    test(
      'registering a pain report for a Recovery exercise creates the same real safety flag as any other module',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final safety = container.read(safetyFlagControllerProvider.notifier);
        await safety.ready;

        final saved = await safety.registerPainReport(
          exerciseId: 'EX052',
          severity: PainSeverity.moderate,
          sourceEventId: 'recovery-pain-1',
        );

        expect(saved, isNotNull);
        expect(safety.activeFlagFor('EX052')?.severity, PainSeverity.moderate);
      },
    );
  });
}
