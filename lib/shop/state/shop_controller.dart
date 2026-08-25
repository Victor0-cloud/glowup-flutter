import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../brain/events/learning_event.dart';
import '../../brain/events/learning_event_controller.dart';
import '../../brain/reactive/reactive_event_processor.dart';
import '../../scan/data/private_image_store.dart';
import '../../workout/models/workout_completion_record.dart'
    show WorkoutCompletionRecord;
import '../../workout/state/workout_history_controller.dart'
    show sharedPreferencesProvider;
import '../data/shop_repository.dart';
import '../models/shop_models.dart';

class ShopState {
  const ShopState({required this.products, required this.listItems});

  final List<ScannedProduct> products;
  final List<ShopListItem> listItems;

  List<ShopListItem> itemsFor(ShopListType type) =>
      listItems.where((i) => i.listType == type).toList();

  /// Sums [lineTotal] across [items], grouped by currency code — never
  /// converts between currencies (no fake FX rate anywhere in this app),
  /// so a basket with two currencies simply reports two totals. Items
  /// with no price and no currency are excluded entirely (never counted
  /// as zero).
  static Map<String, double> totalsByCurrency(Iterable<ShopListItem> items) {
    final totals = <String, double>{};
    for (final item in items) {
      final total = item.lineTotal;
      final currency = item.currencyCode;
      if (total == null || currency == null) continue;
      totals[currency] = (totals[currency] ?? 0) + total;
    }
    return totals;
  }

  /// Spending totals for purchased items in [type] whose [purchaseDate]
  /// falls within the last [days] days (inclusive of today) — a rolling
  /// window, not a calendar-week/month boundary, so "weekly" (days: 7)
  /// and "monthly" (days: 30) are both fully deterministic and testable
  /// with no timezone/calendar-edge-case ambiguity.
  Map<String, double> spendingInLastDays(
    ShopListType type,
    int days, {
    DateTime? now,
  }) {
    final cutoff = (now ?? DateTime.now()).subtract(Duration(days: days));
    final purchased = listItems.where(
      (i) =>
          i.listType == type &&
          i.status == ShopItemStatus.purchased &&
          i.purchaseDate != null &&
          !i.purchaseDate!.isBefore(cutoff),
    );
    return totalsByCurrency(purchased);
  }
}

/// Durable Glow Shop Scanner state — same honest [AsyncValue] states as
/// `FoodScanController`/`WaterController`: loading only during the brief
/// `SharedPreferences` resolution, an empty product library/list is a
/// completely normal starting state, never an error.
class ShopController extends StateNotifier<AsyncValue<ShopState>> {
  ShopController(this._ref, [this._brainEvents, this._brainReactive])
    : super(const AsyncLoading()) {
    _init();
  }

  final Ref _ref;
  ShopRepository? _repo;
  PrivateImageStore? _receiptStore;

  final LearningEventController? _brainEvents;
  final ReactiveEventProcessor? _brainReactive;

  int _idSuffix = 0;

  Future<void> get ready => _readyCompleter.future;
  final _readyCompleter = Completer<void>();

