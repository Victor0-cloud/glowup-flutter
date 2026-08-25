import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../models/routine_models.dart';

/// 368:2082 "Icon-Grid" — the 8 emoji choices Figma shows for a new
/// routine's icon. Rendered as literal emoji (as Figma itself does here),
/// not SVG assets.
const kRoutineEmojiChoices = [
  '🧘‍♀️',
  '💧',
  '🧠',
  '✨',
  '🏋️‍♀️',
  '🍎',
  '📝',
  '🚶‍♀️',
];

class RoutineIconPicker extends StatelessWidget {
  const RoutineIconPicker({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.accent,
  });

  final String selected;
  final ValueChanged<String> onSelected;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final emoji in kRoutineEmojiChoices)
          Semantics(
            button: true,
            selected: emoji == selected,
            label: 'Icon $emoji',
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onSelected(emoji),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: emoji == selected ? accent : null,
                    gradient: emoji == selected
                        ? null
                        : const LinearGradient(
                            colors: [AppColors.cardStart, AppColors.cardEnd],
                          ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  alignment: Alignment.center,
                  child: Text(emoji, style: const TextStyle(fontSize: 20)),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 368:2101 "Theme-Row" — the 4 Color-Ring swatches.
class RoutineColorThemePicker extends StatelessWidget {
  const RoutineColorThemePicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final RoutineColorTheme selected;
  final ValueChanged<RoutineColorTheme> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final theme in RoutineColorTheme.values) ...[
          Semantics(
            button: true,
            selected: theme == selected,
            label: '${theme.name} theme',
            child: GestureDetector(
              onTap: () => onSelected(theme),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.color,
                  border: theme == selected
                      ? Border.all(color: Colors.white, width: 2)
                      : null,
                ),
              ),
            ),
          ),
          if (theme != RoutineColorTheme.values.last) const SizedBox(width: 12),
        ],
      ],
    );
  }
}
