import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../models/workout_completion_record.dart';

/// One "how did this feel" choice — mirrors [ExerciseReflectionCard]'s
/// `_SignalChip` styling but is single-select (a difficulty rating, not a
/// multi-select signal list).
class _FeelingOption {
  const _FeelingOption(this.value, this.label, this.icon);
  final WorkoutFeeling value;
  final String label;
  final IconData icon;
}

const _feelingOptions = [
  _FeelingOption(WorkoutFeeling.tooEasy, 'Too Easy', Icons.trending_down),
  _FeelingOption(WorkoutFeeling.justRight, 'Just Right', Icons.check_circle),
  _FeelingOption(WorkoutFeeling.tooHard, 'Too Hard', Icons.trending_up),
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

/// The post-workout "How did this workout feel?" prompt shown after the
/// completion summary — same card styling as [ExerciseReflectionCard]
/// (gradient surface, "AI COACH" caption, chip choices, optional note,
/// Skip/Save actions), extended with the Pain/Discomfort follow-up and
/// real save/loading/error states this one submits durably rather than
/// discarding on screen exit.
class PostWorkoutFeedbackCard extends StatefulWidget {
  const PostWorkoutFeedbackCard({
    super.key,
    required this.onSubmit,
    required this.onSkip,
    this.saving = false,
    this.errorMessage,
  });

  /// Called with the chosen feeling, optional pain details, and optional
  /// note once the user taps Save. The caller owns the actual persistence
  /// call and reflects its result back via [saving]/[errorMessage].
  final void Function(
    WorkoutFeeling feeling,
    PainDetails? painDetails,
    String? note,
  )
  onSubmit;

  final VoidCallback onSkip;

  /// True while the caller's save is in flight — disables every control so
  /// a rapid repeated tap can never submit twice.
  final bool saving;

  /// Set by the caller when the last save attempt failed — shown inline so
  /// the user can retry, never silently swallowed.
  final String? errorMessage;

  @override
  State<PostWorkoutFeedbackCard> createState() =>
      _PostWorkoutFeedbackCardState();
}

class _PostWorkoutFeedbackCardState extends State<PostWorkoutFeedbackCard> {
  WorkoutFeeling? _feeling;
  PainSeverity? _severity;
  final _bodyAreaController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _bodyAreaController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_feeling == null || widget.saving) return;
    final painDetails = _feeling == WorkoutFeeling.painDiscomfort
        ? PainDetails(
            bodyArea: _bodyAreaController.text.trim().isEmpty
                ? null
                : _bodyAreaController.text.trim(),
            severity: _severity,
          )
        : null;
    final note = _noteController.text.trim();
    widget.onSubmit(_feeling!, painDetails, note.isEmpty ? null : note);
  }

  @override
  Widget build(BuildContext context) {
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
          Text(
            'AI COACH',
            style: AppTextStyles.captionBold.copyWith(
              color: AppColors.gold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'How did this workout feel?',
            style: AppTextStyles.subtitle.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in _feelingOptions)
                _FeelingChip(
                  label: option.label,
                  icon: option.icon,
                  selected: _feeling == option.value,
                  onTap: widget.saving
                      ? null
                      : () => setState(() => _feeling = option.value),
                ),
            ],
          ),
          if (showPainFollowUp) ...[
            const SizedBox(height: 16),
            Text(
              'Optional — helps the AI Coach avoid or adjust similar movements. This is not a diagnosis.',
              style: AppTextStyles.caption.copyWith(fontSize: 12),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _bodyAreaController,
              enabled: !widget.saving,
              style: AppTextStyles.subtitle.copyWith(
                fontSize: 13,
                color: Colors.white,
              ),
              decoration: InputDecoration(
                hintText: 'Body area (optional)',
                hintStyle: AppTextStyles.caption.copyWith(fontSize: 13),
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
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final severity in _severityOptions)
                  _FeelingChip(
                    label: switch (severity) {
                      PainSeverity.mild => 'Mild',
                      PainSeverity.moderate => 'Moderate',
                      PainSeverity.severe => 'Severe',
                    },
                    icon: Icons.circle,
                    selected: _severity == severity,
                    onTap: widget.saving
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
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            enabled: !widget.saving,
            minLines: 1,
            maxLines: 3,
            style: AppTextStyles.subtitle.copyWith(
              fontSize: 13,
              color: Colors.white,
            ),
            decoration: InputDecoration(
              hintText: 'Add a note for the AI Coach (optional)',
              hintStyle: AppTextStyles.caption.copyWith(fontSize: 13),
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
            ),
          ),
          if (widget.errorMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              widget.errorMessage!,
              style: AppTextStyles.captionBold.copyWith(
                color: AppColors.orange,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              TextButton(
                onPressed: widget.saving ? null : widget.onSkip,
                child: Text(
                  'Skip for Now',
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
                  onTap: _feeling == null || widget.saving ? null : _submit,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    child: widget.saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF0A0B1E),
                            ),
                          )
                        : const Text(
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

class _FeelingChip extends StatelessWidget {
  const _FeelingChip({
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
    return Material(
      color: selected
          ? AppColors.gold.withValues(alpha: 0.16)
          : Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(100),
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: onTap,
        child: Container(
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
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 12,
                  color: selected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
