import 'package:flutter/material.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/glow_card.dart';
import '../widgets/onboarding_scaffold.dart';

class _Feature {
  const _Feature(this.icon, this.title, this.subtitle);
  final String icon;
  final String title;
  final String subtitle;
}

const _features = [
  _Feature(
    'feature-workouts',
    'Workouts',
    'Interactive cardio & strength routines',
  ),
  _Feature(
    'feature-nutrition',
    'Nutrition',
    'Personalized meals & macro tracking',
  ),
  _Feature('feature-wellness', 'Wellness', 'Daily physical restoration guide'),
  _Feature(
    'feature-mindmood',
    'Mind & Mood',
    'Guided mindfulness & sleep prep',
  ),
  _Feature(
    'feature-aicoach',
    'AI Coach',
    'Instant answers & supportive messages',
  ),
  _Feature(
    'feature-progress',
    'Track Progress',
    'Weekly summaries & analytics',
  ),
];

/// 01_welcome (node 368:37).
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      title: 'Welcome to Glow Up ✨',
      subtitle:
          'Everything you need to glow every day. All in one place. All for you.',
      progressIndex: 0,
      primaryLabel: 'Next',
      onPrimaryPressed: onNext,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            for (final f in _features) ...[
              GlowCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    AppIcon(f.icon, size: 32),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(f.title, style: AppTextStyles.cardTitle),
                          Text(f.subtitle, style: AppTextStyles.cardSubtitle),
                        ],
                      ),
                    ),
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
