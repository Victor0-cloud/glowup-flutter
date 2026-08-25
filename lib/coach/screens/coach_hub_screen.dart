import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/tod/tod_period.dart';
import '../../core/widgets/ambient_glow.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/bottom_nav_bar.dart';
import '../../core/widgets/gradient_background.dart';
import '../models/coach_models.dart';
import '../theme/coach_variant_config.dart';
import '../widgets/coach_card_widgets.dart';
import '../widgets/coach_hub_widgets.dart';

/// 23a-23d unified (368:2285/2373/2467/2554) — one reusable screen driven
/// by [currentTodPeriodProvider], same architecture as [TodayScreen] and
/// [RoutinesHubScreen]. `onSettings` is a necessary addition: no 23-series
/// frame shows a path to 23h (Coach Settings), so a gear button (using
/// Figma's own exported "settings" icon, node 368:7344, reused from the
/// not-yet-built Profile family) is added next to the mascot avatar —
/// same pattern as the calendar icon added to reach 22g.
class CoachHubScreen extends ConsumerWidget {
  const CoachHubScreen({
    super.key,
    required this.onChat,
    required this.onPlan,
    required this.onMood,
    required this.onSettings,
    required this.onToday,
    required this.onRoutines,
    required this.onProfile,
  });

  final VoidCallback onChat;
  final VoidCallback onPlan;
  final VoidCallback onMood;
  final VoidCallback onSettings;
  final VoidCallback onToday;
  final VoidCallback onRoutines;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(currentTodPeriodProvider);
    final copy = kCoachHubCopy[period]!;
    final variant = CoachVariantConfig.byPeriod[period]!;
    final recentChats = kCoachRecentChats[period]!;

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
                        child: AmbientGlow(
                          color: variant.ambientGlow,
                          size: 280,
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'AI Coach ${copy.emoji}',
                                      style: AppTextStyles.screenTitle.copyWith(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      copy.greeting,
                                      style: AppTextStyles.subtitleLg.copyWith(
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Semantics(
                                button: true,
                                label: 'Coach settings',
                                child: Material(
                                  color: Colors.transparent,
                                  shape: const CircleBorder(),
                                  clipBehavior: Clip.antiAlias,
                                  child: InkWell(
                                    onTap: onSettings,
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.07,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Center(
                                        child: AppIcon(
                                          'settings-gear',
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      AppColors.cardStart,
                                      AppColors.cardEnd,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: AppColors.cardBorder,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: const Text(
                                  '🤖',
                                  style: TextStyle(fontSize: 24),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            children: [
                              CoachActionCircle(
                                emoji: '💬',
                                label: 'Chat',
                                onTap: onChat,
                              ),
                              CoachActionCircle(
                                emoji: '📅',
                                label: 'Plan',
                                onTap: onPlan,
                              ),
                              CoachActionCircle(
                                emoji: '🎭',
                                label: 'Mood',
                                onTap: onMood,
                              ),
                            ],
                          ),
                        ),
                        if (copy.widget != CoachHubWidget.none) ...[
                          const SizedBox(height: 20),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: copy.widget == CoachHubWidget.todaysTarget
                                ? const TodaysTargetWidget()
                                : const SleepTargetWidget(),
                          ),
                        ],
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: CoachTipCard(tip: copy.tip),
                        ),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'RECENT CHATS',
                                style: AppTextStyles.captionBold.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 12),
                              for (var i = 0; i < recentChats.length; i++) ...[
                                ConversationItem(
                                  data: recentChats[i],
                                  onTap: onChat,
                                ),
                                if (i != recentChats.length - 1)
                                  const SizedBox(height: 12),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ],
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
