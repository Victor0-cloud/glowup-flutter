/// The five field-set groups the Glow Shop Scanner covers, spanning all
/// eight product types from the approved spec: `food` (food & beverages),
/// `supplement` (protein powders/bars, sports drinks, vitamins &
/// supplements — shares the same nutrition field set as `food`),
/// `equipment` (workout equipment, yoga/recovery equipment, water
/// bottles & accessories), `activewear` (activewear & footwear), and
/// `skincare` (skincare & wellness). [subcategory] on [ScannedProduct]
/// carries the finer label (e.g. "Yoga mat", "Protein powder") within
/// whichever group it belongs to.
enum ProductCategory { food, supplement, equipment, activewear, skincare }

extension ProductCategoryLabel on ProductCategory {
  String get label => switch (this) {
    ProductCategory.food => 'Food & Beverages',
    ProductCategory.supplement => 'Protein, Vitamins & Supplements',
    ProductCategory.equipment => 'Workout, Yoga & Recovery Equipment',
    ProductCategory.activewear => 'Activewear & Footwear',
    ProductCategory.skincare => 'Skincare & Wellness',
  };

  /// Whether this category's detail form shows the nutrition/ingredient
  /// field group (food + supplement share it — a protein bar and an
  /// apple both carry macros/ingredients/allergens).
  bool get hasNutritionFields =>
      this == ProductCategory.food || this == ProductCategory.supplement;

  static ProductCategory fromName(String name) => ProductCategory.values
      .firstWhere((c) => c.name == name, orElse: () => ProductCategory.food);
}

/// Where a [ScannedProduct]'s data came from — always shown to the user,
/// never hidden, per the approved "data source + confidence" requirement.
/// `manual` entries never carry a [ScannedProduct.dataConfidence].
enum ProductDataSource { barcode, labelPhoto, manual }

/// One saved product — from a barcode lookup, a label-photo analysis, or
/// fully manual entry. Every field beyond the identity fields
/// (id/category/name) is nullable/empty by default: a category-mismatched
/// field (e.g. [muscleGroups] on a skincare item) is simply never set,
/// never a fabricated empty-string placeholder. This is always the
/// *confirmed* record — same contract as `FoodScanEntry`/`MealItem`: it is
/// never written until the user reviews and confirms it, and an
/// AI-suggested value here is the one the user accepted, not the raw
/// provider guess (see `ShopScanController.confirmProduct`).
class ScannedProduct {
  const ScannedProduct({
    required this.id,
    required this.category,
    required this.name,
    this.brand,
    this.subcategory,
    this.barcode,
    this.servingSize,
    this.caloriesPerServing,
    this.proteinGrams,
    this.carbsGrams,
    this.fatGrams,
    this.fiberGrams,
    this.sugarGrams,
    this.sodiumMg,
    this.ingredients,
    this.allergens,
    this.intendedUse,
    this.exercisesSupported = const [],
    this.muscleGroups = const [],
    this.beginnerSuitable,
    this.safetyNotes,
    this.size,
    this.material,
    this.activityType,
    this.careInstructions,
    this.skinTypeInfo,
    this.possibleIrritants,
    required this.dataSource,
    this.dataConfidence,
    required this.scannedAt,
  });

  final String id;
  final ProductCategory category;
  final String name;
  final String? brand;
  final String? subcategory;
  final String? barcode;

  // Food / supplement fields.
  final String? servingSize;
  final int? caloriesPerServing;
  final double? proteinGrams;
  final double? carbsGrams;
  final double? fatGrams;
  final double? fiberGrams;
  final double? sugarGrams;
  final double? sodiumMg;
  final String? ingredients;
  final String? allergens;

  // Equipment fields.
  final String? intendedUse;
  final List<String> exercisesSupported;
  final List<String> muscleGroups;
  final bool? beginnerSuitable;
  final String? safetyNotes;

  // Activewear fields.
  final String? size;
  final String? material;
  final String? activityType;
  final String? careInstructions;

  // Skincare fields (ingredients/allergens above are shared with food).
  final String? skinTypeInfo;
  final String? possibleIrritants;

  final ProductDataSource dataSource;
  final double? dataConfidence;
  final DateTime scannedAt;

