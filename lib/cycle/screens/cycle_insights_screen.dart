import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glow_card.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/sub_screen_header.dart';
import '../state/cycle_controller.dart';

/// PC08 Cycle Insights — real, deterministic patterns computed from stored
/// data only (see [CycleState.energyLowerOnPeriodDaysInsight]). Shows an
/// honest "not enough data yet" state rather than a fabricated pattern when
/// fewer than 3 real data points exist in either bucket. The design
/// reference's "Workout pattern" narrative card and 7-bucket bar chart
/// aren't backed by any real cross-module computation in this app yet, so
/// they're intentionally omitted here rather than invented.
class CycleInsightsScreen extends ConsumerWidget {
  const CycleInsightsScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cycleAsync = ref.watch(cycleControllerProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: Column(
          children: [
            SubScreenHeader(
              title: 'Cycle Insights',
              subtitle: 'Observed patterns—not diagnoses or proven causes.',
              onBack: onBack ?? () => Navigator.maybePop(context),
            ),
            Expanded(
              child: cycleAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.purple),
                ),
                error: (e, st) => Center(
                  child: Text(
                    "Couldn't load Period & Cycle.",
                    style: AppTextStyles.subtitle,
                  ),
                ),
                data: (state) {
                  final insight = state.energyLowerOnPeriodDaysInsight;
                  final cycleCount = state.recordedPeriodCount;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GlowCard(
                          borderColor: AppColors.purple.withValues(alpha: 0.4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.auto_awesome,
                                    size: 16,
                                    color: AppColors.purple,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'ENERGY PATTERN',
                                    style: AppTextStyles.captionBold.copyWith(
                                      color: AppColors.purple,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                insight == null
                                    ? 'Not enough data yet'
                                    : 'Your energy was usually lower on period days 1-2',
                                style: AppTextStyles.cardTitleLg.copyWith(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                insight == null
                                    ? 'Log your energy on at least 3 period days and 3 other days to see a real pattern here.'
                                    : 'Based on $cycleCount recorded ${cycleCount == 1 ? 'cycle' : 'cycles'}',
                                style: AppTextStyles.subtitle.copyWith(
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Energy across your cycle',
                          style: AppTextStyles.cardTitleLg.copyWith(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        GlowCard(
                          child: insight == null
                              ? Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  child: Text(
                                    "Not enough data yet — this compares your real logged energy on period days vs. other days once there's enough history.",
                                    style: AppTextStyles.subtitle.copyWith(
                                      fontSize: 13,
                                    ),
                                  ),
                                )
                              : SizedBox(
                                  height: 140,
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _EnergyBar(
                                        label: 'Period days',
                                        value: insight.periodDaysAvg,
                                        color: AppColors.ctaStart,
                                      ),
                                      _EnergyBar(
                                        label: 'Other days',
                                        value: insight.otherDaysAvg,
                                        color: AppColors.purple,
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.success.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CONNECTED INSIGHT',
                                style: AppTextStyles.captionBold.copyWith(
                                  color: AppColors.success,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Sleep, hydration, food and notes can add context here once you turn on Cycle-aware suggestions and AI memory in Cycle Privacy.',
                                style: AppTextStyles.subtitle.copyWith(
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EnergyBar extends StatelessWidget {
  const _EnergyBar({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final heightFraction = (value / 5).clamp(0.1, 1.0);
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          value.toStringAsFixed(1),
          style: AppTextStyles.captionBold.copyWith(color: color, fontSize: 13),
        ),
        const SizedBox(height: 6),
        Container(
          width: 56,
          height: 90 * heightFraction,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: AppTextStyles.caption.copyWith(fontSize: 12)),
      ],
    );
  }
}
