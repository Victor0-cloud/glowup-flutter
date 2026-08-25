import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// 23b's "Today's Target" bar (368:2406). Percent is hardcoded to match
/// the approved frame exactly, same as Today's Glow Score placeholder —
/// real progress needs a scoring engine that doesn't exist yet.
class TodaysTargetWidget extends StatelessWidget {
  const TodaysTargetWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.cardStart, AppColors.cardEnd],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "Today's Target",
                  style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
                ),
              ),
              Text(
                '60% Complete',
                style: AppTextStyles.captionBold.copyWith(
                  color: AppColors.ctaStart,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 8,
              color: const Color(0xFF181436),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: 0.6,
                child: Container(color: AppColors.ctaStart),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 23d's "Sleep Target: 8h" card (368:2587).
class SleepTargetWidget extends StatelessWidget {
  const SleepTargetWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
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
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.purple.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(24),
            ),
            alignment: Alignment.center,
            child: const Text('💤', style: TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sleep Target: 8h',
                  style: AppTextStyles.cardTitle.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  'Wake up set for 6:30 AM',
                  style: AppTextStyles.caption.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