  ScannedProduct copyWith({
    ProductCategory? category,
    String? name,
    String? brand,
    bool clearBrand = false,
    String? subcategory,
    bool clearSubcategory = false,
    String? servingSize,
    bool clearServingSize = false,
    int? caloriesPerServing,
    bool clearCalories = false,
    double? proteinGrams,
    bool clearProtein = false,
    double? carbsGrams,
    bool clearCarbs = false,
    double? fatGrams,
    bool clearFat = false,
    double? fiberGrams,
    bool clearFiber = false,
    double? sugarGrams,
    bool clearSugar = false,
    double? sodiumMg,
    bool clearSodium = false,
    String? ingredients,
    bool clearIngredients = false,
    String? allergens,
    bool clearAllergens = false,
    String? intendedUse,
    bool clearIntendedUse = false,
    List<String>? exercisesSupported,
    List<String>? muscleGroups,
    bool? beginnerSuitable,
    String? safetyNotes,
    bool clearSafetyNotes = false,
    String? size,
    bool clearSize = false,
    String? material,
    bool clearMaterial = false,
    String? activityType,
    bool clearActivityType = false,
    String? careInstructions,
    bool clearCareInstructions = false,
    String? skinTypeInfo,
    bool clearSkinTypeInfo = false,
    String? possibleIrritants,
    bool clearPossibleIrritants = false,
  }) => ScannedProduct(
    id: id,
    category: category ?? this.category,
    name: name ?? this.name,
    brand: clearBrand ? null : (brand ?? this.brand),
    subcategory: clearSubcategory ? null : (subcategory ?? this.subcategory),
    barcode: barcode,
    servingSize: clearServingSize ? null : (servingSize ?? this.servingSize),
    caloriesPerServing: clearCalories
        ? null
        : (caloriesPerServing ?? this.caloriesPerServing),
    proteinGrams: clearProtein ? null : (proteinGrams ?? this.proteinGrams),
    carbsGrams: clearCarbs ? null : (carbsGrams ?? this.carbsGrams),
    fatGrams: clearFat ? null : (fatGrams ?? this.fatGrams),
    fiberGrams: clearFiber ? null : (fiberGrams ?? this.fiberGrams),
    sugarGrams: clearSugar ? null : (sugarGrams ?? this.sugarGrams),
    sodiumMg: clearSodium ? null : (sodiumMg ?? this.sodiumMg),
    ingredients: clearIngredients ? null : (ingredients ?? this.ingredients),
    allergens: clearAllergens ? null : (allergens ?? this.allergens),
    intendedUse: clearIntendedUse ? null : (intendedUse ?? this.intendedUse),
    exercisesSupported: exercisesSupported ?? this.exercisesSupported,
    muscleGroups: muscleGroups ?? this.muscleGroups,
    beginnerSuitable: beginnerSuitable ?? this.beginnerSuitable,
    safetyNotes: clearSafetyNotes ? null : (safetyNotes ?? this.safetyNotes),
    size: clearSize ? null : (size ?? this.size),
    material: clearMaterial ? null : (material ?? this.material),
    activityType: clearActivityType
        ? null
        : (activityType ?? this.activityType),
    careInstructions: clearCareInstructions
        ? null
        : (careInstructions ?? this.careInstructions),
    skinTypeInfo: clearSkinTypeInfo
        ? null
        : (skinTypeInfo ?? this.skinTypeInfo),
    possibleIrritants: clearPossibleIrritants
        ? null
        : (possibleIrritants ?? this.possibleIrritants),
    dataSource: dataSource,
    dataConfidence: dataConfidence,
    scannedAt: scannedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category.name,
    'name': name,
    if (brand != null) 'brand': brand,
    if (subcategory != null) 'subcategory': subcategory,
    if (barcode != null) 'barcode': barcode,
    if (servingSize != null) 'servingSize': servingSize,
    if (caloriesPerServing != null) 'caloriesPerServing': caloriesPerServing,
    if (proteinGrams != null) 'proteinGrams': proteinGrams,
    if (carbsGrams != null) 'carbsGrams': carbsGrams,
    if (fatGrams != null) 'fatGrams': fatGrams,
    if (fiberGrams != null) 'fiberGrams': fiberGrams,
    if (sugarGrams != null) 'sugarGrams': sugarGrams,
    if (sodiumMg != null) 'sodiumMg': sodiumMg,
    if (ingredients != null) 'ingredients': ingredients,
    if (allergens != null) 'allergens': allergens,
    if (intendedUse != null) 'intendedUse': intendedUse,
    if (exercisesSupported.isNotEmpty) 'exercisesSupported': exercisesSupported,
    if (muscleGroups.isNotEmpty) 'muscleGroups': muscleGroups,
    if (beginnerSuitable != null) 'beginnerSuitable': beginnerSuitable,
    if (safetyNotes != null) 'safetyNotes': safetyNotes,
    if (size != null) 'size': size,
    if (material != null) 'material': material,
    if (activityType != null) 'activityType': activityType,
    if (careInstructions != null) 'careInstructions': careInstructions,
    if (skinTypeInfo != null) 'skinTypeInfo': skinTypeInfo,
    if (possibleIrritants != null) 'possibleIrritants': possibleIrritants,
    'dataSource': dataSource.name,
    if (dataConfidence != null) 'dataConfidence': dataConfidence,
    'scannedAt': scannedAt.toIso8601String(),
  };

