// Covers the real paywall + entitlement architecture: centralized
// SubscriptionController/EntitlementService, FeatureGate (Skin & Acne Scan
// stays visible with a Premium badge, never hidden), the once-only
// onboarding soft offer, PW01-PW07 navigation with working back buttons,
// truthful purchase/restore outcomes (never a fabricated sale), and
// analytics events that never carry private wellness content.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:glow_up/app/glow_up_app.dart';
import 'package:glow_up/coach/screens/coach_plan_screen.dart';
import 'package:glow_up/profile/screens/subscription_screen.dart';
import 'package:glow_up/routing/app_router.dart';
import 'package:glow_up/subscription/analytics/subscription_analytics.dart';
import 'package:glow_up/subscription/data/subscription_repository.dart';
import 'package:glow_up/subscription/models/subscription_models.dart';
import 'package:glow_up/subscription/screens/pw02_choose_plan_screen.dart';
import 'package:glow_up/subscription/screens/pw03_premium_benefits_screen.dart';
import 'package:glow_up/subscription/screens/pw04_restore_terms_screen.dart';
import 'package:glow_up/subscription/screens/pw06_features_overview_screen.dart';
import 'package:glow_up/subscription/screens/pw07_plan_comparison_screen.dart';
import 'package:glow_up/subscription/state/subscription_controller.dart';

