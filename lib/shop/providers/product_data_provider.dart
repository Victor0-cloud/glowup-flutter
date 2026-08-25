import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../scan/config/scan_backend_config.dart';
import '../../scan/models/scan_analysis_models.dart'
    show ScanProviderCapability, ScanAnalysisFormatException;
import '../../scan/providers/scan_analysis_provider.dart'
    show kMaxScanImageBytes, kAllowedScanMimeTypes, mimeTypeForPath;
import '../models/shop_models.dart';

enum ProductLookupStatus { found, notFound, offline, providerFailure }

/// The result of one barcode lookup or label-photo analysis. [product] is
/// non-null only when [status] is [ProductLookupStatus.found] — every
/// other status is an honest "nothing to show," never a partially-filled
/// guess. [product.id]/[product.scannedAt] are placeholders the caller
/// (`ShopScanController.confirmProduct`) always regenerates before saving,
/// since a lookup result is a suggestion, not yet a confirmed record.
class ProductLookupResult {
  const ProductLookupResult({required this.status, this.product});

  final ProductLookupStatus status;
  final ScannedProduct? product;

  static const notFound = ProductLookupResult(
    status: ProductLookupStatus.notFound,
  );
  static const offline = ProductLookupResult(
    status: ProductLookupStatus.offline,
  );
  static const providerFailure = ProductLookupResult(
    status: ProductLookupStatus.providerFailure,
  );
}

/// The real provider boundary for Glow Shop Scanner product data —
/// mirrors `ScanAnalysisProvider`'s Remote/Unavailable split. Barcode
/// lookup and label-photo analysis are two independent capabilities: a
/// barcode lookup never depends on this app's own backend (it calls the
/// free, keyless Open Food Facts family of APIs directly), while
/// label-photo analysis depends on the same `analyze-scan` Edge Function
/// used by Food/Facial Scan. A future swap to a different product
/// database only ever touches [RemoteProductDataProvider]'s internals,
/// never this interface or any UI code.
abstract class ProductDataProvider {
  Future<ScanProviderCapability> checkLabelPhotoCapability();
  Future<ProductLookupResult> lookupBarcode(
    String barcode, {
    ProductCategory? categoryHint,
  });
  Future<ProductLookupResult> analyzeLabelPhoto(
    String imagePath, {
    ProductCategory? categoryHint,
  });
}

/// Barcode-family endpoints, chosen by category hint — never invented:
/// each is the real, free, keyless Open Food Facts-family API for that
/// product type. Food/supplement barcodes are genuinely well-covered by
/// Open Food Facts; equipment/activewear coverage on Open Products Facts
/// is much sparser (a young, community-run database), so a `notFound`
/// result for those categories is common and expected, not a bug — the
/// UI always offers manual entry / label photo as the fallback.
String _hostForCategory(ProductCategory? category) => switch (category) {
  ProductCategory.skincare => 'world.openbeautyfacts.org',
  ProductCategory.equipment ||
  ProductCategory.activewear => 'world.openproductsfacts.org',
  _ => 'world.openfoodfacts.org',
};

/// The real, deployed implementation. Barcode lookup calls the
/// category-appropriate Open Food Facts-family API directly over HTTPS
/// (`dart:io HttpClient`, no API key, no new package dependency). Label-
/// photo analysis authenticates via Supabase anonymous sign-in (same
/// pattern as `RemoteScanAnalysisProvider`) and calls `analyze-scan` with
/// `kind: 'product'`.
class RemoteProductDataProvider implements ProductDataProvider {
  RemoteProductDataProvider({SupabaseClient? client})
    : _client =
          client ??
          SupabaseClient(
            ScanBackendConfig.supabaseUrl,
            ScanBackendConfig.supabaseAnonKey,
          );

  final SupabaseClient _client;
  bool _signedIn = false;

