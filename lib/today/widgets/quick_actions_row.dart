import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_icon.dart';
import '../models/today_models.dart';

class _ActionSpec {
  const _ActionSpec(this.type, this.icon, this.label);
  final QuickActionType type;
  final String icon;
  final String label;
}

const _actions = [
  _ActionSpec(QuickActionType.workout, 'dumbbell', 'Workout'),
  _ActionSpec(QuickActionType.water, 'droplet', 'Water'),
  _ActionSpec(QuickActionType.mood, 'smile', 'Mood'),
  _ActionSpec(QuickActionType.journal, 'book-open', 'Journal'),
];

/// 368:912 "Quick-Actions-Container". Icons take the variant accent color —
/// confirmed by diffing the exported dumbbell/droplet icons across all 4
/// Today frames (gold on morning, muted on night, etc).
class QuickActionsRow extends StatelessWidget {
  const QuickActionsRow({
    super.key,
    required this.accent,
    required this.onSelect,
  });

  final Color accent;
  final ValueChanged<QuickActionType> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          for (final a in _actions)
            Expanded(
              child: Semantics(
                button: true,
                label: a.label,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(28),
                    onTap: () => onSelect(a.type),
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.cardEnd,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: AppColors.cardBorder),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x40000000),
                                blurRadius: 4,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: AppIcon(a.icon, size: 24, color: accent),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(a.label, style: AppTextStyles.caption),
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
