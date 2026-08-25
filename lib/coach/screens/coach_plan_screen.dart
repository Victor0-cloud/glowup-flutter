import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/ambient_glow.dart';
import '../../core/widgets/bottom_nav_bar.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/sub_screen_header.dart';
import '../../subscription/state/subscription_controller.dart';
import '../../subscription/widgets/feature_gate.dart';
import '../models/coach_models.dart';
import '../theme/coach_variant_config.dart';
import '../widgets/plan_and_mood_widgets.dart';

/// 23f_coach_plan (368:2736). The exported frame's own bottom nav
/// highlights "Routines" gold instead of "Coach" — an inconsistency in the
/// source file (23g/23h/23e all correctly highlight their reached-from
/// tab pattern differently too). Since this screen belongs to the Coach
/// family and is reached from the Coach hub, the active tab here follows
/// real navigation state (Coach) rather than that inconsistency, matching
/// how [BottomNavBar] is driven everywhere else in the app.
class CoachPlanScreen extends ConsumerWidget {
  const CoachPlanScreen({
    super.key,
    required this.onBack,
    required this.onToday,
    required this.onRoutines,
    required this.onProfile,
    this.onHydrationTap,
    this.onNutritionTap,
    this.onWellnessCheckInTap,
    this.onCycleTap,
    this.onShopScanTap,
  });

  final VoidCallback onBack;
  final VoidCallback onToday;
  final VoidCallback onRoutines;
  final VoidCallback onProfile;

  /// Real navigation for the Hydration plan row — the "relevant Coach
  /// recommendation" entry point into the Water Tracker. Null-safe/no-op
  /// if not supplied so this screen still renders standalone in tests
  /// that don't care about it. The row's data stays the same static seed
  /// every other row on this screen also uses (Coach itself has no real
  /// recommendation engine yet) — only the navigation is real.
  final VoidCallback? onHydrationTap;

  /// Same pattern as [onHydrationTap] — the Nutrition plan row's real
  /// entry point into Food Scan.
  final VoidCallback? onNutritionTap;

  /// There is no approved "Wellness"/Profile surface yet for a Facial
  /// Scan row to live on, so this is a small, additive, disclosed link
  /// below the existing plan rows rather than a new plan-row visual —
  /// the minimal necessary addition to satisfy "Coach recommendations"
  /// as a real Facial Scan entry point without redesigning this screen's
  /// approved 4-row content.
  final VoidCallback? onWellnessCheckInTap;

  /// Same minimal-additive pattern as [onWellnessCheckInTap] — the real
  /// entry point into Period & Cycle, since there is likewise no
  /// approved plan row for it yet.
  final VoidCallback? onCycleTap;

  /// Same minimal-additive pattern as [onWellnessCheckInTap] — the real
  /// entry point into the Glow Shop Scanner.
  final VoidCallback? onShopScanTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = ref.watch(subscriptionControllerProvider).isPremium;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: 80,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: AmbientGlow(color: AppColors.purple, size: 200),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SubScreenHeader(
                          title: 'Your AI Plan',
                          subtitle: 'Personalized weekly wellness blueprint',
                          onBack: onBack,
                        ),
                        const SizedBox(height: 130),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            children: [
                              for (
                                var i = 0;
                                i < kCoachPlanItems.length;
                                i++
                              ) ...[
                                PlanCardRow(
                                  item: kCoachPlanItems[i],
                                  onTap: switch (kCoachPlanItems[i].title) {
                                    'Hydration' => onHydrationTap,
                                    'Nutrition' => onNutritionTap,
                                    _ => null,
                                  },
                                ),
                                const SizedBox(height: 12),
                              ],
                              Wrap(
                                spacing: 16,
                                runSpacing: 4,
                                children: [
                                  if (onWellnessCheckInTap != null)
                                    TextButton(
                                      onPressed: onWellnessCheckInTap,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Skin & Acne Scan',
                                            style: AppTextStyles.captionBold
                                                .copyWith(
                                                  color: CoachVariantConfig
                                                      .navActiveColor,
                                                  fontSize: 13,
                                                ),
                                          ),
                                          // Skin & Acne Scan stays visible
                                          // to every user — this badge is
                                          // what lets a Free user see it's
                                          // a Premium feature before
                                          // tapping, never a hidden row.
                                          if (!isPremium) ...[
                                            const SizedBox(width: 6),
                                            const PremiumBadge(),
                                          ],
                                        ],
                                      ),
                                    ),
                                  if (onCycleTap != null)
                                    TextButton(
                                      onPressed: onCycleTap,
                                      child: Text(
                                        'Period & Cycle',
                                        style: AppTextStyles.captionBold
                                            .copyWith(
                                              color: CoachVariantConfig
                                                  .navActiveColor,
                                              fontSize: 13,
                                            ),
                                      ),
                                    ),
                                  if (onShopScanTap != null)
                                    TextButton(
                                      onPressed: onShopScanTap,
                                      child: Text(
                                        'Glow Shop Scanner',
                                        style: AppTextStyles.captionBold
                                            .copyWith(
                                              color: CoachVariantConfig
                                                  .navActiveColor,
                                              fontSize: 13,
                                            ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: RoutineGradientButton(
                label: 'Adjust Plan',
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Plan adjustment isn\'t connected yet.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                ),
              ),
            ),
            BottomNavBar(
              active: AppNavTab.coach,
              activeAccent: CoachVariantConfig.navActiveColor,
              onTabSelected: (tab) {
                switch (tab) {
                  case AppNavTab.today:
                    onToday();
                  case AppNavTab.routines:
                    onRoutines();
                  case AppNavTab.coach:
                    break;
                  case AppNavTab.profile:
                    onProfile();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
