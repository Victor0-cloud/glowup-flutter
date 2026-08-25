import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../models/coach_models.dart';

/// A 23f plan row (368:2752) — colored left bar, title/subtitle, status
/// badge. Colors come from [CoachPlanItem.colorHex] (see its doc comment).
class PlanCardRow extends StatelessWidget {
  const PlanCardRow({super.key, required this.item, this.onTap});

  final CoachPlanItem item;

  /// Real navigation for rows that have a live entry point elsewhere in the
  /// app (currently just Hydration -> Water Tracker). Null for every other
  /// row, which stays exactly as non-interactive as before.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(item.colorHex);
    final content = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.cardStart, AppColors.cardEnd],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: AppTextStyles.cardTitle.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.subtitle,
                  style: AppTextStyles.subtitle.copyWith(fontSize: 14),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              item.badgeLabel,
              style: AppTextStyles.captionBold.copyWith(
                fontSize: 11,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Semantics(
          button: true,
          label: '${item.title}, view in Water Tracker',
          child: content,
        ),
      ),
    );
  }
}

/// 23g's Week/Month/Year filter tab (368:2815).
class MoodFilterTab extends StatelessWidget {
  const MoodFilterTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: selected ? AppColors.purple : const Color(0xFF181436),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.cardBorder),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: AppTextStyles.captionBold.copyWith(
                fontSize: 13,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One "Daily Emotions" day cell (368:2853).
class MoodDayBox extends StatelessWidget {
  const MoodDayBox({super.key, required this.entry});

  final MoodDayEntry entry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${entry.day}',
          style: AppTextStyles.caption.copyWith(
            fontSize: 11,
            color: AppColors.textSecondary.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: entry.dimmed
                ? Colors.white.withValues(alpha: 0.05)
                : const Color(0xFF181436),
            borderRadius: BorderRadius.circular(18),
          ),
          alignment: Alignment.center,
          child: Text(entry.emoji, style: const TextStyle(fontSize: 18)),
        ),
      ],
    );
  }
}

/// A "Best Day" / "Common" stat card (368:2882).
class MoodStatCard extends StatelessWidget {
  const MoodStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.cardStart, AppColors.cardEnd],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: AppTextStyles.captionBold.copyWith(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                fontFamily: AppTextStyles.cardTitle.fontFamily,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
