import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../models/water_entry.dart';
import '../state/water_controller.dart';

/// Above this, in ml, a single entry triggers an explicit "are you sure?"
/// confirmation before saving — "warn before an unusually large single
/// entry" per the approved spec. Not a medical limit, just a plausible
/// mis-tap/typo guard (e.g. "2000" typed where "200" was meant).
const kLargeEntryWarningMl = 2000.0;

/// The custom water-entry bottom sheet: amount, ml/fl oz toggle, date and
/// time, optional label, Cancel/Save. Opened both from "Add Water" (the
/// main full-width action) and from the Custom quick-add slot — the same
/// one flow, never a second/duplicate entry surface.
Future<void> showWaterCustomEntrySheet(
  BuildContext context,
  WidgetRef ref, {
  required WaterUnit initialUnit,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _WaterCustomEntrySheet(initialUnit: initialUnit),
  );
}

class _WaterCustomEntrySheet extends ConsumerStatefulWidget {
  const _WaterCustomEntrySheet({required this.initialUnit});
  final WaterUnit initialUnit;

  @override
  ConsumerState<_WaterCustomEntrySheet> createState() =>
      _WaterCustomEntrySheetState();
}

class _WaterCustomEntrySheetState
    extends ConsumerState<_WaterCustomEntrySheet> {
  late WaterUnit _unit = widget.initialUnit;
  final _amountController = TextEditingController();
  final _labelController = TextEditingController();
  DateTime _when = DateTime.now();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  double? _parseAmount() {
    final text = _amountController.text.trim().replaceAll(',', '.');
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null || !mounted) return;
    setState(
      () => _when = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _when.hour,
        _when.minute,
      ),
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_when),
    );
    if (picked == null || !mounted) return;
    setState(
      () => _when = DateTime(
        _when.year,
        _when.month,
        _when.day,
        picked.hour,
        picked.minute,
      ),
    );
  }

  Future<void> _save() async {
    final amount = _parseAmount();
    if (amount == null) {
      setState(() => _error = 'Enter a valid amount.');
      return;
    }
    if (amount <= 0) {
      setState(() => _error = 'Amount must be greater than zero.');
      return;
    }
    final amountMl = _unit.toMl(amount);

    if (amountMl > kLargeEntryWarningMl) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.cardStart,
          title: const Text(
            'That\'s a large amount',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Log ${_unit.fromMl(amountMl).toStringAsFixed(_unit == WaterUnit.ml ? 0 : 1)} ${_unit.label} in one entry?',
            style: AppTextStyles.subtitle,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Log it'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    if (!mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final label = _labelController.text.trim();
    final saved = await ref
        .read(waterControllerProvider.notifier)
        .addEntry(
          amountMl,
          label: label.isEmpty ? null : label,
          clientId: 'custom_${_when.microsecondsSinceEpoch}',
        );

    if (!mounted) return;
    if (saved == null) {
      setState(() {
        _saving = false;
        _error = 'Could not save. Please try again.';
      });
      return;
    }
    SemanticsService.sendAnnouncement(
      View.of(context),
      'Added ${_unit.fromMl(amountMl).toStringAsFixed(0)} ${_unit.label} of water',
      TextDirection.ltr,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.cardStart, AppColors.bgBottom],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.fromBorderSide(
            BorderSide(color: AppColors.cardBorder),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add Water',
              style: AppTextStyles.screenTitle.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    label: 'Amount',
                    textField: true,
                    child: TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: AppTextStyles.subtitle.copyWith(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Amount',
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
                  ),
                ),
                const SizedBox(width: 10),
                _UnitToggle(
                  unit: _unit,
                  onChanged: (u) => setState(() => _unit = u),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _PickerField(
                    label: '${_when.month}/${_when.day}/${_when.year}',
                    icon: Icons.calendar_today,
                    semanticLabel: 'Date',
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PickerField(
                    label: TimeOfDay.fromDateTime(_when).format(context),
                    icon: Icons.access_time,
                    semanticLabel: 'Time',
                    onTap: _pickTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Semantics(
              label: 'Optional label',
              textField: true,
              child: TextField(
                controller: _labelController,
                style: AppTextStyles.subtitle.copyWith(
                  fontSize: 14,
                  color: Colors.white,
                ),
                decoration: InputDecoration(
                  hintText: 'Label (optional) — e.g. "with lunch"',
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
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.cardBorder),
                      ),
                      child: Text(
                        'Cancel',
                        style: AppTextStyles.captionBold.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: Material(
                      color: AppColors.blue,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _saving ? null : _save,
                        child: Center(
                          child: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF0A0B1E),
                                  ),
                                )
                              : const Text(
                                  'Save',
                                  style: TextStyle(
                                    color: Color(0xFF0A0B1E),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UnitToggle extends StatelessWidget {
  const _UnitToggle({required this.unit, required this.onChanged});
  final WaterUnit unit;
  final ValueChanged<WaterUnit> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final u in WaterUnit.values)
            Semantics(
              button: true,
              selected: unit == u,
              label: u.label,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onChanged(u),
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 42,
                  ),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: unit == u ? AppColors.blue : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    u.label,
                    style: AppTextStyles.captionBold.copyWith(
                      fontSize: 12,
                      color: unit == u
                          ? const Color(0xFF0A0B1E)
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      value: label,
      child: Material(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: AppTextStyles.subtitle.copyWith(
                    fontSize: 13,
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
