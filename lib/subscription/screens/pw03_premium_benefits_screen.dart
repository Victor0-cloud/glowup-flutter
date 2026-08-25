import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/gradient_pill_button.dart';
import '../../core/widgets/sub_screen_header.dart';

/// PW03 Premium Benefits — replicates the approved
/// `PW03_premium_benefits.png` exactly: title, exactly these 6 rows in
/// this order (icon + title + subtitle, no checkmarks — those only
/// appear on PW07's comparison table), and a single Continue button.
/// Deliberately no extra links/content beyond what the reference shows —
/// PW06 (Premium Features Overview) is reached from PW02 instead, not
/// from here.
class PremiumBenefitsScreen extends StatelessWidget {
  const PremiumBenefitsScreen({
    super.key,
    required this.onContinue,
    this.onBack,
    this.errorText,
    this.loading = false,
  });

  final VoidCallback onContinue;
  final VoidCallback? onBack;
  final String? errorText;
  final bool loading;

  static const _benefits = [
    (
      Icons.support_agent,
      AppColors.blue,
      'AI Coach',
      'Personalized plans, answers and motivation 24/7',
    ),
    (
      Icons.center_focus_strong,
      AppColors.purple,
      'Skin & Acne Scan',
      'Premium analysis and personalized care tips',
    ),
    (
      Icons.favorite,
      AppColors.ctaStart,
      'Period & Cycle Insights',
      'Track, predict and understand your cycle better',
    ),
    (
      Icons.bar_chart,
      AppColors.purple,
      'Advanced Progress',
      'Detailed stats, trends and monthly reports',
    ),
    (
      Icons.pool,
      AppColors.pinkSubtle,
      'Pre-Swim & Recovery',
      'Expert routines to prepare and recover your body',
    ),
    (
      Icons.block,
      AppColors.orange,
      'Ad-Free Experience',
      'Focus on you. Zero distractions.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              SubScreenHeader(title: 'Unlock Your Best Glow', onBack: onBack),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final b in _benefits) ...[
                        _BenefitRow(
                          icon: b.$1,
                          color: b.$2,
                          title: b.$3,
                          subtitle: b.$4,
                        ),
                        const SizedBox(height: 14),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Column(
                  children: [
                    // Unobtrusive, never blocks Continue/navigation — see
                    // SubscriptionRepository's doc comment: Windows has no
                    // purchasing platform, so this is the honest outcome
                    // here, not an error to work around.
                    if (errorText != null) ...[
                      Text(
                        errorText!,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.caption.copyWith(fontSize: 11),
                      ),
                      const SizedBox(height: 8),
                    ],
                    GradientPillButton(
                      label: 'Continue',
                      loading: loading,
                      onPressed: loading ? null : onContinue,
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

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({
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
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.cardTitle),
                Text(subtitle, style: AppTextStyles.cardSubtitle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
