import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glow_card.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/gradient_pill_button.dart';
import '../../core/widgets/sub_screen_header.dart';
import '../models/mood_models.dart';
import '../state/mood_controller.dart';

/// Mood Check-In (Figma family 45). A warm, few-taps daily check-in: pick
/// how you're feeling, optionally say why, optionally rate energy/stress,
/// optionally add a private note. Only the mood level is required — the
/// Save button stays disabled until one is picked, everything else is
/// genuinely skippable per the approved product spec.
class MoodCheckInScreen extends ConsumerStatefulWidget {
  const MoodCheckInScreen({
    super.key,
    this.onBack,
    this.onSaved,
    this.onViewHistory,
  });

  final VoidCallback? onBack;
  final VoidCallback? onSaved;
  final VoidCallback? onViewHistory;

  @override
  ConsumerState<MoodCheckInScreen> createState() => _MoodCheckInScreenState();
}

class _MoodCheckInScreenState extends ConsumerState<MoodCheckInScreen> {
  MoodLevel? _level;
  final Set<String> _reasons = {};
  int? _energy;
  int? _stress;
  final _noteController = TextEditingController();
  bool _loadedToday = false;
  bool _saving = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _loadTodayIntoForm(MoodState state) {
    if (_loadedToday) return;
    _loadedToday = true;
    final today = state.todayEntry;
    if (today == null) return;
    _level = today.level;
    _reasons
      ..clear()
      ..addAll(today.reasons);
    _energy = today.energyLevel;
    _stress = today.stressLevel;
    if (today.note != null) _noteController.text = today.note!;
  }

  Future<void> _save() async {
    final level = _level;
    if (level == null) return;
    setState(() => _saving = true);
    final note = _noteController.text.trim();
    await ref
        .read(moodControllerProvider.notifier)
        .logCheckIn(
          level: level,
          reasons: Set.from(_reasons),
          energyLevel: _energy,
          stressLevel: _stress,
          note: note.isEmpty ? null : note,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    SemanticsService.sendAnnouncement(
      View.of(context),
      'Mood check-in saved',
      TextDirection.ltr,
    );
    if (widget.onSaved != null) {
      widget.onSaved!();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Check-in saved'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final moodState = ref.watch(moodControllerProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: Column(
          children: [
            SubScreenHeader(
              title: 'Mood Check-In',
              subtitle: 'How are you feeling today?',
              onBack: widget.onBack ?? () => Navigator.maybePop(context),
              trailing: widget.onViewHistory == null
                  ? null
                  : Semantics(
                      button: true,
                      label: 'View mood history',
                      child: IconButton(
                        icon: const Icon(
                          Icons.history,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: widget.onViewHistory,
                        tooltip: 'View history',
                      ),
                    ),
            ),
            Expanded(
              child: moodState.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.purple),
                ),
                error: (err, st) => Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      "Couldn't load Mood Check-In. Please restart the app.",
                      style: AppTextStyles.subtitle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                data: (data) {
                  _loadTodayIntoForm(data);
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                    child: _body(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How are you feeling right now?',
          style: AppTextStyles.cardTitleLg,
        ),
        const SizedBox(height: 12),
        GlowCard(
          child: Wrap(
            spacing: 8,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            children: [
              for (final level in kMoodLevelDisplayOrder)
                _MoodFaceOption(
                  level: level,
                  selected: _level == level,
                  onTap: () => setState(() => _level = level),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Why do you feel this way? (optional)',
          style: AppTextStyles.cardTitleLg,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final r in kMoodReasons)
              _Chip(
                label: r,
                selected: _reasons.contains(r),
                onTap: () => setState(
                  () => _reasons.contains(r)
                      ? _reasons.remove(r)
                      : _reasons.add(r),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        GlowCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LevelPicker(
                label: 'Energy level (optional)',
                value: _energy,
                onChanged: (v) => setState(() => _energy = v),
              ),
              const SizedBox(height: 16),
              _LevelPicker(
                label: 'Stress level (optional)',
                value: _stress,
                onChanged: (v) => setState(() => _stress = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Semantics(
          label: 'Optional note',
          textField: true,
          child: TextField(
            controller: _noteController,
            maxLength: 200,
            maxLines: 3,
            style: AppTextStyles.subtitle.copyWith(
              fontSize: 14,
              color: Colors.white,
            ),
            decoration: InputDecoration(
              hintText: 'Write a few words (optional)',
              hintStyle: AppTextStyles.caption,
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
        const SizedBox(height: 20),
        GradientPillButton(
          label: 'Save Check-In',
          onPressed: _level == null ? null : _save,
          loading: _saving,
        ),
      ],
    );
  }
}

class _MoodFaceOption extends StatelessWidget {
  const _MoodFaceOption({
    required this.level,
    required this.selected,
    required this.onTap,
  });

  final MoodLevel level;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: level.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? level.color.withValues(alpha: 0.25)
                      : Colors.white.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? level.color : AppColors.cardBorder,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Text(level.emoji, style: const TextStyle(fontSize: 28)),
              ),
              const SizedBox(height: 6),
              Text(
                level.label,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 11,
                  color: selected ? level.color : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelPicker extends StatelessWidget {
  const _LevelPicker({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.subtitle.copyWith(fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (var i = 1; i <= 5; i++)
              Semantics(
                button: true,
                selected: value == i,
                label: '$label $i of 5',
                child: InkWell(
                  borderRadius: BorderRadius.circular(100),
                  onTap: () => onChanged(value == i ? null : i),
                  child: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: value == i
                          ? AppColors.purple
                          : Colors.white.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: value == i
                            ? AppColors.purple
                            : AppColors.cardBorder,
                      ),
                    ),
                    child: Text(
                      '$i',
                      style: TextStyle(
                        color: value == i ? Colors.white : Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected
            ? AppColors.purple.withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(100),
        child: InkWell(
          borderRadius: BorderRadius.circular(100),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: selected ? AppColors.purple : AppColors.cardBorder,
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 13,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
