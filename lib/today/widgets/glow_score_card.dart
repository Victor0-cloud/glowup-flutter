import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glow_score_ring.dart';
import '../models/today_models.dart';

/// 368:902 "Glow-Score-Card".
class GlowScoreCard extends StatelessWidget {
  const GlowScoreCard({
    super.key,
    required this.summary,
    required this.ringGradient,
    required this.onTap,
  });

  final GlowScoreSummary summary;
  final List<Color> ringGradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Semantics(
        button: true,
        label: 'Glow Score ${summary.score}. ${summary.message}',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.cardStart, AppColors.cardEnd],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                children: [
                  GlowScoreRing(
                    score: summary.score,
                    gradientColors: ringGradient,
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Glow Score',
                          style: AppTextStyles.screenTitle.copyWith(
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          summary.message,
                          style: AppTextStyles.cardSubtitleMd.copyWith(
                            height: 1.4,
                          ),
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
    );
  }
}
