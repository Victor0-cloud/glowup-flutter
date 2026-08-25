import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/state/auth_controller.dart';
import '../../workout/state/workout_history_controller.dart'
    show sharedPreferencesProvider;
import '../analytics/subscription_analytics.dart';
import '../data/subscription_repository.dart';
import '../models/subscription_models.dart';

/// The ONE centralized place every feature-access decision in this app
/// goes through — see `FeatureGate`. No widget anywhere should read
/// `isPremium` off local state directly or invent its own `if (isPremium)`
/// check; they all call [isEntitled] here.
///
/// Real mobile purchase architecture (documented, not yet wired — no
/// `in_app_purchase`/StoreKit/Play Billing package is installed):
/// - iOS: StoreKit 2 via the `in_app_purchase`/`in_app_purchase_storekit`
///   packages, product ids registered in App Store Connect, receipts
///   verified server-side (App Store Server API) before entitlement is
///   granted.
/// - Android: Google Play Billing via `in_app_purchase`/
///   `in_app_purchase_android`, product ids registered in Play Console,
///   receipts verified server-side (Play Developer API / RTDN).
/// - Stripe is NOT the primary in-app mobile subscription mechanism —
///   platform billing is required for iOS/Android per store policy; Stripe
///   would only ever be a secondary/web-only path, and only if explicitly
///   approved later.
/// - Windows (this build's dev target) has no purchasing platform at all;
///   [SubscriptionRepository] honestly reports `billingUnavailable` here,
///   which is the correct, real behavior for a non-purchasing preview
///   target — not a stub to "fix" later.
class SubscriptionController extends StateNotifier<SubscriptionState> {
  SubscriptionController(this._ref)
    : super(const SubscriptionState(status: SubscriptionStatus.loading)) {
    _init();
    _ref.listen(authControllerProvider, (previous, next) {
      final previousId = previous?.valueOrNull?.user.id;
      final nextId = next.valueOrNull?.user.id;
      if (previousId != nextId) _init();
    });
  }

  final Ref _ref;
  SubscriptionRepository? _repo;

  Future<void> get ready => _readyCompleter.future;
  Completer<void> _readyCompleter = Completer<void>();
  bool get isReady => _readyCompleter.isCompleted;

  Future<void> _init() async {
    if (_readyCompleter.isCompleted) _readyCompleter = Completer<void>();
    try {
      final prefs = await _ref.read(sharedPreferencesProvider.future);
      final userId = _ref.read(authControllerProvider).valueOrNull?.user.id;
      final repo = SubscriptionRepository(prefs, userId: userId);
      _repo = repo;
      final loaded = await repo.getCurrentEntitlement();
      if (!_readyCompleter.isCompleted) _readyCompleter.complete();
      state = loaded;
    } finally {
      if (!_readyCompleter.isCompleted) _readyCompleter.complete();
    }
  }

  /// The single access-decision function every feature gate calls.
  /// Deliberately tier-level today (Glow Up sells one Premium tier, not
  /// à-la-carte features) — [feature] is still required so call sites are
  /// self-documenting and never need to change if per-entitlement pricing
  /// is introduced later.
  bool isEntitled(FeatureEntitlement feature) => state.isPremium;

  Future<void> markOnboardingOfferSeen() async {
    state = state.copyWith(hasSeenOnboardingOffer: true);
    await _repo?.save(state);
  }

  Future<List<SubscriptionProduct>> availableProducts() async {
    final repo = _repo;
    if (repo == null) return const [];
    return repo.getAvailableProducts();
  }

  Future<SubscriptionResult> purchase(PlanId planId) async {
    final repo = _repo;
    if (repo == null) {
      return const SubscriptionResult.billingUnavailable(
        'Purchases are not available in this development build.',
      );
    }
    SubscriptionAnalytics.instance.log(
      PurchaseStartedEvent(planId: planId.name),
    );
    state = state.copyWith(status: SubscriptionStatus.purchaseInProgress);
    final result = await repo.purchase(planId);
    switch (result) {
      case SubscriptionSuccess(state: final newState):
        state = newState;
        await repo.save(newState);
        SubscriptionAnalytics.instance.log(
          PurchaseSucceededEvent(planId: planId.name),
        );
      case SubscriptionBillingUnavailable(:final message):
        state = state.copyWith(
          status: SubscriptionStatus.billingUnavailable,
          lastError: message,
        );
        SubscriptionAnalytics.instance.log(
          PurchaseFailedEvent(
            planId: planId.name,
            reason: 'billing_unavailable',
          ),
        );
      case SubscriptionFailure(:final message):
        state = state.copyWith(
          status: SubscriptionStatus.purchaseFailed,
          lastError: message,
        );
        SubscriptionAnalytics.instance.log(
          PurchaseFailedEvent(planId: planId.name, reason: 'failure'),
        );
    }
    return result;
  }

  Future<SubscriptionResult> restorePurchases() async {
    final repo = _repo;
    if (repo == null) {
      return const SubscriptionResult.billingUnavailable(
        'Restore is not available in this development build.',
      );
    }
    SubscriptionAnalytics.instance.log(const RestoreStartedEvent());
    state = state.copyWith(status: SubscriptionStatus.restoreInProgress);
    final result = await repo.restorePurchases();
    switch (result) {
      case SubscriptionSuccess(state: final newState):
        state = newState;
        await repo.save(newState);
        SubscriptionAnalytics.instance.log(const RestoreSucceededEvent());
      case SubscriptionBillingUnavailable(:final message):
        state = state.copyWith(
          status: SubscriptionStatus.billingUnavailable,
          lastError: message,
        );
      case SubscriptionFailure(:final message):
        state = state.copyWith(
          status: SubscriptionStatus.expired,
          lastError: message,
        );
    }
    return result;
  }

  Future<void> refreshEntitlements() async {
    final repo = _repo;
    if (repo == null) return;
    final loaded = await repo.getCurrentEntitlement();
    state = loaded;
  }
}

final subscriptionControllerProvider =
    StateNotifierProvider<SubscriptionController, SubscriptionState>((ref) {
      return SubscriptionController(ref);
    });
