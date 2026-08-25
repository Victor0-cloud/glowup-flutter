import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glow_card.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/sub_screen_header.dart';
import '../../subscription/models/subscription_models.dart';
import '../../subscription/state/subscription_controller.dart';

/// Profile → Subscription. Shows the real, current entitlement — never a
/// fake "Premium Active" status — and links into the real PW01-PW07
/// paywall flow (never a dead-end snackbar).
class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({
    super.key,
    this.onBack,
    this.onViewPlans,
    this.onRestorePurchases,
    this.onViewBenefits,
  });

  final VoidCallback? onBack;
  final VoidCallback? onViewPlans;
  final VoidCallback? onRestorePurchases;
  final VoidCallback? onViewBenefits;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscription = ref.watch(subscriptionControllerProvider);
    final isPremium = subscription.isPremium;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: Column(
          children: [
            SubScreenHeader(
              title: 'Subscription',
              onBack: onBack ?? () => Navigator.maybePop(context),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GlowCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isPremium
                                    ? Icons.workspace_premium
                                    : Icons.workspace_premium_outlined,
                                color: isPremium
                                    ? AppColors.gold
                                    : AppColors.textSecondary,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                isPremium ? 'Glow Up Premium' : 'Glow Up Free',
                                style: AppTextStyles.cardTitleLg.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isPremium
                                ? "You're on Glow Up Premium."
                                : "You're currently on the free plan.",
                            style: AppTextStyles.subtitle.copyWith(
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _ActionRow(
                      label: isPremium ? 'Manage Plan' : 'View Plans',
                      onTap: onViewPlans,
                    ),
                    const SizedBox(height: 12),
                    _ActionRow(
                      label: 'Restore Purchases',
                      onTap: onRestorePurchases,
                    ),
                    const SizedBox(height: 12),
                    _ActionRow(label: 'View Benefits', onTap: onViewBenefits),
                    if (subscription.status ==
                        SubscriptionStatus.billingUnavailable) ...[
                      const SizedBox(height: 16),
                      Text(
                        subscription.lastError ??
                            'Purchases are not available in this development build.',
                        style: AppTextStyles.caption.copyWith(fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.label, this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 48),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Text(
              label,
              style: AppTextStyles.captionBold.copyWith(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