  factory ScannedProduct.fromJson(Map<String, dynamic> j) => ScannedProduct(
    id: j['id'] as String,
    category: ProductCategoryLabel.fromName(j['category'] as String),
    name: j['name'] as String,
    brand: j['brand'] as String?,
    subcategory: j['subcategory'] as String?,
    barcode: j['barcode'] as String?,
    servingSize: j['servingSize'] as String?,
    caloriesPerServing: (j['caloriesPerServing'] as num?)?.round(),
    proteinGrams: (j['proteinGrams'] as num?)?.toDouble(),
    carbsGrams: (j['carbsGrams'] as num?)?.toDouble(),
    fatGrams: (j['fatGrams'] as num?)?.toDouble(),
    fiberGrams: (j['fiberGrams'] as num?)?.toDouble(),
    sugarGrams: (j['sugarGrams'] as num?)?.toDouble(),
    sodiumMg: (j['sodiumMg'] as num?)?.toDouble(),
    ingredients: j['ingredients'] as String?,
    allergens: j['allergens'] as String?,
    intendedUse: j['intendedUse'] as String?,
    exercisesSupported:
        (j['exercisesSupported'] as List?)?.cast<String>() ?? const [],
    muscleGroups: (j['muscleGroups'] as List?)?.cast<String>() ?? const [],
    beginnerSuitable: j['beginnerSuitable'] as bool?,
    safetyNotes: j['safetyNotes'] as String?,
    size: j['size'] as String?,
    material: j['material'] as String?,
    activityType: j['activityType'] as String?,
    careInstructions: j['careInstructions'] as String?,
    skinTypeInfo: j['skinTypeInfo'] as String?,
    possibleIrritants: j['possibleIrritants'] as String?,
    dataSource: ProductDataSource.values.firstWhere(
      (s) => s.name == j['dataSource'],
      orElse: () => ProductDataSource.manual,
    ),
    dataConfidence: (j['dataConfidence'] as num?)?.toDouble(),
    scannedAt: DateTime.parse(j['scannedAt'] as String),
  );
}

/// `grocery` and `fitness` are kept as two entirely separate lists (per
/// the approved "view grocery vs fitness spending separately"
/// requirement) — a `basket` is not a third list type; it is the
/// `inBasket`/`purchased` [ShopItemStatus] states within whichever list
/// an item already belongs to.
enum ShopListType { grocery, fitness }

enum ShopItemStatus { planned, inBasket, purchased }

/// One line item on a grocery or fitness/wellness list. Always a snapshot
/// of the product's name/category/brand at the time it was added (never a
/// live join against [ScannedProduct] — same self-contained-record
/// philosophy as `FoodScanEntry`), plus [productId] so the two can still
/// be cross-referenced when both happen to still exist.
class ShopListItem {
  const ShopListItem({
    required this.id,
    required this.productId,
    required this.listType,
    required this.productName,
    required this.productCategory,
    this.brand,
    this.unitPrice,
    this.currencyCode,
    this.quantity = 1,
    this.status = ShopItemStatus.planned,
    this.storeName,
    this.purchaseDate,
    this.note,
    this.receiptImagePath,
    required this.addedAt,
  });

