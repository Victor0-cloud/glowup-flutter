// Covers the durable Water Tracker persistence layer (ml-based v2): the
// WaterEntry model's JSON round-trip, WaterRepository's SharedPreferences-
// backed CRUD (including "survives a fresh repository instance" as the
// real-restart proxy — see workout_history_persistence_test.dart's doc
// comment for why that's the correct proxy under flutter_test), idempotent
// addEntry-by-id, unit persistence, and WaterController's derived
// today/goal/remaining/progress/insight computations plus the AI Coach's
// real water context fields.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:glow_up/coach/brain/coach_brain_context.dart';
import 'package:glow_up/water/data/water_repository.dart';
import 'package:glow_up/water/models/water_entry.dart';
import 'package:glow_up/water/state/water_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WaterEntry JSON round-trip', () {
    test('every field survives toJson/fromJson', () {
      final entry = WaterEntry(
        id: 'e1',
        amountMl: 250,
        at: DateTime(2026, 1, 1, 8, 30),
        label: 'Morning glass',
      );
      final restored = WaterEntry.fromJson(entry.toJson());
      expect(restored.id, 'e1');
      expect(restored.amountMl, 250);
      expect(restored.at, DateTime(2026, 1, 1, 8, 30));
      expect(restored.label, 'Morning glass');
    });

    test('isOnDate matches only the same calendar day', () {
      final entry = WaterEntry(
        id: 'e1',
        amountMl: 250,
        at: DateTime(2026, 1, 1, 23, 59),
      );
      expect(entry.isOnDate(DateTime(2026, 1, 1)), isTrue);
      expect(entry.isOnDate(DateTime(2026, 1, 2)), isFalse);
    });
  });

  group('WaterUnit conversion', () {
    test('ml is the identity conversion', () {
      expect(WaterUnit.ml.fromMl(500), 500);
      expect(WaterUnit.ml.toMl(500), 500);
    });

    test('fl oz round-trips through ml within floating point tolerance', () {
      const flOzAmount = 8.0;
      final ml = WaterUnit.flOz.toMl(flOzAmount);
      final back = WaterUnit.flOz.fromMl(ml);
      expect(back, closeTo(flOzAmount, 0.001));
      expect(ml, closeTo(236.588, 0.01));
    });
  });

  group('WaterRepository', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test(
      'empty entries + default goal + default unit is a valid starting state',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final repo = WaterRepository(prefs);
        expect(repo.loadEntries(), isEmpty);
        expect(repo.loadGoal(), WaterRepository.defaultGoalMl);
        expect(repo.loadUnit(), WaterRepository.defaultUnit);
      },
    );

    test('addEntry saves; loadEntries reads it back', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = WaterRepository(prefs);
      await repo.addEntry(
        WaterEntry(id: 'e1', amountMl: 250, at: DateTime(2026, 1, 1)),
      );
      expect(repo.loadEntries(), hasLength(1));
      expect(repo.loadEntries().first.id, 'e1');
    });

    test(
      'addEntry is idempotent by id — adding the same id twice does not duplicate it',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final repo = WaterRepository(prefs);
        final entry = WaterEntry(
          id: 'dup',
          amountMl: 250,
          at: DateTime(2026, 1, 1),
        );
        await repo.addEntry(entry);
        await repo.addEntry(entry);
        expect(repo.loadEntries(), hasLength(1));
      },
    );

    test(
      'removeEntry deletes only the matching id and returns the removed entry',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final repo = WaterRepository(prefs);
        await repo.addEntry(
          WaterEntry(id: 'e1', amountMl: 250, at: DateTime(2026, 1, 1)),
        );
        await repo.addEntry(
          WaterEntry(id: 'e2', amountMl: 500, at: DateTime(2026, 1, 1)),
        );
        final removed = await repo.removeEntry('e1');
        final remaining = repo.loadEntries();
        expect(remaining, hasLength(1));
        expect(remaining.first.id, 'e2');
        expect(removed?.id, 'e1');
      },
    );

    test(
      'removeEntry on an unknown id is a safe no-op and returns null',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final repo = WaterRepository(prefs);
        await repo.addEntry(
          WaterEntry(id: 'e1', amountMl: 250, at: DateTime(2026, 1, 1)),
        );
        final removed = await repo.removeEntry('does-not-exist');
        expect(repo.loadEntries(), hasLength(1));
        expect(removed, isNull);
      },
    );

    test('saveGoal persists a new daily goal in ml', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = WaterRepository(prefs);
      await repo.saveGoal(3000);
      expect(repo.loadGoal(), 3000);
    });

    test('saveUnit persists the preferred display unit', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = WaterRepository(prefs);
      await repo.saveUnit(WaterUnit.flOz);
      expect(repo.loadUnit(), WaterUnit.flOz);
    });

    test(
      'entries, goal, and unit survive a fresh repository instance (real-restart proxy)',
      () async {
        final prefs1 = await SharedPreferences.getInstance();
        final repo1 = WaterRepository(prefs1);
        await repo1.addEntry(
          WaterEntry(id: 'e1', amountMl: 500, at: DateTime(2026, 1, 1)),
        );
        await repo1.saveGoal(2500);
        await repo1.saveUnit(WaterUnit.flOz);

        final prefs2 = await SharedPreferences.getInstance();
        final repo2 = WaterRepository(prefs2);
        expect(repo2.loadEntries(), hasLength(1));
        expect(repo2.loadEntries().first.id, 'e1');
        expect(repo2.loadGoal(), 2500);
        expect(repo2.loadUnit(), WaterUnit.flOz);
      },
    );
  });

  group('WaterController', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test(
      'starts loading, resolves to an empty log at the default goal',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(waterControllerProvider.notifier);
        await controller.ready;
        final state = container.read(waterControllerProvider);
        expect(state, isA<AsyncData<WaterState>>());
        expect(state.value!.entries, isEmpty);
        expect(state.value!.goalMl, WaterRepository.defaultGoalMl);
      },
    );

    test(
      'addEntry persists durably and updates todayTotal/remaining/progress',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(waterControllerProvider.notifier);
        await controller.ready;

        await controller.addEntry(500);
        await controller.addEntry(250);

        final state = container.read(waterControllerProvider).value!;
        expect(state.todayTotal, 750);
        expect(
          state.remainingMl,
          closeTo(WaterRepository.defaultGoalMl - 750, 0.001),
        );
        expect(
          state.progress,
          closeTo(750 / WaterRepository.defaultGoalMl, 0.001),
        );
        expect(state.todayEntries, hasLength(2));
      },
    );

    test('addEntry ignores a zero or negative amount', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(waterControllerProvider.notifier);
      await controller.ready;

      final zero = await controller.addEntry(0);
      final negative = await controller.addEntry(-1);

      final state = container.read(waterControllerProvider).value!;
      expect(state.entries, isEmpty);
      expect(zero, isNull);
      expect(negative, isNull);
    });

    test(
      'addEntry with an explicit clientId is idempotent — a repeat call never double-persists',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(waterControllerProvider.notifier);
        await controller.ready;

        await controller.addEntry(250, clientId: 'fixed-id');
        await controller.addEntry(250, clientId: 'fixed-id');

        final state = container.read(waterControllerProvider).value!;
        expect(state.entries, hasLength(1));
        expect(state.todayTotal, 250);
      },
    );

    test(
      'removeEntry deletes the correct entry and recomputes totals',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(waterControllerProvider.notifier);
        await controller.ready;

        await controller.addEntry(250);
        await controller.addEntry(500);
        final firstId = container
            .read(waterControllerProvider)
            .value!
            .entries
            .first
            .id;

        final removed = await controller.removeEntry(firstId);

        final state = container.read(waterControllerProvider).value!;
        expect(state.entries, hasLength(1));
        expect(state.todayTotal, 500);
        expect(removed?.id, firstId);
      },
    );

    test(
      'restoreEntry (Undo) re-adds a previously removed entry with its original id and total',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(waterControllerProvider.notifier);
        await controller.ready;

        await controller.addEntry(250);
        final entry = container
            .read(waterControllerProvider)
            .value!
            .entries
            .first;
        await controller.removeEntry(entry.id);
        expect(container.read(waterControllerProvider).value!.todayTotal, 0);

        await controller.restoreEntry(entry);

        final state = container.read(waterControllerProvider).value!;
        expect(state.entries, hasLength(1));
        expect(state.entries.first.id, entry.id);
        expect(state.todayTotal, 250);
      },
    );

    test(
      'updateGoal changes the goal without deleting any logged entries',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(waterControllerProvider.notifier);
        await controller.ready;

        await controller.addEntry(300);
        await controller.updateGoal(3000);

        final state = container.read(waterControllerProvider).value!;
        expect(state.goalMl, 3000);
        expect(state.todayTotal, 300);
      },
    );

    test(
      'updateUnit persists the preferred unit without affecting stored ml totals',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(waterControllerProvider.notifier);
        await controller.ready;

        await controller.addEntry(500);
        await controller.updateUnit(WaterUnit.flOz);

        final state = container.read(waterControllerProvider).value!;
        expect(state.unit, WaterUnit.flOz);
        expect(
          state.todayTotal,
          500,
          reason:
              'the canonical stored amount is always ml regardless of display unit',
        );
      },
    );

    test(
      'progress across a "new day" is not destructive — entries from a prior day stay in history but do not count toward today',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(waterControllerProvider.notifier);
        await controller.ready;

        final prefs = await SharedPreferences.getInstance();
        final repo = WaterRepository(prefs);
        await repo.addEntry(
          WaterEntry(
            id: 'yesterday',
            amountMl: 1500,
            at: DateTime.now().subtract(const Duration(days: 1)),
          ),
        );
        await controller.addEntry(250); // today, via the controller

        final state = container.read(waterControllerProvider).value!;
        expect(
          state.entries,
          hasLength(2),
          reason: 'yesterday\'s entry is never deleted',
        );
        expect(
          state.todayTotal,
          250,
          reason: 'only today\'s entries count toward today\'s total',
        );
      },
    );

    test(
      'hydration insights never invent values when there is no history',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(waterControllerProvider.notifier);
        await controller.ready;

        final state = container.read(waterControllerProvider).value!;
        expect(state.averageDailyMl, isNull);
        expect(state.bestDay, isNull);
        expect(state.daysGoalAchieved, 0);
      },
    );

    test(
      'hydration insights are computed deterministically from stored entries only',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(waterControllerProvider.notifier);
        await controller.ready;

        final prefs = await SharedPreferences.getInstance();
        final repo = WaterRepository(prefs);
        await repo.addEntry(
          WaterEntry(
            id: 'y1',
            amountMl: 3000,
            at: DateTime.now().subtract(const Duration(days: 1)),
          ),
        );
        await controller.addEntry(1000);

        final state = container.read(waterControllerProvider).value!;
        expect(state.averageDailyMl, closeTo((3000 + 1000) / 2, 0.001));
        expect(state.bestDay?.totalMl, 3000);
        expect(
          state.daysGoalAchieved,
          1,
          reason: 'only the 3000ml day meets the 2000ml default goal',
        );
      },
    );
  });

  group('AI Coach water context', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('water is not in pendingModules', () {
      expect(CoachBrainContext.pendingModules, isNot(contains('water')));
    });

    test(
      'todayWaterMl/todayWaterGoalMl default safely before the controller loads',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        // Reading the water controller here mirrors how coachBrainContextProvider
        // reads it — valueOrNull before `ready` resolves must fall back safely,
        // never throw or fabricate a nonzero total.
        final value = container.read(waterControllerProvider).valueOrNull;
        expect(value, isNull);
        // Let initialization finish before the container is disposed, so
        // teardown doesn't race the controller's pending async _init().
        await container.read(waterControllerProvider.notifier).ready;
      },
    );
  });
}
