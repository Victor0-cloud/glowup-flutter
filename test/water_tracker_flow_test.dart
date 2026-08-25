// Widget-level coverage of the Water Tracker screen (ml-based v2): quick-add
// chips, the custom-entry bottom sheet (amount validation, large-amount
// warning, ml/fl oz toggle), removing a logged entry with Undo, editing the
// daily goal, rapid-tap debounce, and the loading/empty/data states all
// being real and wired.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:glow_up/water/screens/water_tracker_screen.dart';
import 'package:glow_up/water/state/water_controller.dart';

/// The Quick Add row's chip carries a unique `Semantics` label ("Add 250 ml
/// of water") distinct from the same amount text that may later also
/// appear in the log/insights once an entry exists — a plain
/// `find.text('250 ml')` becomes ambiguous the moment a matching entry is
/// logged, so tests that tap a quick-add amount more than once (or after
/// state has changed) must target the chip specifically via this finder.
Finder quickAddChip(String label) => find.byWidgetPredicate(
  (w) => w is Semantics && w.properties.label == 'Add $label of water',
);

Future<ProviderContainer> _boot(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(402, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final container = ProviderContainer();
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: WaterTrackerScreen()),
    ),
  );
  // Let the async SharedPreferences load resolve.
  await tester.pump();
  await tester.pump();
  return container;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('starts empty and shows the empty-log message', (tester) async {
    await _boot(tester);
    expect(find.textContaining('No water logged yet today'), findsOneWidget);
  });

  testWidgets(
    'tapping a quick-add chip logs an entry durably and updates the log/remaining text',
    (tester) async {
      final container = await _boot(tester);

      await tester.tap(find.text('250 ml'));
      await tester.pump();
      await tester.pump();

      final state = container.read(waterControllerProvider).value!;
      expect(state.todayTotal, 250);
      expect(find.textContaining('No water logged yet today'), findsNothing);
      expect(find.text('1750 ml'), findsOneWidget);
    },
  );

  testWidgets(
    'a genuine second tap of the same quick-add amount after the debounce window logs a second entry',
    (tester) async {
      final container = await _boot(tester);

      await tester.tap(quickAddChip('250 ml'));
      await tester.pump();
      await tester.pump();
      // The debounce guard compares real wall-clock DateTime.now() values, not
      // flutter_test's fake animation clock, so a real delay is required here —
      // via runAsync, the sanctioned way to wait real time inside a widget test
      // without it competing with (or hanging inside) the fake async test zone.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 700)),
      );

      await tester.tap(quickAddChip('250 ml'));
      await tester.pump();
      await tester.pump();

      final state = container.read(waterControllerProvider).value!;
      expect(state.todayEntries, hasLength(2));
      expect(state.todayTotal, 500);
    },
  );

  testWidgets(
    'a rapid accidental double-tap of the same quick-add amount is debounced into a single entry',
    (tester) async {
      final container = await _boot(tester);

      await tester.tap(quickAddChip('250 ml'));
      await tester.tap(quickAddChip('250 ml'));
      await tester.pump();
      await tester.pump();

      final state = container.read(waterControllerProvider).value!;
      expect(
        state.todayEntries,
        hasLength(1),
        reason:
            'the second, near-instant tap of the same amount is a debounce guard, not a real second add',
      );
    },
  );

  testWidgets('custom amount entry adds an entry with the typed ml value', (
    tester,
  ) async {
    final container = await _boot(tester);

    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '333');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final state = container.read(waterControllerProvider).value!;
    expect(state.todayTotal, 333);
  });

  testWidgets(
    'the full-width Add Water button opens the same custom-entry sheet',
    (tester) async {
      await _boot(tester);

      await tester.tap(find.text('Add Water'));
      await tester.pumpAndSettle();

      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    },
  );

  testWidgets(
    'custom-entry sheet rejects a zero amount with a validation message',
    (tester) async {
      await _boot(tester);

      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '0');
      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(find.text('Amount must be greater than zero.'), findsOneWidget);
    },
  );

  testWidgets(
    'custom-entry sheet rejects malformed input with a validation message',
    (tester) async {
      await _boot(tester);

      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'abc');
      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(find.text('Enter a valid amount.'), findsOneWidget);
    },
  );

  testWidgets(
    'custom-entry sheet warns before an unusually large single entry, and Cancel does not log it',
    (tester) async {
      final container = await _boot(tester);

      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '5000');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('That\'s a large amount'), findsOneWidget);
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();

      expect(container.read(waterControllerProvider).value!.entries, isEmpty);
    },
  );

  testWidgets('confirming the large-amount warning logs the entry', (
    tester,
  ) async {
    final container = await _boot(tester);

    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '5000');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Log it'));
    await tester.pumpAndSettle();

    final state = container.read(waterControllerProvider).value!;
    expect(state.todayTotal, 5000);
  });

  testWidgets('removing a logged entry deletes it and recomputes the total', (
    tester,
  ) async {
    final container = await _boot(tester);

    await tester.tap(find.text('500 ml'));
    await tester.pump();
    await tester.pump();
    expect(container.read(waterControllerProvider).value!.todayTotal, 500);

    await tester.tap(find.byTooltip('Remove entry'));
    await tester.pump();
    await tester.pump();

    final state = container.read(waterControllerProvider).value!;
    expect(state.todayTotal, 0);
    expect(find.textContaining('No water logged yet today'), findsOneWidget);
  });

  testWidgets('removing an entry shows an Undo action that restores it', (
    tester,
  ) async {
    final container = await _boot(tester);

    await tester.tap(find.text('500 ml'));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byTooltip('Remove entry'));
    await tester.pump();
    await tester.pump();
    expect(container.read(waterControllerProvider).value!.todayTotal, 0);

    // Let the SnackBar's own slide-in animation finish before tapping its
    // action (mid-animation it can sit just outside the test surface).
    // Bounded pumps, not pumpAndSettle, to avoid ever spinning on some
    // unrelated indefinite animation elsewhere in the tree.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Undo'));
    await tester.pump();
    await tester.pump();

    expect(container.read(waterControllerProvider).value!.todayTotal, 500);
  });

  testWidgets(
    'editing the daily goal persists the new goal without deleting logged entries',
    (tester) async {
      final container = await _boot(tester);

      await tester.tap(find.text('250 ml'));
      await tester.pump();
      await tester.pump();

      await tester.ensureVisible(find.byTooltip('Edit goal'));
      await tester.tap(find.byTooltip('Edit goal'));
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, '3000');
      await tester.tap(find.byTooltip('Save goal'));
      await tester.pump();
      await tester.pump();

      final state = container.read(waterControllerProvider).value!;
      expect(state.goalMl, 3000);
      expect(
        state.todayTotal,
        250,
        reason: 'changing the goal must never clear logged entries',
      );
    },
  );

  testWidgets(
    'the ml/fl oz unit toggle switches the displayed unit without changing stored totals',
    (tester) async {
      final container = await _boot(tester);

      await tester.tap(find.text('250 ml'));
      await tester.pump();
      await tester.pump();

      await tester.ensureVisible(find.text('ml'));
      await tester.tap(find.text('ml'));
      await tester.pump();
      await tester.pump();

      final state = container.read(waterControllerProvider).value!;
      expect(state.unit.name, 'flOz');
      expect(
        state.todayTotal,
        250,
        reason: 'ml is always the canonical stored amount',
      );
    },
  );
}
