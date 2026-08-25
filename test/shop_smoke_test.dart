// Minimal smoke coverage that the Glow Shop Scanner (Barcode/Product Scan)
// still initializes and functions correctly — no dedicated test file
// existed for this module before this Pre-Swim task, and it was not
// otherwise touched by this change.

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:glow_up/shop/models/shop_models.dart';
import 'package:glow_up/shop/state/shop_controller.dart';

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
    tempDir = await Directory.systemTemp.createTemp('shop_smoke_test_');
    PathProviderPlatform.instance = _FakePathProvider(tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'ShopController initializes to a real empty state, never an error',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(shopControllerProvider.notifier);
      await controller.ready;

      final state = container.read(shopControllerProvider).value!;
      expect(state.products, isEmpty);
      expect(state.listItems, isEmpty);
    },
  );

  test(
    'one merged product architecture still covers groceries, supplements, equipment, activewear, and skincare — no separate Fitness Store Scan category',
    () {
      expect(ProductCategory.values.map((c) => c.name).toSet(), {
        'food',
        'supplement',
        'equipment',
        'activewear',
        'skincare',
      });
      expect(ShopListType.values.map((t) => t.name).toSet(), {
        'grocery',
        'fitness',
      });
    },
  );
}
