import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/sub_screen_header.dart';
import '../models/routine_models.dart';

/// 368:1637 "Routine-Card". The featured (streak) card gets a solid accent
/// border; others use the standard faint card border — exactly as shown
/// on every 22a-22d hub frame.
class RoutineCard extends StatelessWidget {
  const RoutineCard({
    super.key,
    required this.routine,
    required this.accent,
    required this.onTap,
  });

  final Routine routine;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label:
          '${routine.title}, ${routine.schedule.formattedTime}, ${routine.activities.length} steps'
          '${routine.hasStreak ? ', ${routine.streakDays} day streak' : ''}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.cardStart, AppColors.cardEnd],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: routine.hasStreak ? accent : AppColors.cardBorder,
              ),
            ),
            child: Row(
              children: [
                RoutineBadge(highlighted: routine.hasStreak),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              routine.title,
                              style: AppTextStyles.cardTitleLg,
                            ),
                          ),
                          Text(
                            routine.schedule.formattedTime,
                            style: AppTextStyles.cardSubtitle,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '${routine.activities.length} steps',
                            style: AppTextStyles.cardSubtitle,
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              color: AppColors.textSecondary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: routine.hasStreak
                                  ? accent.withValues(alpha: 0.13)
                                  : Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              routine.hasStreak
                                  ? '${routine.streakDays} days'
                                  : 'No streak',
                              style: TextStyle(
                                color: routine.hasStreak
                                    ? accent
                                    : AppColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                fontFamily:
                                    AppTextStyles.captionBold.fontFamily,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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
