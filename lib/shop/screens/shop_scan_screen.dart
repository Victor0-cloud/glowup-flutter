import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glow_card.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/sub_screen_header.dart';
import '../../scan/models/scan_analysis_models.dart'
    show ScanProviderCapability;
import '../../scan/providers/barcode_acquisition_provider.dart';
import '../../scan/providers/image_acquisition_provider.dart';
import '../../scan/widgets/camera_permission_help.dart';
import '../../scan/widgets/live_barcode_scanner.dart';
import '../../scan/widgets/scan_image_preview.dart';
import '../models/shop_models.dart';
import '../providers/product_data_provider.dart';
import '../state/shop_controller.dart';

enum _Step {
  category,
  inputMethod,
  liveBarcodeScan,
  barcodeEntry,
  capture,
  analyzing,
  form,
  saved,
}

/// The complete Glow Shop Scanner flow — category, then barcode / product-
/// label photo / manual entry, then an editable category-aware review
/// form, then confirm-and-save. Nothing is ever saved before the user
/// explicitly confirms — see `ShopController.confirmProduct`. An unknown
/// barcode or a failed photo analysis always falls through to manual
/// entry with an honest message, never a fabricated result.
class ShopScanScreen extends ConsumerStatefulWidget {
  const ShopScanScreen({super.key, this.onBack, this.onViewList});

  final VoidCallback? onBack;
  final VoidCallback? onViewList;

  @override
  ConsumerState<ShopScanScreen> createState() => _ShopScanScreenState();
}

class _ShopScanScreenState extends ConsumerState<ShopScanScreen> {
  final _acquisition = ImagePickerAcquisitionProvider();
  late final ProductDataProvider _provider = selectProductDataProvider();
  final _scannerKey = GlobalKey<LiveBarcodeScannerState>();

  _Step _step = _Step.category;
  ProductCategory? _category;
  String? _imagePath;
  String? _error;
  String? _info;
  bool _busy = false;
  bool _permissionDenied = false;
  ScannedProduct? _draft;
  ScannedProduct? _savedProduct;

  ScanProviderCapability _labelPhotoCapability =
      ScanProviderCapability.unavailable;

  final _barcodeController = TextEditingController();

  // Form controllers — (re)created when entering the form step.
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _subcategoryController = TextEditingController();
  final _servingController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  final _fiberController = TextEditingController();
  final _sugarController = TextEditingController();
  final _sodiumController = TextEditingController();
  final _ingredientsController = TextEditingController();
  final _allergensController = TextEditingController();
  final _intendedUseController = TextEditingController();
  final _exercisesController = TextEditingController();
  final _muscleGroupsController = TextEditingController();
  final _safetyController = TextEditingController();
  final _sizeController = TextEditingController();
  final _materialController = TextEditingController();
  final _activityController = TextEditingController();
  final _careController = TextEditingController();
  final _skinTypeController = TextEditingController();
  final _irritantsController = TextEditingController();
  bool? _beginnerSuitable;

