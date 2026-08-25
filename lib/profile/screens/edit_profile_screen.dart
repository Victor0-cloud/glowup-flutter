import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/gradient_pill_button.dart';
import '../../core/widgets/sub_screen_header.dart';
import '../models/profile_models.dart';
import '../state/profile_controller.dart';

/// Edit Profile. Every field is optional — nothing here is required to
/// save, matching "do not require optional demographic fields." Name and
/// birthday are pre-filled from real stored data when available; nothing
/// is pre-filled from the design reference's demo values.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key, this.onBack, this.onSaved});

  final VoidCallback? onBack;
  final VoidCallback? onSaved;

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _nameController = TextEditingController();
  DateTime? _dateOfBirth;
  Gender? _gender;
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _loadOnce(ProfileDetails details) {
    if (_loaded) return;
    _loaded = true;
    _nameController.text = details.name ?? '';
    _dateOfBirth = details.dateOfBirth;
    _gender = details.gender;
    if (details.heightCm != null) {
      _heightController.text = details.heightCm!.toStringAsFixed(0);
    }
    if (details.weightKg != null) {
      _weightController.text = details.weightKg!.toStringAsFixed(0);
    }
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(now.year - 120),
      lastDate: now,
    );
    if (picked == null || !mounted) return;
    setState(() => _dateOfBirth = picked);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final name = _nameController.text.trim();
    final height = double.tryParse(_heightController.text.trim());
    final weight = double.tryParse(_weightController.text.trim());
    await ref
        .read(profileControllerProvider.notifier)
        .updateDetails(
          ProfileDetails(
            name: name.isEmpty ? null : name,
            dateOfBirth: _dateOfBirth,
            gender: _gender,
            heightCm: height,
            weightKg: weight,
          ),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (widget.onSaved != null) {
      widget.onSaved!();
    } else {
      Navigator.maybePop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileControllerProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: Column(
          children: [
            SubScreenHeader(
              title: 'Edit Profile',
              onBack: widget.onBack ?? () => Navigator.maybePop(context),
            ),
            Expanded(
              child: profileAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.purple),
                ),
                error: (e, st) => Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      "Couldn't load your profile. Please restart the app.",
                      style: AppTextStyles.subtitle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                data: (profileState) {
                  _loadOnce(profileState.details);
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Field(
                          label: 'Name',
                          child: _TextInput(
                            controller: _nameController,
                            hint: 'Your name',
                          ),
                        ),
                        const SizedBox(height: 14),
                        _Field(
                          label: 'Birthday',
                          child: _PickerInput(
                            label: 'Birthday',
                            value: _dateOfBirth == null
                                ? 'Not set'
                                : '${_dateOfBirth!.month}/${_dateOfBirth!.day}/${_dateOfBirth!.year}',
                            onTap: _pickDateOfBirth,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _Field(
                          label: 'Gender',
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final g in Gender.values)
                                _Chip(
                                  label: g.label,
                                  selected: _gender == g,
                                  onTap: () => setState(
                                    () => _gender = _gender == g ? null : g,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _Field(
                                label: 'Height (cm)',
                                child: _TextInput(
                                  controller: _heightController,
                                  hint: 'Optional',
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _Field(
                                label: 'Weight (kg)',
                                child: _TextInput(
                                  controller: _weightController,
                                  hint: 'Optional',
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        GradientPillButton(
                          label: 'Save Changes',
                          onPressed: _save,
                          loading: _saving,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.fieldLabel.copyWith(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _TextInput extends StatelessWidget {
  const _TextInput({
    required this.controller,
    required this.hint,
    this.keyboardType,
  });
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: hint,
      textField: true,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: AppTextStyles.subtitle.copyWith(
          fontSize: 15,
          color: Colors.white,
        ),
        decoration: InputDecoration(
          hintText: hint,
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
    );
  }
}

class _PickerInput extends StatelessWidget {
  const _PickerInput({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      value: value,
      child: Material(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 10),
                Text(
                  value,
                  style: AppTextStyles.subtitle.copyWith(
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
            ? AppColors.purple.withValues(alpha: 0.2)
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
                color: selected ? AppColors.purple : AppColors.cardBorder,
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 13,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
