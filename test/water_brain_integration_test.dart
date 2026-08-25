// Verifies the Water Tracker's AI Coach Brain integration stays within the
// approved tier boundaries: Tier 0 (ingest) and Tier 1 (deterministic
// reactive) only, never Tier 2 (decision engine unless requested by an
// adaptive surface), Tier 3 (generative expression / any real AI provider),
// or a per-entry Tier 4 batch job. Every water mutation collapses to ONE
// deterministic daily `CurrentStateEntry` regardless of how many entries
// were logged that day — see `ReactiveEventProcessor._handleHydrationLogged`
// and `WaterController._syncHydrationAggregate`'s doc comments.

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:glow_up/brain/state/current_state_controller.dart';
import 'package:glow_up/water/state/water_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('structural: no Tier 2/3/4 reference from the water module', () {
    test(
      'no water file imports the decision engine, generative expression service, or batch job',
      () {
        final waterDir = Directory('lib/water');
        final files = waterDir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'));
        expect(files, isNotEmpty);

        const forbidden = [
          'brain/recommendations/adaptation_engine.dart',
          'brain/expression/generative_expression_service.dart',
          'brain/batch/pattern_promotion_job.dart',
        ];

        for (final file in files) {
          final content = file.readAsStringSync();
          for (final banned in forbidden) {
            expect(
              content.contains(banned),
              isFalse,
              reason:
                  '${file.path} must never reference $banned — water logging is Tier 0/1 only',
            );
          }
        }
      },
    );

    test(
      'water_controller only imports Tier 0 (events) and Tier 1 (reactive) Brain modules',
      () {
        final content = File(
          'lib/water/state/water_controller.dart',
        ).readAsStringSync();
        expect(content.contains("import '../../brain/events/"), isTrue);
        expect(content.contains("import '../../brain/reactive/"), isTrue);
        expect(content.contains('brain/recommendations/'), isFalse);
        expect(content.contains('brain/expression/'), isFalse);
        expect(content.contains('brain/batch/'), isFalse);
      },
    );
  });

  group('daily hydration aggregate (Tier 1 upsert-by-key collapse)', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test(
      'a single add produces exactly one hydration CurrentStateEntry for today',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final water = container.read(waterControllerProvider.notifier);
        await water.ready;
        await container.read(currentStateControllerProvider.notifier).ready;

        await water.addEntry(500);
        // Let the Tier 0 ingest + Tier 1 reactive process settle.
        await Future<void>.delayed(Duration.zero);

        final entries =
            container.read(currentStateControllerProvider).value ?? const [];
        final hydrationEntries = entries.where(
          (e) => e.key.startsWith('hydration:'),
        );
        expect(hydrationEntries, hasLength(1));
        expect(hydrationEntries.first.value, '500/2000');
      },
    );

    test(
      'multiple mutations the same day always collapse to the same one hydration entry, never a growing list',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final water = container.read(waterControllerProvider.notifier);
        await water.ready;
        await container.read(currentStateControllerProvider.notifier).ready;

        await water.addEntry(250);
        await Future<void>.delayed(Duration.zero);
        await water.addEntry(250);
        await Future<void>.delayed(Duration.zero);
        await water.addEntry(500);
        await Future<void>.delayed(Duration.zero);

        final entries =
            container.read(currentStateControllerProvider).value ?? const [];
        final hydrationEntries = entries.where(
          (e) => e.key.startsWith('hydration:'),
        );
        expect(
          hydrationEntries,
          hasLength(1),
          reason:
              'three same-day mutations must upsert one entry, not create three',
        );
        expect(hydrationEntries.first.value, '1000/2000');
      },
    );

    test(
      'removing an entry re-syncs the same daily aggregate to the new total',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final water = container.read(waterControllerProvider.notifier);
        await water.ready;
        await container.read(currentStateControllerProvider.notifier).ready;

        await water.addEntry(500);
        await Future<void>.delayed(Duration.zero);
        final id = container
            .read(waterControllerProvider)
            .value!
            .entries
            .first
            .id;
        await water.removeEntry(id);
        await Future<void>.delayed(Duration.zero);

        final entries =
            container.read(currentStateControllerProvider).value ?? const [];
        final hydrationEntries = entries.where(
          (e) => e.key.startsWith('hydration:'),
        );
        expect(hydrationEntries, hasLength(1));
        expect(hydrationEntries.first.value, '0/2000');
      },
    );

    test(
      'a goal update re-syncs the aggregate to reflect the new goal',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final water = container.read(waterControllerProvider.notifier);
        await water.ready;
        await container.read(currentStateControllerProvider.notifier).ready;

        await water.addEntry(500);
        await Future<void>.delayed(Duration.zero);
        await water.updateGoal(3000);
        await Future<void>.delayed(Duration.zero);

        final entries =
            container.read(currentStateControllerProvider).value ?? const [];
        final hydrationEntries = entries.where(
          (e) => e.key.startsWith('hydration:'),
        );
        expect(hydrationEntries.first.value, '500/3000');
      },
    );
  });

  group('no AI provider required for correct hydration behavior', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test(
      'WaterController accepts its Brain hooks as optional/nullable and no-ops the Brain sync when absent — so logging works with the Brain entirely unavailable',
      () {
        final content = File(
          'lib/water/state/water_controller.dart',
        ).readAsStringSync();
        expect(
          content.contains('LearningEventController? _brainEvents'),
          isTrue,
          reason:
              'Brain hooks must be nullable so water logging never hard-depends on the Brain being available',
        );
        expect(
          content.contains('if (events == null || reactive == null'),
          isTrue,
          reason:
              '_syncHydrationAggregate must no-op, not throw, when Brain hooks are absent',
        );
      },
    );

    test(
      'the real waterControllerProvider never throws even though no real AI provider is connected anywhere in the app',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final water = container.read(waterControllerProvider.notifier);
        await water.ready;

        await expectLater(water.addEntry(500), completes);
        await expectLater(water.updateGoal(2500), completes);
      },
    );
  });
}
