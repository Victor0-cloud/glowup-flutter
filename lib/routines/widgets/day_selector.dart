import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../models/routine_models.dart';

/// 368:2112 "Days-Row" (create screen) — 7 toggleable day bubbles.
class DaySelector extends StatelessWidget {
  const DaySelector({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.accent,
  });

  final Set<Weekday> selected;
  final ValueChanged<Set<Weekday>> onChanged;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final day in Weekday.values)
          _DayBubble(
            label: day.shortLabel,
            selected: selected.contains(day),
            accent: accent,
            onTap: () {
              final next = {...selected};
              if (!next.remove(day)) next.add(day);
              onChanged(next);
            },
          ),
      ],
    );
  }
}

class _DayBubble extends StatelessWidget {
  const _DayBubble({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: selected
                  ? null
                  : const LinearGradient(
                      colors: [AppColors.cardStart, AppColors.cardEnd],
                    ),
              color: selected ? accent : null,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.onSelected : Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
