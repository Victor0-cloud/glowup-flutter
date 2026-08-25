import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/sub_screen_header.dart';

/// PW06 Premium Features Overview — informational only (no purchase
/// action on this screen in the approved reference); back navigation is
/// the only way forward/out, matching PW06's own layout.
class FeaturesOverviewScreen extends StatelessWidget {
  const FeaturesOverviewScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  // Order matches the reference's 2-column grid exactly, row by row:
  // AI Coach / Skin & Acne Scan, Period & Cycle Insights / Advanced
  // Progress, Pre-Swim & Recovery / Unlimited Access.
  static const _features = [
    (
      Icons.support_agent,
      AppColors.blue,
      'AI Coach',
      'Real conversations, adaptive plans and smart recommendations.',
    ),
    (
      Icons.center_focus_strong,
      AppColors.purple,
      'Skin & Acne Scan',
      'Advanced analysis with personalized skincare guidance.',
    ),
    (
      Icons.favorite_border,
      AppColors.ctaStart,
      'Period & Cycle Insights',
      'Track your cycle, symptoms, mood and predictions.',
    ),
    (
      Icons.bar_chart,
      AppColors.orange,
      'Advanced Progress',
      'Deep insights, trends and monthly reports.',
    ),
    (
      Icons.pool,
      AppColors.success,
      'Pre-Swim & Recovery',
      'Expert routines to prepare and recover your body.',
    ),
    (
      Icons.shield_outlined,
      AppColors.purple,
      'Unlimited Access',
      'All features, all the time. No limits.',
    ),
  ];

  static const _includes = [
    (Icons.block_flipped, 'Ad-Free'),
    (Icons.cloud_outlined, 'Cloud Sync'),
    (Icons.support_agent_outlined, 'Priority Support'),
    (Icons.bolt_outlined, 'Early Access'),
    (Icons.workspace_premium_outlined, 'Exclusive Content'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              SubScreenHeader(
                title: 'PREMIUM FEATURES OVERVIEW',
                onBack: onBack,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final f in _features)
                            SizedBox(
                              width:
                                  (MediaQuery.of(context).size.width -
                                      24 * 2 -
                                      12) /
                                  2,
                              child: _FeatureCard(
                                icon: f.$1,
                                color: f.$2,
                                title: f.$3,
                                subtitle: f.$4,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text('Also includes:', style: AppTextStyles.fieldLabel),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 20,
                        runSpacing: 12,
                        children: [
                          for (final i in _includes)
                            Column(
                              children: [
                                Icon(
                                  i.$1,
                                  color: AppColors.textSecondary,
                                  size: 22,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  i.$2,
                                  style: AppTextStyles.caption.copyWith(
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.cardStart, AppColors.cardEnd],
        ),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(title, style: AppTextStyles.cardTitle.copyWith(fontSize: 13)),
          const SizedBox(height: 4),
          Text(subtitle, style: AppTextStyles.caption.copyWith(fontSize: 11)),
        ],
      ),
    );
  }
}
