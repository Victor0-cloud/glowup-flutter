import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/gradient_pill_button.dart';
import '../../core/widgets/sub_screen_header.dart';

/// PW04 Restore / Terms — "You're in Control". Restore Purchases here
/// calls the real `SubscriptionRepository.restorePurchases()`; on Windows
/// (no purchasing platform connected) that honestly reports
/// [SubscriptionStatus.billingUnavailable] rather than faking a restored
/// purchase — see [statusText].
class RestoreTermsScreen extends StatelessWidget {
  const RestoreTermsScreen({
    super.key,
    required this.onRestorePurchases,
    required this.onContinue,
    this.onBack,
    this.statusText,
    this.restoring = false,
    this.onPreviewSuccess,
  });

  final VoidCallback onRestorePurchases;
  final VoidCallback onContinue;
  final VoidCallback? onBack;
  final String? statusText;
  final bool restoring;

  /// Debug-only (only ever rendered when [kDebugMode] is true — see
  /// [build]): lets the owner visually review PW05 without a real
  /// purchase existing on this platform, per the explicit "Windows
  /// billing unavailable != paywall navigation unavailable" requirement.
  /// Never touches entitlement state — see PaywallSuccessScreen.isPreview.
  final VoidCallback? onPreviewSuccess;

  static const _bullets = [
    'Cancel anytime in your account settings.',
    'Your data stays private and secure.',
    'By continuing you agree to our Terms of Service and Privacy Policy.',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              SubScreenHeader(title: "You're in Control", onBack: onBack),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < _bullets.length; i++) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.gold.withValues(alpha: 0.16),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${i + 1}',
                                style: AppTextStyles.captionBold.copyWith(
                                  color: AppColors.gold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _bullets[i],
                                style: AppTextStyles.subtitle.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (statusText != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          statusText!,
                          style: AppTextStyles.caption.copyWith(fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: restoring ? null : onRestorePurchases,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: restoring
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Restore Purchases',
                                style: AppTextStyles.captionBold.copyWith(
                                  color: Colors.white,
                                  fontSize: 15,
                                ),
                              ),
                      ),
                    ),
                    if (kDebugMode && onPreviewSuccess != null) ...[
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: onPreviewSuccess,
                        child: Text(
                          'Preview: Success page (dev only)',
                          style: AppTextStyles.caption.copyWith(fontSize: 12),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    GradientPillButton(
                      label: 'Continue',
                      onPressed: onContinue,
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
