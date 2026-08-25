import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glow_card.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/sub_screen_header.dart';
import '../../onboarding/models/onboarding_profile.dart';
import '../../onboarding/state/onboarding_controller.dart';

/// Goals & Preferences — the real [OnboardingProfile.goals] set, editable
/// here the same way onboarding's own goals screen edits it. No
/// completion percentages are shown for any goal — none are tracked
/// anywhere in this app yet, and the approved design's demo percentages
/// are not real data.
class GoalsPreferencesScreen extends ConsumerWidget {
  const GoalsPreferencesScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: Column(
          children: [
            SubScreenHeader(
              title: 'Goals & Preferences',
              subtitle: 'Your goals help personalize your plan',
              onBack: onBack ?? () => Navigator.maybePop(context),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (profile.goals.isEmpty) ...[
                      Text(
                        'No goals selected yet.',
                        style: AppTextStyles.subtitle,
                      ),
                      const SizedBox(height: 16),
                    ],
                    for (final goal in Goal.values) ...[
                      _GoalRow(
                        goal: goal,
                        selected: profile.goals.contains(goal),
                        onTap: () => controller.toggleGoal(goal),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({
    required this.goal,
    required this.selected,
    required this.onTap,
  });

  final Goal goal;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: goal.label,
      child: GlowCard(
        onTap: onTap,
        borderColor: selected ? AppColors.purple : AppColors.cardBorder,
        child: Row(
          children: [
            Expanded(
              child: Text(
                goal.label,
                style: AppTextStyles.cardTitle.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selected ? AppColors.purple : AppColors.textSecondary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
