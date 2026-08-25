import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ambient_glow.dart';
import '../../core/widgets/bottom_nav_bar.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/sub_screen_header.dart';
import '../models/routine_models.dart';
import '../state/routines_controller.dart';
import '../theme/routines_variant_config.dart';

enum _DayStatus { none, completed, missed, inProgress }

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// 22g_routine_calendar (368:2159).
class RoutineCalendarScreen extends ConsumerWidget {
  const RoutineCalendarScreen({
    super.key,
    required this.onBack,
    required this.onToday,
    required this.onRoutines,
    required this.onCoach,
    required this.onProfile,
  });

  final VoidCallback onBack;
  final VoidCallback onToday;
  final VoidCallback onRoutines;
  final VoidCallback onCoach;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routines = ref.watch(routinesControllerProvider);
    final completions = ref.watch(routineCompletionsControllerProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monthLabel = '${_monthNames[now.month - 1]} ${now.year}';

    _DayStatus statusFor(DateTime date) {
      if (date.isAfter(today)) return _DayStatus.none;
      final weekday = Weekday.values[date.weekday - 1];
      final scheduled = routines
          .where((r) => r.schedule.days.contains(weekday))
          .toList();
      if (scheduled.isEmpty) return _DayStatus.none;

      final relevant = completions.values
          .where(
            (c) => c.date == date && scheduled.any((r) => r.id == c.routineId),
          )
          .toList();
      if (relevant.isEmpty)
        return date == today ? _DayStatus.none : _DayStatus.missed;

      final totalSteps = scheduled.fold<int>(
        0,
        (sum, r) => sum + r.activities.length,
      );
      final doneSteps = relevant.fold<int>(
        0,
        (sum, c) => sum + c.completedActivityIds.length,
      );
      if (doneSteps == 0) return _DayStatus.missed;
      if (doneSteps >= totalSteps) return _DayStatus.completed;
      return _DayStatus.inProgress;
    }

    final firstOfMonth = DateTime(now.year, now.month, 1);
    final gridStart = firstOfMonth.subtract(
      Duration(days: firstOfMonth.weekday - 1),
    );
    final days = List.generate(35, (i) => gridStart.add(Duration(days: i)));

    final todaysRoutines = routines
        .where(
          (r) => r.schedule.days.contains(Weekday.values[today.weekday - 1]),
        )
        .toList();

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
                      top: 140,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: AmbientGlow(color: AppColors.purple, size: 280),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SubScreenHeader(
                          title: 'Routine Calendar',
                          subtitle: monthLabel,
                          onBack: onBack,
                        ),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  AppColors.cardStart,
                                  AppColors.cardEnd,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(AppRadii.xl),
                              border: Border.all(color: AppColors.cardBorder),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    for (final w in Weekday.values)
                                      SizedBox(
                                        width: 36,
                                        child: Text(
                                          w.shortLabel,
                                          textAlign: TextAlign.center,
                                          style: AppTextStyles.captionBold
                                              .copyWith(
                                                color: AppColors.textSecondary,
                                                fontSize: 12,
                                              ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    for (final d in days)
                                      _CalendarCell(
                                        date: d,
                                        inCurrentMonth: d.month == now.month,
                                        isToday: d == today,
                                        status: statusFor(d),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "TODAY'S LOG — ${_monthNames[today.month - 1].substring(0, 3)} ${today.day}",
                                style: AppTextStyles.captionBold.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      AppColors.cardStart,
                                      AppColors.cardEnd,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.lg,
                                  ),
                                  border: Border.all(
                                    color: AppColors.cardBorder,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    for (
                                      var i = 0;
                                      i < todaysRoutines.length;
                                      i++
                                    ) ...[
                                      _LogRow(
                                        routine: todaysRoutines[i],
                                        completion: completions.values
                                            .where(
                                              (c) =>
                                                  c.routineId ==
                                                      todaysRoutines[i].id &&
                                                  c.date == today,
                                            )
                                            .firstOrNull,
                                      ),
                                      if (i != todaysRoutines.length - 1)
                                        const SizedBox(height: 12),
                                    ],
                                    if (todaysRoutines.isEmpty)
                                      Text(
                                        'No routines scheduled today.',
                                        style: AppTextStyles.subtitle,
                                      ),
                                  ],
                                ),
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
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.cardStart, AppColors.cardEnd],
                  ),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'This Month Completion',
                        style: AppTextStyles.fieldLabel.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      '${_monthCompletionPercent(routines, completions, now)}%',
                      style: const TextStyle(
                        color: Color(0xFF3CD070),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
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

int _monthCompletionPercent(
  List<Routine> routines,
  Map<String, RoutineCompletion> completions,
  DateTime now,
) {
  final relevant = completions.values
      .where((c) => c.date.month == now.month && c.date.year == now.year)
      .toList();
  if (relevant.isEmpty) return 0;
  var total = 0;
  var done = 0;
  for (final c in relevant) {
    final routine = routines.where((r) => r.id == c.routineId).firstOrNull;
    if (routine == null) continue;
    total += routine.activities.length;
    done += c.completedActivityIds.length;
  }
  if (total == 0) return 0;
  return ((done / total) * 100).round();
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}

class _CalendarCell extends StatelessWidget {
  const _CalendarCell({
    required this.date,
    required this.inCurrentMonth,
    required this.isToday,
    required this.status,
  });

  final DateTime date;
  final bool inCurrentMonth;
  final bool isToday;
  final _DayStatus status;

  @override
  Widget build(BuildContext context) {
    final dotColor = switch (status) {
      _DayStatus.completed => const Color(0xFF3CD070),
      _DayStatus.missed => const Color(0xFFFF4D4D),
      _DayStatus.inProgress => AppColors.gold,
      _DayStatus.none => null,
    };
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: isToday ? Colors.white.withValues(alpha: 0.08) : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${date.day}',
            style: TextStyle(
              color: inCurrentMonth
                  ? Colors.white
                  : AppColors.textSecondary.withValues(alpha: 0.5),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 6,
            height: 6,
            child: dotColor == null
                ? null
                : DecoratedBox(
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.routine, required this.completion});

  final Routine routine;
  final RoutineCompletion? completion;

  @override
  Widget build(BuildContext context) {
    final done = completion?.completedActivityIds.length ?? 0;
    final total = routine.activities.length;
    final label = done == 0
        ? 'Not Started'
        : (done >= total ? 'Completed' : 'In Progress');
    final color = done == 0
        ? AppColors.textSecondary
        : (done >= total ? const Color(0xFF3CD070) : AppColors.gold);
    return Row(
      children: [
        Expanded(
          child: Text(
            routine.title,
            style: AppTextStyles.fieldLabel.copyWith(fontSize: 14),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
