import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../models/workout_completion_record.dart';

/// Optional selectable feedback chips — fixed vocabulary, never free text,
/// so this can never become a place personal data accidentally leaks into.
const kGenericFeedbackChips = [
  'Form felt unclear',
  'Reduced repetitions',
  'Needed more rest',
  'Used an easier variation',
  'Felt stronger',
  'Helpful',
  'Skip next time',
];

const kPainBodyAreas = [
  'Shoulder',
  'Knee',
  'Back',
  'Neck',
  'Hip',
  'Ankle',
  'Wrist',
  'Other',
];

/// One "how did this feel" choice — the standardized 5-option scale
/// (Easy/Good/Challenging/Too Difficult/Pain or Discomfort) required for
/// *every* exercise, distinct from the specialized [ExerciseReflectionCard]
/// used only for the 4 Sleep Prep exercises' open-ended sensation
/// checklist (that card is untouched — this is an additive, generalized
/// second card).
class _FeelingOption {
  const _FeelingOption(this.value, this.label, this.icon);
  final WorkoutFeeling value;
  final String label;
  final IconData icon;
}

const _feelingOptions = [
  _FeelingOption(WorkoutFeeling.tooEasy, 'Easy', Icons.trending_down),
  _FeelingOption(WorkoutFeeling.justRight, 'Good', Icons.check_circle),
  _FeelingOption(
    WorkoutFeeling.challenging,
    'Challenging',
    Icons.fitness_center,
  ),
  _FeelingOption(WorkoutFeeling.tooHard, 'Too Difficult', Icons.trending_up),
  _FeelingOption(
    WorkoutFeeling.painDiscomfort,
    'Pain or Discomfort',
    Icons.healing,
  ),
];

const _severityOptions = [
  PainSeverity.mild,
  PainSeverity.moderate,
  PainSeverity.severe,
];

const _kNoteMaxLength = 300;

/// The generalized "Tell your Coach how the exercise felt" prompt — shown
/// for every exercise (not gated by a per-exercise config, unlike
/// [ExerciseReflectionCard]). Entirely optional: Skip never blocks the
/// routine player, and this widget never calls an AI provider itself —
/// [onSubmit] hands the caller a plain typed result to forward to
/// `submitExerciseFeedback` (Tier 0/1 only).
class ExerciseFeedbackCard extends StatefulWidget {
  const ExerciseFeedbackCard({
    super.key,
    required this.onSubmit,
    required this.onSkip,
  });

  final void Function(
    WorkoutFeeling feeling,
    List<String> chips,
    String? note,
    PainDetails? painDetails,
  )
  onSubmit;
  final VoidCallback onSkip;

  @override
  State<ExerciseFeedbackCard> createState() => _ExerciseFeedbackCardState();
}

class _ExerciseFeedbackCardState extends State<ExerciseFeedbackCard> {
  WorkoutFeeling? _feeling;
  final Set<String> _selectedChips = {};
  String? _bodyArea;
  PainSeverity? _severity;
  final _noteController = TextEditingController();
  bool _saved = false;
  bool _skipped = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_feeling == null) return;
    final painDetails = _feeling == WorkoutFeeling.painDiscomfort
        ? PainDetails(bodyArea: _bodyArea, severity: _severity)
        : null;
    final note = _noteController.text.trim();
    widget.onSubmit(
      _feeling!,
      _selectedChips.toList(),
      note.isEmpty ? null : note,
      painDetails,
    );
    setState(() => _saved = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_skipped) return const SizedBox.shrink();
    final showPainFollowUp = _feeling == WorkoutFeeling.painDiscomfort;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.cardStart, AppColors.cardEnd],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Deliberately not "AI COACH" (the label `ExerciseReflectionCard`
          // already uses) — both cards can render together in REST for the
          // 4 specialized exercises, and a duplicate caption text would
          // make `find.text('AI COACH')` ambiguous in existing, protected
          // widget tests for that card.
          Text(
            'COACH FEEDBACK',
            style: AppTextStyles.captionBold.copyWith(
              color: AppColors.gold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'How did this exercise feel?',
            style: AppTextStyles.subtitle.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in _feelingOptions)
                _Chip(
                  label: option.label,
                  icon: option.icon,
                  selected: _feeling == option.value,
                  onTap: _saved
                      ? null
                      : () => setState(() => _feeling = option.value),
                ),
            ],
          ),
          if (showPainFollowUp) ...[
            const SizedBox(height: 14),
            Text(
              'Optional — helps your Coach avoid or adjust similar movements. This is not a diagnosis.',
              style: AppTextStyles.caption.copyWith(fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final area in kPainBodyAreas)
                  _Chip(
                    label: area,
                    icon: Icons.circle_outlined,
                    selected: _bodyArea == area,
                    onTap: _saved
                        ? null
                        : () => setState(
                            () => _bodyArea = _bodyArea == area ? null : area,
                          ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final severity in _severityOptions)
                  _Chip(
                    label: switch (severity) {
                      PainSeverity.mild => 'Mild',
                      PainSeverity.moderate => 'Moderate',
                      PainSeverity.severe => 'Severe',
                    },
                    icon: Icons.circle,
                    selected: _severity == severity,
                    onTap: _saved
                        ? null
                        : () => setState(
                            () => _severity = _severity == severity
                                ? null
                                : severity,
                          ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final chip in kGenericFeedbackChips)
                _Chip(
                  label: chip,
                  icon: _selectedChips.contains(chip)
                      ? Icons.check_circle
                      : Icons.circle_outlined,
                  selected: _selectedChips.contains(chip),
                  onTap: _saved
                      ? null
                      : () => setState(() {
                          if (_selectedChips.contains(chip)) {
                            _selectedChips.remove(chip);
                          } else {
                            _selectedChips.add(chip);
                          }
                        }),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            enabled: !_saved,
            minLines: 1,
            maxLines: 3,
            maxLength: _kNoteMaxLength,
            style: AppTextStyles.subtitle.copyWith(
              fontSize: 13,
              color: Colors.white,
            ),
            decoration: InputDecoration(
              hintText:
                  'Example: My shoulders felt tight, but the exercise became easier after the first set.',
              hintStyle: AppTextStyles.caption.copyWith(fontSize: 12),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              counterStyle: AppTextStyles.caption.copyWith(fontSize: 11),
            ),
          ),
          const SizedBox(height: 10),
          if (_saved)
            Text(
              'Feedback saved',
              style: AppTextStyles.captionBold.copyWith(
                color: AppColors.success,
                fontSize: 13,
              ),
            )
          else
            Row(
              children: [
                TextButton(
                  onPressed: () => setState(() => _skipped = true),
                  child: Text(
                    'Skip',
                    style: AppTextStyles.captionBold.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
                const Spacer(),
                Material(
                  color: _feeling == null
                      ? AppColors.gold.withValues(alpha: 0.4)
                      : AppColors.gold,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _feeling == null ? null : _submit,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      child: Text(
                        'Save',
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
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected
            ? AppColors.gold.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(100),
        child: InkWell(
          borderRadius: BorderRadius.circular(100),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: selected ? AppColors.gold : AppColors.cardBorder,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: selected ? AppColors.gold : AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 12,
                      color: selected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
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
