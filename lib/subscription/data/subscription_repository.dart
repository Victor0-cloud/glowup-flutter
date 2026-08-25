import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/subscription_models.dart';

/// The one production-ready abstraction over "what plan is this account
/// entitled to, and can they buy one." No App Store (StoreKit) or Google
/// Play Billing package is installed in this project yet — see the
/// architecture note in `SubscriptionController`'s doc comment for what
/// that integration will look like — so every purchase/restore call here
/// honestly reports [SubscriptionStatus.billingUnavailable] rather than
/// fabricating a completed sale. [getCurrentEntitlement] and
/// [getAvailableProducts] never invent a `premium` result: entitlement can
/// only ever come from a real completed purchase (which this build cannot
/// produce) or a previously-persisted real entitlement.
///
/// Persists locally (SharedPreferences), namespaced per authenticated user
/// id — same pattern as `ProfileRepository`/`OnboardingRepository` — so
/// entitlement is tied to the account, never inferred from display name or
/// email. A server-side entitlement table (validated against real App
/// Store/Play receipts) is the natural next step once real billing exists;
/// not built here since there is no real receipt to validate yet (see the
/// final report's "billing pieces still requiring configuration").
class SubscriptionRepository {
  SubscriptionRepository(this._prefs, {String? userId})
    : _key = userId == null
          ? 'subscription_state_v1'
          : 'subscription_state_v1_$userId';

  final SharedPreferences _prefs;
  final String _key;

  SubscriptionState load() {
    final raw = _prefs.getString(_key);
    if (raw == null) {
      return const SubscriptionState(status: SubscriptionStatus.free);
    }
    final loaded = SubscriptionState.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
    // A restart never silently keeps a stale "loading"/"in progress" status.
    final status = loaded.tier == SubscriptionTier.premium
        ? SubscriptionStatus.premium
        : SubscriptionStatus.free;
    return loaded.copyWith(status: status);
  }

  Future<void> save(SubscriptionState state) {
    return _prefs.setString(_key, jsonEncode(state.toJson()));
  }

  /// The plans PW02/PW07 render. The approved reference's own PW07 frame
  /// labels this column "PRICING (EXAMPLE)" — these numbers are that same
  /// example copy, never claimed as real/purchasable. `isDevelopmentPlaceholder`
  /// stays true on every entry until a real product catalog (StoreKit /
  /// Play Billing) is wired in and approved pricing is documented — see
  /// the final report's explicit pricing note.
  Future<List<SubscriptionProduct>> getAvailableProducts() async {
    return const [
      SubscriptionProduct(
        planId: PlanId.yearly,
        title: 'Yearly',
        priceDisplay: '\$39.99 / year',
        periodLabel: '\$3.33 / month',
        badge: 'Most Popular',
        valueLabel: 'Best Value',
        savingsLabel: 'Save 60%',
      ),
      SubscriptionProduct(
        planId: PlanId.monthly,
        title: 'Monthly',
        priceDisplay: '\$9.99 / month',
      ),
      SubscriptionProduct(
        planId: PlanId.lifetime,
        title: 'Lifetime',
        priceDisplay: '\$149.99',
        periodLabel: 'One-time payment',
      ),
    ];
  }

  /// Real state only — never upgrades tier as a side effect of being
  /// called. Returns whatever was last persisted (or Free, honestly, if
  /// nothing was ever purchased).
  Future<SubscriptionState> getCurrentEntitlement() async => load();

  Future<SubscriptionResult> purchase(PlanId planId) async {
    // No StoreKit/Play Billing package is integrated — never fabricate a
    // completed sale. This is the one, honest, truthful outcome until real
    // billing exists.
    return const SubscriptionResult.billingUnavailable(
      'Purchases are not available in this development build.',
    );
  }

  Future<SubscriptionResult> restorePurchases() async {
    return const SubscriptionResult.billingUnavailable(
      'Restore is not available in this development build — no purchase '
      'platform is connected yet.',
    );
  }
}

/// The real, typed outcome of a purchase/restore attempt — callers switch
/// on this rather than guessing from a thrown exception or a boolean.
sealed class SubscriptionResult {
  const SubscriptionResult();

  const factory SubscriptionResult.success(SubscriptionState state) =
      SubscriptionSuccess;
  const factory SubscriptionResult.billingUnavailable(String message) =
      SubscriptionBillingUnavailable;
  const factory SubscriptionResult.failure(String message) =
      SubscriptionFailure;
}

class SubscriptionSuccess extends SubscriptionResult {
  const SubscriptionSuccess(this.state);
  final SubscriptionState state;
}

class SubscriptionBillingUnavailable extends SubscriptionResult {
  const SubscriptionBillingUnavailable(this.message);
  final String message;
}

class SubscriptionFailure extends SubscriptionResult {
  const SubscriptionFailure(this.message);
  final String message;
}
