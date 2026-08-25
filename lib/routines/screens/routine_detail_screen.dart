import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/ambient_glow.dart';
import '../../core/widgets/bottom_nav_bar.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/sub_screen_header.dart';
import '../models/routine_models.dart';
import '../state/routines_controller.dart';
import '../theme/routines_variant_config.dart';
import '../widgets/routine_step_row.dart';

/// 22e_routine_detail (368:1956).
class RoutineDetailScreen extends ConsumerWidget {
  const RoutineDetailScreen({
    super.key,
    required this.routineId,
    required this.onToday,
    required this.onRoutines,
    required this.onCoach,
    required this.onProfile,
  });

  final String routineId;
  final VoidCallback onToday;
  final VoidCallback onRoutines;
  final VoidCallback onCoach;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routines = ref.watch(routinesControllerProvider);
    Routine? routine;
    for (final r in routines) {
      if (r.id == routineId) {
        routine = r;
        break;
      }
    }

    if (routine == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: GradientBackground(
          child: SubScreenHeader(
            title: 'Routine not found',
            onBack: onRoutines,
          ),
        ),
      );
    }
    final routine_ = routine;

    final accent = routine_.theme.color;
    final today = DateTime.now();
    ref.watch(
      routineCompletionsControllerProvider,
    ); // subscribe so toggles rebuild this screen
    final completion = ref
        .read(routineCompletionsControllerProvider.notifier)
        .completionFor(routine_.id, today);
    final completedCount = completion.completedActivityIds.length;

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
                      top: -40,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: AmbientGlow(color: accent, size: 220),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SubScreenHeader(
                          title: routine_.title,
                          subtitle: routine_.subtitle,
                          onBack: onRoutines,
                        ),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  emoji: '🔥',
                                  value: routine_.hasStreak
                                      ? '${routine_.streakDays} days'
                                      : '0 days',
                                  label: 'Streak',
                                  color: AppColors.gold,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _StatCard(
                                  emoji: '🎯',
                                  value: '${routine_.activities.length} Steps',
                                  label: 'Total tasks',
                                  color: AppColors.ctaStart,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _StatCard(
                                  emoji: '⏱',
                                  value: '${routine_.totalMinutes} min',
                                  label: 'Duration',
                                  color: AppColors.lavenderAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ROUTINE STEPS',
                                style: AppTextStyles.captionBold.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 12),
                              for (
                                var i = 0;
                                i < routine_.activities.length;
                                i++
                              ) ...[
                                RoutineStepRow(
                                  index: i + 1,
                                  activity: routine_.activities[i],
                                  done: completion.isActivityDone(
                                    routine_.activities[i].id,
                                  ),
                                  accent: accent,
                                  onToggle: () => ref
                                      .read(
                                        routineCompletionsControllerProvider
                                            .notifier,
                                      )
                                      .toggleActivity(
                                        routine_.id,
                                        today,
                                        routine_.activities[i].id,
                                      ),
                                ),
                                const SizedBox(height: 12),
                              ],
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
                label: completedCount == routine_.activities.length
                    ? 'Routine Complete ✨'
                    : 'Start Routine',
                onPressed: completedCount == routine_.activities.length
                    ? null
                    : () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Routine started — check off each step as you go.',
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      ),
              ),
            ),
            BottomNavBar(
              active: AppNavTab.routines,
              activeAccent: RoutinesVariantConfig.navActiveColor,
              onTabSelected: (tab) {
                switch (tab) {
                  case AppNavTab.today:
                    onToday();
                  case AppNavTab.routines:
                    onRoutines();
                  case AppNavTab.coach:
                    onCoach();
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

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.emoji,
    required this.value,
    required this.label,
    required this.color,
  });

  final String emoji;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.cardStart, AppColors.cardEnd],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              fontFamily: AppTextStyles.cardTitle.fontFamily,
            ),
          ),
          Text(label, style: AppTextStyles.caption.copyWith(fontSize: 11)),
        ],
      ),
    );
  }
}
