import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glow_card.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/sub_screen_header.dart';
import '../../scan/models/scan_analysis_models.dart';
import '../../scan/providers/image_acquisition_provider.dart';
import '../../scan/providers/scan_analysis_provider.dart';
import '../../scan/widgets/camera_permission_help.dart';
import '../../scan/widgets/scan_image_preview.dart';
import '../models/food_scan_models.dart';
import '../state/food_scan_controller.dart';

enum _Step {
  intro,
  permission,
  preview,
  analyzing,
  analysisFailed,
  manualEntry,
  confirm,
}

/// The complete Food Scan flow — intro, permission explanation,
/// camera-or-gallery selection (file picker on Windows, where live
/// camera capture is not supported), preview with replace/remove, a real
/// analysis call through [ScanAnalysisProvider] (falling back to an
/// honest "automatic recognition not connected" message when no backend
/// is configured or the call fails), editable item review, and a confirm
/// step. Nothing is ever saved before the user explicitly confirms — see
/// [FoodScanController.confirmMeal].
class FoodScanScreen extends ConsumerStatefulWidget {
  const FoodScanScreen({super.key, this.onBack, this.onViewHistory});

  final VoidCallback? onBack;
  final VoidCallback? onViewHistory;

  @override
  ConsumerState<FoodScanScreen> createState() => _FoodScanScreenState();
}

class _FoodScanScreenState extends ConsumerState<FoodScanScreen> {
  final _acquisition = ImagePickerAcquisitionProvider();
  late final ScanAnalysisProvider _analysis = selectScanAnalysisProvider();

  _Step _step = _Step.intro;
  String? _imagePath;
  String? _error;
  bool _busy = false;
  bool _permissionDenied = false;
  final List<MealItem> _items = [];
  final _noteController = TextEditingController();
  int _itemIdSuffix = 0;
  String? _qualityNote;

  /// Read once at startup via the real provider boundary — the UI always
  /// derives its "automatic recognition unavailable" messaging from this
  /// state rather than a hardcoded assumption, so a real, deployed
  /// [RemoteScanAnalysisProvider] changes behavior with zero UI changes.
  ScanProviderCapability _analysisState = ScanProviderCapability.unavailable;

