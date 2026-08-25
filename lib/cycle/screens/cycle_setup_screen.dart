import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../coach/widgets/settings_widgets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glow_card.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/gradient_pill_button.dart';
import '../../core/widgets/sub_screen_header.dart';
import '../models/cycle_models.dart';
import '../state/cycle_controller.dart';

/// PC02 Cycle Setup — last period start date (optional) and typical
/// cycle/period lengths (optional, 15-60 / 1-15 per the approved data
/// contract). Nothing here is required; "Skip details for now" enables
/// tracking with no numbers at all.
class CycleSetupScreen extends ConsumerStatefulWidget {
  const CycleSetupScreen({super.key, this.onBack, this.onSaved});

  final VoidCallback? onBack;
  final VoidCallback? onSaved;

  @override
  ConsumerState<CycleSetupScreen> createState() => _CycleSetupScreenState();
}

class _CycleSetupScreenState extends ConsumerState<CycleSetupScreen> {
  DateTime? _lastPeriodStart;
  int _typicalCycleDays = 28;
  int _typicalPeriodDays = 5;
  bool _cycleAwareSuggestions = true;
  bool _saving = false;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _lastPeriodStart ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    if (picked == null || !mounted) return;
    setState(() => _lastPeriodStart = picked);
  }

  Future<void> _save({required bool skip}) async {
    setState(() => _saving = true);
    final controller = ref.read(cycleControllerProvider.notifier);
    final current =
        ref.read(cycleControllerProvider).valueOrNull?.settings ??
        const CycleSettings();
    await controller.updateSettings(
      current.copyWith(
        trackingEnabled: true,
        typicalCycleDays: skip ? null : _typicalCycleDays,
        typicalPeriodDays: skip ? null : _typicalPeriodDays,
        cycleAwareSuggestions: _cycleAwareSuggestions,
      ),
    );
    if (!skip && _lastPeriodStart != null) {
      await controller.logPeriodStart(_lastPeriodStart!);
    }
    if (!mounted) return;
    setState(() => _saving = false);
    widget.onSaved?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: Column(
          children: [
            SubScreenHeader(
              title: 'Cycle Setup',
              subtitle: 'Add what you know. You can skip uncertain details.',
              onBack: widget.onBack ?? () => Navigator.maybePop(context),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'When did your last period start?',
                      style: AppTextStyles.cardTitleLg.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    Semantics(
                      button: true,
                      label: 'Last period start date',
                      value: _lastPeriodStart == null
                          ? 'Not set'
                          : _fullDate(_lastPeriodStart!),
                      child: Material(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: _pickDate,
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 52),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.water_drop,
                                  size: 18,
                                  color: AppColors.ctaStart,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _lastPeriodStart == null
                                        ? 'Not set'
                                        : _fullDate(_lastPeriodStart!),
                                    style: AppTextStyles.cardTitle.copyWith(
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  size: 18,
                                  color: AppColors.textSecondary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _Stepper(
                            label: 'Typical cycle length',
                            value: _typicalCycleDays,
                            min: 15,
                            max: 60,
                            onChanged: (v) =>
                                setState(() => _typicalCycleDays = v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _Stepper(
                            label: 'Typical period length',
                            value: _typicalPeriodDays,
                            min: 1,
                            max: 15,
                            onChanged: (v) =>
                                setState(() => _typicalPeriodDays = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ToggleRow(
                      label: 'Cycle-aware suggestions',
                      value: _cycleAwareSuggestions,
                      onChanged: (v) =>
                          setState(() => _cycleAwareSuggestions = v),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.blue.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 18,
                            color: AppColors.blue,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Estimates improve as you log. They are not contraception or medical advice.',
                              style: AppTextStyles.subtitle.copyWith(
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    GradientPillButton(
                      label: 'Save and continue',
                      onPressed: _saving ? null : () => _save(skip: false),
                      loading: _saving,
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Semantics(
                        button: true,
                        label: 'Skip details for now',
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _saving ? null : () => _save(skip: true),
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 44),
                              alignment: Alignment.center,
                              child: Text(
                                'Skip details for now',
                                style: AppTextStyles.captionBold.copyWith(
                                  color: AppColors.purple,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.subtitle.copyWith(fontSize: 13)),
        const SizedBox(height: 8),
        GlowCard(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          child: Column(
            children: [
              Row(
                children: [
                  Semantics(
                    button: true,
                    label: 'Decrease $label',
                    child: IconButton(
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      iconSize: 20,
                      padding: EdgeInsets.zero,
                      onPressed: value > min
                          ? () => onChanged(value - 1)
                          : null,
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '$value',
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.screenTitle.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Increase $label',
                    child: IconButton(
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      iconSize: 20,
                      padding: EdgeInsets.zero,
                      onPressed: value < max
                          ? () => onChanged(value + 1)
                          : null,
                      icon: const Icon(
                        Icons.add_circle_outline,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              Text('days', style: AppTextStyles.caption),
            ],
          ),
        ),
      ],
    );
  }
}
