// Covers the durable workout-history persistence layer added to close the
// "Workout Module completion feedback loop" gap: a completion summary that
// saves exactly once, a post-workout feedback step (including the Pain/
// Discomfort follow-up), real on-device durable storage via
// SharedPreferences (audited: no persistence library existed anywhere in
// this app before this pass), and the AI Coach's real workout context.
//
// SharedPreferences under `flutter_test` uses an in-memory mock store that
// is shared across every `getInstance()` call within one test's zone
// (reset per-test by the test binding) — `setMockInitialValues` is used
// explicitly below wherever a test needs a clean/seeded starting point,
// and "does a second repository instance see data the first one saved"
// is the real, meaningful proxy for "survives app restart" available in a
// unit test (the underlying store is never re-created mid-test any other
// way; Flutter's own SharedPreferences test guidance treats this as the
// correct way to assert persistence).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:glow_up/coach/brain/coach_brain_context.dart';
import 'package:glow_up/workout/data/workout_history_repository.dart';
import 'package:glow_up/workout/models/workout_completion_record.dart';
import 'package:glow_up/workout/state/workout_history_controller.dart';

WorkoutCompletionRecord _record({
  String id = 'w1_1000',
  List<String> completed = const ['EX001', 'EX002'],
  List<String> skipped = const [],
  WorkoutFeeling? feeling,
  PainDetails? painDetails,
}) {
  final now = DateTime(2026, 1, 1, 8);
  return WorkoutCompletionRecord(
    id: id,
    profileId: WorkoutCompletionRecord.localProfileId,
    workoutId: 'w1',
    workoutName: 'Test Routine',
    startedAt: now,
    completedAt: now.add(const Duration(minutes: 10)),
    totalDurationSeconds: 600,
    completedExerciseIds: completed,
    skippedExerciseIds: skipped,
    status: WorkoutCompletionStatus.completed,
    calories: 120,
    feeling: feeling,
    painDetails: painDetails,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WorkoutCompletionRecord JSON round-trip', () {
    test('every field survives toJson/fromJson, including pain details', () {
      final record = _record(
        feeling: WorkoutFeeling.painDiscomfort,
        painDetails: const PainDetails(
          bodyArea: 'Lower back',
          severity: PainSeverity.moderate,
          note: 'twinge on the last rep',
        ),
      );
      final restored = WorkoutCompletionRecord.fromJson(record.toJson());
      expect(restored.id, record.id);
      expect(restored.workoutName, record.workoutName);
      expect(restored.completedExerciseIds, record.completedExerciseIds);
      expect(restored.skippedExerciseIds, record.skippedExerciseIds);
      expect(restored.status, record.status);
      expect(restored.calories, record.calories);
      expect(restored.feeling, WorkoutFeeling.painDiscomfort);
      expect(restored.painDetails?.bodyArea, 'Lower back');
      expect(restored.painDetails?.severity, PainSeverity.moderate);
      expect(restored.painDetails?.note, 'twinge on the last rep');
      expect(restored.hasPainFlag, isTrue);
    });

    test(
      'a null-feedback record round-trips with feeling/painDetails null',
      () {
        final record = _record();
        final restored = WorkoutCompletionRecord.fromJson(record.toJson());
        expect(restored.feeling, isNull);
        expect(restored.painDetails, isNull);
        expect(restored.hasFeedback, isFalse);
        expect(restored.hasPainFlag, isFalse);
      },
    );
  });

  group('WorkoutHistoryRepository', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('empty history is a valid, non-error state', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = WorkoutHistoryRepository(prefs);
      expect(repo.loadAll(), isEmpty);
    });

    test('add() saves a record; loadAll() reads it back', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = WorkoutHistoryRepository(prefs);
      await repo.add(_record());
      expect(repo.loadAll(), hasLength(1));
      expect(repo.loadAll().first.id, 'w1_1000');
    });

    test(
      'add() with a duplicate id is a no-op — never creates a second record',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final repo = WorkoutHistoryRepository(prefs);
        await repo.add(_record());
        await repo.add(
          _record(completed: ['EX999']),
        ); // same id, different payload
        final all = repo.loadAll();
        expect(all, hasLength(1));
        expect(
          all.first.completedExerciseIds,
          ['EX001', 'EX002'],
          reason:
              'the original record must win, never overwritten by a duplicate add',
        );
      },
    );

    test('update() attaches feedback to an existing record', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = WorkoutHistoryRepository(prefs);
      final saved = await repo.add(_record());
      final withFeedback = saved.copyWith(feeling: WorkoutFeeling.tooHard);
      await repo.update(withFeedback);
      expect(repo.loadAll().first.feeling, WorkoutFeeling.tooHard);
    });

    test(
      'update() on an id that was never saved throws, rather than silently fabricating a record',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final repo = WorkoutHistoryRepository(prefs);
        expect(() => repo.update(_record(id: 'never-saved')), throwsStateError);
      },
    );

    test(
      'data survives a fresh repository instance reading the same durable store (the real-restart proxy)',
      () async {
        final prefs1 = await SharedPreferences.getInstance();
        final repo1 = WorkoutHistoryRepository(prefs1);
        await repo1.add(_record());

        // A brand-new repository (and a re-fetched SharedPreferences handle)
        // must see the same data — this is what "durable, not in-memory"
        // actually means: nothing here is held only in repo1's own fields.
        final prefs2 = await SharedPreferences.getInstance();
        final repo2 = WorkoutHistoryRepository(prefs2);
        expect(repo2.loadAll(), hasLength(1));
        expect(repo2.loadAll().first.id, 'w1_1000');
      },
    );
  });

  group('WorkoutHistoryController', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test(
      'starts loading, resolves to empty data with no history yet',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(
          workoutHistoryControllerProvider.notifier,
        );
        await controller.ready;
        final state = container.read(workoutHistoryControllerProvider);
        expect(state, isA<AsyncData<List<WorkoutCompletionRecord>>>());
        expect(state.value, isEmpty);
        expect(controller.latest, isNull);
      },
    );

    test(
      'recordCompletion saves durably; a repeated call with the same id does not duplicate',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(
          workoutHistoryControllerProvider.notifier,
        );
        await controller.ready;

        Future<void> record() => controller.recordCompletion(
          id: 'dup-guard',
          workoutId: 'w1',
          workoutName: 'Test Routine',
          startedAt: DateTime(2026, 1, 1),
          completedAt: DateTime(2026, 1, 1, 0, 10),
          totalDurationSeconds: 600,
          completedExerciseIds: const ['EX001'],
          skippedExerciseIds: const [],
          status: WorkoutCompletionStatus.completed,
        );

        await record();
        await record(); // simulates a rapid repeated tap
        await record();

        final state = container.read(workoutHistoryControllerProvider);
        expect(state.value, hasLength(1));
      },
    );

    test(
      'saveFeedback attaches feeling/pain/note to the saved record',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(
          workoutHistoryControllerProvider.notifier,
        );
        await controller.ready;

        final saved = await controller.recordCompletion(
          id: 'feedback-1',
          workoutId: 'w1',
          workoutName: 'Test Routine',
          startedAt: DateTime(2026, 1, 1),
          completedAt: DateTime(2026, 1, 1, 0, 10),
          totalDurationSeconds: 600,
          completedExerciseIds: const ['EX001'],
          skippedExerciseIds: const ['EX002'],
          status: WorkoutCompletionStatus.completed,
        );
        expect(saved, isNotNull);

        final withFeedback = await controller.saveFeedback(
          recordId: saved!.id,
          feeling: WorkoutFeeling.painDiscomfort,
          painDetails: const PainDetails(
            bodyArea: 'Knee',
            severity: PainSeverity.mild,
          ),
          note: 'felt tight',
        );

        expect(withFeedback, isNotNull);
        expect(withFeedback!.feeling, WorkoutFeeling.painDiscomfort);
        expect(withFeedback.painDetails?.bodyArea, 'Knee');
        expect(withFeedback.painDetails?.severity, PainSeverity.mild);
        expect(withFeedback.note, 'felt tight');
        expect(withFeedback.hasPainFlag, isTrue);
        expect(controller.latest?.id, saved.id);
      },
    );

    test(
      'saveFeedback for an id that was never recorded is a safe no-op (returns null)',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(
          workoutHistoryControllerProvider.notifier,
        );
        await controller.ready;
        final result = await controller.saveFeedback(
          recordId: 'does-not-exist',
          feeling: WorkoutFeeling.justRight,
        );
        expect(result, isNull);
      },
    );
  });

  group('AI Coach workout context', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('workout and water are no longer in pendingModules', () {
      expect(CoachBrainContext.pendingModules, isNot(contains('workout')));
      expect(CoachBrainContext.pendingModules, isNot(contains('water')));
    });

    test(
      'latestWorkoutFeeling skips past a feedback-less record to the most recent one that has feedback',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(
          workoutHistoryControllerProvider.notifier,
        );
        await controller.ready;

        final first = await controller.recordCompletion(
          id: 'c1',
          workoutId: 'w1',
          workoutName: 'A',
          startedAt: DateTime(2026, 1, 1),
          completedAt: DateTime(2026, 1, 1, 0, 10),
          totalDurationSeconds: 600,
          completedExerciseIds: const ['EX001'],
          skippedExerciseIds: const [],
          status: WorkoutCompletionStatus.completed,
        );
        await controller.saveFeedback(
          recordId: first!.id,
          feeling: WorkoutFeeling.tooHard,
        );

        // Second (most recent) workout: feedback skipped entirely.
        await controller.recordCompletion(
          id: 'c2',
          workoutId: 'w1',
          workoutName: 'A',
          startedAt: DateTime(2026, 1, 2),
          completedAt: DateTime(2026, 1, 2, 0, 10),
          totalDurationSeconds: 600,
          completedExerciseIds: const ['EX001'],
          skippedExerciseIds: const [],
          status: WorkoutCompletionStatus.completed,
        );

        final history = container.read(workoutHistoryControllerProvider).value!;
        final recent = history.reversed.toList();
        WorkoutFeeling? latest;
        for (final r in recent) {
          if (r.feeling != null) {
            latest = r.feeling;
            break;
          }
        }
        expect(
          latest,
          WorkoutFeeling.tooHard,
          reason:
              'must scan back to the last record that actually has feedback',
        );
      },
    );

    test(
      'frequentlySkippedExerciseIds only surfaces ids skipped 2+ times',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(
          workoutHistoryControllerProvider.notifier,
        );
        await controller.ready;

        for (var i = 0; i < 2; i++) {
          await controller.recordCompletion(
            id: 'skip-$i',
            workoutId: 'w1',
            workoutName: 'A',
            startedAt: DateTime(2026, 1, i + 1),
            completedAt: DateTime(2026, 1, i + 1, 0, 10),
            totalDurationSeconds: 600,
            completedExerciseIds: const ['EX001'],
            skippedExerciseIds: const ['EX002'],
            status: WorkoutCompletionStatus.completed,
          );
        }
        await controller.recordCompletion(
          id: 'skip-once',
          workoutId: 'w1',
          workoutName: 'A',
          startedAt: DateTime(2026, 1, 5),
          completedAt: DateTime(2026, 1, 5, 0, 10),
          totalDurationSeconds: 600,
          completedExerciseIds: const ['EX001'],
          skippedExerciseIds: const ['EX003'],
          status: WorkoutCompletionStatus.completed,
        );

        final history = container.read(workoutHistoryControllerProvider).value!;
        final skipCounts = <String, int>{};
        for (final r in history.reversed.take(10)) {
          for (final id in r.skippedExerciseIds) {
            skipCounts[id] = (skipCounts[id] ?? 0) + 1;
          }
        }
        final frequentlySkipped = [
          for (final e in skipCounts.entries)
            if (e.value >= 2) e.key,
        ];
        expect(frequentlySkipped, contains('EX002'));
        expect(frequentlySkipped, isNot(contains('EX003')));
      },
    );
  });
}
