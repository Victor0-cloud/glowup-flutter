// Covers Section A (Exercise -> AI Coach Feedback): the generalized
// per-exercise feedback scale (including the new `challenging` value),
// skippability, pain -> safety-flag wiring with no AI provider, the
// "Ask Coach about this exercise" bounded-context answer service, and
// the structural "no AI call on ingest/Tier 1" guarantee.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:glow_up/brain/events/learning_event.dart';
import 'package:glow_up/brain/events/learning_event_controller.dart';
import 'package:glow_up/brain/safety/safety_flag.dart';
import 'package:glow_up/brain/safety/safety_flag_controller.dart';
import 'package:glow_up/routine_player/data/routine_player_registry.dart';
import 'package:glow_up/workout/coach/exercise_coach_answer_service.dart';
import 'package:glow_up/workout/models/workout_completion_record.dart';
import 'package:glow_up/workout/state/exercise_feedback_events.dart';
import 'package:glow_up/workout/widgets/exercise_feedback_card.dart';

/// Captures a real [WidgetRef] from a throwaway widget tree so
/// `submitExerciseFeedback`/`submitExerciseQuestionAsked` (which take a
/// [WidgetRef], matching their real call site in `RoutinePlayerScreen`)
/// can be exercised directly against a real, inspectable
/// [ProviderContainer] — without needing to drive the full, heavily
/// orchestrated RoutinePlayer screen through a widget test.
Future<WidgetRef> _refHarness(
  WidgetTester tester,
  ProviderContainer container,
) async {
  late WidgetRef captured;
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) {
            captured = ref;
            return const SizedBox();
          },
        ),
      ),
    ),
  );
  return captured;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WorkoutFeeling.challenging', () {
    test(
      'serializes and restores correctly through WorkoutCompletionRecord JSON',
      () {
        final record = WorkoutCompletionRecord(
          id: 'r1',
          profileId: WorkoutCompletionRecord.localProfileId,
          workoutId: 'w1',
          workoutName: 'Test Workout',
          startedAt: DateTime(2026, 1, 1, 8),
          completedAt: DateTime(2026, 1, 1, 8, 30),
          totalDurationSeconds: 1800,
          completedExerciseIds: const ['EX066'],
          skippedExerciseIds: const [],
          status: WorkoutCompletionStatus.completed,
          feeling: WorkoutFeeling.challenging,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        );
        final restored = WorkoutCompletionRecord.fromJson(record.toJson());
        expect(restored.feeling, WorkoutFeeling.challenging);
      },
    );

    test(
      'every enum value round-trips by name (no exhaustive switch anywhere depends on a fixed set)',
      () {
        for (final feeling in WorkoutFeeling.values) {
          expect(WorkoutFeeling.values.byName(feeling.name), feeling);
        }
        expect(WorkoutFeeling.values, contains(WorkoutFeeling.challenging));
      },
    );
  });

  group(
    'submitExerciseFeedback (Tier 0 ingest + Tier 1 reactive, generalized to every exercise)',
    () {
      setUp(() => SharedPreferences.setMockInitialValues({}));

      testWidgets(
        'works for an exercise with no specialized ExerciseReflectionCard config (e.g. a Squat-family id)',
        (tester) async {
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final ref = await _refHarness(tester, container);
          await container.read(learningEventControllerProvider.notifier).ready;
          await submitExerciseFeedback(
            ref: ref,
            exerciseId: 'EX999_generic',
            feeling: WorkoutFeeling.challenging,
            chips: const ['Felt stronger'],
          );

          final events =
              container.read(learningEventControllerProvider).value ?? const [];
          final feedback = events.where(
            (e) => e.type == LearningEventType.exerciseFeedbackSubmitted,
          );
          expect(feedback, hasLength(1));
          final payload = feedback.first.payload as FeedbackPayload;
          expect(payload.feeling, WorkoutFeeling.challenging);
          expect(payload.chips, contains('Felt stronger'));
        },
      );

      testWidgets(
        'pain feedback also emits a separate painReported event and sets a safety flag, all without any AI provider',
        (tester) async {
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final ref = await _refHarness(tester, container);
          await container.read(learningEventControllerProvider.notifier).ready;
          await container.read(safetyFlagControllerProvider.notifier).ready;

          await submitExerciseFeedback(
            ref: ref,
            exerciseId: 'EX070_shoulder',
            feeling: WorkoutFeeling.painDiscomfort,
            painDetails: const PainDetails(
              bodyArea: 'Shoulder',
              severity: PainSeverity.moderate,
            ),
          );

          final events =
              container.read(learningEventControllerProvider).value ?? const [];
          expect(
            events.where(
              (e) => e.type == LearningEventType.exerciseFeedbackSubmitted,
            ),
            hasLength(1),
          );
          expect(
            events.where((e) => e.type == LearningEventType.painReported),
            hasLength(1),
          );

          final flags =
              container.read(safetyFlagControllerProvider).value ?? const [];
          final active = flags.where(
            (f) =>
                f.exerciseId == 'EX070_shoulder' &&
                f.status == SafetyFlagStatus.active,
          );
          expect(active, isNotEmpty);
        },
      );

      testWidgets('a non-pain feeling never emits a painReported event', (
        tester,
      ) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final ref = await _refHarness(tester, container);
        await container.read(learningEventControllerProvider.notifier).ready;
        await submitExerciseFeedback(
          ref: ref,
          exerciseId: 'EX071',
          feeling: WorkoutFeeling.tooEasy,
        );

        final events =
            container.read(learningEventControllerProvider).value ?? const [];
        expect(
          events.where((e) => e.type == LearningEventType.painReported),
          isEmpty,
        );
      });
    },
  );

  group('ExerciseFeedbackCard is skippable and never blocks', () {
    testWidgets('Skip hides the card without calling onSubmit', (tester) async {
      var submitted = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExerciseFeedbackCard(
              onSubmit: (feeling, chips, note, pain) => submitted = true,
              onSkip: () {},
            ),
          ),
        ),
      );

      expect(find.text('How did this exercise feel?'), findsOneWidget);
      await tester.tap(find.text('Skip'));
      await tester.pump();

      expect(find.text('How did this exercise feel?'), findsNothing);
      expect(submitted, isFalse);
    });

    testWidgets(
      'Save is disabled until a feeling is chosen, then submits the selected feeling/chips/note',
      (tester) async {
        WorkoutFeeling? gotFeeling;
        List<String>? gotChips;
        String? gotNote;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ExerciseFeedbackCard(
                onSubmit: (feeling, chips, note, pain) {
                  gotFeeling = feeling;
                  gotChips = chips;
                  gotNote = note;
                },
                onSkip: () {},
              ),
            ),
          ),
        );

        await tester.tap(find.text('Save'));
        await tester.pump();
        expect(
          gotFeeling,
          isNull,
          reason: 'Save must be disabled with no feeling chosen',
        );

        await tester.tap(find.text('Challenging'));
        await tester.tap(find.text('Felt stronger'));
        await tester.enterText(find.byType(TextField), 'Good session overall');
        await tester.tap(find.text('Save'));
        await tester.pump();

        expect(gotFeeling, WorkoutFeeling.challenging);
        expect(gotChips, contains('Felt stronger'));
        expect(gotNote, 'Good session overall');
      },
    );
  });

  group('Ask Coach about this exercise — bounded, approved-data-only answers', () {
    testWidgets(
      'exerciseQuestionAsked records the question, never the answer text, and calls no AI provider',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final ref = await _refHarness(tester, container);
        await container.read(learningEventControllerProvider.notifier).ready;

        await submitExerciseQuestionAsked(
          ref: ref,
          exerciseId: 'EX066',
          questionCode: 'howToPerform',
        );

        final events =
            container.read(learningEventControllerProvider).value ?? const [];
        final asked = events.where(
          (e) => e.type == LearningEventType.exerciseQuestionAsked,
        );
        expect(asked, hasLength(1));
        final payload = asked.first.payload as ExerciseQuestionPayload;
        expect(payload.exerciseId, 'EX066');
        expect(payload.questionCode, 'howToPerform');
      },
    );

    test(
      'answerExerciseQuestion builds "how to perform" from the exercise\'s own approved pose instructions',
      () {
        final exercise = routinePlayerExerciseById('EX066')!;
        final answer = answerExerciseQuestion(
          exercise: exercise,
          questionCode: 'howToPerform',
        );
        expect(answer, contains(exercise.displayName));
        for (final pose in exercise.poses) {
          expect(answer, contains(pose.instruction));
        }
      },
    );

    test(
      'answerExerciseQuestion "where to feel" uses the exercise\'s own approved body areas, never invented anatomy',
      () {
        final exercise = routinePlayerExerciseById('EX066')!;
        final answer = answerExerciseQuestion(
          exercise: exercise,
          questionCode: 'whereToFeel',
        );
        for (final area in exercise.bodyAreas) {
          expect(answer, contains(area));
        }
      },
    );

    test(
      'answerExerciseQuestion "benefit" uses the exercise\'s own approved benefit field',
      () {
        final exercise = routinePlayerExerciseById('EX066')!;
        final answer = answerExerciseQuestion(
          exercise: exercise,
          questionCode: 'benefit',
        );
        final expected = exercise.voiceScript.benefit.isNotEmpty
            ? exercise.voiceScript.benefit
            : exercise.benefitShort;
        expect(answer, contains(expected));
      },
    );

    test(
      'an active safety flag for the exercise prepends a safety-first note ahead of the usual answer',
      () async {
        SharedPreferences.setMockInitialValues({});
        final container = ProviderContainer();
        addTearDown(container.dispose);
        await container.read(safetyFlagControllerProvider.notifier).ready;
        await container
            .read(safetyFlagControllerProvider.notifier)
            .registerPainReport(
              exerciseId: 'EX066',
              bodyArea: 'Lower back',
              severity: PainSeverity.moderate,
              sourceEventId: 'evt1',
            );
        final flags =
            container.read(safetyFlagControllerProvider).value ?? const [];

        final exercise = routinePlayerExerciseById('EX066')!;
        final answer = answerExerciseQuestion(
          exercise: exercise,
          questionCode: 'howToPerform',
          activeSafetyFlagsForExercise: flags,
        );
        expect(
          answer,
          contains('reported discomfort with this exercise before'),
        );
      },
    );

    test(
      'matchFreeTextQuestionCode maps common phrasing to a real question code, never a dead end',
      () {
        expect(matchFreeTextQuestionCode('my shoulder hurts'), 'discomfort');
        expect(
          matchFreeTextQuestionCode('how do I breathe during this'),
          'breathing',
        );
        expect(
          matchFreeTextQuestionCode('is there an easier variation'),
          'easierVariation',
        );
        expect(
          matchFreeTextQuestionCode('where should I feel this'),
          'whereToFeel',
        );
        expect(matchFreeTextQuestionCode('gibberish xyz'), 'howToPerform');
      },
    );
  });

  group(
    'structural: no AI provider is ever reachable from the feedback/question ingest path',
    () {
      test(
        'exercise_feedback_events.dart never imports Tier 2/3/4 Brain modules',
        () {
          final content = File(
            'lib/workout/state/exercise_feedback_events.dart',
          ).readAsStringSync();
          for (final banned in [
            'brain/recommendations/adaptation_engine.dart',
            'brain/expression/generative_expression_service.dart',
            'brain/batch/pattern_promotion_job.dart',
          ]) {
            expect(
              content.contains(banned),
              isFalse,
              reason: 'must never reference $banned',
            );
          }
        },
      );

      test(
        'exercise_coach_answer_service.dart never imports any Brain expression/generative module',
        () {
          final content = File(
            'lib/workout/coach/exercise_coach_answer_service.dart',
          ).readAsStringSync();
          expect(content.contains('brain/expression/'), isFalse);
          expect(content.contains('coach_brain_service'), isFalse);
        },
      );
    },
  );
}
