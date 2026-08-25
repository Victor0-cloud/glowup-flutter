import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/tod/tod_period.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/dev_tod_picker.dart';
import '../../core/widgets/glow_card.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/sub_screen_header.dart';
import '../models/cycle_models.dart' show CycleDayEntry;
import '../theme/cycle_variant_config.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../state/cycle_controller.dart';

/// PC03 Cycle Home — the real entry point once tracking is enabled.
/// Shows current cycle day (never a phase/fertility label — "day N" only,
/// per the no-fertility-claims rule), the next-period estimate (null,
/// never guessed, until real history exists), today's latest logged
/// energy/mood, and real this-cycle stats. This screen itself never calls
/// an AI provider — the "Glow Up Brain" card ([_GlowUpBrainCard]) shows a
/// real, data-grounded suggestion computed locally from the same
/// `CycleState`/`CycleDayEntry` fields the AI Coach itself now receives
/// (see `CoachBrainContext`) — the Coach *is* genuinely connected as of
/// the Period & Cycle integration pass, this card just doesn't trigger a
/// live network call merely by being on screen.
///
/// Unlike its GPT-designed reference (which shows no back affordance,
/// having been drawn as if Cycle were a 5th bottom-nav tab), this screen is
/// a *pushed* route in the app's real 4-tab architecture — so it uses the
/// same [SubScreenHeader] back chevron every other pushed Cycle screen
/// uses. Omitting it (as the original reference implies) left this the one
/// page in the module with no way back on Windows, where there is no OS
/// back gesture to fall back on.
class CycleHomeScreen extends ConsumerWidget {
  const CycleHomeScreen({
    super.key,
    this.onBack,
    this.onSettings,
    this.onLogPeriod,
    this.onDailyCheckIn,
    this.onCalendar,
    this.onInsights,
  });

