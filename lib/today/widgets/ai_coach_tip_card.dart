import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/glow_card.dart';
import '../models/today_models.dart';

/// 368:955 "AI-Coach-Tip". Purple branding stays constant across all 4
/// variants (confirmed identical in every captured frame) — this card is
/// the Brain speaking, not part of the TOD accent system.
class AiCoachTipCard extends StatelessWidget {
  const AiCoachTipCard({super.key, required this.insight, required this.onTap});

  final BrainInsight insight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GlowCard(
        borderColor: AppColors.cardBorder,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AppColors.purple.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: AppIcon(
                      'sparkles',
                      size: 14,
                      color: AppColors.lavenderAccent,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'AI COACH TIP',
                  style: AppTextStyles.captionBold.copyWith(
                    color: AppColors.lavenderAccent,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '"${insight.message}"',
              style: AppTextStyles.cardSubtitleMd.copyWith(
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
