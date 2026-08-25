// Coverage for connecting real app activity to the Glow Up Brain: the new
// exerciseName/category/workoutName fields added to ExerciseLifecyclePayload
// and WorkoutCompletedPayload (see learning_event.dart) — without these,
// only opaque ids ever reached the Coach's remote context, which is why it
// previously couldn't answer "what exercise did I just do." Also covers the
// consent-scope opt-in added to the exerciseCompleted/workoutCompleted
// factory constructors.

import 'package:flutter_test/flutter_test.dart';

import 'package:glow_up/brain/events/learning_event.dart';

void main() {
  group('ExerciseLifecyclePayload — real name/category round-trip', () {
    test('toJson/fromJson preserves exerciseName and category', () {
      const payload = ExerciseLifecyclePayload(
        exerciseId: 'EX055',
        workoutId: 'morning-yoga-flow',
        exerciseName: 'Sun Salutation',
        category: 'yoga',
      );
      final json = payload.toJson();
      expect(json['exerciseName'], 'Sun Salutation');
      expect(json['category'], 'yoga');

      final restored = ExerciseLifecyclePayload.fromJson(json);
      expect(restored.exerciseName, 'Sun Salutation');
      expect(restored.category, 'yoga');
      expect(restored.exerciseId, 'EX055');
    });

    test(
      'older serialized events without the new fields still parse (additive, backward-compatible)',
      () {
        final restored = ExerciseLifecyclePayload.fromJson({
          'exerciseId': 'EX010',
          'workoutId': 'hiit-blast',
        });
        expect(restored.exerciseName, isNull);
        expect(restored.category, isNull);
      },
    );

    test('omits exerciseName/category from JSON entirely when null', () {
      const payload = ExerciseLifecyclePayload(exerciseId: 'EX010');
      final json = payload.toJson();
      expect(json.containsKey('exerciseName'), isFalse);
      expect(json.containsKey('category'), isFalse);
    });
  });

  group('WorkoutCompletedPayload — real workoutName round-trip', () {
    test('toJson/fromJson preserves workoutName', () {
      const payload = WorkoutCompletedPayload(
        workoutId: 'morning-yoga-flow',
        totalDurationSeconds: 600,
        completedExerciseIds: ['EX055'],
        skippedExerciseIds: [],
        workoutName: 'Morning Yoga Flow',
      );
      final json = payload.toJson();
      expect(json['workoutName'], 'Morning Yoga Flow');

      final restored = WorkoutCompletedPayload.fromJson(json);
      expect(restored.workoutName, 'Morning Yoga Flow');
    });

    test('older serialized events without workoutName still parse', () {
      final restored = WorkoutCompletedPayload.fromJson({
        'workoutId': 'hiit-blast',
        'totalDurationSeconds': 900,
        'completedExerciseIds': ['EX010', 'EX011'],
        'skippedExerciseIds': [],
      });
      expect(restored.workoutName, isNull);
    });
  });

  group(
    'LearningEvent.exerciseLifecycle/workoutCompleted — consent-scope opt-in',
    () {
      test(
        'exerciseLifecycle defaults to deviceLocal, never forwarded unless explicitly opted in',
        () {
          final event = LearningEvent.exerciseLifecycle(
            id: 'e1',
            userId: 'u1',
            type: LearningEventType.exerciseCompleted,
            exerciseId: 'EX055',
            occurredAt: DateTime.now(),
          );
          expect(event.consentScope, ConsentScope.deviceLocal);
        },
      );

      test(
        'exerciseLifecycle can be explicitly opted into aiExpressionEligible with a real name/category',
        () {
          final event = LearningEvent.exerciseLifecycle(
            id: 'e1',
            userId: 'u1',
            type: LearningEventType.exerciseCompleted,
            exerciseId: 'EX055',
            exerciseName: 'Sun Salutation',
            category: 'yoga',
            occurredAt: DateTime.now(),
            consentScope: ConsentScope.aiExpressionEligible,
          );
          expect(event.consentScope, ConsentScope.aiExpressionEligible);
          final payload = event.payload as ExerciseLifecyclePayload;
          expect(payload.exerciseName, 'Sun Salutation');
          expect(payload.category, 'yoga');
        },
      );

      test('workoutCompleted defaults to deviceLocal', () {
        final event = LearningEvent.workoutCompleted(
          id: 'w1',
          userId: 'u1',
          workoutId: 'morning-yoga-flow',
          totalDurationSeconds: 600,
          completedExerciseIds: const ['EX055'],
          skippedExerciseIds: const [],
          occurredAt: DateTime.now(),
        );
        expect(event.consentScope, ConsentScope.deviceLocal);
      });
    },
  );
}
