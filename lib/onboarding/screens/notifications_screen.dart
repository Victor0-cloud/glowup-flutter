import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/glow_card.dart';
import '../../core/widgets/glow_switch.dart';
import '../models/onboarding_profile.dart';
import '../state/onboarding_controller.dart';
import '../widgets/onboarding_scaffold.dart';

/// 10_notifications (node 368:610). Labels/defaults match the rendered
/// screen exactly — the frame's own annotation uses slightly different
/// names ("Glow Up Coach messages", "Progress Celebrations") for the same
/// two toggles; the visible labels ("Hydration Nudges", "Weekly Summary")
/// are what's implemented.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key, required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(onboardingControllerProvider).notifications;
    final controller = ref.read(onboardingControllerProvider.notifier);

    return OnboardingScaffold(
      title: 'Stay on Track 🔔',
      subtitle: 'Get gentle reminders to keep your daily glow going strong.',
      progressIndex: 3,
      primaryLabel: 'Next',
      onPrimaryPressed: () {
        controller.advanceStep(OnboardingStep.healthConnections);
        onNext();
      },
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            // Phone-Mockup (368:625): dark card frame around the sample
            // notification, matching the approved screen exactly.
            Center(
              child: Container(
                width: 260,
                height: 120,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.cardEnd,
                  border: Border.all(color: AppColors.cardBorder),
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: AppColors.gold,
                          shape: BoxShape.circle,
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(5),
                          child: AppMascot(size: 14),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Glow Up Coach',
                              style: TextStyle(
                                color: Color(0xFF0A0B1E),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Time to hydrate and shine! 💧',
                              style: TextStyle(
                                color: Color(0xFF555555),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _ToggleRow(
              title: 'Daily Reminders',
              subtitle: 'Start your morning motivated',
              value: prefs.dailyReminders,
              onChanged: (v) => controller.updateNotifications(
                prefs.copyWith(dailyReminders: v),
              ),
            ),
            const SizedBox(height: 12),
            _ToggleRow(
              title: 'Workout Alerts',
              subtitle: 'Reminders before schedule sessions',
              value: prefs.workoutAlerts,
              onChanged: (v) => controller.updateNotifications(
                prefs.copyWith(workoutAlerts: v),
              ),
            ),
            const SizedBox(height: 12),
            _ToggleRow(
              title: 'Hydration Nudges',
              subtitle: 'Keep water intake consistent',
              value: prefs.hydrationNudges,
              onChanged: (v) => controller.updateNotifications(
                prefs.copyWith(hydrationNudges: v),
              ),
            ),
            const SizedBox(height: 12),
            _ToggleRow(
              title: 'Weekly Summary',
              subtitle: 'Celebrate milestones each Sunday',
              value: prefs.weeklySummary,
              onChanged: (v) => controller.updateNotifications(
                prefs.copyWith(weeklySummary: v),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GlowCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.cardTitle),
                Text(subtitle, style: AppTextStyles.cardSubtitle),
              ],
            ),
          ),
          GlowSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
