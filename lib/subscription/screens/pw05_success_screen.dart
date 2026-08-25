import 'package:flutter/material.dart';

import '../../auth/widgets/auth_widgets.dart' show StarMascot;
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/gradient_pill_button.dart';

/// PW05 Success — reached after a real completed purchase, with the
/// approved copy/layout unchanged. [isPreview] is the one addition beyond
/// the reference: a small, honest disclosure line shown ONLY when this
/// screen is opened for dev visual review without a real purchase (see
/// PW04's debug-only preview link) — [SubscriptionController]'s
/// entitlement state is never touched by that path, so a preview visit
/// here can never be confused with (or accidentally grant) real Premium.
class PaywallSuccessScreen extends StatelessWidget {
  const PaywallSuccessScreen({
    super.key,
    required this.onStartExploring,
    this.isPreview = false,
  });

  final VoidCallback onStartExploring;
  final bool isPreview;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const Spacer(flex: 3),
                const StarMascot(size: 140),
                const SizedBox(height: 32),
                Text(
                  "You're all set! 🎉",
                  textAlign: TextAlign.center,
                  style: AppTextStyles.screenTitle.copyWith(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Welcome to Glow Up Premium. Let\'s keep glowing and growing.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.subtitleLg,
                ),
                if (isPreview) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Preview only — no purchase was made.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
                const Spacer(flex: 4),
                GradientPillButton(
                  label: 'Start Glowing',
                  onPressed: onStartExploring,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