  final String id;
  final String productId;
  final ShopListType listType;
  final String productName;
  final ProductCategory productCategory;
  final String? brand;

  /// Shelf price for ONE unit, in [currencyCode] — never inferred from a
  /// barcode database (barcode lookups never carry a real local price;
  /// see `ProductDataProvider` doc comment). Always user-entered or
  /// photo-captured.
  final double? unitPrice;
  final String? currencyCode;
  final int quantity;
  final ShopItemStatus status;
  final String? storeName;
  final DateTime? purchaseDate;
  final String? note;

  /// A [PrivateImageStore]-backed path, same storage contract as Food/
  /// Facial Scan photos — never a public asset path.
  final String? receiptImagePath;
  final DateTime addedAt;

  /// Null (not zero) unless a price is actually known — never invents a
  /// total from a missing price.
  double? get lineTotal => unitPrice == null ? null : unitPrice! * quantity;

  ShopListItem copyWith({
    double? unitPrice,
    bool clearUnitPrice = false,
    String? currencyCode,
    int? quantity,
    ShopItemStatus? status,
    String? storeName,
    bool clearStoreName = false,
    DateTime? purchaseDate,
    bool clearPurchaseDate = false,
    String? note,
    bool clearNote = false,
    String? receiptImagePath,
    bool clearReceiptImagePath = false,
  }) => ShopListItem(
    id: id,
    productId: productId,
    listType: listType,
    productName: productName,
    productCategory: productCategory,
    brand: brand,
    unitPrice: clearUnitPrice ? null : (unitPrice ?? this.unitPrice),
    currencyCode: currencyCode ?? this.currencyCode,
    quantity: quantity ?? this.quantity,
    status: status ?? this.status,
    storeName: clearStoreName ? null : (storeName ?? this.storeName),
    purchaseDate: clearPurchaseDate
        ? null
        : (purchaseDate ?? this.purchaseDate),
    note: clearNote ? null : (note ?? this.note),
    receiptImagePath: clearReceiptImagePath
        ? null
        : (receiptImagePath ?? this.receiptImagePath),
    addedAt: addedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'productId': productId,
    'listType': listType.name,
    'productName': productName,
    'productCategory': productCategory.name,
    if (brand != null) 'brand': brand,
    if (unitPrice != null) 'unitPrice': unitPrice,
    if (currencyCode != null) 'currencyCode': currencyCode,
    'quantity': quantity,
    'status': status.name,
    if (storeName != null) 'storeName': storeName,
    if (purchaseDate != null) 'purchaseDate': purchaseDate!.toIso8601String(),
    if (note != null) 'note': note,
    if (receiptImagePath != null) 'receiptImagePath': receiptImagePath,
    'addedAt': addedAt.toIso8601String(),
  };

  factory ShopListItem.fromJson(Map<String, dynamic> j) => ShopListItem(
    id: j['id'] as String,
    productId: j['productId'] as String,
    listType: ShopListType.values.firstWhere(
      (t) => t.name == j['listType'],
      orElse: () => ShopListType.grocery,
    ),
    productName: j['productName'] as String,
    productCategory: ProductCategoryLabel.fromName(
      j['productCategory'] as String,
    ),
    brand: j['brand'] as String?,
    unitPrice: (j['unitPrice'] as num?)?.toDouble(),
    currencyCode: j['currencyCode'] as String?,
    quantity: (j['quantity'] as num?)?.toInt() ?? 1,
    status: ShopItemStatus.values.firstWhere(
      (s) => s.name == j['status'],
      orElse: () => ShopItemStatus.planned,
    ),
    storeName: j['storeName'] as String?,
    purchaseDate: j['purchaseDate'] != null
        ? DateTime.parse(j['purchaseDate'] as String)
        : null,
    note: j['note'] as String?,
    receiptImagePath: j['receiptImagePath'] as String?,
    addedAt: DateTime.parse(j['addedAt'] as String),
  );
}