  Future<bool> _ensureSignedIn() async {
    if (_signedIn || _client.auth.currentSession != null) {
      _signedIn = true;
      return true;
    }
    try {
      await _client.auth.signInAnonymously();
      _signedIn = _client.auth.currentSession != null;
      return _signedIn;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<ScanProviderCapability> checkLabelPhotoCapability() async {
    if (!ScanBackendConfig.isConfigured)
      return ScanProviderCapability.unavailable;
    final signedIn = await _ensureSignedIn();
    return signedIn
        ? ScanProviderCapability.available
        : ScanProviderCapability.offline;
  }

  @override
  Future<ProductLookupResult> lookupBarcode(
    String barcode, {
    ProductCategory? categoryHint,
  }) async {
    final trimmed = barcode.trim();
    if (trimmed.isEmpty || !RegExp(r'^\d{6,14}$').hasMatch(trimmed))
      return ProductLookupResult.notFound;

    final host = _hostForCategory(categoryHint);
    final uri = Uri.https(host, '/api/v2/product/$trimmed.json');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.getUrl(uri);
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'GlowUp-App/1.0 (women\'s wellness app; contact via app store listing)',
      );
      final response = await request.close().timeout(
        const Duration(seconds: 8),
      );
      if (response.statusCode != 200) {
        return response.statusCode == 404
            ? ProductLookupResult.notFound
            : ProductLookupResult.providerFailure;
      }
      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body);
      if (json is! Map<String, dynamic>)
        return ProductLookupResult.providerFailure;
      final status = json['status'];
      final rawProduct = json['product'];
      if (status != 1 || rawProduct is! Map<String, dynamic>)
        return ProductLookupResult.notFound;

      final product = _productFromOpenFactsJson(
        rawProduct,
        barcode: trimmed,
        categoryHint: categoryHint,
      );
      return product == null
          ? ProductLookupResult.notFound
          : ProductLookupResult(
              status: ProductLookupStatus.found,
              product: product,
            );
    } on SocketException {
      return ProductLookupResult.offline;
    } on TimeoutException {
      return ProductLookupResult.offline;
    } catch (_) {
      return ProductLookupResult.providerFailure;
    } finally {
      client.close(force: true);
    }
  }

  ScannedProduct? _productFromOpenFactsJson(
    Map<String, dynamic> p, {
    required String barcode,
    ProductCategory? categoryHint,
  }) {
    final name = (p['product_name'] as String?)?.trim();
    if (name == null || name.isEmpty) return null;

    final category = categoryHint ?? ProductCategory.food;
    final nutriments = p['nutriments'];
    final n = nutriments is Map<String, dynamic>
        ? nutriments
        : const <String, dynamic>{};
    num? asNum(String key) => n[key] as num?;

    final hasServing =
        (p['serving_size'] as String?)?.trim().isNotEmpty ?? false;
    final suffix = hasServing ? '_serving' : '_100g';
    final servingLabel = hasServing
        ? (p['serving_size'] as String).trim()
        : 'Per 100g';

    final sodiumGrams = asNum('sodium$suffix');

    return ScannedProduct(
      id: '',
      category: category,
      name: name,
      brand: (p['brands'] as String?)?.split(',').first.trim(),
      barcode: barcode,
      servingSize: category.hasNutritionFields ? servingLabel : null,
      caloriesPerServing: category.hasNutritionFields
          ? asNum('energy-kcal$suffix')?.round()
          : null,
      proteinGrams: category.hasNutritionFields
          ? asNum('proteins$suffix')?.toDouble()
          : null,
      carbsGrams: category.hasNutritionFields
          ? asNum('carbohydrates$suffix')?.toDouble()
          : null,
      fatGrams: category.hasNutritionFields
          ? asNum('fat$suffix')?.toDouble()
          : null,
      fiberGrams: category.hasNutritionFields
          ? asNum('fiber$suffix')?.toDouble()
          : null,
      sugarGrams: category.hasNutritionFields
          ? asNum('sugars$suffix')?.toDouble()
          : null,
      sodiumMg: category.hasNutritionFields && sodiumGrams != null
          ? sodiumGrams.toDouble() * 1000
          : null,
      ingredients: (p['ingredients_text'] as String?)?.trim().isNotEmpty == true
          ? (p['ingredients_text'] as String).trim()
          : null,
      allergens: (p['allergens'] as String?)?.trim().isNotEmpty == true
          ? (p['allergens'] as String)
                .replaceAll('en:', '')
                .replaceAll(',', ', ')
                .trim()
          : null,
      skinTypeInfo: null,
      possibleIrritants: null,
      dataSource: ProductDataSource.barcode,
      dataConfidence: null,
      scannedAt: DateTime.now(),
    );
  }

  @override
  Future<ProductLookupResult> analyzeLabelPhoto(
    String imagePath, {
    ProductCategory? categoryHint,
  }) async {
    if (!ScanBackendConfig.isConfigured) return ProductLookupResult.offline;

    final mimeType = mimeTypeForPath(imagePath);
    if (mimeType == null || !kAllowedScanMimeTypes.contains(mimeType))
      return ProductLookupResult.providerFailure;

    final file = File(imagePath);
    if (!await file.exists()) return ProductLookupResult.providerFailure;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty || bytes.length > kMaxScanImageBytes)
      return ProductLookupResult.providerFailure;

    if (!await _ensureSignedIn()) return ProductLookupResult.offline;

    try {
      final response = await _client.functions.invoke(
        'analyze-scan',
        body: {
          'kind': 'product',
          'mimeType': mimeType,
          'imageBase64': base64Encode(bytes),
          if (categoryHint != null) 'category': categoryHint.name,
        },
      );
      final data = response.data;
      final json = data is Map<String, dynamic>
          ? data
          : data is Map
          ? Map<String, dynamic>.from(data)
          : null;
      if (json == null) return ProductLookupResult.providerFailure;

      final name = (json['name'] as String?)?.trim();
      if (name == null || name.isEmpty) return ProductLookupResult.notFound;

      final category = json['category'] is String
          ? ProductCategory.values.firstWhere(
              (c) => c.name == json['category'],
              orElse: () => categoryHint ?? ProductCategory.food,
            )
          : (categoryHint ?? ProductCategory.food);

      final product = ScannedProduct(
        id: '',
        category: category,
        name: name,
        brand: (json['brand'] as String?)?.trim(),
        servingSize: json['servingSize'] as String?,
        caloriesPerServing: (json['caloriesPerServing'] as num?)?.round(),
        proteinGrams: (json['proteinGrams'] as num?)?.toDouble(),
        carbsGrams: (json['carbsGrams'] as num?)?.toDouble(),
        fatGrams: (json['fatGrams'] as num?)?.toDouble(),
        fiberGrams: (json['fiberGrams'] as num?)?.toDouble(),
        sugarGrams: (json['sugarGrams'] as num?)?.toDouble(),
        sodiumMg: (json['sodiumMg'] as num?)?.toDouble(),
        ingredients: json['ingredients'] as String?,
        allergens: json['allergens'] as String?,
        intendedUse: json['intendedUse'] as String?,
        exercisesSupported:
            (json['exercisesSupported'] as List?)?.cast<String>() ?? const [],
        muscleGroups:
            (json['muscleGroups'] as List?)?.cast<String>() ?? const [],
        beginnerSuitable: json['beginnerSuitable'] as bool?,
        safetyNotes: json['safetyNotes'] as String?,
        size: json['size'] as String?,
        material: json['material'] as String?,
        activityType: json['activityType'] as String?,
        careInstructions: json['careInstructions'] as String?,
        skinTypeInfo: json['skinTypeInfo'] as String?,
        possibleIrritants: json['possibleIrritants'] as String?,
        dataSource: ProductDataSource.labelPhoto,
        dataConfidence: (json['confidence'] as num?)?.toDouble(),
        scannedAt: DateTime.now(),
      );
      return ProductLookupResult(
        status: ProductLookupStatus.found,
        product: product,
      );
    } on ScanAnalysisFormatException {
      return ProductLookupResult.providerFailure;
    } catch (_) {
      return ProductLookupResult.providerFailure;
    }
  }
}

/// The honest "not connected" implementation — used only in tests/direct
/// construction sites that need a provider guaranteed to never make a
/// network call. Never fabricates a result. (In production,
/// [selectProductDataProvider] always returns [RemoteProductDataProvider]
/// — barcode lookup has no configuration prerequisite, so there is no
/// build state where product lookup as a whole should be statically
/// disabled; label-photo analysis degrades per-call via
/// [ScanProviderCapability.unavailable] instead.)
class UnavailableProductDataProvider implements ProductDataProvider {
  const UnavailableProductDataProvider();

  @override
  Future<ScanProviderCapability> checkLabelPhotoCapability() async =>
      ScanProviderCapability.unavailable;

  @override
  Future<ProductLookupResult> lookupBarcode(
    String barcode, {
    ProductCategory? categoryHint,
  }) async => ProductLookupResult.offline;

  @override
  Future<ProductLookupResult> analyzeLabelPhoto(
    String imagePath, {
    ProductCategory? categoryHint,
  }) async => ProductLookupResult.offline;
}

/// The one place that decides which provider backs the app — every
/// screen reads a provider through this, never constructing one directly.
ProductDataProvider selectProductDataProvider() => RemoteProductDataProvider();