Future<ProviderContainer> _boot(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(402, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final container = ProviderContainer();
  addTearDown(container.dispose);
  appRouter.go(AppRoutes.today);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const GlowUpApp()),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('1-2. Free tier never blocks Today/Free features', () {
    test(
      'a fresh SubscriptionController defaults to Free, never Premium',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        await container.read(subscriptionControllerProvider.notifier).ready;
        expect(
          container.read(subscriptionControllerProvider).isPremium,
          isFalse,
        );
      },
    );

    test(
      "Today's route never calls the feature gate — Free users are never blocked from it",
      () {
        final content = File('lib/routing/app_router.dart').readAsStringSync();
        final todayBlock = content.substring(
          content.indexOf("path: AppRoutes.today,"),
        );
        final nextRoute = todayBlock.indexOf('GoRoute(', 1);
        final block = todayBlock.substring(
          0,
          nextRoute == -1 ? todayBlock.length : nextRoute,
        );
        expect(block.contains('openGatedFeature'), isFalse);
      },
    );
  });

  group('3-5. Skin & Acne Scan: visible, badged, gated', () {
    testWidgets(
      '3. Skin & Acne Scan stays visible to a Free user, with a Premium badge',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(402, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var tapped = false;
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: CoachPlanScreen(
                onBack: () {},
                onToday: () {},
                onRoutines: () {},
                onProfile: () {},
                onWellnessCheckInTap: () => tapped = true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Skin & Acne Scan'),
          findsOneWidget,
          reason: 'requirement: never hidden, even though it is Premium',
        );
        expect(find.text('Premium'), findsOneWidget);
        await tester.tap(find.text('Skin & Acne Scan'));
        expect(tapped, isTrue, reason: 'still fully tappable for a Free user');
      },
    );

    testWidgets(
      '4. a Free user tapping Skin & Acne Scan is routed to the contextual paywall (PW01), never the real feature',
      (tester) async {
        await _boot(tester);
        appRouter.go(AppRoutes.coachPlan);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Skin & Acne Scan'));
        await tester.pumpAndSettle();

        expect(appRouter.state.matchedLocation, AppRoutes.paywallEntry);
        expect(find.textContaining('Unlock Premium'), findsWidgets);
      },
    );

    testWidgets(
      '5. a Premium entitlement opens Skin & Acne Scan directly, bypassing the paywall entirely',
      (tester) async {
        final container = await _boot(tester);
        await container.read(subscriptionControllerProvider.notifier).ready;
        container
            .read(subscriptionControllerProvider.notifier)
            .state = const SubscriptionState(
          status: SubscriptionStatus.premium,
          tier: SubscriptionTier.premium,
        );

        appRouter.go(AppRoutes.coachPlan);
        await tester.pumpAndSettle();
        expect(
          find.text('Premium'),
          findsNothing,
          reason: 'a Premium user never sees their own feature badged',
        );

        await tester.tap(find.text('Skin & Acne Scan'));
        // Bounded pumps, not pumpAndSettle — Facial Scan's real camera/
        // permission UI can keep scheduling frames indefinitely, which is
        // unrelated to what this test is actually verifying (routing).
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        expect(
          appRouter.state.matchedLocation,
          AppRoutes.facialScan,
          reason: 'requirement 5: Premium bypasses the paywall',
        );
      },
    );
  });

  group('6-8. Onboarding soft offer', () {
    testWidgets(
      '6/7. onboarding finish opens PW01, and "Maybe later" leads to Today',
      (tester) async {
        await _boot(tester);
        appRouter.go(
          AppRoutes.paywallEntry,
          extra: const PaywallLaunchContext(origin: PaywallOrigin.onboarding),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('Unlock Premium'), findsWidgets);
        expect(find.text('Maybe later'), findsOneWidget);

        await tester.tap(find.text('Maybe later'));
        await tester.pumpAndSettle();

        expect(appRouter.state.matchedLocation, AppRoutes.today);
      },
    );

    test(
      '8. "Maybe later" (hasSeenOnboardingOffer) survives a real relaunch, never re-shown automatically',
      () async {
        final firstRun = ProviderContainer();
        await firstRun.read(subscriptionControllerProvider.notifier).ready;
        await firstRun
            .read(subscriptionControllerProvider.notifier)
            .markOnboardingOfferSeen();
        firstRun.dispose();

        final secondRun = ProviderContainer();
        addTearDown(secondRun.dispose);
        await secondRun.read(subscriptionControllerProvider.notifier).ready;
        expect(
          secondRun.read(subscriptionControllerProvider).hasSeenOnboardingOffer,
          isTrue,
        );
      },
    );

    test(
      '16. Bluebook onboarding order is unchanged — 13_finish_setup still marks onboardingComplete itself, only its destination changed',
      () {
        final content = File(
          'lib/onboarding/screens/finish_setup_screen.dart',
        ).readAsStringSync();
        expect(content.contains('completeOnboarding()'), isTrue);
        expect(content.contains("'Start My Glow Up'"), isTrue);
        final routerContent = File(
          'lib/routing/app_router.dart',
        ).readAsStringSync();
        expect(
          routerContent.contains('AppRoutes.paywallEntry'),
          isTrue,
          reason:
              'onboarding now leads into the soft offer, not Today directly',
        );
        // The full 00->13 sequence itself (each screen pushing the next)
        // is untouched — same routes, same order, verified already by
        // onboarding_resume_test.dart's end-to-end walkthrough.
      },
    );
  });

  group('9. Profile -> Subscription is real, never a dead end', () {
    testWidgets(
      'shows real Free/Premium state and a working View Plans action',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(402, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var viewPlansTapped = false;
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: SubscriptionScreen(
                onViewPlans: () => viewPlansTapped = true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Glow Up Free'), findsOneWidget);
        expect(
          find.textContaining('not available'),
          findsNothing,
          reason: 'the old snackbar dead-end must be gone',
        );
        await tester.tap(find.text('View Plans'));
        expect(viewPlansTapped, isTrue);
      },
    );
  });

  group('10-12. Purchase/restore are truthful, never fabricated', () {
    test(
      '11/12. purchase and restore both honestly report billingUnavailable in this dev build, never a fabricated success — user stays Free',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(
          subscriptionControllerProvider.notifier,
        );
        await controller.ready;

        final purchaseResult = await controller.purchase(PlanId.monthly);
        expect(purchaseResult, isA<SubscriptionBillingUnavailable>());
        expect(
          container.read(subscriptionControllerProvider).isPremium,
          isFalse,
        );

        final restoreResult = await controller.restorePurchases();
        expect(restoreResult, isA<SubscriptionBillingUnavailable>());
        expect(
          container.read(subscriptionControllerProvider).isPremium,
          isFalse,
        );
      },
    );

    test(
      '10. entitlement state updates immediately (no restart) once tier becomes Premium',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        await container.read(subscriptionControllerProvider.notifier).ready;
        expect(
          container.read(subscriptionControllerProvider).isPremium,
          isFalse,
        );

        // Simulates what SubscriptionController.purchase does internally
        // on a real SubscriptionSuccess result (see its `case
        // SubscriptionSuccess(state: final newState): state = newState;`)
        // — `state` is @visibleForTesting on StateNotifier specifically
        // for asserting this reactivity without needing a real store.
        container
            .read(subscriptionControllerProvider.notifier)
            .state = const SubscriptionState(
          status: SubscriptionStatus.premium,
          tier: SubscriptionTier.premium,
        );
        expect(
          container.read(subscriptionControllerProvider).isPremium,
          isTrue,
          reason: 'no app restart required',
        );
      },
    );
  });

  group('13. Entitlement logic is centralized', () {
    test(
      'no widget outside the subscription module (and its two real call sites) checks isPremium directly — every gate goes through SubscriptionController.isEntitled/openGatedFeature',
      () {
        final allowed = {
          'lib/coach/screens/coach_plan_screen.dart',
          'lib/profile/screens/subscription_screen.dart',
        };
        final dir = Directory('lib');
        for (final file in dir.listSync(recursive: true).whereType<File>()) {
          if (!file.path.endsWith('.dart')) continue;
          final relPath = file.path.replaceAll('\\', '/');
          if (relPath.contains('lib/subscription/')) continue;
          if (!relPath.contains('.dart')) continue;
          final content = file.readAsStringSync();
          if (content.contains('isPremium')) {
            final isAllowed = allowed.any((a) => relPath.endsWith(a));
            expect(
              isAllowed,
              isTrue,
              reason:
                  '$relPath checks isPremium directly instead of going through '
                  'SubscriptionController.isEntitled/openGatedFeature',
            );
          }
        }
      },
    );
  });

  group('14. Analytics never carry private wellness content', () {
    test(
      'event payloads are limited to subscription-mechanics fields only',
      () {
        const forbidden = [
          'journal',
          'cycleNote',
          'faceScan',
          'foodPhoto',
          'coachMessage',
          'healthDetail',
        ];
        final events = [
          const PaywallViewedEvent(screen: 'PW01', origin: 'onboarding'),
          const PremiumFeatureTappedEvent(feature: 'skinAcneScan'),
          const PlanSelectedEvent(planId: 'yearly'),
          const PurchaseStartedEvent(planId: 'yearly'),
          const PurchaseSucceededEvent(planId: 'yearly'),
          const PurchaseFailedEvent(
            planId: 'yearly',
            reason: 'billing_unavailable',
          ),
          const RestoreStartedEvent(),
          const RestoreSucceededEvent(),
        ];
        for (final event in events) {
          for (final key in event.payload.keys) {
            expect(
              forbidden.contains(key),
              isFalse,
              reason: '${event.name} payload must never carry $key',
            );
          }
        }
      },
    );
  });

  group('15. Back navigation works on every paywall page', () {
    testWidgets('PW02 back works', (tester) async {
      var backTapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: ChoosePlanScreen(
            products: const [],
            onContinue: (_) {},
            onRestorePurchases: () {},
            onBack: () => backTapped = true,
          ),
        ),
      );
      await tester.tap(find.bySemanticsLabel('Back'));
      expect(backTapped, isTrue);
    });

    testWidgets('PW03 back works', (tester) async {
      var backTapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: PremiumBenefitsScreen(
            onContinue: () {},
            onBack: () => backTapped = true,
          ),
        ),
      );
      await tester.tap(find.bySemanticsLabel('Back'));
      expect(backTapped, isTrue);
    });

    testWidgets('PW04 back works', (tester) async {
      var backTapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: RestoreTermsScreen(
            onRestorePurchases: () {},
            onContinue: () {},
            onBack: () => backTapped = true,
          ),
        ),
      );
      await tester.tap(find.bySemanticsLabel('Back'));
      expect(backTapped, isTrue);
    });

    testWidgets('PW06 back works', (tester) async {
      var backTapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: FeaturesOverviewScreen(onBack: () => backTapped = true),
        ),
      );
      await tester.tap(find.bySemanticsLabel('Back'));
      expect(backTapped, isTrue);
    });

    testWidgets('PW07 back works', (tester) async {
      var backTapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: PlanComparisonScreen(
            products: const [],
            onBack: () => backTapped = true,
          ),
        ),
      );
      await tester.tap(find.bySemanticsLabel('Back'));
      expect(backTapped, isTrue);
    });
  });

  group('pricing is never invented from code', () {
    test(
      'every product from SubscriptionRepository is marked isDevelopmentPlaceholder',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final repo = SubscriptionRepository(prefs);
        final products = await repo.getAvailableProducts();
        expect(products, isNotEmpty);
        for (final p in products) {
          expect(
            p.isDevelopmentPlaceholder,
            isTrue,
            reason:
                '${p.title} must be marked as a development placeholder until '
                'real App Store/Play Billing products and approved pricing exist',
          );
        }
      },
    );
  });
}
