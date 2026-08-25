import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/glow_card.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/gradient_pill_button.dart';
import '../../core/widgets/onboarding_back_button.dart';
import '../models/onboarding_profile.dart';
import '../state/onboarding_controller.dart';

/// 13_finish_setup (node 368:757). Final confirmation — no new input.
/// Tapping "Start My Glow Up" is what creates the initialized user state
/// (marks onboarding complete) and hands off to 20a_today_morning.
class FinishSetupScreen extends ConsumerWidget {
  const FinishSetupScreen({super.key, required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);

    final planSubtitle = profile.goals.isEmpty
        ? 'A balanced plan built around you'
        : 'Tailored to ${profile.goals.map((g) => g.label.toLowerCase()).take(2).join(' & ')}';
    final routineSubtitle = profile.scheduleWindow == null
        ? 'Daily routine ready to go'
        : '${profile.scheduleWindow!.label} workout alerts '
              '${profile.notifications.workoutAlerts ? 'enabled' : 'disabled'}';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: Column(
          children: [
            const OnboardingBackButton(),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  AppIcon('sparkles', size: 24),
                  AppIcon('sparkles-cluster', size: 16),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Text(
                    "You're All Set! ✨",
                    textAlign: TextAlign.center,
                    style: AppTextStyles.screenTitleBlack,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your customized Glow Up track is officially ready.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.subtitleLg,
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: Column(
                  children: [
                    Container(
                      width: 110,
                      height: 110,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [AppColors.gold, AppColors.ctaStart],
                        ),
                      ),
                      child: const Center(child: AppMascot(size: 90)),
                    ),
                    const SizedBox(height: 24),
                    _SummaryRow(
                      icon: 'clipboard-check',
                      tint: AppColors.ctaStart,
                      title: 'Your Plan',
                      subtitle: planSubtitle,
                    ),
                    const SizedBox(height: 10),
                    _SummaryRow(
                      icon: 'brain-cog',
                      tint: AppColors.purple,
                      title: 'AI Companion',
                      subtitle: 'Personal coach active 24/7',
                    ),
                    const SizedBox(height: 10),
                    _SummaryRow(
                      icon: 'calendar-plus',
                      tint: AppColors.success,
                      title: 'Daily Routine',
                      subtitle: routineSubtitle,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: GradientPillButton(
                label: 'Start My Glow Up',
                onPressed: () {
                  controller.completeOnboarding();
                  onStart();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.tint,
    required this.title,
    required this.subtitle,
  });

  final String icon;
  final Color tint;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return GlowCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderColor: Colors.white.withValues(alpha: 0.07),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(child: AppIcon(icon, size: 16)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
                ),
                Text(subtitle, style: AppTextStyles.cardSubtitle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
