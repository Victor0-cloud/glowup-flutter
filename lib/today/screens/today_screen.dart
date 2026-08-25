import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../brain/batch/pattern_promotion_job.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/bottom_nav_bar.dart';
import '../../core/widgets/dev_tod_picker.dart';
import '../../core/widgets/gradient_background.dart';
import '../models/today_models.dart';
import '../state/today_state_provider.dart';
import '../theme/today_variant_config.dart';
import '../widgets/ai_coach_tip_card.dart';
import '../widgets/daily_progress_card.dart';
import '../widgets/glow_score_card.dart';
import '../widgets/quick_actions_row.dart';
import '../widgets/today_header.dart';
import '../widgets/up_next_card.dart';

/// The single reusable Today Dashboard (covers 20a-20d/368:885,980,1075,1170).
/// Which of the 4 approved variants renders is resolved automatically from
/// [currentTodPeriodProvider] — this is intentionally one screen with a
/// data-driven variant, not four separate screen implementations.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({
    super.key,
    required this.onWorkout,
    required this.onWater,
    required this.onMood,
    required this.onJournal,
    required this.onGlowScore,
    required this.onCoach,
    required this.onUpNext,
    required this.onRoutines,
    required this.onProfile,
  });

  final VoidCallback onWorkout;
  final VoidCallback onWater;
  final VoidCallback onMood;
  final VoidCallback onJournal;
  final VoidCallback onGlowScore;
  final VoidCallback onCoach;
  final VoidCallback onUpNext;
  final VoidCallback onRoutines;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(todayStateProvider);

    if (state == null) {
      // Reached /today without a completed Brain context (e.g. deep link
      // during dev). Nothing to render a dashboard from yet.
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: GradientBackground(
          child: Center(
            child: Text(
              'Complete onboarding first.',
              style: AppTextStyles.subtitle,
            ),
          ),
        ),
      );
    }

    // Tier 4 — fires the lazy batch-promotion check at most once per app
    // session (FutureProvider caches after its first run); this is what
    // actually calls it in the running app, closing the gap where
    // `BatchScheduler.runIfDue()` was built and tested but never invoked
    // from anywhere real. The result is discarded here — nothing in this
    // screen needs to react to it directly.
    ref.watch(batchOnStartupProvider);

    final variant = TodayVariantConfig.byPeriod[state.period]!;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: Column(
          children: [
            if (kDebugMode) const DevTodPicker(),
            TodayHeader(name: state.greetingName, variant: variant),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GlowScoreCard(
                      summary: state.glowScore,
                      ringGradient: variant.scoreRingGradient,
                      onTap: onGlowScore,
                    ),
                    const SizedBox(height: 20),
                    QuickActionsRow(
                      accent: variant.accent,
                      onSelect: (type) => _onQuickAction(type),
                    ),
                    const SizedBox(height: 20),
                    UpNextCard(
                      plan: state.plan,
                      accent: variant.accent,
                      onTap: onUpNext,
                    ),
                    const SizedBox(height: 20),
                    DailyProgressCard(
                      rows: state.progress,
                      barColor: variant.progressBarColor,
                    ),
                    const SizedBox(height: 20),
                    AiCoachTipCard(insight: state.coachTip, onTap: onCoach),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            BottomNavBar(
              active: AppNavTab.today,
              activeAccent: variant.accent,
              onTabSelected: (tab) {
                switch (tab) {
                  case AppNavTab.today:
                    break;
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

  void _onQuickAction(QuickActionType type) {
    switch (type) {
      case QuickActionType.workout:
        onWorkout();
      case QuickActionType.water:
        onWater();
      case QuickActionType.mood:
        onMood();
      case QuickActionType.journal:
        onJournal();
    }
  }
}
