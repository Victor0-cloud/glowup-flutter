import 'package:flutter/material.dart';

import '../../brain/recommendations/typed_action.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glow_card.dart';

/// The one live surface for a stored Tier 2 [CoachRecommendation]: a
/// grounded, template-sourced (Tier 3) explanation shown before starting a
/// workout that has an active safety flag or pattern for one of its
/// exercises. Purely advisory — this never blocks "Start Workout" itself
/// (per the Bluebook: "may recommend stopping... never force"); it only
/// records what the user did with the advisory (accepted/dismissed) as a
/// new traceable event.
class AdaptiveAdvisoryCard extends StatelessWidget {
  const AdaptiveAdvisoryCard({
    super.key,
    required this.safetyDecision,
    required this.explanation,
    required this.onAccept,
    required this.onDismiss,
  });

  final SafetyDecision safetyDecision;
  final String explanation;
  final VoidCallback onAccept;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final isPause = safetyDecision == SafetyDecision.pause;
    final accent = isPause ? AppColors.orange : AppColors.gold;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GlowCard(
        borderColor: isPause ? AppColors.orange.withValues(alpha: 0.4) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isPause ? Icons.pause_circle_outline : Icons.info_outline,
                  size: 16,
                  color: accent,
                ),
                const SizedBox(width: 6),
                Text(
                  'AI COACH',
                  style: AppTextStyles.captionBold.copyWith(
                    color: accent,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              explanation,
              style: AppTextStyles.subtitle.copyWith(fontSize: 14),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                TextButton(
                  onPressed: onDismiss,
                  child: Text(
                    'Dismiss',
                    style: AppTextStyles.captionBold.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
                const Spacer(),
                Material(
                  color: accent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: onAccept,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      child: Text(
                        'Got It',
                        style: TextStyle(
                          color: Color(0xFF0A0B1E),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
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
