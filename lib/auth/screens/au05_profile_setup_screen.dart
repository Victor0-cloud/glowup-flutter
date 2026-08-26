import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/gradient_pill_button.dart';
import '../../profile/models/profile_models.dart';
import '../../profile/utils/unit_conversion.dart';
import '../../scan/data/private_image_store.dart';
import '../../scan/providers/image_acquisition_provider.dart';

/// AU05 Profile Setup — writes directly into the existing, real
/// [ProfileDetails] (`profileControllerProvider`), the only home
/// gender/height/weight/photo have anywhere in this app. Never a second
/// profile-data structure.
///
/// Height/weight respect the app's existing metric/imperial preference
/// ([AppUnits], set on the Settings screen) rather than always assuming
/// centimeters — [ProfileDetails.heightCm]/[weightKg] are still always
/// stored in metric internally; only the input fields shown here change.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({
    super.key,
    required this.initialDetails,
    required this.units,
    required this.onContinue,
    this.saving = false,
    this.errorText,
  });

  final ProfileDetails initialDetails;
  final AppUnits units;
  final ValueChanged<ProfileDetails> onContinue;
  final bool saving;

  /// A real save failure from the repository, surfaced here rather than
  /// failing silently — see the router's `_ProfileSetupPage`.
  final String? errorText;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  DateTime? _dateOfBirth;
  Gender? _gender;
  final _nameController = TextEditingController();
  final _heightController = TextEditingController();
  final _feetController = TextEditingController();
  final _inchesController = TextEditingController();
  final _weightController = TextEditingController();
  String? _photoPath;
  bool _pickingPhoto = false;

  String? _heightError;
  String? _weightError;

  @override
  void initState() {
    super.initState();
    _dateOfBirth = widget.initialDetails.dateOfBirth;
    _gender = widget.initialDetails.gender;
    _nameController.text = widget.initialDetails.name ?? '';
    final heightCm = widget.initialDetails.heightCm;
    if (heightCm != null) {
      if (widget.units == AppUnits.metric) {
        _heightController.text = heightCm.toStringAsFixed(0);
      } else {
        final (feet, inches) = cmToFeetAndInches(heightCm);
        _feetController.text = feet.toString();
        _inchesController.text = inches.round().toString();
      }
    }
    final weightKg = widget.initialDetails.weightKg;
    if (weightKg != null) {
      _weightController.text = widget.units == AppUnits.metric
          ? weightKg.toStringAsFixed(0)
          : kgToLb(weightKg).toStringAsFixed(0);
    }
    _photoPath = widget.initialDetails.photoPath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _heightController.dispose();
    _feetController.dispose();
    _inchesController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  bool get _isMetric => widget.units == AppUnits.metric;

  /// Presence-only gate — enables the button as soon as the required
  /// fields have *some* input. Real validity (a parseable, sane number) is
  /// checked in [_submit], which shows a visible error instead of
  /// silently refusing to navigate.
  bool get _canAttemptSubmit =>
      _dateOfBirth != null &&
      _gender != null &&
      (_isMetric
          ? _heightController.text.trim().isNotEmpty
          : _feetController.text.trim().isNotEmpty);

  /// Cross-platform image provider for a locally-picked photo path — never
  /// touches `dart:io`'s FileImage on Web, where [path] is a `blob:` URL
  /// (unsupported there; see the Web safety audit). NetworkImage loads a
  /// `blob:` URL correctly via the browser's own image loading.
  ImageProvider _photoImageProvider(String path) =>
      kIsWeb ? NetworkImage(path) : FileImage(File(path));

  Future<void> _pickPhoto() async {
    setState(() => _pickingPhoto = true);
    try {
      final path = await ImagePickerAcquisitionProvider().pickFromGallery();
      if (path == null) return;
      final store = await PrivateImageStore.forCategory('profile');
      final saved = await store.save(path);
      if (!mounted) return;
      setState(() => _photoPath = saved);
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 20),
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year - 13),
    );
    if (picked == null || !mounted) return;
    setState(() => _dateOfBirth = picked);
  }

  /// Real height validation, unit-aware. Returns the height in
  /// centimeters, or null (with [_heightError] set) if what was entered
  /// isn't a real, sane height — never silently ignored.
  double? _validateHeight() {
    if (_isMetric) {
      final cm = double.tryParse(_heightController.text.trim());
      if (cm == null || cm < 50 || cm > 250) {
        setState(() => _heightError = 'Enter height in centimeters');
        return null;
      }
      return cm;
    }
    final feet = double.tryParse(_feetController.text.trim());
    final inchesText = _inchesController.text.trim();
    final inches = inchesText.isEmpty ? 0.0 : double.tryParse(inchesText);
    if (feet == null || inches == null || inches < 0 || inches >= 12) {
      setState(() => _heightError = 'Enter height in feet and inches');
      return null;
    }
    final cm = feetInchesToCm(feet, inches);
    if (cm < 50 || cm > 250) {
      setState(() => _heightError = 'Enter height in feet and inches');
      return null;
    }
    return cm;
  }

  /// Weight stays genuinely optional: a blank field is always valid (never
  /// blocks Continue). Only non-blank, non-numeric input produces a visible
  /// error — typed-but-garbled input is never silently discarded.
  ({double? kg, bool valid}) _validateWeight() {
    final text = _weightController.text.trim();
    if (text.isEmpty) return (kg: null, valid: true);
    final value = double.tryParse(text);
    if (value == null || value <= 0) {
      setState(
        () => _weightError = _isMetric
            ? 'Enter weight in kilograms, or leave it blank'
            : 'Enter weight in pounds, or leave it blank',
      );
      return (kg: null, valid: false);
    }
    return (kg: _isMetric ? value : lbToKg(value), valid: true);
  }

  void _submit() {
    setState(() {
      _heightError = null;
      _weightError = null;
    });
    if (_dateOfBirth == null || _gender == null) return;

    final heightCm = _validateHeight();
    final weightResult = _validateWeight();
    if (heightCm == null || !weightResult.valid) return;

    final name = _nameController.text.trim();
    widget.onContinue(
      widget.initialDetails.copyWith(
        name: name.isEmpty ? null : name,
        clearName: name.isEmpty,
        dateOfBirth: _dateOfBirth,
        gender: _gender,
        heightCm: heightCm,
        weightKg: weightResult.kg,
        clearWeight: weightResult.kg == null,
        photoPath: _photoPath,
        clearPhotoPath: _photoPath == null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Almost there!',
                  style: AppTextStyles.screenTitle.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tell us a bit about you.',
                  style: AppTextStyles.subtitleLg,
                ),
                const SizedBox(height: 24),
                Center(
                  child: Semantics(
                    button: true,
                    label: 'Choose a profile photo',
                    child: InkWell(
                      onTap: _pickingPhoto ? null : _pickPhoto,
                      borderRadius: BorderRadius.circular(60),
                      child: Stack(
                        children: [
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.gold,
                                width: 2,
                              ),
                              color: AppColors.cardStart,
                              image: _photoPath != null
                                  ? DecorationImage(
                                      image: _photoImageProvider(
                                        _photoPath!,
                                      ),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: _photoPath == null
                                ? Icon(
                                    Icons.person,
                                    size: 44,
                                    color: AppColors.textSecondary,
                                  )
                                : null,
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: const BoxDecoration(
                                color: AppColors.gold,
                                shape: BoxShape.circle,
                              ),
                              child: _pickingPhoto
                                  ? const Padding(
                                      padding: EdgeInsets.all(7),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF0A0B1E),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.camera_alt,
                                      size: 16,
                                      color: Color(0xFF0A0B1E),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Name (optional)', style: AppTextStyles.fieldLabel),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.cardStart, AppColors.cardEnd],
                    ),
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  alignment: Alignment.centerLeft,
                  child: TextField(
                    controller: _nameController,
                    style: AppTextStyles.fieldValue.copyWith(
                      color: Colors.white,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      hintText: 'e.g., Alex',
                      hintStyle: AppTextStyles.fieldPlaceholder,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text('Date of Birth', style: AppTextStyles.fieldLabel),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.cardStart, AppColors.cardEnd],
                      ),
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _dateOfBirth == null
                          ? 'Select date'
                          : _fullDate(_dateOfBirth!),
                      style: _dateOfBirth == null
                          ? AppTextStyles.fieldPlaceholder
                          : AppTextStyles.fieldValue.copyWith(
                              color: Colors.white,
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text('Gender', style: AppTextStyles.fieldLabel),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.cardStart, AppColors.cardEnd],
                    ),
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<Gender>(
                      value: _gender,
                      isExpanded: true,
                      dropdownColor: AppColors.cardStart,
                      hint: Text(
                        'Select',
                        style: AppTextStyles.fieldPlaceholder,
                      ),
                      style: AppTextStyles.fieldValue.copyWith(
                        color: Colors.white,
                      ),
                      icon: const Icon(
                        Icons.keyboard_arrow_down,
                        color: AppColors.textSecondary,
                      ),
                      items: [
                        for (final g in Gender.values)
                          DropdownMenuItem(value: g, child: Text(g.label)),
                      ],
                      onChanged: (g) => setState(() => _gender = g),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                if (_isMetric)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _NumberField(
                          label: 'Height (cm)',
                          controller: _heightController,
                          errorText: _heightError,
                          onChanged: () => setState(() => _heightError = null),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _NumberField(
                          label: 'Weight (kg, optional)',
                          controller: _weightController,
                          errorText: _weightError,
                          onChanged: () => setState(() => _weightError = null),
                        ),
                      ),
                    ],
                  )
                else ...[
                  Text(
                    'Height',
                    style: AppTextStyles.fieldLabel.copyWith(fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _NumberField(
                          label: 'Feet',
                          controller: _feetController,
                          onChanged: () => setState(() => _heightError = null),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _NumberField(
                          label: 'Inches',
                          controller: _inchesController,
                          onChanged: () => setState(() => _heightError = null),
                        ),
                      ),
                    ],
                  ),
                  if (_heightError != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _heightError!,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.ctaStart,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  _NumberField(
                    label: 'Weight (lb, optional)',
                    controller: _weightController,
                    errorText: _weightError,
                    onChanged: () => setState(() => _weightError = null),
                  ),
                ],
                if (widget.errorText != null) ...[
                  const SizedBox(height: 18),
                  Text(
                    widget.errorText!,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.ctaStart,
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                GradientPillButton(
                  label: 'Continue',
                  loading: widget.saving,
                  onPressed: _canAttemptSubmit && !widget.saving
                      ? _submit
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _fullDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.label,
    required this.controller,
    required this.onChanged,
    this.errorText,
  });
  final String label;
  final TextEditingController controller;
  final VoidCallback onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.fieldLabel.copyWith(fontSize: 13)),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.cardStart, AppColors.cardEnd],
            ),
            borderRadius: BorderRadius.circular(AppRadii.sm),
            border: Border.all(
              color: errorText != null
                  ? AppColors.ctaStart
                  : AppColors.cardBorder,
            ),
          ),
          alignment: Alignment.centerLeft,
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => onChanged(),
            style: AppTextStyles.fieldValue.copyWith(color: Colors.white),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: AppTextStyles.caption.copyWith(color: AppColors.ctaStart),
          ),
        ],
      ],
    );
  }
}
