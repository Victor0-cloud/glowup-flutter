import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/bottom_nav_bar.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/sub_screen_header.dart';
import '../../mood/models/mood_models.dart';
import '../../mood/state/mood_controller.dart';
import '../models/coach_models.dart';
import '../theme/coach_variant_config.dart';
import '../widgets/plan_and_mood_widgets.dart';

enum _MoodRange { week, month, year }

extension on _MoodRange {
  int get windowDays => switch (this) {
    _MoodRange.week => 7,
    _MoodRange.month => 30,
    _MoodRange.year => 365,
  };
}

const _kWeekdayAbbrev = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// 23g_mood_history (368:2800). Now wired to real, persisted [MoodEntry]
/// data via [moodControllerProvider] — every number here (average, best
/// day, most common reason, daily emotion boxes) is computed from what the
/// user has actually logged, never seed/fabricated data. An honest "no
/// entries yet" state renders when there's nothing to summarize, rather
/// than a fake trend.
class MoodHistoryScreen extends ConsumerStatefulWidget {
  const MoodHistoryScreen({
    super.key,
    required this.onBack,
    required this.onToday,
    required this.onRoutines,
    required this.onProfile,
  });

  final VoidCallback onBack;
  final VoidCallback onToday;
  final VoidCallback onRoutines;
  final VoidCallback onProfile;

  @override
  ConsumerState<MoodHistoryScreen> createState() => _MoodHistoryScreenState();
}

class _MoodHistoryScreenState extends ConsumerState<MoodHistoryScreen> {
  _MoodRange _range = _MoodRange.week;

  @override
  Widget build(BuildContext context) {
    final moodAsync = ref.watch(moodControllerProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SubScreenHeader(
                      title: 'Mood History',
                      subtitle: 'Your emotional trend over time',
                      onBack: widget.onBack,
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          MoodFilterTab(
                            label: 'Week',
                            selected: _range == _MoodRange.week,
                            onTap: () =>
                                setState(() => _range = _MoodRange.week),
                          ),
                          const SizedBox(width: 8),
                          MoodFilterTab(
                            label: 'Month',
                            selected: _range == _MoodRange.month,
                            onTap: () =>
                                setState(() => _range = _MoodRange.month),
                          ),
                          const SizedBox(width: 8),
                          MoodFilterTab(
                            label: 'Year',
                            selected: _range == _MoodRange.year,
                            onTap: () =>
                                setState(() => _range = _MoodRange.year),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    moodAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.purple,
                          ),
                        ),
                      ),
                      error: (err, st) => Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        child: Text(
                          "Couldn't load mood history. Please restart the app.",
                          style: AppTextStyles.subtitle,
                        ),
                      ),
                      data: (moodState) => moodState.entries.isEmpty
                          ? _emptyState()
                          : _content(moodState),
                    ),
                    const SizedBox(height: 24),
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
                    widget.onToday();
                  case AppNavTab.routines:
                    widget.onRoutines();
                  case AppNavTab.coach:
                    break;
                  case AppNavTab.profile:
                    widget.onProfile();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.cardStart, AppColors.cardEnd],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MOOD TREND',
              style: AppTextStyles.captionBold.copyWith(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text('No mood check-ins yet', style: AppTextStyles.cardTitleLg),
            const SizedBox(height: 4),
            Text(
              'Check in from Today\'s Mood quick action to start your history.',
              style: AppTextStyles.subtitle.copyWith(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(MoodState moodState) {
    final windowDays = _range.windowDays;
    final avg = moodState.averageScoreInLastDays(windowDays);
    final best = moodState.bestDayInLastDays(windowDays);
    final commonReason = moodState.mostCommonReasonInLastDays(windowDays);
    final commonLabel =
        commonReason ?? _mostCommonLevelLabel(moodState.inLastDays(windowDays));

    final today = DateTime.now();
    final last7 = [
      for (var i = 6; i >= 0; i--)
        DateTime(today.year, today.month, today.day - i),
    ];
    final dayEntries = [
      for (final d in last7)
        MoodDayEntry(
          day: d.day,
          emoji: moodState.entryFor(d)?.level.emoji ?? '',
          dimmed: moodState.entryFor(d) == null,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.cardStart, AppColors.cardEnd],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'MOOD TREND',
                      style: AppTextStyles.captionBold.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      avg == null
                          ? 'Avg: —'
                          : 'Avg: ${avg.toStringAsFixed(1)}/5',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.gold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final d in last7)
                      _TrendBar(
                        entry: moodState.entryFor(d),
                        label: _kWeekdayAbbrev[d.weekday - 1],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.cardStart, AppColors.cardEnd],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DAILY EMOTIONS',
                  style: AppTextStyles.captionBold.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final entry in dayEntries) MoodDayBox(entry: entry),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              MoodStatCard(
                label: 'Best Day',
                value: best == null
                    ? '—'
                    : _kWeekdayAbbrev[best.date.weekday - 1],
                color: best?.level.color ?? AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              MoodStatCard(
                label: 'Common',
                value: commonLabel ?? '—',
                color: AppColors.ctaStart,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String? _mostCommonLevelLabel(List<MoodEntry> entries) {
    if (entries.isEmpty) return null;
    final counts = <MoodLevel, int>{};
    for (final e in entries) {
      counts[e.level] = (counts[e.level] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => b.value > a.value ? b : a).key.label;
  }
}

class _TrendBar extends StatelessWidget {
  const _TrendBar({required this.entry, required this.label});

  final MoodEntry? entry;
  final String label;

  @override
  Widget build(BuildContext context) {
    final score = entry?.level.score ?? 0;
    final height = 8.0 + score * 12.0; // 0 (no entry) .. 68 (amazing)
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 68,
          alignment: Alignment.bottomCenter,
          child: Container(
            width: 12,
            height: height,
            decoration: BoxDecoration(
              color: entry == null
                  ? Colors.white.withValues(alpha: 0.08)
                  : entry!.level.color,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: AppTextStyles.caption.copyWith(fontSize: 10)),
      ],
    );
  }
}