  Future<void> _init() async {
    try {
      final prefs = await _ref.read(sharedPreferencesProvider.future);
      _repo = ShopRepository(prefs);
      _receiptStore = await PrivateImageStore.forCategory('shop_receipts');
      state = AsyncValue.data(
        ShopState(
          products: _repo!.loadProducts(),
          listItems: _repo!.loadListItems(),
        ),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    } finally {
      if (!_readyCompleter.isCompleted) _readyCompleter.complete();
    }
  }

  void _refreshState() {
    final repo = _repo;
    if (repo == null) return;
    state = AsyncValue.data(
      ShopState(products: repo.loadProducts(), listItems: repo.loadListItems()),
    );
  }

  /// The one real "save" path for a product — [draft] is a lookup result
  /// or manually-typed entry the user has reviewed and confirmed;
  /// [draft.id]/[draft.scannedAt] are always regenerated here regardless
  /// of what the draft carried, since only a confirmed save gets a real
  /// identity.
  Future<ScannedProduct?> confirmProduct(ScannedProduct draft) async {
    final repo = _repo;
    if (repo == null || draft.name.trim().isEmpty) return null;

    final product = ScannedProduct(
      id: '${DateTime.now().microsecondsSinceEpoch}_${_idSuffix++}',
      category: draft.category,
      name: draft.name.trim(),
      brand: draft.brand,
      subcategory: draft.subcategory,
      barcode: draft.barcode,
      servingSize: draft.servingSize,
      caloriesPerServing: draft.caloriesPerServing,
      proteinGrams: draft.proteinGrams,
      carbsGrams: draft.carbsGrams,
      fatGrams: draft.fatGrams,
      fiberGrams: draft.fiberGrams,
      sugarGrams: draft.sugarGrams,
      sodiumMg: draft.sodiumMg,
      ingredients: draft.ingredients,
      allergens: draft.allergens,
      intendedUse: draft.intendedUse,
      exercisesSupported: draft.exercisesSupported,
      muscleGroups: draft.muscleGroups,
      beginnerSuitable: draft.beginnerSuitable,
      safetyNotes: draft.safetyNotes,
      size: draft.size,
      material: draft.material,
      activityType: draft.activityType,
      careInstructions: draft.careInstructions,
      skinTypeInfo: draft.skinTypeInfo,
      possibleIrritants: draft.possibleIrritants,
      dataSource: draft.dataSource,
      dataConfidence: draft.dataConfidence,
      scannedAt: DateTime.now(),
    );

    final saved = await repo.addProduct(product);
    _refreshState();
    await _emitProductScanConfirmed(saved);
    return saved;
  }

  /// Adds [product] to [listType], merging into an existing non-purchased
  /// line for the same product rather than creating a duplicate row —
  /// re-scanning/re-adding the same item is always an intentional
  /// quantity increase on one line, never a second line. [quantity] is
  /// the amount being added right now (defaults to 1).
  Future<ShopListItem?> addToList({
    required ScannedProduct product,
    required ShopListType listType,
    int quantity = 1,
    double? unitPrice,
    String? currencyCode,
    String? storeName,
  }) async {
    final repo = _repo;
    if (repo == null || quantity <= 0) return null;

    final current = repo.loadListItems();
    final existingIndex = current.indexWhere(
      (i) =>
          i.productId == product.id &&
          i.listType == listType &&
          i.status != ShopItemStatus.purchased,
    );

    ShopListItem saved;
    if (existingIndex != -1) {
      final existing = current[existingIndex];
      final updated = existing.copyWith(
        quantity: existing.quantity + quantity,
        unitPrice: unitPrice ?? existing.unitPrice,
        currencyCode: currencyCode ?? existing.currencyCode,
        storeName: storeName ?? existing.storeName,
      );
      final result = await repo.updateListItem(existing.id, (_) => updated);
      saved = result ?? updated;
    } else {
      final item = ShopListItem(
        id: '${DateTime.now().microsecondsSinceEpoch}_${_idSuffix++}',
        productId: product.id,
        listType: listType,
        productName: product.name,
        productCategory: product.category,
        brand: product.brand,
        unitPrice: unitPrice,
        currencyCode: currencyCode,
        quantity: quantity,
        storeName: storeName,
        addedAt: DateTime.now(),
      );
      saved = await repo.addListItem(item);
    }

    _refreshState();
    await _emitProductAddedToList(saved, addedQuantity: quantity);
    return saved;
  }

  Future<ShopListItem?> updateListItem(
    String id, {
    double? unitPrice,
    bool clearUnitPrice = false,
    String? currencyCode,
    int? quantity,
    ShopItemStatus? status,
    String? storeName,
    bool clearStoreName = false,
    String? note,
    bool clearNote = false,
    String? receiptImagePath,
    bool clearReceiptImagePath = false,
  }) async {
    final repo = _repo;
    if (repo == null) return null;
    final updated = await repo.updateListItem(
      id,
      (i) => i.copyWith(
        unitPrice: unitPrice,
        clearUnitPrice: clearUnitPrice,
        currencyCode: currencyCode,
        quantity: quantity,
        status: status,
        storeName: storeName,
        clearStoreName: clearStoreName,
        note: note,
        clearNote: clearNote,
        receiptImagePath: receiptImagePath,
        clearReceiptImagePath: clearReceiptImagePath,
      ),
    );
    _refreshState();
    return updated;
  }

  /// Copies a picked receipt photo into private storage and returns the
  /// new path — same [PrivateImageStore] contract as Food/Facial Scan
  /// photos, in its own `shop_receipts` subdirectory. The caller still
  /// has to pass the returned path into [updateListItem] to attach it.
  Future<String?> saveReceiptImage(String sourcePath) async {
    final store = _receiptStore;
    if (store == null) return null;
    return store.save(sourcePath);
  }

  /// Marks a list item purchased with the given store/date — the "amount
  /// spent" recorded on the Brain event is exactly [item.lineTotal] at the
  /// moment of purchase (user-entered price × quantity), never a
  /// database/estimated price.
  Future<ShopListItem?> markPurchased(
    String id, {
    required DateTime purchaseDate,
    String? storeName,
  }) async {
    final repo = _repo;
    if (repo == null) return null;
    final updated = await repo.updateListItem(
      id,
      (i) => i.copyWith(
        status: ShopItemStatus.purchased,
        purchaseDate: purchaseDate,
        storeName: storeName ?? i.storeName,
      ),
    );
    if (updated == null) return null;
    _refreshState();
    await _emitProductPurchased(updated);
    return updated;
  }

  Future<bool> removeListItem(String id) async {
    final repo = _repo;
    if (repo == null) return false;
    final removed = await repo.removeListItem(id);
    if (removed == null) return false;
    final store = _receiptStore;
    if (store != null && removed.receiptImagePath != null) {
      await store.delete(removed.receiptImagePath!);
    }
    _refreshState();
    return true;
  }

  Future<bool> deleteProduct(String id) async {
    final repo = _repo;
    if (repo == null) return false;
    final removed = await repo.removeProduct(id);
    if (removed == null) return false;
    _refreshState();
    await _emitScanDataDeleted(removed.id);
    return true;
  }

  /// Deletes every saved product and list item — the same "real, complete
  /// erase" contract as `CycleController.deleteAllData`.
  Future<void> deleteAllData() async {
    final repo = _repo;
    if (repo == null) return;
    await repo.deleteAll();
    _refreshState();
  }

  Future<void> _emitProductScanConfirmed(ScannedProduct product) async {
    final events = _brainEvents;
    final reactive = _brainReactive;
    if (events == null || reactive == null) return;
    final event = LearningEvent.productScanConfirmed(
      id: 'productScanConfirmed_${product.id}',
      userId: WorkoutCompletionRecord.localProfileId,
      productId: product.id,
      category: product.category.name,
      dataSource: product.dataSource.name,
      hadPhoto: product.dataSource == ProductDataSource.labelPhoto,
      occurredAt: product.scannedAt,
    );
    final saved = await events.ingest(event);
    if (saved != null) await reactive.process(saved);
  }

  Future<void> _emitProductAddedToList(
    ShopListItem item, {
    required int addedQuantity,
  }) async {
    final events = _brainEvents;
    final reactive = _brainReactive;
    if (events == null || reactive == null) return;
    final event = LearningEvent.productAddedToList(
      id: 'productAddedToList_${item.id}_${DateTime.now().microsecondsSinceEpoch}',
      userId: WorkoutCompletionRecord.localProfileId,
      listItemId: item.id,
      listType: item.listType.name,
      category: item.productCategory.name,
      quantity: addedQuantity,
      occurredAt: DateTime.now(),
    );
    final saved = await events.ingest(event);
    if (saved != null) await reactive.process(saved);
  }

  Future<void> _emitProductPurchased(ShopListItem item) async {
    final events = _brainEvents;
    final reactive = _brainReactive;
    if (events == null || reactive == null) return;
    final event = LearningEvent.productPurchased(
      id: 'productPurchased_${item.id}',
      userId: WorkoutCompletionRecord.localProfileId,
      listItemId: item.id,
      listType: item.listType.name,
      amount: item.lineTotal,
      currencyCode: item.currencyCode,
      occurredAt: item.purchaseDate ?? DateTime.now(),
    );
    final saved = await events.ingest(event);
    if (saved != null) await reactive.process(saved);
  }

  Future<void> _emitScanDataDeleted(String productId) async {
    final events = _brainEvents;
    final reactive = _brainReactive;
    if (events == null || reactive == null) return;
    final event = LearningEvent.scanDataDeleted(
      id: 'scanDataDeleted_product_${productId}_${DateTime.now().microsecondsSinceEpoch}',
      userId: WorkoutCompletionRecord.localProfileId,
      scanKind: 'product',
      scanId: productId,
      occurredAt: DateTime.now(),
    );
    final saved = await events.ingest(event);
    if (saved != null) await reactive.process(saved);
  }
}

final shopControllerProvider =
    StateNotifierProvider<ShopController, AsyncValue<ShopState>>((ref) {
      return ShopController(
        ref,
        ref.watch(learningEventControllerProvider.notifier),
        ref.read(reactiveEventProcessorProvider),
      );
    });
