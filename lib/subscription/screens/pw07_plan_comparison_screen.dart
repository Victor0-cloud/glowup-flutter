import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/gradient_pill_button.dart';
import '../../core/widgets/sub_screen_header.dart';
import '../models/subscription_models.dart';

/// PW07 Plan Comparison — the approved reference's own pricing column is
/// literally titled "PRICING (EXAMPLE)"; this screen keeps that exact
/// framing rather than presenting [products] as real, purchasable prices.
class PlanComparisonScreen extends StatelessWidget {
  const PlanComparisonScreen({
    super.key,
    required this.products,
    this.onBack,
    this.onContinue,
  });

  final List<SubscriptionProduct> products;
  final VoidCallback? onBack;
  final VoidCallback? onContinue;

  static const _rows = [
    ('AI Coach', 'Limited', true),
    ('Skin & Acne Scan', '—', true),
    ('Period & Cycle Insights', 'Basic', true),
    ('Workouts & Routines', 'Basic', true),
    ('Pre-Swim & Recovery', '—', true),
    ('Advanced Progress', '—', true),
    ('Monthly Reports', 'Limited', true),
    ('Ad-Free', '—', true),
    ('Cloud Sync', '—', true),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              SubScreenHeader(title: 'PLAN COMPARISON', onBack: onBack),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Table(
                          border: TableBorder.all(
                            color: AppColors.cardBorder,
                            borderRadius: BorderRadius.circular(AppRadii.sm),
                          ),
                          columnWidths: const {
                            0: FixedColumnWidth(180),
                            1: FixedColumnWidth(70),
                            2: FixedColumnWidth(100),
                          },
                          children: [
                            TableRow(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.04),
                              ),
                              children: [
                                const _Cell('Features', bold: true),
                                const _Cell('Free', bold: true),
                                Container(
                                  color: AppColors.gold.withValues(alpha: 0.12),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 10,
                                  ),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.workspace_premium,
                                          color: AppColors.gold,
                                          size: 13,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          'Premium',
                                          style: AppTextStyles.captionBold
                                              .copyWith(
                                                fontSize: 11,
                                                color: AppColors.gold,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            for (final row in _rows)
                              TableRow(
                                children: [
                                  _Cell(row.$1),
                                  _Cell(row.$2),
                                  Container(
                                    color: AppColors.gold.withValues(
                                      alpha: 0.06,
                                    ),
                                    child: _CheckCell(row.$3),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'PRICING (EXAMPLE)',
                        style: AppTextStyles.fieldLabel,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Development placeholder — pricing not yet approved.',
                        style: AppTextStyles.caption.copyWith(fontSize: 11),
                      ),
                      const SizedBox(height: 12),
                      for (final product in products) ...[
                        _PricingCard(product: product),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
              ),
              if (onContinue != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: GradientPillButton(
                    label: 'Choose a Plan',
                    onPressed: onContinue,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reference (PW07_plan_comparison.png): each plan card is tinted with its
/// own accent color (Yearly gold, Monthly blue, Lifetime purple) rather
/// than sharing one neutral card style, and shows the same price/period/
/// savings detail as PW02's cards.
class _PricingCard extends StatelessWidget {
  const _PricingCard({required this.product});
  final SubscriptionProduct product;

  Color get _accent => switch (product.planId) {
    PlanId.yearly => AppColors.gold,
    PlanId.monthly => AppColors.blue,
    PlanId.lifetime => AppColors.purple,
  };

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.title, style: AppTextStyles.cardTitle),
                Text(
                  product.priceDisplay,
                  style: AppTextStyles.cardTitle.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (product.periodLabel != null)
                  Text(
                    product.periodLabel!,
                    style: AppTextStyles.caption.copyWith(fontSize: 11),
                  ),
              ],
            ),
          ),
          if (product.savingsLabel != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell(this.text, {this.bold = false});
  final String text;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Text(
        text,
        style: (bold ? AppTextStyles.captionBold : AppTextStyles.caption)
            .copyWith(fontSize: 12, color: AppColors.textSecondary),
      ),
    );
  }
}

class _CheckCell extends StatelessWidget {
  const _CheckCell(this.checked);
  final bool checked;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: checked
            ? const Icon(Icons.check_circle, color: AppColors.gold, size: 18)
            : Text('—', style: AppTextStyles.caption),
      ),
    );
  }
}
