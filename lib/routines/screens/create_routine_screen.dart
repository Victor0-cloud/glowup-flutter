import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/tod/tod_period.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/bottom_nav_bar.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/sub_screen_header.dart';
import '../models/routine_models.dart';
import '../state/routines_controller.dart';
import '../theme/routines_variant_config.dart';
import '../widgets/day_selector.dart';
import '../widgets/icon_and_theme_pickers.dart';

/// A small curated activity library for the "+ Add Steps" picker — Figma
/// doesn't design a separate step-picker screen, so this is a lightweight
/// bottom sheet in the app's existing visual language rather than an
/// invented full screen.
const _stepChoices = [
  RoutineActivity(
    id: 'lib-water',
    emoji: '💧',
    title: 'Drink Water',
    durationMinutes: 2,
  ),
  RoutineActivity(
    id: 'lib-stretch',
    emoji: '🧘‍♀️',
    title: 'Stretch',
    durationMinutes: 5,
  ),
  RoutineActivity(
    id: 'lib-meditate',
    emoji: '🧠',
    title: 'Meditation',
    durationMinutes: 10,
  ),
  RoutineActivity(
    id: 'lib-skincare',
    emoji: '✨',
    title: 'Skincare',
    durationMinutes: 5,
  ),
  RoutineActivity(
    id: 'lib-plan',
    emoji: '📝',
    title: 'Plan Day',
    durationMinutes: 3,
  ),
  RoutineActivity(
    id: 'lib-walk',
    emoji: '🚶',
    title: 'Walk',
    durationMinutes: 10,
  ),
  RoutineActivity(
    id: 'lib-eat',
    emoji: '🍎',
    title: 'Eat Healthy',
    durationMinutes: 5,
  ),
  RoutineActivity(
    id: 'lib-read',
    emoji: '📖',
    title: 'Read',
    durationMinutes: 10,
  ),
  RoutineActivity(
    id: 'lib-music',
    emoji: '🎵',
    title: 'Music',
    durationMinutes: 3,
  ),
  RoutineActivity(
    id: 'lib-rest',
    emoji: '😴',
    title: 'Rest',
    durationMinutes: 5,
  ),
  RoutineActivity(
    id: 'lib-breathe',
    emoji: '🫁',
    title: 'Breathe',
    durationMinutes: 2,
  ),
  RoutineActivity(
    id: 'lib-teeth',
    emoji: '🦷',
    title: 'Brush Teeth',
    durationMinutes: 3,
  ),
];

/// 22f_create_routine (368:2057).
class CreateRoutineScreen extends ConsumerStatefulWidget {
  const CreateRoutineScreen({
    super.key,
    required this.period,
    required this.onSaved,
    required this.onBack,
    required this.onToday,
    required this.onRoutines,
    required this.onCoach,
    required this.onProfile,
  });

  final TodPeriod period;
  final VoidCallback onSaved;
  final VoidCallback onBack;
  final VoidCallback onToday;
  final VoidCallback onRoutines;
  final VoidCallback onCoach;
  final VoidCallback onProfile;

  @override
  ConsumerState<CreateRoutineScreen> createState() =>
      _CreateRoutineScreenState();
}

class _CreateRoutineScreenState extends ConsumerState<CreateRoutineScreen> {
  final _nameController = TextEditingController();
  String _emoji = kRoutineEmojiChoices.first;
  RoutineColorTheme _theme = RoutineColorTheme.gold;
  Set<Weekday> _days = {
    Weekday.monday,
    Weekday.tuesday,
    Weekday.wednesday,
    Weekday.thursday,
    Weekday.friday,
  };
  TimeOfDay _time = const TimeOfDay(hour: 6, minute: 30);
  final List<RoutineActivity> _steps = [];
  int _stepInstanceCounter = 0;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _nameController.text.trim().isNotEmpty &&
      _days.isNotEmpty &&
      _steps.isNotEmpty;

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  void _addStep(RoutineActivity template) {
    setState(() {
      _stepInstanceCounter++;
      _steps.add(
        RoutineActivity(
          id: '${template.id}-$_stepInstanceCounter',
          emoji: template.emoji,
          title: template.title,
          durationMinutes: template.durationMinutes,
        ),
      );
    });
    Navigator.of(context).pop();
  }

  void _removeStep(String id) =>
      setState(() => _steps.removeWhere((s) => s.id == id));

