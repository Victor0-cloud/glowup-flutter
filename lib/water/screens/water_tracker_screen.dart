import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/tod/tod_period.dart';
import '../../core/widgets/dev_tod_picker.dart';
import '../../core/widgets/glow_card.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/sub_screen_header.dart';
import '../models/water_entry.dart';
import '../state/water_controller.dart';
import '../theme/water_variant_config.dart';
import '../widgets/water_bottle_level.dart';
import '../widgets/water_custom_entry_sheet.dart';
import '../widgets/water_progress_ring.dart';

const _quickAddAmountsMl = [250.0, 500.0, 750.0, 1000.0];

class WaterTrackerScreen extends ConsumerStatefulWidget {
  const WaterTrackerScreen({super.key, this.onBack, this.onViewHistory});

  final VoidCallback? onBack;
  final VoidCallback? onViewHistory;

  @override
  ConsumerState<WaterTrackerScreen> createState() => _WaterTrackerScreenState();
}

class _WaterTrackerScreenState extends ConsumerState<WaterTrackerScreen> {
  bool _editingGoal = false;
  final _goalController = TextEditingController();
  DateTime? _lastQuickAddAt;
  double? _lastQuickAddAmount;

  @override
  void dispose() {
    _goalController.dispose();
    super.dispose();
  }

  /// Guards against a rapid *accidental* double-fire of the same quick-add
  /// button (e.g. a stray double-tap event) while still allowing a
  /// genuine intentional repeat of the same amount a moment later — the
  /// spec's "prevent duplicate entries... while still allowing intentional
  /// repeated additions". A real second tap more than [_debounce] apart is
  /// always honored.
  static const _debounce = Duration(milliseconds: 600);

  Future<void> _quickAdd(double amountMl) async {
    final now = DateTime.now();
    if (_lastQuickAddAmount == amountMl &&
        _lastQuickAddAt != null &&
        now.difference(_lastQuickAddAt!) < _debounce) {
      return;
    }
    _lastQuickAddAmount = amountMl;
    _lastQuickAddAt = now;
    await ref.read(waterControllerProvider.notifier).addEntry(amountMl);
  }

