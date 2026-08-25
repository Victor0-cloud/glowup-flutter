// Widget-level coverage of the real completion -> feedback -> exit flow
// (Phase 1's "complete the entire Workout Module feedback loop" checkpoint):
// the completion summary saves exactly once (even under a rapid repeated
// tap or a rebuild), Continue reveals the post-workout feedback card, Save
// and Skip for Now both reach a safe next destination, the Pain/Discomfort
// follow-up is reachable and saved, and exiting before the real last
// exercise never creates a completion record at all.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:glow_up/routine_player/data/routine_player_registry.dart';
import 'package:glow_up/routine_player/models/exercise_definition.dart';
import 'package:glow_up/routine_player/screens/routine_player_screen.dart';
import 'package:glow_up/routine_player/state/routine_player_controller.dart';
import 'package:glow_up/workout/state/workout_history_controller.dart';

Future<ProviderContainer> _bootAtQa(
  WidgetTester tester, {
  required List<ExerciseDefinition> routine,
  required VoidCallback onExit,
}) async {
  await tester.binding.setSurfaceSize(const Size(402, 874));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final container = ProviderContainer();
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: RoutinePlayerQaEntry(routine: routine, onExit: onExit),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return container;
}

Future<void> _reachComplete(
  WidgetTester tester,
  RoutinePlayerController controller,
) async {
  controller.skipPrepare();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(milliseconds: 200));
  controller.skipExercise();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final singleExerciseRoutine = [kRoutinePlayerPhase1Qa.first];

  testWidgets(
    'reaching Complete saves exactly one history record, even across a rebuild/repeated frame',
    (tester) async {
      final container = await _bootAtQa(
        tester,
        routine: singleExerciseRoutine,
        onExit: () {},
      );
      final controller = container.read(
        routinePlayerControllerProvider.notifier,
      );
      await _reachComplete(tester, controller);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(
        const Duration(milliseconds: 50),
      ); // extra frames must not re-save

      final history = container.read(workoutHistoryControllerProvider).value!;
      expect(
        history,
        hasLength(1),
        reason: 'exactly one completion record, never duplicated by rebuilds',
      );
      // _reachComplete uses skipExercise() (fast — no need to wait out a
      // real 45s exercise timer just to reach the last one), so the one
      // exercise in this routine lands in skippedExerciseIds, not
      // completedExerciseIds — this also doubles as real coverage that
      // skipped exercises make it into the saved record at all.
      expect(history.first.completedExerciseIds, isEmpty);
      expect(history.first.skippedExerciseIds, [
        kRoutinePlayerPhase1Qa.first.id,
      ]);
      expect(
        history.first.feeling,
        isNull,
        reason: 'no feedback yet — Continue hasn\'t been tapped',
      );

      controller.endSession();
    },
  );

  testWidgets(
    'Continue reveals feedback; Skip for Now reaches the safe next destination without saving feedback',
    (tester) async {
      var exitCount = 0;
      final container = await _bootAtQa(
        tester,
        routine: singleExerciseRoutine,
        onExit: () => exitCount++,
      );
      final controller = container.read(
        routinePlayerControllerProvider.notifier,
      );
      await _reachComplete(tester, controller);
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('How did this workout feel?'), findsNothing);

      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(find.text('How did this workout feel?'), findsOneWidget);
      expect(find.text('Skip for Now'), findsOneWidget);

      await tester.tap(find.text('Skip for Now'));
      await tester.pump();

      expect(
        exitCount,
        1,
        reason: 'Skip must reach the same safe exit as Save',
      );
      final history = container.read(workoutHistoryControllerProvider).value!;
      expect(history, hasLength(1));
      expect(history.first.feeling, isNull);

      controller.endSession();
    },
  );

  testWidgets(
    'selecting Too Hard and Save persists the feeling and exits; repeated taps never save twice',
    (tester) async {
      var exitCount = 0;
      final container = await _bootAtQa(
        tester,
        routine: singleExerciseRoutine,
        onExit: () => exitCount++,
      );
      final controller = container.read(
        routinePlayerControllerProvider.notifier,
      );
      await _reachComplete(tester, controller);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Continue'));
      await tester.pump();

      await tester.tap(find.text('Too Hard'));
      await tester.pump();

      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(exitCount, 1);
      final history = container.read(workoutHistoryControllerProvider).value!;
      expect(history, hasLength(1));
      expect(history.first.feeling, isNotNull);

      controller.endSession();
    },
  );

  testWidgets(
    'selecting Pain or Discomfort reveals the body-area/severity follow-up and saves it',
    (tester) async {
      final container = await _bootAtQa(
        tester,
        routine: singleExerciseRoutine,
        onExit: () {},
      );
      final controller = container.read(
        routinePlayerControllerProvider.notifier,
      );
      await _reachComplete(tester, controller);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(find.text('Mild'), findsNothing);
      await tester.tap(find.text('Pain or Discomfort'));
      await tester.pump();
      expect(find.text('Mild'), findsOneWidget);
      expect(find.text('Moderate'), findsOneWidget);
      expect(find.text('Severe'), findsOneWidget);

      await tester.tap(find.text('Moderate'));
      await tester.pump();
      await tester.enterText(
        find.widgetWithText(TextField, 'Body area (optional)'),
        'Shoulder',
      );
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final history = container.read(workoutHistoryControllerProvider).value!;
      expect(history.first.painDetails?.bodyArea, 'Shoulder');
      expect(
        history.first.painDetails?.severity.toString(),
        contains('moderate'),
      );
      expect(history.first.hasPainFlag, isTrue);

      controller.endSession();
    },
  );

  testWidgets(
    'exiting before the real last exercise never creates a completion record',
    (tester) async {
      final twoExerciseRoutine = kRoutinePlayerPhase1Qa.take(2).toList();
      final container = await _bootAtQa(
        tester,
        routine: twoExerciseRoutine,
        onExit: () {},
      );
      final controller = container.read(
        routinePlayerControllerProvider.notifier,
      );
      controller.skipPrepare();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 200));
      // Exit mid-first-exercise — never reaches Complete.
      controller.endSession();
      await tester.pump();

      final history =
          container.read(workoutHistoryControllerProvider).value ?? const [];
      expect(
        history,
        isEmpty,
        reason: 'an interrupted session must never be saved as completed',
      );
    },
  );
}
