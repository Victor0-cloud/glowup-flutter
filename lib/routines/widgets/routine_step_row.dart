import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_icon.dart';
import '../models/routine_models.dart';

/// 368:1990 "Step-Card". Completed steps get an accent border + filled
/// checkbox; incomplete steps get the standard faint border + outline
/// checkbox — exactly as shown for Morning Wellness's 5 steps.
class RoutineStepRow extends StatelessWidget {
  const RoutineStepRow({
    super.key,
    required this.index,
    required this.activity,
    required this.done,
    required this.accent,
    required this.onToggle,
  });

  final int index;
  final RoutineActivity activity;
  final bool done;
  final Color accent;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label:
          '${activity.title}, ${activity.durationMinutes} min, ${done ? 'completed' : 'not completed'}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onToggle,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.cardStart, AppColors.cardEnd],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: done ? accent : AppColors.cardBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: done
                        ? accent.withValues(alpha: 0.13)
                        : Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      '$index',
                      style: TextStyle(
                        color: done ? accent : Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        fontFamily: AppTextStyles.cardTitle.fontFamily,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(activity.emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(activity.title, style: AppTextStyles.cardTitle),
                      Text(
                        '${activity.durationMinutes} min',
                        style: AppTextStyles.cardSubtitle,
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: done ? accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: done
                        ? null
                        : Border.all(color: AppColors.textSecondary, width: 2),
                  ),
                  child: done
                      ? const Center(
                          child: AppIcon(
                            'check',
                            size: 12,
                            color: AppColors.onSelected,
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
