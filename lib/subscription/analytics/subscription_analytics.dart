/// Paywall/subscription analytics events. Every payload here is limited to
/// subscription-mechanics fields (plan id, feature name, screen name,
/// error code) — never journal text, cycle notes, face scan contents,
/// food photos, AI Coach conversation content, or any other private
/// wellness content. This module makes no network call itself (no
/// analytics SDK is wired into this project yet); [SubscriptionAnalytics]
/// is the one place events are named/shaped so wiring a real sink later
/// never requires touching call sites.
library;

sealed class SubscriptionEvent {
  const SubscriptionEvent(this.name);
  final String name;
  Map<String, Object?> get payload;
}

class PaywallViewedEvent extends SubscriptionEvent {
  const PaywallViewedEvent({required this.screen, required this.origin})
    : super('paywall_viewed');
  final String screen;
  final String origin;
  @override
  Map<String, Object?> get payload => {'screen': screen, 'origin': origin};
}

class PremiumFeatureTappedEvent extends SubscriptionEvent {
  const PremiumFeatureTappedEvent({required this.feature})
    : super('premium_feature_tapped');
  final String feature;
  @override
  Map<String, Object?> get payload => {'feature': feature};
}

class PlanSelectedEvent extends SubscriptionEvent {
  const PlanSelectedEvent({required this.planId}) : super('plan_selected');
  final String planId;
  @override
  Map<String, Object?> get payload => {'planId': planId};
}

class PurchaseStartedEvent extends SubscriptionEvent {
  const PurchaseStartedEvent({required this.planId})
    : super('purchase_started');
  final String planId;
  @override
  Map<String, Object?> get payload => {'planId': planId};
}

class PurchaseSucceededEvent extends SubscriptionEvent {
  const PurchaseSucceededEvent({required this.planId})
    : super('purchase_succeeded');
  final String planId;
  @override
  Map<String, Object?> get payload => {'planId': planId};
}

class PurchaseFailedEvent extends SubscriptionEvent {
  const PurchaseFailedEvent({required this.planId, required this.reason})
    : super('purchase_failed');
  final String planId;
  final String reason;
  @override
  Map<String, Object?> get payload => {'planId': planId, 'reason': reason};
}

class RestoreStartedEvent extends SubscriptionEvent {
  const RestoreStartedEvent() : super('restore_started');
  @override
  Map<String, Object?> get payload => const {};
}

class RestoreSucceededEvent extends SubscriptionEvent {
  const RestoreSucceededEvent() : super('restore_succeeded');
  @override
  Map<String, Object?> get payload => const {};
}

/// Records events for later inspection/testing — a real sink (e.g. an
/// analytics SDK's `logEvent`) can replace `_log`'s body without changing
/// any call site. Kept in-memory only; never persisted, never sent
/// anywhere, matching this app's existing "no network call" convention
/// for anything not explicitly a backend feature.
class SubscriptionAnalytics {
  SubscriptionAnalytics._();
  static final SubscriptionAnalytics instance = SubscriptionAnalytics._();

  final List<SubscriptionEvent> recorded = [];

  void log(SubscriptionEvent event) {
    recorded.add(event);
  }
}
