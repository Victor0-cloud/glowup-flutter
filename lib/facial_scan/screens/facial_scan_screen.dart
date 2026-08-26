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
import '../state/facial_scan_controller.dart';

enum _Step {
  consent,
  permission,
  preview,
  analyzing,
  analysisFailed,
  checkIn,
  confirm,
}

const kFacialWellnessAreas = [
  'Breakouts',
  'Redness',
  'Feeling oily',
  'Feeling dry',
  'Dark marks after acne',
  'Uneven-looking texture',
  'Feeling great',
];

/// The complete Skin & Acne Scan flow — explicit consent first (never
/// skippable, never assumed), permission explanation, camera-or-gallery
/// selection (file picker on Windows), preview, an honest manual wellness
/// check-in (self-reported, non-diagnostic language throughout — this is
/// for healthy-skin support, never an attractiveness score and never a
/// medical diagnosis), and a confirm step. Internally still the
/// `facial_scan` module/route (an implementation detail, not shown to the
/// user) — every user-facing string says "Skin & Acne Scan."
class FacialScanScreen extends ConsumerStatefulWidget {
  const FacialScanScreen({super.key, this.onBack, this.onViewHistory});

  final VoidCallback? onBack;
  final VoidCallback? onViewHistory;

  @override
  ConsumerState<FacialScanScreen> createState() => _FacialScanScreenState();
}

class _FacialScanScreenState extends ConsumerState<FacialScanScreen> {
  final _acquisition = ImagePickerAcquisitionProvider();
  late final ScanAnalysisProvider _analysis = selectScanAnalysisProvider();

  _Step? _stepOverride;
  String? _imagePath;
  String? _error;
  bool _busy = false;
  bool _permissionDenied = false;
  final Set<String> _selectedAreas = {};
  final _noteController = TextEditingController();
  ScanProviderCapability _analysisState = ScanProviderCapability.unavailable;
  List<FacialObservation> _observations = const [];
  String? _qualityNote;

