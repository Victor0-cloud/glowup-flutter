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

/// Connects "View History" to a real surface: daily totals, weekly
/// totals, previous dates, goal completion, and an honest empty state —
/// all computed from the same durable [WaterState] the main tracker
/// screen already reads, never a second/duplicate data source.
class WaterHistoryScreen extends ConsumerWidget {
  const WaterHistoryScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              title: 'Water History',
              subtitle: 'Your hydration over time',
              onBack: onBack ?? () => Navigator.maybePop(context),
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
                      "Couldn't load your history. Please restart the app.",
                      style: AppTextStyles.subtitle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                data: (state) => _HistoryBody(state: state, variant: variant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryBody extends StatelessWidget {
  const _HistoryBody({required this.state, required this.variant});
  final WaterState state;
  final WaterVariantConfig variant;

  @override
  Widget build(BuildContext context) {
    final dates = state.loggedDates;

    if (dates.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.water_drop_outlined,
                size: 36,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 12),
              Text('No history yet', style: AppTextStyles.cardTitle),
              const SizedBox(height: 6),
              Text(
                'Log your first glass of water to start building your history.',
                style: AppTextStyles.subtitle,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final unit = state.unit;
    final weekMet = dates
        .take(7)
        .where((d) => state.totalOn(d) >= state.goalMl)
        .length;
    final weekDays = dates.length < 7 ? dates.length : 7;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlowCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'This Week',
                        style: AppTextStyles.captionBold.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$weekMet of $weekDays days on goal',
                        style: AppTextStyles.cardTitle,
                      ),
                    ],
                  ),
                ),
                Text(
                  '${state.weeklyCompletionPercent.round()}%',
                  style: TextStyle(
                    color: variant.accent,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Daily Totals',
            style: AppTextStyles.captionBold.copyWith(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          for (final date in dates) ...[
            _DayRow(
              date: date,
              totalMl: state.totalOn(date),
              goalMl: state.goalMl,
              unit: unit,
              accent: variant.accent,
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.date,
    required this.totalMl,
    required this.goalMl,
    required this.unit,
    required this.accent,
  });

  final DateTime date;
  final double totalMl;
  final double goalMl;
  final WaterUnit unit;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final met = goalMl > 0 && totalMl >= goalMl;
    final total = unit.fromMl(totalMl);
    final totalLabel = total == total.roundToDouble()
        ? total.toStringAsFixed(0)
        : total.toStringAsFixed(1);
    return GlowCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle_outline : Icons.circle_outlined,
            size: 18,
            color: met ? accent : AppColors.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_fullDate(date), style: AppTextStyles.cardTitle),
          ),
          Text(
            '$totalLabel ${unit.label}',
            style: AppTextStyles.cardSubtitleMd.copyWith(color: Colors.white),
          ),
        ],
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
    final today = DateTime.now();
    if (d.year == today.year && d.month == today.month && d.day == today.day)
      return 'Today';
    final yesterday = today.subtract(const Duration(days: 1));
    if (d.year == yesterday.year &&
        d.month == yesterday.month &&
        d.day == yesterday.day)
      return 'Yesterday';
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}