  void _openAddStepsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.cardStart, AppColors.cardEnd],
            ),
            borderRadius: BorderRadius.circular(AppRadii.xl),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add a Step',
                style: AppTextStyles.screenTitle.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 16),
              // Flexible+scrollable: 12 choices can wrap to more rows than
              // fit a short window, and a fixed-size Column would overflow
              // instead of letting the sheet's own content scroll.
              Flexible(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final choice in _stepChoices)
                        Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _addStep(choice),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    choice.emoji,
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    choice.title,
                                    style: AppTextStyles.cardSubtitleMd
                                        .copyWith(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _save() {
    if (!_canSave) return;
    final controller = ref.read(routinesControllerProvider.notifier);
    controller.addRoutine(
      Routine(
        id: 'custom-${DateTime.now().millisecondsSinceEpoch}',
        title: _nameController.text.trim(),
        subtitle: 'Your custom routine',
        emoji: _emoji,
        theme: _theme,
        period: widget.period,
        schedule: RoutineSchedule(days: _days, time: _time),
        activities: List.unmodifiable(_steps),
      ),
    );
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final accent = _theme.color;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SubScreenHeader(
                      title: 'Create Routine',
                      subtitle: 'Design your personal success formula',
                      onBack: widget.onBack,
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FieldLabel('ROUTINE NAME'),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  AppColors.cardStart,
                                  AppColors.cardEnd,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(AppRadii.md),
                              border: Border.all(color: AppColors.cardBorder),
                            ),
                            child: TextField(
                              controller: _nameController,
                              style: AppTextStyles.fieldValue.copyWith(
                                fontSize: 16,
                              ),
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                hintText: 'e.g., Morning Wellness',
                                hintStyle: AppTextStyles.fieldPlaceholder,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          _FieldLabel('CHOOSE ICON'),
                          const SizedBox(height: 8),
                          RoutineIconPicker(
                            selected: _emoji,
                            onSelected: (e) => setState(() => _emoji = e),
                            accent: accent,
                          ),
                          const SizedBox(height: 20),
                          _FieldLabel('COLOR THEME'),
                          const SizedBox(height: 8),
                          RoutineColorThemePicker(
                            selected: _theme,
                            onSelected: (t) => setState(() => _theme = t),
                          ),
                          const SizedBox(height: 20),
                          _FieldLabel('WEEKLY SCHEDULE'),
                          const SizedBox(height: 8),
                          DaySelector(
                            selected: _days,
                            onChanged: (d) => setState(() => _days = d),
                            accent: accent,
                          ),
                          const SizedBox(height: 20),
                          _FieldLabel('REMINDER TIME'),
                          const SizedBox(height: 8),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(AppRadii.md),
                              onTap: _pickTime,
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      AppColors.cardStart,
                                      AppColors.cardEnd,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.md,
                                  ),
                                  border: Border.all(
                                    color: AppColors.cardBorder,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _time.format(context),
                                      style: AppTextStyles.cardTitleLg,
                                    ),
                                    const AppIcon(
                                      'clock',
                                      size: 20,
                                      color: AppColors.textSecondary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (_steps.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            _FieldLabel('STEPS (${_steps.length})'),
                            const SizedBox(height: 8),
                            for (final step in _steps)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        step.emoji,
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${step.title} · ${step.durationMinutes} min',
                                          style: AppTextStyles.cardSubtitleMd
                                              .copyWith(color: Colors.white),
                                        ),
                                      ),
                                      Semantics(
                                        button: true,
                                        label: 'Remove ${step.title}',
                                        child: InkWell(
                                          onTap: () => _removeStep(step.id),
                                          child: const Icon(
                                            Icons.close,
                                            size: 16,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Column(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      onTap: _openAddStepsSheet,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.cardBorder),
                          borderRadius: BorderRadius.circular(AppRadii.md),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '+ Add Steps',
                          style: AppTextStyles.cardTitleLg,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  RoutineGradientButton(
                    label: 'Save Routine',
                    onPressed: _canSave ? _save : null,
                  ),
                ],
              ),
            ),
            BottomNavBar(
              active: AppNavTab.routines,
              activeAccent: RoutinesVariantConfig.navActiveColor,
              onTabSelected: (tab) {
                switch (tab) {
                  case AppNavTab.today:
                    widget.onToday();
                  case AppNavTab.routines:
                    widget.onRoutines();
                  case AppNavTab.coach:
                    widget.onCoach();
                  case AppNavTab.profile:
                    widget.onProfile();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.captionBold.copyWith(
        color: AppColors.textSecondary,
        fontSize: 14,
      ),
    );
  }
}
