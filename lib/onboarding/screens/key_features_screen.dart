import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/glow_card.dart';
import '../../core/widgets/gradient_pill_button.dart';
import '../widgets/onboarding_scaffold.dart';

class _KeyFeature {
  const _KeyFeature(this.icon, this.title, this.tint, this.description);
  final String icon;
  final String title;
  final Color tint;
  final String description;
}

const _keyFeatures = [
  _KeyFeature(
    'dumbbell',
    'Smart Exercise Tracking',
    AppColors.ctaStart,
    'Interactive cardio and strength routines that adapt to your fitness level, log every rep, and adjust as you progress.',
  ),
  _KeyFeature(
    'message-circle-heart',
    'AI Coach Guidance',
    AppColors.purple,
    'An always-on coach that answers questions, checks in on how you\'re doing, and nudges you when it helps.',
  ),
  _KeyFeature(
    'calendar-cog',
    'Personalized Plans',
    AppColors.orange,
    'Daily routines built around your goals, fitness level, and the schedule you choose during setup.',
  ),
  _KeyFeature(
    'chart-line',
    'Track Progress',
    AppColors.blue,
    'Weekly summaries and analytics so you can see exactly how far you\'ve come, at a glance.',
  ),
  _KeyFeature(
    'utensils',
    'Food & Nutrition',
    AppColors.success,
    'Personalized meals and macro tracking that fit your goals, without the manual spreadsheet work.',
  ),
  _KeyFeature(
    'book-heart',
    'Mood & Journal',
    AppColors.lavenderAccent,
    'A private space to log how you\'re feeling and reflect on your day, whenever you need it.',
  ),
];

/// 03_key_features (node 368:140). Rows carry chevrons in the approved
/// design, signalling they're tappable — each opens a lightweight detail
/// sheet (not a navigation away from onboarding) and returns here.
class KeyFeaturesScreen extends StatelessWidget {
  const KeyFeaturesScreen({super.key, required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      title: 'Key Features',
      subtitle: 'Premium tools tuned specifically for your balance',
      progressIndex: 2,
      primaryLabel: 'Next',
      onPrimaryPressed: onNext,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            for (final f in _keyFeatures) ...[
              Semantics(
                button: true,
                label: '${f.title}. Tap for details.',
                child: GlowCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  onTap: () => _showFeatureDetail(context, f),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: f.tint.withValues(alpha: 0.11),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(child: AppIcon(f.icon, size: 22)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(f.title, style: AppTextStyles.cardTitle),
                      ),
                      const AppIcon(
                        'chevron-right',
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  void _showFeatureDetail(BuildContext context, _KeyFeature f) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _FeatureDetailSheet(feature: f),
    );
  }
}

class _FeatureDetailSheet extends StatelessWidget {
  const _FeatureDetailSheet({required this.feature});

  final _KeyFeature feature;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.cardStart, AppColors.cardEnd],
          ),
          borderRadius: BorderRadius.circular(AppRadii.xl),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: feature.tint.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(child: AppIcon(feature.icon, size: 26)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    feature.title,
                    style: AppTextStyles.screenTitle.copyWith(fontSize: 20),
                  ),
                ),
                Semantics(
                  button: true,
                  label: 'Close',
                  child: Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              feature.description,
              style: AppTextStyles.subtitle.copyWith(height: 1.5),
            ),
            const SizedBox(height: 24),
            GradientPillButton(
              label: 'Got it',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
