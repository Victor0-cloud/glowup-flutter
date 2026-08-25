import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_icon.dart';
import '../models/today_models.dart';

/// 368:929 "Up-Next-Container". Border color is the per-variant accent.
class UpNextCard extends StatelessWidget {
  const UpNextCard({
    super.key,
    required this.plan,
    required this.accent,
    required this.onTap,
  });

  final DailyPlan plan;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'UP NEXT',
            style: AppTextStyles.captionBold.copyWith(
              color: AppColors.textSecondary,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          Semantics(
            button: true,
            label: '${plan.title}. ${plan.subtitle}',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.cardStart, AppColors.cardEnd],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: accent),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.cardEnd,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: AppIcon('clock', size: 20, color: accent),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(plan.title, style: AppTextStyles.cardTitleLg),
                            const SizedBox(height: 4),
                            Text(
                              plan.subtitle,
                              style: AppTextStyles.cardSubtitleMd,
                            ),
                          ],
                        ),
                      ),
                    ],
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
