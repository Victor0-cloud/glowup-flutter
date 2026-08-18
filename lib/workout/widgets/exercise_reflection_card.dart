import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// One selectable AI Coach reflection signal (a checkbox-style option) —
/// [key] is the stable machine-readable id logged to [WorkoutSignalLog]
/// (matches the exercise's approved `manifest.json` `trainingSignals`),
/// [label] is what the user sees.
class ReflectionSignal {
  const ReflectionSignal(this.key, this.label);
  final String key;
  final String label;
}

/// The approved post-exercise AI Coach prompt + signal list for one
/// exercise (currently only Legs Up Wall/Reclined Butterfly — see
/// `WorkoutRestScreen`). Never invented per-exercise copy beyond what was
/// explicitly specified.
class ReflectionConfig {
  const ReflectionConfig({required this.prompt, required this.signals});
  final String prompt;
  final List<ReflectionSignal> signals;
}

/// Approved reflection prompts, keyed by Tier 1 catalog id.
const Map<String, ReflectionConfig> kExerciseReflectionConfigs = {
  'EX066': ReflectionConfig(
    prompt: 'How did Legs Up Wall feel? Note hamstring tension, back comfort, tingling or dizziness.',
    signals: [
      ReflectionSignal('hamstring_tension', 'Hamstring tension'),
      ReflectionSignal('lower_back_comfort', 'Lower-back comfort'),
      ReflectionSignal('tingling', 'Tingling'),
      ReflectionSignal('numbness', 'Numbness'),
      ReflectionSignal('dizziness', 'Dizziness'),
      ReflectionSignal('wall_distance_modification', 'Wall-distance modification'),
      ReflectionSignal('knee_bend_modification', 'Knee-bend modification'),
    ],
  ),
  'EX067': ReflectionConfig(
    prompt: 'How did Reclined Butterfly feel? Note hip, groin, knee or lower-back comfort and whether you needed support.',
    signals: [
      ReflectionSignal('hip_comfort', 'Hip comfort'),
      ReflectionSignal('groin_comfort', 'Groin comfort'),
      ReflectionSignal('knee_comfort', 'Knee comfort'),
      ReflectionSignal('lower_back_comfort', 'Lower-back comfort'),
      ReflectionSignal('support_used', 'Support used'),
      ReflectionSignal('range_of_motion', 'Range of motion'),
    ],
  ),
};

/// Post-exercise AI Coach reflection card shown on [WorkoutRestScreen]
/// right after Legs Up Wall/Reclined Butterfly finish. Entirely optional —
/// "Skip" and "Save Note" both leave the already-logged
/// [WorkoutSignalType.exerciseCompleted]/`skipped` signal untouched; this
/// only ever adds an additional [WorkoutSignalType.exerciseNoteSaved]
/// signal and, if saved, an [ExerciseResult.note] for the completed-
/// exercise history. A [StatefulWidget] (not a Riverpod provider) because
/// the selection is purely ephemeral UI state scoped to this one rest
/// period — it must survive the once-a-second rest-timer rebuild but
/// never needs to be read anywhere else.
class ExerciseReflectionCard extends StatefulWidget {
  const ExerciseReflectionCard({super.key, required this.config, required this.onSave});

  final ReflectionConfig config;
  final ValueChanged<String> onSave;

  @override
  State<ExerciseReflectionCard> createState() => _ExerciseReflectionCardState();
}

class _ExerciseReflectionCardState extends State<ExerciseReflectionCard> {
  final Set<String> _selected = {};
  final TextEditingController _noteController = TextEditingController();
  bool _saved = false;
  bool _skipped = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _toggle(String key) {
    setState(() {
      if (_selected.contains(key)) {
        _selected.remove(key);
      } else {
        _selected.add(key);
      }
    });
  }

  void _save() {
    final labels = widget.config.signals.where((s) => _selected.contains(s.key)).map((s) => s.label);
    final freeText = _noteController.text.trim();
    final parts = [...labels, if (freeText.isNotEmpty) freeText];
    if (parts.isEmpty) return;
    widget.onSave(parts.join(', '));
    setState(() => _saved = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_skipped) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.cardStart, AppColors.cardEnd]),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AI COACH', style: AppTextStyles.captionBold.copyWith(color: AppColors.gold, fontSize: 12)),
          const SizedBox(height: 8),
          Text(widget.config.prompt, style: AppTextStyles.subtitle.copyWith(fontSize: 14)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final signal in widget.config.signals) _SignalChip(label: signal.label, selected: _selected.contains(signal.key), onTap: _saved ? null : () => _toggle(signal.key)),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            enabled: !_saved,
            minLines: 1,
            maxLines: 3,
            style: AppTextStyles.subtitle.copyWith(fontSize: 13, color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Add a note (optional)',
              hintStyle: AppTextStyles.caption.copyWith(fontSize: 13),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 14),
          if (_saved)
            Text('Note saved', style: AppTextStyles.captionBold.copyWith(color: AppColors.success, fontSize: 13))
          else
            Row(
              children: [
                TextButton(
                  onPressed: () => setState(() => _skipped = true),
                  child: Text('Skip', style: AppTextStyles.captionBold.copyWith(color: AppColors.textSecondary, fontSize: 14)),
                ),
                const Spacer(),
                Material(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _save,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Text('Save Note', style: TextStyle(color: Color(0xFF0A0B1E), fontSize: 14, fontWeight: FontWeight.w800)),
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

class _SignalChip extends StatelessWidget {
  const _SignalChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.gold.withValues(alpha: 0.16) : Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(100),
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: selected ? AppColors.gold : AppColors.cardBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(selected ? Icons.check_circle : Icons.circle_outlined, size: 14, color: selected ? AppColors.gold : AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(label, style: AppTextStyles.caption.copyWith(fontSize: 12, color: selected ? AppColors.textPrimary : AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}
