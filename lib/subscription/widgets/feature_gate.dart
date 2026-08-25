import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../analytics/subscription_analytics.dart';
import '../models/subscription_models.dart';
import '../state/subscription_controller.dart';

/// The one reusable gate every premium-feature entry point calls through —
/// never a scattered `if (isPremium)` in a screen. Premium users open the
/// feature directly; Free users see the contextual paywall (PW01) instead,
/// with a return path back to the feature once real entitlement is
/// granted (see `PaywallLaunchContext.returnRoute`).
void openGatedFeature(
  BuildContext context,
  WidgetRef ref, {
  required FeatureEntitlement feature,
  required String featureName,
  required VoidCallback onOpen,
  required String returnRoute,
}) {
  final entitled = ref
      .read(subscriptionControllerProvider.notifier)
      .isEntitled(feature);
  if (entitled) {
    onOpen();
    return;
  }
  SubscriptionAnalytics.instance.log(
    PremiumFeatureTappedEvent(feature: feature.name),
  );
  context.push(
    '/paywall',
    extra: PaywallLaunchContext(
      origin: PaywallOrigin.feature,
      feature: feature,
      returnRoute: returnRoute,
    ),
  );
}

/// Small, tasteful "Premium" pill — shown next to a feature's label so
/// Free users can see the feature exists and what tier it needs, per the
/// explicit "do not hide Skin & Acne Scan" requirement. Never rendered for
/// an already-entitled Premium user.
class PremiumBadge extends StatelessWidget {
  const PremiumBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
      ),
      child: Text(
        'Premium',
        style: AppTextStyles.caption.copyWith(
          color: AppColors.gold,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}
