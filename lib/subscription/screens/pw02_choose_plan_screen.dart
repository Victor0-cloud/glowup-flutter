import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/gradient_pill_button.dart';
import '../../core/widgets/sub_screen_header.dart';
import '../models/subscription_models.dart';

/// PW02 Choose Your Plan. Prices come from [products] (see
/// `SubscriptionRepository.getAvailableProducts` — every entry is a
/// disclosed development placeholder until real App Store/Play Billing
/// product ids and owner-approved pricing exist).
class ChoosePlanScreen extends StatefulWidget {
  const ChoosePlanScreen({
    super.key,
    required this.products,
    required this.onContinue,
    required this.onRestorePurchases,
    this.onComparePlans,
    this.onSeeWhatsIncluded,
    this.onBack,
  });

  final List<SubscriptionProduct> products;
  final ValueChanged<PlanId> onContinue;
  final VoidCallback onRestorePurchases;
  final VoidCallback? onComparePlans;

  /// The real entry point into PW06 (Premium Features Overview) — that
  /// screen has no on-screen button of its own in the approved reference,
  /// so this link is what makes it reachable at all rather than a dead
  /// route (see item 5's "no screen may become a dead end").
  final VoidCallback? onSeeWhatsIncluded;
  final VoidCallback? onBack;

  @override
  State<ChoosePlanScreen> createState() => _ChoosePlanScreenState();
}

class _ChoosePlanScreenState extends State<ChoosePlanScreen> {
  PlanId? _selected;

  @override
  void initState() {
    super.initState();
    final popular = widget.products.where((p) => p.badge != null);
    _selected = popular.isNotEmpty
        ? popular.first.planId
        : (widget.products.isNotEmpty ? widget.products.first.planId : null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              SubScreenHeader(
                title: 'Choose Your Plan',
                subtitle: 'Cancel anytime. No commitments.',
                onBack: widget.onBack,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final product in widget.products) ...[
                        _PlanCard(
                          product: product,
                          selected: _selected == product.planId,
                          onTap: () =>
                              setState(() => _selected = product.planId),
                        ),
                        const SizedBox(height: 14),
                      ],
                      Text(
                        'Development placeholder — pricing not yet approved.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.caption.copyWith(fontSize: 11),
                      ),
                      if (widget.onComparePlans != null ||
                          widget.onSeeWhatsIncluded != null) ...[
                        const SizedBox(height: 8),
                        Center(
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            children: [
                              if (widget.onSeeWhatsIncluded != null)
                                TextButton(
                                  onPressed: widget.onSeeWhatsIncluded,
                                  child: Text(
                                    "See what's included",
                                    style: AppTextStyles.captionBold.copyWith(
                                      color: AppColors.gold,
                                    ),
                                  ),
                                ),
                              if (widget.onComparePlans != null)
                                TextButton(
                                  onPressed: widget.onComparePlans,
                                  child: Text(
                                    'Compare plans',
                                    style: AppTextStyles.captionBold.copyWith(
                                      color: AppColors.gold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
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
                    GradientPillButton(
                      label: 'Continue',
                      onPressed: _selected == null
                          ? null
                          : () => widget.onContinue(_selected!),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: widget.onRestorePurchases,
                      child: Text(
                        'Restore Purchases',
                        style: AppTextStyles.subtitle.copyWith(
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
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

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.product,
    required this.selected,
    required this.onTap,
  });

  final SubscriptionProduct product;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: selected
                    ? const LinearGradient(
                        colors: [
                          AppColors.selectedStart,
                          AppColors.selectedEnd,
                        ],
                      )
                    : const LinearGradient(
                        colors: [AppColors.cardStart, AppColors.cardEnd],
                      ),
                borderRadius: BorderRadius.circular(AppRadii.lg),
                border: Border.all(
                  color: selected ? AppColors.gold : AppColors.cardBorder,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          product.title,
                          style: AppTextStyles.cardTitleLg.copyWith(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (product.valueLabel != null)
                        Text(
                          product.valueLabel!,
                          style: AppTextStyles.captionBold.copyWith(
                            color: AppColors.gold,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.priceDisplay,
                              style: AppTextStyles.cardTitle.copyWith(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: AppColors.gold,
                              ),
                            ),
                            if (product.periodLabel != null)
                              Text(
                                product.periodLabel!,
                                style: AppTextStyles.caption,
                              ),
                          ],
                        ),
                      ),
                      if (product.savingsLabel != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            product.savingsLabel!,
                            style: AppTextStyles.captionBold.copyWith(
                              color: AppColors.success,
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (product.badge != null)
              Positioned(
                top: -10,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    product.badge!.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0A0B1E),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
