import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_icon.dart';
import '../models/onboarding_profile.dart';
import '../state/onboarding_controller.dart';
import '../widgets/onboarding_scaffold.dart';

/// 08_fitness_level (node 368:511). Single-select.
class FitnessLevelScreen extends ConsumerWidget {
  const FitnessLevelScreen({super.key, required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);

    return OnboardingScaffold(
      title: 'Fitness Level 💪',
      subtitle: "Where are you right now? Let's choose the optimal intensity.",
      progressIndex: 1,
      primaryLabel: 'Next',
      primaryEnabled: profile.fitnessLevel != null,
      onPrimaryPressed: profile.fitnessLevel != null
          ? () {
              controller.advanceStep(OnboardingStep.schedule);
              onNext();
            }
          : null,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            for (final level in FitnessLevel.values) ...[
              _LevelCard(
                level: level,
                selected: profile.fitnessLevel == level,
                onTap: () => controller.setFitnessLevel(level),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.level,
    required this.selected,
    required this.onTap,
  });

  final FitnessLevel level;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: selected
                  ? const [AppColors.selectedStart, AppColors.selectedEnd]
                  : const [AppColors.cardStart, AppColors.cardEnd],
            ),
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(
              color: selected ? AppColors.gold : AppColors.cardBorder,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.2)
                      : AppColors.pinkSubtle,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: AppIcon(
                    level.icon,
                    size: 24,
                    color: selected ? AppColors.onSelected : AppColors.ctaStart,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      level.label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: selected ? AppColors.onSelected : Colors.white,
                        fontFamily: AppTextStyles.cardTitle.fontFamily,
                      ),
                    ),
                    Text(
                      level.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: selected
                            ? AppColors.onSelected.withValues(alpha: 0.8)
                            : AppColors.textSecondary,
                        fontFamily: AppTextStyles.cardSubtitleMd.fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
