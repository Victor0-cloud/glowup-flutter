import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/glow_card.dart';
import '../widgets/onboarding_scaffold.dart';

class _BenefitData {
  const _BenefitData(this.title, this.description, this.dotIcon);
  final String title;
  final String description;
  final String dotIcon;
}

// Each of the 4 benefit rows has its own distinctly-colored bullet dot in
// Figma (green / purple / blue / pink) — not the same dot reused 4x.
const _benefits = [
  _BenefitData(
    'Build Healthy Habits',
    'Consistency made light, natural and highly rewarding.',
    'dot',
  ),
  _BenefitData(
    'Personalized Plans',
    'Every flow crafted specifically around your schedule.',
    'dot-purple',
  ),
  _BenefitData(
    'Track Everything',
    'Log workouts, nutrition, mood and daily hydration.',
    'dot-blue',
  ),
  _BenefitData(
    'Feel Amazing',
    'Step forward into a sustainable, glowing wellness state.',
    'dot-pink',
  ),
];

/// 04_benefits (node 368:191).
class BenefitsScreen extends StatelessWidget {
  const BenefitsScreen({super.key, required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      title: 'Benefits',
      subtitle: 'Small steps today, big transformations tomorrow.',
      progressIndex: 3,
      primaryLabel: 'Continue',
      onPrimaryPressed: onNext,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            GlowCard(
              radius: 24,
              child: Row(
                children: [
                  const AppMascot(size: 72),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Unlock your full glow!',
                          style: AppTextStyles.cardTitle.copyWith(
                            color: AppColors.gold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Small daily actions accumulate into major health breakthroughs.',
                          style: AppTextStyles.cardSubtitle,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            for (final b in _benefits) ...[
              GlowCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        AppIcon(b.dotIcon, size: 8),
                        const SizedBox(width: 8),
                        Text(b.title, style: AppTextStyles.cardTitle),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(b.description, style: AppTextStyles.cardSubtitleMd),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}
