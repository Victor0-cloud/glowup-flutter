/// The two real tiers Glow Up has. Nothing in this app infers `premium`
/// from any other signal (visiting the paywall, completing onboarding,
/// picking a plan on screen) — it only ever comes from [SubscriptionState.
/// tier], which [SubscriptionController] only ever sets from a real
/// [SubscriptionRepository] entitlement result.
enum SubscriptionTier { free, premium }

/// Individually named premium capabilities. Every current feature gate in
/// this app checks tier-level access (see [SubscriptionController.
/// isEntitled]) rather than per-entitlement logic, since Glow Up does not
/// yet sell partial/à-la-carte access — but call sites already name the
/// specific capability they're gating, so introducing per-entitlement
/// pricing later never requires touching call sites again.
enum FeatureEntitlement {
  aiCoachLive,
  skinAcneScan,
  advancedInsights,
  advancedReports,
  premiumPersonalization,
  expandedHistory,
  premiumRoutines,
  unlimitedPremiumUsage,
}

/// Every real state the subscription system can honestly be in. `premium`
/// is never inferred — only ever set from a real entitlement result.
enum SubscriptionStatus {
  loading,
  free,
  premium,
  expired,
  billingUnavailable,
  restoreInProgress,
  purchaseInProgress,
  purchaseFailed,
}

enum PlanId { monthly, yearly, lifetime }

/// A plan as shown on PW02/PW07. [isDevelopmentPlaceholder] is true for
/// every product this build can currently produce, because no App Store/
/// Google Play product catalog is connected yet (see `SubscriptionRepository`'s
/// doc comment) — the approved PW02/PW07 references show illustrative
/// numbers themselves labeled "(EXAMPLE)"/example pricing, and this app
/// must never present example numbers as real, purchasable prices.
class SubscriptionProduct {
  const SubscriptionProduct({
    required this.planId,
    required this.title,
    required this.priceDisplay,
    this.periodLabel,
    this.badge,
    this.valueLabel,
    this.savingsLabel,
    this.isDevelopmentPlaceholder = true,
  });

  final PlanId planId;
  final String title;
  final String priceDisplay;
  final String? periodLabel;

  /// The pill above the card (PW02_choose_plan.png: "MOST POPULAR").
  final String? badge;

  /// Small text at the top-right of the card, next to [title] (reference:
  /// "Best Value") — distinct from [savingsLabel], which sits lower next
  /// to [periodLabel] (reference: "Save 60%").
  final String? valueLabel;
  final String? savingsLabel;
  final bool isDevelopmentPlaceholder;
}

class SubscriptionState {
  const SubscriptionState({
    this.status = SubscriptionStatus.loading,
    this.tier = SubscriptionTier.free,
    this.activeProductId,
    this.expiresAt,
    this.lastError,
    this.hasSeenOnboardingOffer = false,
  });

  final SubscriptionStatus status;
  final SubscriptionTier tier;
  final PlanId? activeProductId;
  final DateTime? expiresAt;
  final String? lastError;

  /// Whether the once-only onboarding soft offer (PW01 right after
  /// 13_finish_setup) has already been shown/dismissed for this account —
  /// never re-shown automatically once true (see "do not spam users").
  final bool hasSeenOnboardingOffer;

  bool get isPremium => tier == SubscriptionTier.premium;

  SubscriptionState copyWith({
    SubscriptionStatus? status,
    SubscriptionTier? tier,
    PlanId? activeProductId,
    bool clearActiveProductId = false,
    DateTime? expiresAt,
    bool clearExpiresAt = false,
    String? lastError,
    bool clearLastError = false,
    bool? hasSeenOnboardingOffer,
  }) => SubscriptionState(
    status: status ?? this.status,
    tier: tier ?? this.tier,
    activeProductId: clearActiveProductId
        ? null
        : (activeProductId ?? this.activeProductId),
    expiresAt: clearExpiresAt ? null : (expiresAt ?? this.expiresAt),
    lastError: clearLastError ? null : (lastError ?? this.lastError),
    hasSeenOnboardingOffer:
        hasSeenOnboardingOffer ?? this.hasSeenOnboardingOffer,
  );

  Map<String, dynamic> toJson() => {
    'tier': tier.name,
    if (activeProductId != null) 'activeProductId': activeProductId!.name,
    if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
    'hasSeenOnboardingOffer': hasSeenOnboardingOffer,
  };

  factory SubscriptionState.fromJson(Map<String, dynamic> j) =>
      SubscriptionState(
        status: (j['tier'] as String?) == 'premium'
            ? SubscriptionStatus.premium
            : SubscriptionStatus.free,
        tier: j['tier'] == null
            ? SubscriptionTier.free
            : SubscriptionTier.values.byName(j['tier'] as String),
        activeProductId: j['activeProductId'] == null
            ? null
            : PlanId.values.byName(j['activeProductId'] as String),
        expiresAt: j['expiresAt'] == null
            ? null
            : DateTime.parse(j['expiresAt'] as String),
        hasSeenOnboardingOffer: j['hasSeenOnboardingOffer'] as bool? ?? false,
      );
}

/// Where a paywall flow was opened from — governs what "Maybe later" / the
/// PW05 success button return to. Never inferred from the current route,
/// since a feature gate can be reached from many different screens.
enum PaywallOrigin { onboarding, feature, profile }

class PaywallLaunchContext {
  const PaywallLaunchContext({
    required this.origin,
    this.feature,
    this.returnRoute,
  });

  final PaywallOrigin origin;
  final FeatureEntitlement? feature;

  /// The exact route to return to on dismiss/success when [origin] is
  /// [PaywallOrigin.feature] — e.g. the Facial Scan route, so a purchase
  /// that started from tapping a locked feature actually opens that
  /// feature afterward rather than just going to Today.
  final String? returnRoute;
}

/// Carries both the original launch context and the plan the user picked
/// on PW02 forward into PW03, where the real purchase attempt happens.
class PlanSelectionContext {
  const PlanSelectionContext({required this.launch, required this.planId});
  final PaywallLaunchContext launch;
  final PlanId planId;
}

/// PW05's real `extra` payload — [isPreview] true only for the debug-only
/// "visually review PW05 without a real purchase" path from PW04 (see
/// PaywallSuccessScreen.isPreview); never true for a genuine purchase
/// success.
class PaywallSuccessLaunch {
  const PaywallSuccessLaunch({this.launch, this.isPreview = false});
  final PaywallLaunchContext? launch;
  final bool isPreview;
}