  final VoidCallback? onBack;
  final VoidCallback? onSettings;
  final VoidCallback? onLogPeriod;
  final VoidCallback? onDailyCheckIn;
  final VoidCallback? onCalendar;
  final VoidCallback? onInsights;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(currentTodPeriodProvider);
    final variant = CycleVariantConfig.byPeriod[period]!;
    final cycleAsync = ref.watch(cycleControllerProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: Column(
          children: [
            SubScreenHeader(
              title: 'Period & Cycle',
              subtitle: 'Your rhythm, energy and wellness — connected.',
              onBack: onBack ?? () => Navigator.maybePop(context),
              trailing: Semantics(
                button: true,
                label: 'Cycle privacy settings',
                child: Material(
                  color: Colors.transparent,
                  shape: CircleBorder(
                    side: BorderSide(
                      color: variant.accent.withValues(alpha: 0.5),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onSettings,
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: AppIcon(
                          'settings-gear',
                          size: 20,
                          color: variant.accent,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (kDebugMode) ...[
                      const DevTodPicker(),
                      const SizedBox(height: 12),
                    ],
                    cycleAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.purple,
                          ),
                        ),
                      ),
                      error: (e, st) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          "Couldn't load Period & Cycle. Please restart the app.",
                          style: AppTextStyles.subtitle,
                        ),
                      ),
                      data: (state) {
                        final today = DateTime.now();
                        final cycleDay = state.currentCycleDay(today);
                        final estimated = state.estimatedNextPeriodStart;
                        final todayEntry = state.dayEntryFor(today);
                        final periodDays = state.mostRecentPeriod?.lengthInDays;
                        final checkInCount = state.dayEntries.length;
                        // A determinate arc showing real progress through the
                        // cycle — always a concrete value, never `null`
                        // (which would put CircularProgressIndicator into its
                        // indeterminate, endlessly-spinning mode). Falls back
                        // to the 28-day default only for this display ratio;
                        // never fabricates a typical-cycle-length the user
                        // hasn't set or logged.
                        final cycleRingProgress = cycleDay == null
                            ? 0.0
                            : (cycleDay /
                                      (state.settings.typicalCycleDays ?? 28))
                                  .clamp(0.0, 1.0);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GlowCard(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 100,
                                    height: 100,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        SizedBox(
                                          width: 100,
                                          height: 100,
                                          child: CircularProgressIndicator(
                                            value: cycleRingProgress,
                                            strokeWidth: 8,
                                            backgroundColor: Colors.white
                                                .withValues(alpha: 0.08),
                                            valueColor: AlwaysStoppedAnimation(
                                              variant.accent,
                                            ),
                                          ),
                                        ),
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              cycleDay == null
                                                  ? '—'
                                                  : '$cycleDay',
                                              style: AppTextStyles.screenTitle
                                                  .copyWith(
                                                    fontSize: 28,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                            ),
                                            Text(
                                              'cycle day',
                                              style: AppTextStyles.caption
                                                  .copyWith(fontSize: 10),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Next period',
                                          style: AppTextStyles.caption.copyWith(
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          estimated == null
                                              ? 'Not enough data yet'
                                              : _fullDate(estimated),
                                          style: AppTextStyles.cardTitleLg
                                              .copyWith(fontSize: 17),
                                        ),
                                        if (estimated != null) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            'in about ${estimated.difference(DateTime(today.year, today.month, today.day)).inDays} days',
                                            style: AppTextStyles.captionBold
                                                .copyWith(
                                                  color: variant.accent,
                                                  fontSize: 12,
                                                ),
                                          ),
                                        ],
                                        const SizedBox(height: 10),
                                        Container(
                                          height: 1,
                                          color: AppColors.cardBorder,
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          'Today',
                                          style: AppTextStyles.caption.copyWith(
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          todayEntry?.energyLevel != null
                                              ? _energyLabel(
                                                  todayEntry!.energyLevel!,
                                                )
                                              : 'Not checked in yet',
                                          style: AppTextStyles.captionBold
                                              .copyWith(
                                                color: AppColors.success,
                                                fontSize: 13,
                                              ),
                                        ),
                                        if (todayEntry?.mood != null)
                                          Text(
                                            todayEntry!.mood!,
                                            style: AppTextStyles.cardTitle
                                                .copyWith(fontSize: 13),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _ActionCard(
                                    icon: Icons.water_drop,
                                    iconColor: AppColors.ctaStart,
                                    title: 'Log period',
                                    subtitle: 'Flow and dates',
                                    onTap: onLogPeriod,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _ActionCard(
                                    icon: Icons.sentiment_satisfied_alt,
                                    iconColor: AppColors.blue,
                                    title: 'How I feel',
                                    subtitle: 'Mood and pain',
                                    onTap: onDailyCheckIn,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _ActionCard(
                              icon: Icons.insights,
                              iconColor: variant.accent,
                              title: 'Cycle insights',
                              subtitle: 'Real patterns from what you log',
                              onTap: onInsights,
                            ),
                            const SizedBox(height: 16),
                            _GlowUpBrainCard(
                              state: state,
                              accent: variant.accent,
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    'This cycle',
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.cardTitleLg.copyWith(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Semantics(
                                  button: true,
                                  label: 'Calendar',
                                  child: InkWell(
                                    onTap: onCalendar,
                                    child: Container(
                                      constraints: const BoxConstraints(
                                        minHeight: 44,
                                      ),
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        'Calendar ›',
                                        style: AppTextStyles.captionBold
                                            .copyWith(
                                              color: variant.accent,
                                              fontSize: 13,
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _StatBox(
                                    label: 'Period',
                                    value: periodDays == null
                                        ? '—'
                                        : '$periodDays days',
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _StatBox(
                                    label: 'Cycle',
                                    value:
                                        state.settings.typicalCycleDays == null
                                        ? '—'
                                        : '${state.settings.typicalCycleDays} days',
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _StatBox(
                                    label: 'Check-ins',
                                    value: '$checkInCount',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _fullDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}';
  }

  static String _energyLabel(int level) {
    if (level <= 2) return 'Low energy';
    if (level == 3) return 'Steady energy';
    return 'High energy';
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title, $subtitle',
      child: GlowCard(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, size: 26, color: iconColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.cardTitle.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTextStyles.caption.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return GlowCard(
      child: Column(
        children: [
          Text(label, style: AppTextStyles.caption.copyWith(fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.cardTitleLg.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// The real "Glow Up Brain" card — the AI Coach genuinely IS connected
/// now (see `RemoteCoachBrainService`/`coach-chat`), so this must never
/// show the old "isn't connected to a live model yet" copy again. Three
/// truthful states only, never a fake success:
///
/// 1. Cycle-aware suggestions OFF — unchanged, already honest.
/// 2. ON but no cycle data logged yet — says exactly what's missing.
/// 3. ON with real data — a genuinely data-grounded suggestion, built
///    from the SAME `CycleState`/`CycleDayEntry` fields the Coach itself
///    receives (see `CoachBrainContext`), not a live network call on
///    every screen view (a home-screen card triggering a paid LLM call
///    just by being visible is its own kind of dishonesty about cost/
///    UX) — and never a phase/fertility claim, matching this screen's
///    own "day N only" rule.
class _GlowUpBrainCard extends StatelessWidget {
  const _GlowUpBrainCard({required this.state, required this.accent});

  final CycleState state;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final cycleDay = state.currentCycleDay(today);
    final todayEntry = state.dayEntryFor(today);

    final String title;
    final String subtitle;
    if (!state.settings.cycleAwareSuggestions) {
      title = 'Cycle-aware suggestions are off';
      subtitle =
          'Turn this on in Privacy settings to get suggestions based on your logged cycle data.';
    } else if (cycleDay == null) {
      title = 'Cycle-aware suggestions are on';
      subtitle = 'Add more cycle data to unlock cycle-aware suggestions.';
    } else {
      title = 'Cycle-aware suggestion';
      subtitle = _suggestionFor(cycleDay, todayEntry);
    }

    return GlowCard(
      borderColor: accent.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 16, color: accent),
              const SizedBox(width: 6),
              Text(
                'GLOW UP BRAIN',
                style: AppTextStyles.captionBold.copyWith(
                  color: accent,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(title, style: AppTextStyles.cardTitleLg.copyWith(fontSize: 16)),
          const SizedBox(height: 6),
          Text(subtitle, style: AppTextStyles.subtitle.copyWith(fontSize: 13)),
        ],
      ),
    );
  }

  static String _suggestionFor(int cycleDay, CycleDayEntry? todayEntry) {
    if (todayEntry?.painIntensity != null && todayEntry!.painIntensity! >= 3) {
      return "You logged some discomfort today (day $cycleDay) — a gentler routine or extra rest might feel better than pushing through.";
    }
    if (todayEntry?.energyLevel != null && todayEntry!.energyLevel! <= 2) {
      return "Your energy is logged lower today (day $cycleDay) — a lighter routine could feel better than a high-intensity one.";
    }
    if (todayEntry?.energyLevel != null && todayEntry!.energyLevel! >= 4) {
      return "You're on day $cycleDay and logged good energy today — a solid day for a more challenging routine if you're up for it.";
    }
    if (todayEntry != null) {
      return "You're on day $cycleDay of your cycle, with today's check-in logged.";
    }
    return "You're on day $cycleDay of your cycle. Log today's mood and energy in Daily Check-In for a more tailored suggestion.";
  }
}
