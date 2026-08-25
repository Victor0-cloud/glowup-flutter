import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../coach/widgets/settings_widgets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glow_card.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/gradient_pill_button.dart';
import '../../core/widgets/sub_screen_header.dart';
import '../models/cycle_models.dart';
import '../state/cycle_controller.dart';

/// The 4 mood chips shown on PC05 — reuses [kCycleMoods]' existing
/// vocabulary (Happy/Calm/Sad/Energized) rather than the reference's
/// "Pain" chip, since pain is already captured by this same screen's
/// Symptoms + Pain intensity slider below; adding a second, overlapping
/// concept to the mood vocabulary would fragment the data model for no
/// real benefit.
const _kCheckInMoods = ['Happy', 'Calm', 'Sad', 'Energized'];

/// PC05 Daily Check-In — energy, mood, symptoms and pain intensity for
/// today. Writes through the same [CycleController.logDayEntry] real data
/// operation as Log Period, upserting today's [CycleDayEntry].
class DailyCheckInScreen extends ConsumerStatefulWidget {
  const DailyCheckInScreen({
    super.key,
    this.onBack,
    this.onSaved,
    this.onMenstrualPainNote,
  });

  final VoidCallback? onBack;
  final VoidCallback? onSaved;

  /// Opens the Daily Notebook (PC07) for today with [Feeling.menstrualPain]
  /// pre-set.
  final VoidCallback? onMenstrualPainNote;

  @override
  ConsumerState<DailyCheckInScreen> createState() => _DailyCheckInScreenState();
}

class _DailyCheckInScreenState extends ConsumerState<DailyCheckInScreen> {
  int _energy = 3;
  String? _mood;
  final Set<String> _symptoms = {};
  int _painIntensity = 0;
  bool _loaded = false;
  bool _saving = false;

  void _loadOnce(CycleState state) {
    if (_loaded) return;
    _loaded = true;
    final today = state.dayEntryFor(DateTime.now());
    if (today == null) return;
    _energy = today.energyLevel ?? 3;
    _mood = today.mood;
    _symptoms.addAll(today.symptoms);
    _painIntensity = today.painIntensity ?? 0;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final controller = ref.read(cycleControllerProvider.notifier);
    final now = DateTime.now();
    final current = ref.read(cycleControllerProvider).valueOrNull;
    final existing = current?.dayEntryFor(now);
    await controller.logDayEntry(
      CycleDayEntry(
        date: now,
        flow: existing?.flow,
        symptoms: _symptoms,
        mood: _mood,
        energyLevel: _energy,
        sleepQuality: existing?.sleepQuality,
        painIntensity: _painIntensity,
        note: existing?.note,
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    widget.onSaved?.call();
  }

  @override
  Widget build(BuildContext context) {
    final cycleAsync = ref.watch(cycleControllerProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: Column(
          children: [
            SubScreenHeader(
              title: 'Daily Check-In',
              subtitle: "Listen to your body. Your answer guides today's plan.",
              onBack: widget.onBack ?? () => Navigator.maybePop(context),
            ),
            Expanded(
              child: cycleAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.purple),
                ),
                error: (e, st) => Center(
                  child: Text(
                    "Couldn't load Period & Cycle.",
                    style: AppTextStyles.subtitle,
                  ),
                ),
                data: (state) {
                  _loadOnce(state);
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Energy',
                          style: AppTextStyles.cardTitleLg.copyWith(
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SegmentedOptionRow<int>(
                          options: const [1, 3, 5],
                          labels: const ['Low', 'Steady', 'High'],
                          selected: _energy,
                          onSelected: (v) => setState(() => _energy = v),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Mood',
                          style: AppTextStyles.cardTitleLg.copyWith(
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 10),
                        GridView.count(
                          crossAxisCount: 4,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.7,
                          children: [
                            for (final m in _kCheckInMoods)
                              _MoodChip(
                                label: m,
                                selected: _mood == m,
                                onTap: () => setState(
                                  () => _mood = _mood == m ? null : m,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Symptoms',
                          style: AppTextStyles.cardTitleLg.copyWith(
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final s in kCycleSymptoms)
                              _SymptomChip(
                                label: s,
                                selected: _symptoms.contains(s),
                                onTap: () => setState(
                                  () => _symptoms.contains(s)
                                      ? _symptoms.remove(s)
                                      : _symptoms.add(s),
                                ),
                              ),
                            _SymptomChip(
                              label: 'None',
                              selected: _symptoms.isEmpty,
                              onTap: () => setState(_symptoms.clear),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Pain intensity',
                          style: AppTextStyles.cardTitleLg.copyWith(
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: AppColors.ctaStart,
                            inactiveTrackColor: Colors.white.withValues(
                              alpha: 0.1,
                            ),
                            thumbColor: Colors.white,
                            overlayColor: AppColors.ctaStart.withValues(
                              alpha: 0.2,
                            ),
                          ),
                          child: Semantics(
                            label: 'Pain intensity',
                            value: '$_painIntensity of 10',
                            slider: true,
                            child: Slider(
                              value: _painIntensity.toDouble(),
                              min: 0,
                              max: 10,
                              divisions: 10,
                              onChanged: (v) =>
                                  setState(() => _painIntensity = v.round()),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Mild',
                                style: AppTextStyles.caption.copyWith(
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                'Severe',
                                style: AppTextStyles.caption.copyWith(
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        GlowCard(
                          onTap: widget.onMenstrualPainNote,
                          child: Row(
                            children: [
                              const Icon(
                                Icons.water_drop,
                                color: AppColors.ctaStart,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Menstrual pain',
                                      style: AppTextStyles.cardTitle.copyWith(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      "Add a private note to today's calendar",
                                      style: AppTextStyles.caption.copyWith(
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right,
                                color: AppColors.textSecondary,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        GradientPillButton(
                          label: 'Save check-in',
                          onPressed: _saving ? null : _save,
                          loading: _saving,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoodChip extends StatelessWidget {
  const _MoodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon => switch (label) {
    'Happy' => Icons.sentiment_satisfied_alt,
    'Calm' => Icons.self_improvement,
    'Sad' => Icons.sentiment_dissatisfied,
    _ => Icons.bolt,
  };

  Color get _color => switch (label) {
    'Happy' => AppColors.ctaStart,
    'Calm' => AppColors.blue,
    'Sad' => AppColors.purple,
    _ => AppColors.orange,
  };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected
            ? _color.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? _color : AppColors.cardBorder,
              ),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_icon, color: _color, size: 22),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: AppTextStyles.cardTitle.copyWith(
                    fontSize: 12,
                    color: selected ? _color : Colors.white,
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

class _SymptomChip extends StatelessWidget {
  const _SymptomChip({
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
            ? AppColors.ctaStart.withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? AppColors.ctaStart : AppColors.cardBorder,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: AppTextStyles.captionBold.copyWith(
                fontSize: 13,
                color: selected ? AppColors.ctaStart : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