  @override
  void initState() {
    super.initState();
    _provider.checkLabelPhotoCapability().then((c) {
      if (mounted) setState(() => _labelPhotoCapability = c);
    });
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    for (final c in [
      _nameController,
      _brandController,
      _subcategoryController,
      _servingController,
      _caloriesController,
      _proteinController,
      _carbsController,
      _fatController,
      _fiberController,
      _sugarController,
      _sodiumController,
      _ingredientsController,
      _allergensController,
      _intendedUseController,
      _exercisesController,
      _muscleGroupsController,
      _safetyController,
      _sizeController,
      _materialController,
      _activityController,
      _careController,
      _skinTypeController,
      _irritantsController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _selectCategory(ProductCategory category) {
    setState(() {
      _category = category;
      _step = _Step.inputMethod;
      _error = null;
      _info = null;
    });
  }

  void _goToBarcodeEntry() => setState(() {
    _step = _Step.barcodeEntry;
    _error = null;
    _info = null;
  });

  void _goToLiveScan() => setState(() {
    _step = _Step.liveBarcodeScan;
    _error = null;
    _info = null;
  });

  /// Handles one barcode recognized by [LiveBarcodeScanner] — locked and
  /// fired exactly once by the widget itself, so this never double-runs
  /// for the same code sitting in frame. A not-found/offline/failure
  /// result re-arms the same live scanner (via [_scannerKey]) rather than
  /// leaving the camera view dead, so "scan another" works without extra
  /// navigation.
  Future<void> _handleLiveBarcode(String code) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    final result = await _provider.lookupBarcode(code, categoryHint: _category);
    if (!mounted) return;
    setState(() {
      _busy = false;
      switch (result.status) {
        case ProductLookupStatus.found:
          _draft = result.product;
          _loadDraftIntoControllers();
          _step = _Step.form;
        case ProductLookupStatus.notFound:
          _info =
              'Product not found for that barcode. You can scan another, try a label photo, or enter it manually.';
          _scannerKey.currentState?.reset();
        case ProductLookupStatus.offline:
          _error =
              'No connection right now. Check your network and try again.';
          _scannerKey.currentState?.reset();
        case ProductLookupStatus.providerFailure:
          _error = 'Could not look up that barcode right now.';
          _scannerKey.currentState?.reset();
      }
    });
  }

  Future<void> _lookupBarcode() async {
    final code = _barcodeController.text.trim();
    if (code.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await _provider.lookupBarcode(code, categoryHint: _category);
    if (!mounted) return;
    setState(() {
      _busy = false;
      switch (result.status) {
        case ProductLookupStatus.found:
          _draft = result.product;
          _loadDraftIntoControllers();
          _step = _Step.form;
        case ProductLookupStatus.notFound:
          _info =
              'Product not found for that barcode. You can try a label photo or enter it manually.';
        case ProductLookupStatus.offline:
          _error =
              'No connection right now. Check your network and try again, or enter the product manually.';
        case ProductLookupStatus.providerFailure:
          _error =
              'Could not look up that barcode right now. You can enter the product manually.';
      }
    });
  }

  void _goToCapture() => setState(() {
    _step = _Step.capture;
    _error = null;
    _info = null;
  });

  Future<void> _capture() async {
    setState(() {
      _busy = true;
      _permissionDenied = false;
      _error = null;
    });
    try {
      final path = await _acquisition.captureFromCamera();
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (path != null) _imagePath = path;
      });
    } on CameraPermissionDeniedException {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _permissionDenied = true;
        _error = cameraPermissionDeniedMessage;
      });
    }
  }

  Future<void> _pickFromGallery() async {
    setState(() {
      _busy = true;
      _permissionDenied = false;
      _error = null;
    });
    try {
      final path = await _acquisition.pickFromGallery();
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (path != null) _imagePath = path;
      });
    } on CameraPermissionDeniedException {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _permissionDenied = true;
        _error = cameraPermissionDeniedMessage;
      });
    }
  }

  Future<void> _analyzePhoto() async {
    final path = _imagePath;
    if (path == null || _busy) return;
    setState(() {
      _step = _Step.analyzing;
      _error = null;
    });
    final result = await _provider.analyzeLabelPhoto(
      path,
      categoryHint: _category,
    );
    if (!mounted) return;
    setState(() {
      switch (result.status) {
        case ProductLookupStatus.found:
          _draft = result.product;
          _loadDraftIntoControllers();
          _step = _Step.form;
        case ProductLookupStatus.notFound:
          _info =
              'Could not read a product from that photo. You can enter the details manually.';
          _startBlankDraft();
          _step = _Step.form;
        case ProductLookupStatus.offline:
        case ProductLookupStatus.providerFailure:
          _error =
              'Automatic label reading is not available right now. You can enter the product manually.';
          _startBlankDraft();
          _step = _Step.form;
      }
    });
  }

  void _skipToManualEntry() {
    _startBlankDraft();
    setState(() {
      _step = _Step.form;
      _error = null;
    });
  }

  void _startBlankDraft() {
    _draft = ScannedProduct(
      id: '',
      category: _category ?? ProductCategory.food,
      name: '',
      barcode: _barcodeController.text.trim().isEmpty
          ? null
          : _barcodeController.text.trim(),
      dataSource: ProductDataSource.manual,
      scannedAt: DateTime.now(),
    );
    _loadDraftIntoControllers();
  }

  void _loadDraftIntoControllers() {
    final d = _draft;
    if (d == null) return;
    _category = d.category;
    _nameController.text = d.name;
    _brandController.text = d.brand ?? '';
    _subcategoryController.text = d.subcategory ?? '';
    _servingController.text = d.servingSize ?? '';
    _caloriesController.text = d.caloriesPerServing?.toString() ?? '';
    _proteinController.text = d.proteinGrams?.toString() ?? '';
    _carbsController.text = d.carbsGrams?.toString() ?? '';
    _fatController.text = d.fatGrams?.toString() ?? '';
    _fiberController.text = d.fiberGrams?.toString() ?? '';
    _sugarController.text = d.sugarGrams?.toString() ?? '';
    _sodiumController.text = d.sodiumMg?.toString() ?? '';
    _ingredientsController.text = d.ingredients ?? '';
    _allergensController.text = d.allergens ?? '';
    _intendedUseController.text = d.intendedUse ?? '';
    _exercisesController.text = d.exercisesSupported.join(', ');
    _muscleGroupsController.text = d.muscleGroups.join(', ');
    _beginnerSuitable = d.beginnerSuitable;
    _safetyController.text = d.safetyNotes ?? '';
    _sizeController.text = d.size ?? '';
    _materialController.text = d.material ?? '';
    _activityController.text = d.activityType ?? '';
    _careController.text = d.careInstructions ?? '';
    _skinTypeController.text = d.skinTypeInfo ?? '';
    _irritantsController.text = d.possibleIrritants ?? '';
  }

  double? _parseDouble(String s) =>
      s.trim().isEmpty ? null : double.tryParse(s.trim());
  List<String> _parseList(String s) =>
      s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  ScannedProduct _buildDraftFromControllers() {
    final category = _category ?? ProductCategory.food;
    final base = _draft;
    return ScannedProduct(
      id: '',
      category: category,
      name: _nameController.text,
      brand: _brandController.text.trim().isEmpty
          ? null
          : _brandController.text.trim(),
      subcategory: _subcategoryController.text.trim().isEmpty
          ? null
          : _subcategoryController.text.trim(),
      barcode: base?.barcode,
      servingSize: _servingController.text.trim().isEmpty
          ? null
          : _servingController.text.trim(),
      caloriesPerServing: int.tryParse(_caloriesController.text.trim()),
      proteinGrams: _parseDouble(_proteinController.text),
      carbsGrams: _parseDouble(_carbsController.text),
      fatGrams: _parseDouble(_fatController.text),
      fiberGrams: _parseDouble(_fiberController.text),
      sugarGrams: _parseDouble(_sugarController.text),
      sodiumMg: _parseDouble(_sodiumController.text),
      ingredients: _ingredientsController.text.trim().isEmpty
          ? null
          : _ingredientsController.text.trim(),
      allergens: _allergensController.text.trim().isEmpty
          ? null
          : _allergensController.text.trim(),
      intendedUse: _intendedUseController.text.trim().isEmpty
          ? null
          : _intendedUseController.text.trim(),
      exercisesSupported: _parseList(_exercisesController.text),
      muscleGroups: _parseList(_muscleGroupsController.text),
      beginnerSuitable: _beginnerSuitable,
      safetyNotes: _safetyController.text.trim().isEmpty
          ? null
          : _safetyController.text.trim(),
      size: _sizeController.text.trim().isEmpty
          ? null
          : _sizeController.text.trim(),
      material: _materialController.text.trim().isEmpty
          ? null
          : _materialController.text.trim(),
      activityType: _activityController.text.trim().isEmpty
          ? null
          : _activityController.text.trim(),
      careInstructions: _careController.text.trim().isEmpty
          ? null
          : _careController.text.trim(),
      skinTypeInfo: _skinTypeController.text.trim().isEmpty
          ? null
          : _skinTypeController.text.trim(),
      possibleIrritants: _irritantsController.text.trim().isEmpty
          ? null
          : _irritantsController.text.trim(),
      dataSource: base?.dataSource ?? ProductDataSource.manual,
      dataConfidence: base?.dataConfidence,
      scannedAt: DateTime.now(),
    );
  }

  bool get _canSave => _nameController.text.trim().isNotEmpty;

  Future<void> _save() async {
    if (!_canSave || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final controller = ref.read(shopControllerProvider.notifier);
    final saved = await controller.confirmProduct(_buildDraftFromControllers());
    if (!mounted) return;
    if (saved == null) {
      setState(() {
        _busy = false;
        _error = 'Could not save this product. Please try again.';
      });
      return;
    }
    setState(() {
      _busy = false;
      _savedProduct = saved;
      _step = _Step.saved;
    });
  }

  Future<void> _addToList(ShopListType type) async {
    final product = _savedProduct;
    if (product == null) return;
    final controller = ref.read(shopControllerProvider.notifier);
    await controller.addToList(product: product, listType: type);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Added to ${type == ShopListType.grocery ? 'Grocery List' : 'Fitness & Wellness List'}',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _reset() {
    setState(() {
      _step = _Step.category;
      _category = null;
      _imagePath = null;
      _draft = null;
      _savedProduct = null;
      _error = null;
      _info = null;
      _barcodeController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: Column(
          children: [
            SubScreenHeader(
              title: 'Glow Shop Scanner',
              subtitle: 'Scan a product — you always review before it saves',
              onBack: widget.onBack ?? () => Navigator.maybePop(context),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: _body(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    return switch (_step) {
      _Step.category => _categoryStep(),
      _Step.inputMethod => _inputMethodStep(),
      _Step.liveBarcodeScan => _liveBarcodeScanStep(),
      _Step.barcodeEntry => _barcodeEntryStep(),
      _Step.capture => _captureStep(),
      _Step.analyzing => _analyzingStep(),
      _Step.form => _formStep(),
      _Step.saved => _savedStep(),
    };
  }

  Widget _liveBarcodeScanStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlowCard(
          child: Text(
            'Point your camera at the barcode. It scans automatically — no need to take a photo.',
            style: AppTextStyles.subtitle.copyWith(fontSize: 13),
          ),
        ),
        const SizedBox(height: 12),
        LiveBarcodeScanner(key: _scannerKey, onDetected: _handleLiveBarcode),
        if (_busy) ...[
          const SizedBox(height: 12),
          const Center(
            child: CircularProgressIndicator(color: AppColors.blue),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            style: AppTextStyles.captionBold.copyWith(
              color: AppColors.orange,
              fontSize: 13,
            ),
          ),
        ],
        if (_info != null) ...[
          const SizedBox(height: 10),
          GlowCard(
            child: Text(
              _info!,
              style: AppTextStyles.subtitle.copyWith(fontSize: 13),
            ),
          ),
        ],
        const SizedBox(height: 16),
        _SecondaryButton(
          label: 'Enter Barcode Manually',
          onTap: _goToBarcodeEntry,
        ),
        const SizedBox(height: 12),
        _SecondaryButton(label: 'Try Photo Instead', onTap: _goToCapture),
      ],
    );
  }

  Widget _categoryStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlowCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What are you scanning?',
                style: AppTextStyles.cardTitle.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                'Covers groceries, protein & supplements, workout/yoga/recovery gear, activewear & footwear, and skincare & wellness. You always review and confirm before anything saves.',
                style: AppTextStyles.subtitle.copyWith(fontSize: 14),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        for (final category in ProductCategory.values) ...[
          _SecondaryButton(
            label: category.label,
            onTap: () => _selectCategory(category),
          ),
          const SizedBox(height: 12),
        ],
        if (widget.onViewList != null) ...[
          const SizedBox(height: 8),
          _SecondaryButton(
            label: 'View Lists & Basket',
            onTap: widget.onViewList!,
          ),
        ],
      ],
    );
  }

  Widget _inputMethodStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlowCard(
          child: Text(
            _category?.label ?? '',
            style: AppTextStyles.cardTitle.copyWith(fontSize: 16),
          ),
        ),
        const SizedBox(height: 20),
        if (supportsLiveBarcodeScan) ...[
          _PrimaryButton(label: 'Scan Barcode', onTap: _goToLiveScan),
          const SizedBox(height: 12),
          _SecondaryButton(
            label: 'Enter Barcode Manually',
            onTap: _goToBarcodeEntry,
          ),
        ] else ...[
          _PrimaryButton(label: 'Enter Barcode', onTap: _goToBarcodeEntry),
        ],
        const SizedBox(height: 12),
        _SecondaryButton(
          label: _labelPhotoCapability == ScanProviderCapability.available
              ? 'Product / Label Photo'
              : 'Product / Label Photo (not connected yet)',
          onTap: _goToCapture,
        ),
        const SizedBox(height: 12),
        _SecondaryButton(label: 'Enter Manually', onTap: _skipToManualEntry),
      ],
    );
  }

  Widget _barcodeEntryStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlowCard(
          child: Text(
            'Type the barcode number printed under the lines. This is only used as an identifier to look up the product — it never provides a store-specific price.',
            style: AppTextStyles.subtitle.copyWith(fontSize: 13),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _barcodeController,
          keyboardType: TextInputType.number,
          style: AppTextStyles.subtitle.copyWith(
            fontSize: 16,
            color: Colors.white,
          ),
          decoration: InputDecoration(
            hintText: 'Barcode number',
            hintStyle: AppTextStyles.caption,
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            style: AppTextStyles.captionBold.copyWith(
              color: AppColors.orange,
              fontSize: 13,
            ),
          ),
        ],
        if (_info != null) ...[
          const SizedBox(height: 10),
          GlowCard(
            child: Text(
              _info!,
              style: AppTextStyles.subtitle.copyWith(fontSize: 13),
            ),
          ),
          const SizedBox(height: 10),
          _SecondaryButton(label: 'Try Photo Instead', onTap: _goToCapture),
          const SizedBox(height: 8),
          _SecondaryButton(label: 'Enter Manually', onTap: _skipToManualEntry),
        ],
        const SizedBox(height: 20),
        _PrimaryButton(
          label: 'Look Up',
          onTap: _busy ? null : _lookupBarcode,
          loading: _busy,
        ),
      ],
    );
  }

  Widget _captureStep() {
    final path = _imagePath;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (path != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              width: double.infinity,
              height: 280,
              child: ScanImagePreview(path: path, fit: BoxFit.contain),
            ),
          )
        else
          GlowCard(
            child: Text(
              _acquisition.supportsCameraCapture
                  ? 'Photograph the front of the product or its nutrition/ingredient label. The photo stays private and is only used to suggest details you review before saving.'
                  : 'Live camera capture is unavailable on this device. Choose a photo instead.',
              style: AppTextStyles.subtitle.copyWith(fontSize: 14),
            ),
          ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            style: AppTextStyles.captionBold.copyWith(
              color: AppColors.orange,
              fontSize: 13,
            ),
          ),
          if (_permissionDenied && supportsOpenAppSettingsDeepLink) ...[
            const SizedBox(height: 8),
            _SecondaryButton(label: 'Open Settings', onTap: openAppSettings),
          ],
        ],
        const SizedBox(height: 16),
        if (path == null) ...[
          if (_acquisition.supportsCameraCapture) ...[
            _PrimaryButton(
              label: 'Take Photo',
              onTap: _busy ? null : _capture,
              loading: _busy,
            ),
            const SizedBox(height: 12),
          ],
          _SecondaryButton(
            label: _acquisition.supportsCameraCapture
                ? 'Choose from gallery'
                : 'Choose Photo',
            onTap: _busy ? null : _pickFromGallery,
          ),
          const SizedBox(height: 12),
          _SecondaryButton(
            label: 'Enter Manually Instead',
            onTap: _skipToManualEntry,
          ),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: _SecondaryButton(
                  label: 'Retake',
                  onTap: () => setState(() => _imagePath = null),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PrimaryButton(label: 'Analyze', onTap: _analyzePhoto),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _analyzingStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          const CircularProgressIndicator(color: AppColors.blue),
          const SizedBox(height: 16),
          Text(
            'Reading the photo…',
            style: AppTextStyles.subtitle.copyWith(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _formStep() {
    final category = _category ?? ProductCategory.food;
    final draft = _draft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (draft != null && draft.dataSource != ProductDataSource.manual)
          GlowCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  draft.dataSource == ProductDataSource.barcode
                      ? 'From barcode lookup — review and correct anything before saving.'
                      : 'Suggested from your photo — review and correct anything before saving. Every value is an estimate.',
                  style: AppTextStyles.subtitle.copyWith(fontSize: 13),
                ),
                if (draft.dataConfidence != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Estimated confidence: ${(draft.dataConfidence! * 100).round()}%',
                    style: AppTextStyles.caption.copyWith(fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        if (_info != null) ...[
          const SizedBox(height: 10),
          GlowCard(
            child: Text(
              _info!,
              style: AppTextStyles.subtitle.copyWith(fontSize: 13),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          'Product details',
          style: AppTextStyles.captionBold.copyWith(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 10),
        _field(_nameController, 'Product name'),
        const SizedBox(height: 10),
        _field(_brandController, 'Brand (optional)'),
        const SizedBox(height: 10),
        _field(_subcategoryController, 'Type (e.g. Yoga mat, Protein powder)'),
        const SizedBox(height: 16),
        if (category.hasNutritionFields) _nutritionFields(),
        if (category == ProductCategory.equipment) _equipmentFields(),
        if (category == ProductCategory.activewear) _activewearFields(),
        if (category == ProductCategory.skincare) _skincareFields(),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            style: AppTextStyles.captionBold.copyWith(
              color: AppColors.orange,
              fontSize: 13,
            ),
          ),
        ],
        const SizedBox(height: 20),
        _PrimaryButton(
          label: 'Save Product',
          onTap: _canSave && !_busy ? _save : null,
          loading: _busy,
        ),
      ],
    );
  }

  Widget _nutritionFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nutrition (per serving, estimates)',
          style: AppTextStyles.captionBold.copyWith(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 10),
        _field(_servingController, 'Serving size (e.g. 1 scoop, 100g)'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _field(_caloriesController, 'Calories', numeric: true),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _field(_proteinController, 'Protein (g)', numeric: true),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _field(_carbsController, 'Carbs (g)', numeric: true),
            ),
            const SizedBox(width: 8),
            Expanded(child: _field(_fatController, 'Fat (g)', numeric: true)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _field(_fiberController, 'Fiber (g)', numeric: true),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _field(_sugarController, 'Sugar (g)', numeric: true),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _field(_sodiumController, 'Sodium (mg)', numeric: true),
        const SizedBox(height: 10),
        _field(_ingredientsController, 'Ingredients (optional)', maxLines: 3),
        const SizedBox(height: 10),
        _field(_allergensController, 'Allergens (optional)'),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _equipmentFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Equipment details',
          style: AppTextStyles.captionBold.copyWith(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 10),
        _field(_intendedUseController, 'Intended use (optional)'),
        const SizedBox(height: 10),
        _field(_exercisesController, 'Exercises supported (comma-separated)'),
        const SizedBox(height: 10),
        _field(_muscleGroupsController, 'Muscle groups (comma-separated)'),
        const SizedBox(height: 10),
        Row(
          children: [
            Text(
              'Beginner-suitable:',
              style: AppTextStyles.subtitle.copyWith(
                fontSize: 13,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            _TriStateChip(
              label: 'Yes',
              selected: _beginnerSuitable == true,
              onTap: () => setState(() => _beginnerSuitable = true),
            ),
            const SizedBox(width: 8),
            _TriStateChip(
              label: 'No',
              selected: _beginnerSuitable == false,
              onTap: () => setState(() => _beginnerSuitable = false),
            ),
            const SizedBox(width: 8),
            _TriStateChip(
              label: 'Unsure',
              selected: _beginnerSuitable == null,
              onTap: () => setState(() => _beginnerSuitable = null),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _field(_safetyController, 'Safety notes (optional)', maxLines: 2),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _activewearFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Activewear details',
          style: AppTextStyles.captionBold.copyWith(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 10),
        _field(_sizeController, 'Size (optional)'),
        const SizedBox(height: 10),
        _field(_materialController, 'Material (optional)'),
        const SizedBox(height: 10),
        _field(_activityController, 'Activity type (optional)'),
        const SizedBox(height: 10),
        _field(_careController, 'Care instructions (optional)'),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _skincareFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Skincare details',
          style: AppTextStyles.captionBold.copyWith(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 10),
        _field(_ingredientsController, 'Ingredients (optional)', maxLines: 3),
        const SizedBox(height: 10),
        _field(_skinTypeController, 'Skin type info (optional)'),
        const SizedBox(height: 10),
        _field(
          _irritantsController,
          'Possible irritants (optional)',
          maxLines: 2,
        ),
        const SizedBox(height: 10),
        Text(
          'This is general product information only — never a diagnosis or a promise that this product will treat, cure, or heal anything.',
          style: AppTextStyles.caption.copyWith(fontSize: 11),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String hint, {
    bool numeric = false,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      maxLines: maxLines,
      onChanged: (_) => setState(() {}),
      style: AppTextStyles.subtitle.copyWith(fontSize: 14, color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.caption,
        isDense: true,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
    );
  }

  Widget _savedStep() {
    final product = _savedProduct;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlowCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Product saved',
                style: AppTextStyles.cardTitle.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                product?.name ?? '',
                style: AppTextStyles.subtitle.copyWith(
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _PrimaryButton(
          label: 'Add to Grocery List',
          onTap: () => _addToList(ShopListType.grocery),
        ),
        const SizedBox(height: 12),
        _PrimaryButton(
          label: 'Add to Fitness & Wellness List',
          onTap: () => _addToList(ShopListType.fitness),
        ),
        const SizedBox(height: 12),
        _SecondaryButton(label: 'Scan Another Product', onTap: _reset),
        if (widget.onViewList != null) ...[
          const SizedBox(height: 12),
          _SecondaryButton(
            label: 'View Lists & Basket',
            onTap: widget.onViewList!,
          ),
        ],
      ],
    );
  }
}

class _TriStateChip extends StatelessWidget {
  const _TriStateChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.blue
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.blue : AppColors.cardBorder,
            ),
          ),
          child: Text(
            label,
            style: AppTextStyles.captionBold.copyWith(
              fontSize: 12,
              color: selected ? const Color(0xFF0A0B1E) : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.onTap,
    this.loading = false,
  });
  final String label;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          color: onTap == null
              ? AppColors.blue.withValues(alpha: 0.4)
              : AppColors.blue,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF0A0B1E),
                      ),
                    )
                  : Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFF0A0B1E),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.cardBorder),
        ),
        child: Text(
          label,
          style: AppTextStyles.captionBold.copyWith(
            color: AppColors.textPrimary,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
