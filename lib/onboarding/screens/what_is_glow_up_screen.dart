import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/ambient_glow.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/glow_card.dart';
import '../widgets/onboarding_scaffold.dart';

class _Point {
  const _Point(this.title, this.description);
  final String title;
  final String description;
}

const _points = [
  _Point(
    'Your Wellness Companion',
    'A cheerful space tracking your fitness and mental clarity.',
  ),
  _Point(
    'Smart Daily Routines',
    'Customized micro-habits that fit your personal workflow.',
  ),
  _Point(
    'AI-Powered Guidance',
    'Intelligent coaching keeping your focus warm and sharp.',
  ),
];

/// 02_what_is_glow_up (node 368:94).
class WhatIsGlowUpScreen extends StatelessWidget {
  const WhatIsGlowUpScreen({super.key, required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      title: 'What is Glow Up',
      progressIndex: 1,
      primaryLabel: 'Next',
      onPrimaryPressed: onNext,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            GlowCard(
              padding: const EdgeInsets.all(20),
              radius: 24,
              child: SizedBox(
                height: 160,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Ambient-Glow (368:105) sits behind the mascot, centered,
                    // larger than the mascot itself, per the approved frame.
                    const AmbientGlow(color: AppColors.gold, size: 160),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const AppMascot(size: 100),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const AppIcon('sparkles', size: 12),
                            const SizedBox(width: 6),
                            Text(
                              'Your cheerful personal guide',
                              style: AppTextStyles.cardSubtitleMd,
                            ),
                            const SizedBox(width: 6),
                            const AppIcon('sparkles', size: 12),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            for (final p in _points) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: AppIcon(
                        'sparkles',
                        size: 12,
                        color: AppColors.gold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.title, style: AppTextStyles.cardTitle),
                        const SizedBox(height: 2),
                        Text(
                          p.description,
                          style: AppTextStyles.cardSubtitleMd,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}