  @override
  void initState() {
    super.initState();
    _analysis.checkCapability().then((s) {
      if (mounted) setState(() => _analysisState = s);
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _grantConsent() async {
    await ref.read(facialScanControllerProvider.notifier).grantConsent();
    if (mounted) setState(() => _stepOverride = _Step.permission);
  }

  /// Calls the real analysis provider on the captured/selected photo.
  /// Observations are shown to the user as *information* alongside the
  /// self-reported check-in chips below — the confirmed, saved data is
  /// always the user's own selection (see `FacialScanController.
  /// confirmCheckIn`), never the raw model output. Three honest outcomes,
  /// same discipline as Food Scan: not-configured falls through quietly to
  /// the manual check-in, a genuine call failure offers an explicit Retry,
  /// success shows real observations. `_busy` guards against a rapid
  /// double-tap on "Continue" firing this twice.
  Future<void> _runAnalysis() async {
    final path = _imagePath;
    if (path == null) {
      setState(() => _stepOverride = _Step.checkIn);
      return;
    }
    if (_busy) return;
    setState(() {
      _busy = true;
      _stepOverride = _Step.analyzing;
    });
    final result = await _analysis.analyzeFacial(path);
    if (!mounted) return;
    final providerWasAvailable =
        _analysisState == ScanProviderCapability.available;
    setState(() {
      _busy = false;
      if (result != null) {
        _observations = result.observations;
        _qualityNote = result.qualityNote;
        _stepOverride = _Step.checkIn;
      } else if (providerWasAvailable) {
        _stepOverride = _Step.analysisFailed;
      } else {
        _stepOverride = _Step.checkIn;
      }
    });
  }

  Future<void> _capture() async {
    setState(() {
      _busy = true;
      _error = null;
      _permissionDenied = false;
    });
    try {
      final path = await _acquisition.captureFromCamera(
        preferFrontCamera: true,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (path != null) {
          _imagePath = path;
          _stepOverride = _Step.preview;
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
          _stepOverride = _Step.preview;
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
      _stepOverride = _Step.permission;
    });
  }

  Future<void> _confirmSave() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final controller = ref.read(facialScanControllerProvider.notifier);
      final note = _noteController.text.trim();
      final saved = await controller.confirmCheckIn(
        selfReportedAreas: _selectedAreas.toList(),
        sourceImagePath: _imagePath,
        note: note.isEmpty ? null : note,
      );
      if (!mounted) return;
      if (saved == null) {
        setState(() {
          _busy = false;
          _error = 'Could not save this check-in. Please try again.';
        });
        return;
      }
      setState(() {
        _busy = false;
        _stepOverride = null;
        _imagePath = null;
        _selectedAreas.clear();
        _noteController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Check-in saved'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not save this check-in. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scanState = ref.watch(facialScanControllerProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: Column(
          children: [
            SubScreenHeader(
              title: 'Skin & Acne Scan',
              subtitle: 'Healthy-skin support, never a beauty score',
              onBack: widget.onBack ?? () => Navigator.maybePop(context),
            ),
            Expanded(
              child: scanState.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.blue),
                ),
                error: (err, st) => Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      "Couldn't load Skin & Acne Scan. Please restart the app.",
                      style: AppTextStyles.subtitle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                data: (data) => SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  child: _body(data.hasConsented),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(bool hasConsented) {
    final step =
        _stepOverride ?? (hasConsented ? _Step.permission : _Step.consent);
    return switch (step) {
      _Step.consent => _consentStep(),
      _Step.permission => _permissionStep(),
      _Step.preview => _previewStep(),
      _Step.analyzing => _analyzingStep(),
      _Step.analysisFailed => _analysisFailedStep(),
      _Step.checkIn => _checkInStep(),
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
            'temporary connection issue — you can try again, or continue '
            'with a manual check-in.',
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
          label: 'Continue Without Analysis',
          onTap: () => setState(() => _stepOverride = _Step.checkIn),
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

  Widget _consentStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlowCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Before you continue',
                style: AppTextStyles.cardTitle.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 10),
              Text(
                'Skin & Acne Scan is for healthy-skin support — it never gives an attractiveness or beauty score, and it is not a medical diagnosis. '
                'Anything it notes is described as a possible visible concern, never a diagnosis, and it never '
                'identifies who you are. A saved photo stays only on this device, in its own private, separate storage — if an '
                'analysis photo is sent for processing, it is used only to generate observations and is not kept afterward. '
                'It is never used for facial/identity recognition, never used to build a biometric profile, and never shared with '
                'other users or any shared cache. Designed to work across skin tones. You can delete a photo or check-in at any time.',
                style: AppTextStyles.subtitle.copyWith(fontSize: 13),
              ),
              const SizedBox(height: 10),
              Text(
                'This feature cannot cure acne and does not replace professional care. If a concern is painful, severe, persistent, '
                'or leaves scarring, please see a medical or dermatology professional. "Natural" or "organic" does not automatically '
                'mean safe for your skin.',
                style: AppTextStyles.caption.copyWith(fontSize: 12),
              ),
              const SizedBox(height: 10),
              Text(
                'If you are under 18, please review this with a parent or guardian before continuing.',
                style: AppTextStyles.caption.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _PrimaryButton(label: 'I Understand & Consent', onTap: _grantConsent),
        if (widget.onBack != null) ...[
          const SizedBox(height: 12),
          _SecondaryButton(label: 'Not Now', onTap: widget.onBack!),
        ],
      ],
    );
  }

  Widget _permissionStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlowCard(
          child: Text(
            _acquisition.supportsCameraCapture
                ? 'Glow Up can use your front camera to take a photo, or you can choose an existing one. The photo stays private on this device.'
                : 'Live camera capture is unavailable on this device. Choose a photo instead.',
            style: AppTextStyles.subtitle.copyWith(fontSize: 14),
          ),
        ),
        if (_acquisition.supportsCameraCapture) ...[
          const SizedBox(height: 10),
          Text(
            'For the clearest photo: face a light source, center your face '
            'in the frame, and hold still before capturing.',
            style: AppTextStyles.caption.copyWith(fontSize: 12),
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
          label: 'Skip Photo — Manual Check-In',
          onTap: _busy
              ? null
              : () => setState(() => _stepOverride = _Step.checkIn),
        ),
        if (widget.onViewHistory != null) ...[
          const SizedBox(height: 12),
          _SecondaryButton(label: 'View History', onTap: widget.onViewHistory!),
        ],
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
                onTap: () => setState(() => _stepOverride = _Step.permission),
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

  Widget _checkInStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_imagePath != null &&
            _analysisState != ScanProviderCapability.available)
          GlowCard(
            child: Text(
              'Automatic facial wellness analysis is not connected yet. You may save this photo privately for progress tracking or complete a manual check-in.',
              style: AppTextStyles.subtitle.copyWith(fontSize: 13),
            ),
          )
        else if (_observations.isNotEmpty)
          GlowCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Possible visible concerns — not a diagnosis, just what your Coach can see below:',
                  style: AppTextStyles.subtitle.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 8),
                for (final observation in _observations)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• ${observation.observation}',
                      style: AppTextStyles.caption.copyWith(fontSize: 12),
                    ),
                  ),
                if (_qualityNote != null) ...[
                  const SizedBox(height: 4),
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
          'How does your skin feel today?',
          style: AppTextStyles.captionBold.copyWith(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final area in kFacialWellnessAreas)
              _Chip(
                label: area,
                selected: _selectedAreas.contains(area),
                onTap: () => setState(() {
                  if (_selectedAreas.contains(area)) {
                    _selectedAreas.remove(area);
                  } else {
                    _selectedAreas.add(area);
                  }
                }),
              ),
          ],
        ),
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
          onTap: () => setState(() => _stepOverride = _Step.confirm),
        ),
      ],
    );
  }

  Widget _confirmStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Confirm check-in',
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
              Text(
                _selectedAreas.isEmpty
                    ? 'No specific areas selected'
                    : _selectedAreas.join(', '),
                style: AppTextStyles.subtitle.copyWith(
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
              if (_imagePath != null) ...[
                const SizedBox(height: 8),
                Text(
                  'A photo will be saved privately with this check-in.',
                  style: AppTextStyles.caption.copyWith(fontSize: 12),
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
                    : () => setState(() => _stepOverride = _Step.checkIn),
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

class _Chip extends StatelessWidget {
  const _Chip({
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
      child: Material(
        color: selected
            ? AppColors.blue.withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(100),
        child: InkWell(
          borderRadius: BorderRadius.circular(100),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: selected ? AppColors.blue : AppColors.cardBorder,
              ),
            ),
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(
                fontSize: 12,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
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