  @override
  void initState() {
    super.initState();
    _analysis.checkCapability().then((state) {
      if (mounted) setState(() => _analysisState = state);
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    setState(() {
      _busy = true;
      _error = null;
      _permissionDenied = false;
    });
    try {
      final path = await _acquisition.captureFromCamera();
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (path != null) {
          _imagePath = path;
          _step = _Step.preview;
        }
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
      _error = null;
      _permissionDenied = false;
    });
    try {
      final path = await _acquisition.pickFromGallery();
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (path != null) {
          _imagePath = path;
          _step = _Step.preview;
        }
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

  void _removeImage() {
    setState(() {
      _imagePath = null;
      _step = _Step.permission;
    });
  }

  void _skipToManualEntry() {
    setState(() => _step = _Step.manualEntry);
  }

  /// Calls the real analysis provider on the captured/selected photo.
  /// Three honest outcomes, never a fabricated detection: (1) provider not
  /// configured at all — goes straight to manual entry with the "not
  /// connected yet" banner; (2) a configured provider's call genuinely
  /// fails (network/timeout/etc.) — offers an explicit Retry rather than
  /// silently dropping into an unexplained empty manual-entry screen; (3)
  /// success — pre-fills the suggested items for review. `_busy` guards
  /// against a rapid double-tap on "Continue" firing this twice.
  Future<void> _runAnalysis() async {
    final path = _imagePath;
    if (path == null) {
      setState(() => _step = _Step.manualEntry);
      return;
    }
    if (_busy) return;
    setState(() {
      _busy = true;
      _step = _Step.analyzing;
    });
    final result = await _analysis.analyzeFood(path);
    if (!mounted) return;
    final providerWasAvailable =
        _analysisState == ScanProviderCapability.available;
    setState(() {
      _busy = false;
      if (result != null) {
        _items
          ..clear()
          ..addAll([
            for (final item in result.items)
              MealItem(
                id: 'item_${_itemIdSuffix++}',
                name: item.name,
                portion: item.portion,
                calories: item.calories,
              ),
          ]);
        _qualityNote = result.qualityNote;
        _step = _Step.manualEntry;
      } else if (providerWasAvailable) {
        // The provider IS connected but this specific call failed — an
        // honest, retryable failure, distinct from "never configured."
        _step = _Step.analysisFailed;
      } else {
        _step = _Step.manualEntry;
      }
    });
  }

  void _addItem() {
    setState(() {
      _items.add(MealItem(id: 'item_${_itemIdSuffix++}', name: ''));
    });
  }

  void _removeItem(String id) {
    setState(() => _items.removeWhere((i) => i.id == id));
  }

  void _updateItem(String id, MealItem Function(MealItem) update) {
    setState(() {
      final index = _items.indexWhere((i) => i.id == id);
      if (index != -1) _items[index] = update(_items[index]);
    });
  }

  bool get _hasValidItems =>
      _items.isNotEmpty && _items.every((i) => i.name.trim().isNotEmpty);

  Future<void> _confirmSave() async {
    if (!_hasValidItems || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final controller = ref.read(foodScanControllerProvider.notifier);
      final note = _noteController.text.trim();
      final saved = await controller.confirmMeal(
        items: _items,
        sourceImagePath: _imagePath,
        note: note.isEmpty ? null : note,
      );
      if (!mounted) return;
      if (saved == null) {
        setState(() {
          _busy = false;
          _error = 'Could not save this meal. Please try again.';
        });
        return;
      }
      setState(() {
        _busy = false;
        _step = _Step.intro;
        _imagePath = null;
        _items.clear();
        _noteController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Meal saved'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not save this meal. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: Column(
          children: [
            SubScreenHeader(
              title: 'Food Scan',
              subtitle: 'Log a meal — you always review before it saves',
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
      _Step.intro => _introStep(),
      _Step.permission => _permissionStep(),
      _Step.preview => _previewStep(),
      _Step.analyzing => _analyzingStep(),
      _Step.analysisFailed => _analysisFailedStep(),
      _Step.manualEntry => _manualEntryStep(),
      _Step.confirm => _confirmStep(),
    };
  }

  Widget _analysisFailedStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlowCard(
          child: Text(
            "Couldn't analyze that photo right now. This is usually a "
            'temporary connection issue — you can try again, or enter the '
            'meal manually.',
            style: AppTextStyles.subtitle.copyWith(fontSize: 14),
          ),
        ),
        const SizedBox(height: 20),
        _PrimaryButton(
          label: 'Retry',
          onTap: _busy ? null : _runAnalysis,
          loading: _busy,
        ),
        const SizedBox(height: 12),
        _SecondaryButton(
          label: 'Enter Manually Instead',
          onTap: _skipToManualEntry,
        ),
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
            'Analyzing your photo…',
            style: AppTextStyles.subtitle.copyWith(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _introStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlowCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Log what you ate',
                style: AppTextStyles.cardTitle.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                'Take or choose a photo of your meal, or skip straight to typing it in. You always review and confirm the details before anything saves — nothing is ever saved automatically.',
                style: AppTextStyles.subtitle.copyWith(fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                _analysisState == ScanProviderCapability.available
                    ? 'A photo is analyzed securely to suggest items — you always review, edit, and confirm before anything saves.'
                    : 'Food Scan works fully offline — your data never leaves this device.',
                style: AppTextStyles.caption.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _PrimaryButton(
          label: 'Get Started',
          onTap: () => setState(() => _step = _Step.permission),
        ),
        if (widget.onViewHistory != null) ...[
          const SizedBox(height: 12),
          _SecondaryButton(
            label: 'View Meal History',
            onTap: widget.onViewHistory!,
          ),
        ],
      ],
    );
  }

  Widget _permissionStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlowCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Camera access',
                style: AppTextStyles.cardTitle.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                _acquisition.supportsCameraCapture
                    ? 'Glow Up can use your camera to photograph a meal, or you can choose an existing photo instead. The photo stays private on this device.'
                    : 'Live camera capture is unavailable on this device. Choose a photo instead.',
                style: AppTextStyles.subtitle.copyWith(fontSize: 14),
              ),
            ],
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
        const SizedBox(height: 20),
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
          label: 'Skip Photo — Enter Manually',
          onTap: _busy ? null : _skipToManualEntry,
        ),
      ],
    );
  }

