import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/gradient_pill_button.dart';

/// 00_splash (node 368:12). Entry point — collects nothing; Brain
/// initialization here is just session-start bookkeeping per the Figma
/// annotation, which this pass doesn't need to persist anywhere yet.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, required this.onGetStarted});

  final VoidCallback onGetStarted;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  AppIcon('sparkles', size: 20),
                  // Distinct asset from 'sparkles' — a denser purple
                  // (#C084FC) sparkle cluster, not the single gold sparkle.
                  AppIcon('sparkles-cluster', size: 14),
                ],
              ),
              const Spacer(),
              const AppMascot(size: 130),
              const SizedBox(height: 32),
              // FittedBox keeps this from overflowing at the true 402px
              // mobile frame width — "glow up" in Rubik Black + the
              // sparkle mark is wider than the available space once the
              // app is correctly constrained to mobile width.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text('glow up', style: AppTextStyles.heroTitle),
                    const SizedBox(width: 6),
                    const AppIcon('sparkles', size: 28, color: AppColors.gold),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your journey to a healthier, happier you',
                textAlign: TextAlign.center,
                style: AppTextStyles.subtitleLg,
              ),
              const Spacer(),
              GradientPillButton(label: 'Get Started', onPressed: onGetStarted),
              const SizedBox(height: 24),
              Opacity(
                opacity: 0.6,
                child: Text(
                  'Premium Wellness Ecosystem',
                  style: AppTextStyles.caption,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
