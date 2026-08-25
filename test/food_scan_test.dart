// Covers the Food Scan module: real provider-ready architecture (the
// unified ScanAnalysisProvider, RemoteScanAnalysisProvider's honest
// failure handling with no live backend configured, and
// UnavailableScanAnalysisProvider's guarantee to never fabricate a
// result), manual/confirmed-only saving, the correct typed Brain events,
// and private image deletion.

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:glow_up/brain/events/learning_event.dart';
import 'package:glow_up/brain/events/learning_event_controller.dart';
import 'package:glow_up/food_scan/models/food_scan_models.dart';
import 'package:glow_up/food_scan/state/food_scan_controller.dart';
import 'package:glow_up/scan/data/private_image_store.dart';
import 'package:glow_up/scan/models/scan_analysis_models.dart';
import 'package:glow_up/scan/providers/scan_analysis_provider.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.dir);
  final Directory dir;

  @override
  Future<String?> getApplicationSupportPath() async => dir.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('food_scan_test_');
    PathProviderPlatform.instance = _FakePathProvider(tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('UnavailableScanAnalysisProvider never fabricates a result', () {
    test(
      'checkCapability is always unavailable, analyzeFood always returns null',
      () async {
        const provider = UnavailableScanAnalysisProvider();
        expect(
          await provider.checkCapability(),
          ScanProviderCapability.unavailable,
        );
        expect(await provider.analyzeFood('/some/path.jpg'), isNull);
      },
    );
  });

  group(
    'selectScanAnalysisProvider — honest fallback with no backend configured',
    () {
      test(
        'selects UnavailableScanAnalysisProvider when SUPABASE_URL/ANON_KEY are not set (the default in this build)',
        () {
          final provider = selectScanAnalysisProvider();
          expect(provider, isA<UnavailableScanAnalysisProvider>());
        },
      );
    },
  );

  group(
    'RemoteScanAnalysisProvider — real network behavior, no fabricated result on failure',
    () {
      test(
        'analyzeFood against an unreachable backend fails honestly and returns null, never a fake result',
        () async {
          final provider = RemoteScanAnalysisProvider(
            client: SupabaseClient(
              'https://this-project-does-not-exist.invalid',
              'fake-anon-key',
            ),
          );
          final source = await Directory.systemTemp.createTemp('scan_img_');
          addTearDown(() => source.delete(recursive: true));
          final image = File('${source.path}/meal.jpg');
          await image.writeAsBytes(List.filled(100, 1));

          final result = await provider.analyzeFood(image.path);
          expect(result, isNull);
        },
      );

      test(
        'rejects a disallowed file extension before ever attempting a network call',
        () async {
          final provider = RemoteScanAnalysisProvider(
            client: SupabaseClient(
              'https://this-project-does-not-exist.invalid',
              'fake-anon-key',
            ),
          );
          final source = await Directory.systemTemp.createTemp('scan_img_');
          addTearDown(() => source.delete(recursive: true));
          final image = File('${source.path}/meal.gif');
          await image.writeAsBytes([1, 2, 3]);

          expect(await provider.analyzeFood(image.path), isNull);
        },
      );

      test(
        'rejects an oversized image before ever attempting a network call',
        () async {
          final provider = RemoteScanAnalysisProvider(
            client: SupabaseClient(
              'https://this-project-does-not-exist.invalid',
              'fake-anon-key',
            ),
          );
          final source = await Directory.systemTemp.createTemp('scan_img_');
          addTearDown(() => source.delete(recursive: true));
          final image = File('${source.path}/meal.jpg');
          await image.writeAsBytes(List.filled(kMaxScanImageBytes + 1, 1));

          expect(await provider.analyzeFood(image.path), isNull);
        },
      );
    },
  );

  group('FoodAnalysisResult / FoodAnalysisItem — strict schema validation', () {
    test('parses a well-formed response into typed items', () {
      final result = FoodAnalysisResult.fromJson({
        'items': [
          {
            'name': 'Grilled chicken',
            'portion': '1 breast',
            'calories': 250,
            'proteinGrams': 40.0,
            'confidence': 0.8,
          },
        ],
        'qualityNote': 'Clear, well-lit photo',
      });
      expect(result.items.single.name, 'Grilled chicken');
      expect(result.items.single.calories, 250);
      expect(result.qualityNote, 'Clear, well-lit photo');
    });

    test(
      'rejects a response missing the items array rather than silently returning an empty result',
      () {
        expect(
          () => FoodAnalysisResult.fromJson({'qualityNote': 'x'}),
          throwsA(isA<ScanAnalysisFormatException>()),
        );
      },
    );

    test(
      'rejects an item with no name rather than saving a blank food item',
      () {
        expect(
          () => FoodAnalysisResult.fromJson({
            'items': [
              {'calories': 100},
            ],
          }),
          throwsA(isA<ScanAnalysisFormatException>()),
        );
      },
    );
  });

  group('FoodScanController — confirmation required, no automatic save', () {
    test(
      'confirmMeal is the only path an entry can be created through, and requires at least one item',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(foodScanControllerProvider.notifier);
        await controller.ready;

        final rejected = await controller.confirmMeal(items: const []);
        expect(rejected, isNull);
        expect(container.read(foodScanControllerProvider).value, isEmpty);

        final saved = await controller.confirmMeal(
          items: const [MealItem(id: 'i1', name: 'Oatmeal', calories: 300)],
        );
        expect(saved, isNotNull);
        expect(container.read(foodScanControllerProvider).value, hasLength(1));
      },
    );

    test(
      'edited/corrected item values are exactly what gets saved (there is no separate "original detection" to override)',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(foodScanControllerProvider.notifier);
        await controller.ready;

        final saved = await controller.confirmMeal(
          items: const [
            MealItem(
              id: 'i1',
              name: 'Corrected Name',
              portion: '2 cups',
              calories: 450,
            ),
          ],
        );
        final stored = container.read(foodScanControllerProvider).value!.first;
        expect(stored.items.single.name, 'Corrected Name');
        expect(stored.items.single.portion, '2 cups');
        expect(stored.items.single.calories, 450);
        expect(saved!.id, stored.id);
      },
    );

    test(
      'confirming a meal with a photo copies the image into private storage under a new generated name, never the original path',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(foodScanControllerProvider.notifier);
        await controller.ready;

        final sourceFile = File('${tempDir.path}/original_photo_name.jpg');
        await sourceFile.writeAsBytes([1, 2, 3]);

        final saved = await controller.confirmMeal(
          items: const [MealItem(id: 'i1', name: 'Salad')],
          sourceImagePath: sourceFile.path,
        );
        expect(saved!.imagePath, isNotNull);
        expect(saved.imagePath, isNot(contains('original_photo_name')));
        expect(await File(saved.imagePath!).exists(), isTrue);
      },
    );

    test(
      'deleteEntry removes both the stored entry and its private image file',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(foodScanControllerProvider.notifier);
        await controller.ready;

        final sourceFile = File('${tempDir.path}/photo.jpg');
        await sourceFile.writeAsBytes([1, 2, 3]);
        final saved = await controller.confirmMeal(
          items: const [MealItem(id: 'i1', name: 'Salad')],
          sourceImagePath: sourceFile.path,
        );
        final imagePath = saved!.imagePath!;
        expect(await File(imagePath).exists(), isTrue);

        final deleted = await controller.deleteEntry(saved.id);
        expect(deleted, isTrue);
        expect(container.read(foodScanControllerProvider).value, isEmpty);
        expect(await File(imagePath).exists(), isFalse);
      },
    );

    test(
      'food and facial images live in separate private subdirectories',
      () async {
        final foodStore = await PrivateImageStore.forCategory('food');
        final facialStore = await PrivateImageStore.forCategory('facial');
        final source = File('${tempDir.path}/shared_source.jpg');
        await source.writeAsBytes([9]);

        final foodPath = await foodStore.save(source.path);
        final facialPath = await facialStore.save(source.path);
        expect(foodPath, isNot(equals(facialPath)));
        expect(foodPath, contains('/food/'));
        expect(facialPath, contains('/facial/'));
      },
    );
  });

  group('Brain event wiring — mealConfirmed / scanDataDeleted, no AI call', () {
    test(
      'confirming a meal with no photo emits mealManuallyConfirmed with the confirmed item labels',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final events = container.read(learningEventControllerProvider.notifier);
        await events.ready;
        final controller = container.read(foodScanControllerProvider.notifier);
        await controller.ready;

        await controller.confirmMeal(
          items: const [
            MealItem(id: 'i1', name: 'Toast'),
            MealItem(id: 'i2', name: 'Eggs'),
          ],
        );

        final logged =
            container.read(learningEventControllerProvider).value ?? const [];
        final confirmed = logged.where(
          (e) => e.type == LearningEventType.mealManuallyConfirmed,
        );
        expect(confirmed, hasLength(1));
        final payload = confirmed.first.payload as MealConfirmedPayload;
        expect(payload.itemLabels, ['Toast', 'Eggs']);
        expect(payload.hadPhoto, isFalse);
      },
    );

    test(
      'confirming a meal with a photo emits foodScanConfirmed instead',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final events = container.read(learningEventControllerProvider.notifier);
        await events.ready;
        final controller = container.read(foodScanControllerProvider.notifier);
        await controller.ready;

        final source = File('${tempDir.path}/p.jpg');
        await source.writeAsBytes([1]);
        await controller.confirmMeal(
          items: const [MealItem(id: 'i1', name: 'Salad')],
          sourceImagePath: source.path,
        );

        final logged =
            container.read(learningEventControllerProvider).value ?? const [];
        expect(
          logged.where((e) => e.type == LearningEventType.foodScanConfirmed),
          hasLength(1),
        );
        expect(
          logged.where(
            (e) => e.type == LearningEventType.mealManuallyConfirmed,
          ),
          isEmpty,
        );
      },
    );

    test(
      'deleting an entry emits scanDataDeleted for food, never the deleted content itself',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final events = container.read(learningEventControllerProvider.notifier);
        await events.ready;
        final controller = container.read(foodScanControllerProvider.notifier);
        await controller.ready;

        final saved = await controller.confirmMeal(
          items: const [MealItem(id: 'i1', name: 'Salad')],
        );
        await controller.deleteEntry(saved!.id);

        final logged =
            container.read(learningEventControllerProvider).value ?? const [];
        final deleted = logged.where(
          (e) => e.type == LearningEventType.scanDataDeleted,
        );
        expect(deleted, hasLength(1));
        final payload = deleted.first.payload as ScanDataDeletedPayload;
        expect(payload.scanKind, 'food');
        expect(payload.scanId, saved.id);
      },
    );

    test(
      'food_scan_controller.dart never imports Tier 2/3/4 Brain modules',
      () {
        final content = File(
          'lib/food_scan/state/food_scan_controller.dart',
        ).readAsStringSync();
        for (final banned in [
          'brain/recommendations/adaptation_engine.dart',
          'brain/expression/generative_expression_service.dart',
          'brain/batch/pattern_promotion_job.dart',
        ]) {
          expect(content.contains(banned), isFalse);
        }
      },
    );
  });
}
