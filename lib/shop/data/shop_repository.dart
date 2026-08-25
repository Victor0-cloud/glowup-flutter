import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/shop_models.dart';

/// Durable on-device storage for the Glow Shop Scanner's product library
/// and grocery/fitness list items — same [SharedPreferences]-backed
/// flat-list pattern as `FoodScanRepository`/`WaterRepository`. A
/// [ScannedProduct] only ever gets here via the confirm/save step; a
/// [ShopListItem] only ever gets here via an explicit "add to list".
class ShopRepository {
  ShopRepository(this._prefs);

  final SharedPreferences _prefs;
  static const _productsKey = 'shop_products_v1';
  static const _listItemsKey = 'shop_list_items_v1';

  List<ScannedProduct> loadProducts() {
    final raw = _prefs.getStringList(_productsKey) ?? const [];
    return [
      for (final e in raw)
        ScannedProduct.fromJson(jsonDecode(e) as Map<String, dynamic>),
    ];
  }

  Future<void> _saveProducts(List<ScannedProduct> products) {
    return _prefs.setStringList(_productsKey, [
      for (final p in products) jsonEncode(p.toJson()),
    ]);
  }

  /// Idempotent by id — a retried/double-fired save never creates a
  /// duplicate.
  Future<ScannedProduct> addProduct(ScannedProduct product) async {
    final current = loadProducts();
    final existing = current.where((p) => p.id == product.id);
    if (existing.isNotEmpty) return existing.first;
    await _saveProducts([...current, product]);
    return product;
  }

  Future<ScannedProduct?> removeProduct(String id) async {
    final current = loadProducts();
    ScannedProduct? removed;
    final updated = current.where((p) {
      if (p.id == id) {
        removed = p;
        return false;
      }
      return true;
    }).toList();
    if (removed == null) return null;
    await _saveProducts(updated);
    return removed;
  }

  List<ShopListItem> loadListItems() {
    final raw = _prefs.getStringList(_listItemsKey) ?? const [];
    return [
      for (final e in raw)
        ShopListItem.fromJson(jsonDecode(e) as Map<String, dynamic>),
    ];
  }

  Future<void> _saveListItems(List<ShopListItem> items) {
    return _prefs.setStringList(_listItemsKey, [
      for (final i in items) jsonEncode(i.toJson()),
    ]);
  }

  Future<ShopListItem> addListItem(ShopListItem item) async {
    final current = loadListItems();
    final existing = current.where((i) => i.id == item.id);
    if (existing.isNotEmpty) return existing.first;
    await _saveListItems([...current, item]);
    return item;
  }

  Future<ShopListItem?> updateListItem(
    String id,
    ShopListItem Function(ShopListItem) update,
  ) async {
    final current = loadListItems();
    final index = current.indexWhere((i) => i.id == id);
    if (index == -1) return null;
    final updated = update(current[index]);
    final newList = [...current];
    newList[index] = updated;
    await _saveListItems(newList);
    return updated;
  }

  Future<ShopListItem?> removeListItem(String id) async {
    final current = loadListItems();
    ShopListItem? removed;
    final updated = current.where((i) {
      if (i.id == id) {
        removed = i;
        return false;
      }
      return true;
    }).toList();
    if (removed == null) return null;
    await _saveListItems(updated);
    return removed;
  }

  Future<void> deleteAll() async {
    await _prefs.remove(_productsKey);
    await _prefs.remove(_listItemsKey);
  }
}