  Future<void> _delete(WaterEntry entry) async {
    final controller = ref.read(waterControllerProvider.notifier);
    final removed = await controller.removeEntry(entry.id);
    if (removed == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Entry removed'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => controller.restoreEntry(removed),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final waterState = ref.watch(waterControllerProvider);
    final period = ref.watch(currentTodPeriodProvider);
    final variant = WaterVariantConfig.byPeriod[period]!;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: Column(
          children: [
            if (kDebugMode) const DevTodPicker(),
            SubScreenHeader(
              title: 'Water Tracker',
              subtitle: 'Stay hydrated, stay glowing!',
              onBack: widget.onBack ?? () => Navigator.maybePop(context),
            ),
            Expanded(
              child: waterState.when(
                loading: () => Center(
                  child: CircularProgressIndicator(color: variant.accent),
                ),
                error: (err, st) => Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      "Couldn't load your water log. Please restart the app.",
                      style: AppTextStyles.subtitle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                data: (data) => _WaterTrackerBody(
                  state: data,
                  variant: variant,
                  editingGoal: _editingGoal,
                  goalController: _goalController,
                  onStartEditGoal: () {
                    final g = data.unit.fromMl(data.goalMl);
                    _goalController.text = g == g.roundToDouble()
                        ? g.toStringAsFixed(0)
                        : g.toStringAsFixed(1);
                    setState(() => _editingGoal = true);
                  },
                  onCancelEditGoal: () => setState(() => _editingGoal = false),
                  onSaveGoal: () async {
                    final value = double.tryParse(_goalController.text.trim());
                    if (value != null && value > 0) {
                      await ref
                          .read(waterControllerProvider.notifier)
                          .updateGoal(data.unit.toMl(value));
                    }
                    if (mounted) setState(() => _editingGoal = false);
                  },
                  onUnitChanged: (u) =>
                      ref.read(waterControllerProvider.notifier).updateUnit(u),
                  onQuickAdd: _quickAdd,
                  onAddWater: () => showWaterCustomEntrySheet(
                    context,
                    ref,
                    initialUnit: data.unit,
                  ),
                  onRemove: _delete,
                  onViewHistory: widget.onViewHistory,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaterTrackerBody extends StatelessWidget {
  const _WaterTrackerBody({
    required this.state,
    required this.variant,
    required this.editingGoal,
    required this.goalController,
    required this.onStartEditGoal,
    required this.onCancelEditGoal,
    required this.onSaveGoal,
    required this.onUnitChanged,
    required this.onQuickAdd,
    required this.onAddWater,
    required this.onRemove,
    required this.onViewHistory,
  });

  final WaterState state;
  final WaterVariantConfig variant;
  final bool editingGoal;
  final TextEditingController goalController;
  final VoidCallback onStartEditGoal;
  final VoidCallback onCancelEditGoal;
  final VoidCallback onSaveGoal;
  final ValueChanged<WaterUnit> onUnitChanged;
  final ValueChanged<double> onQuickAdd;
  final VoidCallback onAddWater;
  final ValueChanged<WaterEntry> onRemove;
  final VoidCallback? onViewHistory;

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final unit = state.unit;
    final todayEntries = state.todayEntries;
    final average = state.averageDailyMl;
    final best = state.bestDay;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today\'s Goal',
            style: AppTextStyles.captionBold.copyWith(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                WaterProgressRing(
                  consumedMl: state.todayTotal,
                  goalMl: state.goalMl,
                  unit: unit,
                  gradientColors: variant.ringGradient,
                  accentColor: variant.accent,
                ),
                const SizedBox(width: 16),
                WaterBottleLevel(progress: state.progress),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatChip(
                  label: 'Remaining',
                  value:
                      '${_fmt(unit.fromMl(state.remainingMl))} ${unit.label}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatChip(
                  label: 'Avg / day',
                  value: average == null
                      ? '—'
                      : '${_fmt(unit.fromMl(average))} ${unit.label}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatChip(
                  label: 'Streak',
                  value:
                      '${state.currentStreak} day${state.currentStreak == 1 ? '' : 's'}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Text(
            'Quick Add',
            style: AppTextStyles.captionBold.copyWith(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final amount in _quickAddAmountsMl)
                _QuickAddChip(
                  label: _quickAddLabel(amount),
                  accent: variant.accent,
                  icon: _quickAddIcon(amount),
                  onTap: () => onQuickAdd(amount),
                ),
              _QuickAddChip(
                label: 'Custom',
                accent: variant.accent,
                icon: Icons.edit_outlined,
                onTap: onAddWater,
              ),
            ],
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: Semantics(
              button: true,
              label: 'Add Water',
              child: Material(
                color: WaterColors.brandBlue,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: onAddWater,
                  child: const Center(
                    child: Text(
                      'Add Water',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Today's Log",
                style: AppTextStyles.captionBold.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              if (onViewHistory != null)
                Semantics(
                  button: true,
                  label: 'View History',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: onViewHistory,
                    child: Container(
                      constraints: const BoxConstraints(
                        minHeight: 44,
                        minWidth: 44,
                      ),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        'View History',
                        style: AppTextStyles.captionBold.copyWith(
                          color: variant.accent,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (todayEntries.isEmpty)
            GlowCard(
              child: Text(
                'No water logged yet today — add your first entry above.',
                style: AppTextStyles.subtitle,
              ),
            )
          else
            for (final entry in todayEntries) ...[
              _WaterEntryRow(
                entry: entry,
                unit: unit,
                onRemove: () => onRemove(entry),
              ),
              const SizedBox(height: 8),
            ],
          const SizedBox(height: 24),

          Text(
            'Hydration Insights',
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
                _InsightRow(
                  label: 'Daily average',
                  value: average == null
                      ? 'Not enough data yet'
                      : '${_fmt(unit.fromMl(average))} ${unit.label}',
                ),
                const SizedBox(height: 10),
                _InsightRow(
                  label: 'Best day',
                  value: best == null
                      ? 'Not enough data yet'
                      : '${_fmt(unit.fromMl(best.totalMl))} ${unit.label} (${_shortDate(best.date)})',
                ),
                const SizedBox(height: 10),
                _InsightRow(
                  label: 'Days goal achieved',
                  value: state.loggedDates.isEmpty
                      ? 'Not enough data yet'
                      : '${state.daysGoalAchieved} of ${state.loggedDates.length}',
                ),
                const SizedBox(height: 10),
                _InsightRow(
                  label: 'This week',
                  value:
                      '${state.weeklyCompletionPercent.round()}% of days on goal',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'Daily Goal',
            style: AppTextStyles.captionBold.copyWith(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          GlowCard(
            child: Row(
              children: [
                Expanded(
                  child: editingGoal
                      ? Text(
                          'Set your own daily target — not medical advice.',
                          style: AppTextStyles.caption.copyWith(fontSize: 12),
                        )
                      : Text(
                          '${_fmt(unit.fromMl(state.goalMl))} ${unit.label} / day',
                          style: AppTextStyles.cardTitle,
                        ),
                ),
                if (editingGoal) ...[
                  SizedBox(
                    width: 70,
                    child: TextField(
                      controller: goalController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: AppTextStyles.fieldValue.copyWith(
                        color: Colors.white,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.check, color: variant.accent),
                    onPressed: onSaveGoal,
                    tooltip: 'Save goal',
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: onCancelEditGoal,
                    tooltip: 'Cancel',
                  ),
                ] else ...[
                  _UnitSwitch(unit: unit, onChanged: onUnitChanged),
                  IconButton(
                    icon: const Icon(
                      Icons.edit,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: onStartEditGoal,
                    tooltip: 'Edit goal',
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _quickAddLabel(double ml) => ml >= 1000
      ? '${(ml / 1000).toStringAsFixed(ml % 1000 == 0 ? 0 : 1)} L'
      : '${ml.toStringAsFixed(0)} ml';

  /// Simple outlined icons distinguishing each quick-add amount, matching
  /// the approved reference's per-amount iconography (cup/glass/bottle)
  /// without departing from this app's flat/outlined icon language.
  static IconData _quickAddIcon(double ml) {
    if (ml <= 250) return Icons.local_cafe_outlined;
    if (ml <= 500) return Icons.local_drink_outlined;
    if (ml <= 750) return Icons.sports_bar_outlined;
    return Icons.water_drop_outlined;
  }

  static String _shortDate(DateTime d) {
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
    return '${months[d.month - 1]} ${d.day}';
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return GlowCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption.copyWith(fontSize: 11)),
          const SizedBox(height: 4),
          Text(value, style: AppTextStyles.cardTitle),
        ],
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.subtitle.copyWith(fontSize: 13),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            style: AppTextStyles.cardSubtitleMd.copyWith(color: Colors.white),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _QuickAddChip extends StatelessWidget {
  const _QuickAddChip({
    required this.label,
    required this.accent,
    required this.onTap,
    this.icon = Icons.add,
  });
  final String label;
  final Color accent;
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Add $label of water',
      child: Material(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(100),
        child: InkWell(
          borderRadius: BorderRadius.circular(100),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: accent),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: AppTextStyles.caption.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UnitSwitch extends StatelessWidget {
  const _UnitSwitch({required this.unit, required this.onChanged});
  final WaterUnit unit;
  final ValueChanged<WaterUnit> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Toggle unit, currently ${unit.label}',
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () =>
            onChanged(unit == WaterUnit.ml ? WaterUnit.flOz : WaterUnit.ml),
        child: Container(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 32),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            unit.label,
            style: AppTextStyles.caption.copyWith(fontSize: 12),
          ),
        ),
      ),
    );
  }
}

class _WaterEntryRow extends StatelessWidget {
  const _WaterEntryRow({
    required this.entry,
    required this.unit,
    required this.onRemove,
  });

  final WaterEntry entry;
  final WaterUnit unit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final amount = unit.fromMl(entry.amountMl);
    final label = amount == amount.roundToDouble()
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(1);
    return GlowCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(
            Icons.water_drop_outlined,
            size: 18,
            color: WaterColors.brandBlue,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$label ${unit.label}', style: AppTextStyles.cardTitle),
                if (entry.label != null && entry.label!.isNotEmpty)
                  Text(entry.label!, style: AppTextStyles.cardSubtitle),
              ],
            ),
          ),
          Text(_formatTime(entry.at), style: AppTextStyles.cardSubtitle),
          Semantics(
            button: true,
            label: 'Remove entry',
            child: IconButton(
              icon: const Icon(
                Icons.close,
                size: 16,
                color: AppColors.textSecondary,
              ),
              onPressed: onRemove,
              tooltip: 'Remove entry',
            ),
          ),
        ],
      ),
    );
  }
}

String _formatTime(DateTime dt) {
  final hour24 = dt.hour;
  final period = hour24 >= 12 ? 'PM' : 'AM';
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  return '$hour12:$minute $period';
}
