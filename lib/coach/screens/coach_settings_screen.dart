import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/bottom_nav_bar.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/sub_screen_header.dart';
import '../models/coach_models.dart';
import '../state/coach_settings_controller.dart';
import '../theme/coach_variant_config.dart';
import '../widgets/settings_widgets.dart';

/// 23h_coach_settings (368:2906).
class CoachSettingsScreen extends ConsumerWidget {
  const CoachSettingsScreen({
    super.key,
    required this.onBack,
    required this.onToday,
    required this.onRoutines,
    required this.onProfile,
  });

  final VoidCallback onBack;
  final VoidCallback onToday;
  final VoidCallback onRoutines;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(coachSettingsControllerProvider);
    final controller = ref.read(coachSettingsControllerProvider.notifier);

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
                      title: 'Coach Settings',
                      subtitle: 'Configure your interactive AI experience',
                      onBack: onBack,
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          ToggleRow(
                            label: 'Proactive Check-ins',
                            value: settings.proactiveCheckins,
                            onChanged: controller.setProactiveCheckins,
                          ),
                          const SizedBox(height: 10),
                          ToggleRow(
                            label: 'Daily Motivation',
                            value: settings.dailyMotivation,
                            onChanged: controller.setDailyMotivation,
                          ),
                          const SizedBox(height: 10),
                          ToggleRow(
                            label: 'Workout Suggestions',
                            value: settings.workoutSuggestions,
                            onChanged: controller.setWorkoutSuggestions,
                          ),
                          const SizedBox(height: 10),
                          ToggleRow(
                            label: 'Nutrition Tips',
                            value: settings.nutritionTips,
                            onChanged: controller.setNutritionTips,
                          ),
                          const SizedBox(height: 10),
                          ToggleRow(
                            label: 'Sleep Reminders',
                            value: settings.sleepReminders,
                            onChanged: controller.setSleepReminders,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'COACH PERSONALITY',
                            style: AppTextStyles.captionBold.copyWith(
                              color: const Color(0xFFB0B5E3),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SegmentedOptionRow<CoachPersonality>(
                            options: CoachPersonality.values,
                            labels: [
                              for (final p in CoachPersonality.values) p.label,
                            ],
                            selected: settings.personality,
                            onSelected: controller.setPersonality,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'NOTIFICATION FREQUENCY',
                            style: AppTextStyles.captionBold.copyWith(
                              color: const Color(0xFFB0B5E3),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SegmentedOptionRow<NotificationFrequency>(
                            options: NotificationFrequency.values,
                            labels: [
                              for (final f in NotificationFrequency.values)
                                f.label,
                            ],
                            selected: settings.frequency,
                            onSelected: controller.setFrequency,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'AI COACH VOICE',
                            style: AppTextStyles.captionBold.copyWith(
                              color: const Color(0xFFB0B5E3),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SegmentedOptionRow<CoachVoicePreference>(
                            options: CoachVoicePreference.values,
                            labels: [
                              for (final v in CoachVoicePreference.values)
                                v.label,
                            ],
                            selected: settings.voicePreference,
                            onSelected: controller.setVoicePreference,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'SPEECH SPEED',
                            style: AppTextStyles.captionBold.copyWith(
                              color: const Color(0xFFB0B5E3),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SegmentedOptionRow<CoachSpeechSpeed>(
                            options: CoachSpeechSpeed.values,
                            labels: [
                              for (final s in CoachSpeechSpeed.values) s.label,
                            ],
                            selected: settings.speechSpeed,
                            onSelected: controller.setSpeechSpeed,
                          ),
                          const SizedBox(height: 16),
                          ToggleRow(
                            label: 'Auto-read replies',
                            value: settings.autoReadReplies,
                            onChanged: controller.setAutoReadReplies,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: RoutineGradientButton(
                label: 'Save Changes',
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Coach settings saved.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                ),
              ),
            ),
            BottomNavBar(
              active: AppNavTab.coach,
              activeAccent: CoachVariantConfig.navActiveColor,
              onTabSelected: (tab) {
                switch (tab) {
                  case AppNavTab.today:
                    onToday();
                  case AppNavTab.routines:
                    onRoutines();
                  case AppNavTab.coach:
                    break;
                  case AppNavTab.profile:
                    onProfile();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