  Widget _previewStep() {
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
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _SecondaryButton(
                label: 'Replace',
                onTap: () => setState(() => _step = _Step.permission),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SecondaryButton(label: 'Remove', onTap: _removeImage),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _PrimaryButton(label: 'Continue', onTap: _runAnalysis),
      ],
    );
  }

  Widget _manualEntryStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_imagePath != null &&
            _analysisState != ScanProviderCapability.available)
          GlowCard(
            child: Text(
              'Automatic food recognition is not connected yet. You can review the photo and enter the meal details manually.',
              style: AppTextStyles.subtitle.copyWith(fontSize: 13),
            ),
          )
        else if (_imagePath != null && _items.isNotEmpty)
          GlowCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Suggested from your photo — review and correct anything before saving. Every value is an estimate.',
                  style: AppTextStyles.subtitle.copyWith(fontSize: 13),
                ),
                if (_qualityNote != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _qualityNote!,
                    style: AppTextStyles.caption.copyWith(fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 16),
        Text(
          'Meal items',
          style: AppTextStyles.captionBold.copyWith(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 10),
        for (final item in _items) ...[
          _MealItemEditor(
            item: item,
            onChanged: (updated) => _updateItem(item.id, (_) => updated),
            onRemove: () => _removeItem(item.id),
          ),
          const SizedBox(height: 10),
        ],
        _SecondaryButton(label: '+ Add Item', onTap: _addItem),
        const SizedBox(height: 16),
        TextField(
          controller: _noteController,
          minLines: 1,
          maxLines: 3,
          maxLength: 300,
          style: AppTextStyles.subtitle.copyWith(
            fontSize: 13,
            color: Colors.white,
          ),
          decoration: InputDecoration(
            hintText: 'Note (optional)',
            hintStyle: AppTextStyles.caption,
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
        ),
        const SizedBox(height: 20),
        _PrimaryButton(
          label: 'Review',
          onTap: _hasValidItems
              ? () => setState(() => _step = _Step.confirm)
              : null,
        ),
      ],
    );
  }

  Widget _confirmStep() {
    final total = _items.every((i) => i.calories != null) && _items.isNotEmpty
        ? _items.fold<int>(0, (sum, i) => sum + (i.calories ?? 0))
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Confirm meal',
          style: AppTextStyles.captionBold.copyWith(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 10),
        GlowCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final item in _items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.portion == null
                              ? item.name
                              : '${item.name} (${item.portion})',
                          style: AppTextStyles.subtitle.copyWith(
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      if (item.calories != null)
                        Text(
                          '~${item.calories} cal',
                          style: AppTextStyles.caption.copyWith(fontSize: 12),
                        ),
                    ],
                  ),
                ),
              if (total != null) ...[
                const Divider(color: AppColors.cardBorder),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Estimated total',
                      style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
                    ),
                    Text(
                      '~$total cal (estimate)',
                      style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
                    ),
                  ],
                ),
              ],
            ],
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
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _SecondaryButton(
                label: 'Back',
                onTap: _busy
                    ? null
                    : () => setState(() => _step = _Step.manualEntry),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PrimaryButton(
                label: 'Save',
                onTap: _busy ? null : _confirmSave,
                loading: _busy,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MealItemEditor extends StatelessWidget {
  const _MealItemEditor({
    required this.item,
    required this.onChanged,
    required this.onRemove,
  });
  final MealItem item;
  final ValueChanged<MealItem> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return GlowCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: [
                TextFormField(
                  initialValue: item.name,
                  style: AppTextStyles.subtitle.copyWith(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Food name',
                    hintStyle: AppTextStyles.caption,
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                  ),
                  onChanged: (v) => onChanged(item.copyWith(name: v)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: item.portion,
                        style: AppTextStyles.subtitle.copyWith(
                          fontSize: 13,
                          color: Colors.white,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Portion (e.g. 1 cup)',
                          hintStyle: AppTextStyles.caption.copyWith(
                            fontSize: 12,
                          ),
                          isDense: true,
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                        ),
                        onChanged: (v) => onChanged(
                          item.copyWith(
                            portion: v.isEmpty ? null : v,
                            clearPortion: v.isEmpty,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 90,
                      child: TextFormField(
                        initialValue: item.calories?.toString(),
                        keyboardType: TextInputType.number,
                        style: AppTextStyles.subtitle.copyWith(
                          fontSize: 13,
                          color: Colors.white,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Cal. est.',
                          hintStyle: AppTextStyles.caption.copyWith(
                            fontSize: 12,
                          ),
                          isDense: true,
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                        ),
                        onChanged: (v) {
                          final parsed = int.tryParse(v);
                          onChanged(
                            item.copyWith(
                              calories: parsed,
                              clearCalories: parsed == null,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: 'Remove item',
            child: IconButton(
              icon: const Icon(
                Icons.close,
                size: 18,
                color: AppColors.textSecondary,
              ),
              onPressed: onRemove,
            ),
          ),
        ],
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
