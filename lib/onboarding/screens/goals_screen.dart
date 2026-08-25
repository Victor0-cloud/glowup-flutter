import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_icon.dart';
import '../models/onboarding_profile.dart';
import '../state/onboarding_controller.dart';
import '../widgets/onboarding_scaffold.dart';

/// 07_goals (node 368:461). Multi-select. The 8 chips here are exactly
/// what's rendered on the approved screen (see [Goal] doc comment for why
/// this differs from the frame's own dev annotation).
class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key, required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);

    return OnboardingScaffold(
      title: 'Your Goals ✨',
      subtitle:
          'What matters most to you? Choose all that apply to tailor your guide.',
      progressIndex: 0,
      primaryLabel: 'Next',
      primaryEnabled: profile.goals.isNotEmpty,
      onPrimaryPressed: profile.goals.isNotEmpty
          ? () {
              controller.advanceStep(OnboardingStep.fitnessLevel);
              onNext();
            }
          : null,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            for (final goal in Goal.values) ...[
              _GoalChip(
                goal: goal,
                selected: profile.goals.contains(goal),
                onTap: () => controller.toggleGoal(goal),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _GoalChip extends StatelessWidget {
  const _GoalChip({
    required this.goal,
    required this.selected,
    required this.onTap,
  });

  final Goal goal;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        onTap: onTap,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: selected
                  ? const [AppColors.selectedStart, AppColors.selectedEnd]
                  : const [AppColors.cardStart, AppColors.cardEnd],
            ),
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(
              color: selected ? AppColors.gold : AppColors.cardBorder,
            ),
          ),
          child: Row(
            children: [
              // Figma's static mock exports each icon pre-colored for
              // whichever state that particular chip happened to be shown
              // in (dark #0A0B1E on the 4 "selected" chips, muted #B0B5E3
              // on the other 4) — since every chip here is a real toggle
              // that can be either state, both are applied dynamically
              // rather than baked per-icon.
              AppIcon(
                goal.icon,
                size: 20,
                color: selected
                    ? AppColors.onSelected
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  goal.label,
                  style: selected
                      ? AppTextStyles.chipLabelSelected
                      : AppTextStyles.chipLabel,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
