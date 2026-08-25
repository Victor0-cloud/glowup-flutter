import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glow_card.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/gradient_pill_button.dart';
import '../../core/widgets/sub_screen_header.dart';
import '../../facial_scan/state/facial_scan_controller.dart';
import '../../food_scan/state/food_scan_controller.dart';
import '../../water/state/water_controller.dart';
import '../../workout/state/workout_history_controller.dart';
import '../models/cycle_models.dart';
import '../state/cycle_controller.dart';

/// PC06 My Calendar — a month grid marking real logged period days and
/// notebook entries, plus a real cross-module "ecosystem" summary (Workout/
/// Water/Food/Skin) for whichever day is selected. Every number shown here
/// is read live from that module's own real controller for the selected
/// date — never fabricated, never a placeholder value.
class CycleCalendarScreen extends ConsumerStatefulWidget {
  const CycleCalendarScreen({super.key, this.onBack, this.onOpenNotebook});

  final VoidCallback? onBack;

  /// Opens the Daily Notebook (PC07) for the given date.
  final ValueChanged<DateTime>? onOpenNotebook;

  @override
  ConsumerState<CycleCalendarScreen> createState() =>
      _CycleCalendarScreenState();
}

class _CycleCalendarScreenState extends ConsumerState<CycleCalendarScreen> {
  late DateTime _visibleMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );
  late DateTime _selected = _dayOnly(DateTime.now());
  bool _myWellness = true;

  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isPeriodDay(DateTime day, List<PeriodEntry> periods) {
    for (final p in periods) {
      final start = _dayOnly(p.startDate);
      final end = p.endDate == null
          ? _dayOnly(DateTime.now())
          : _dayOnly(p.endDate!);
      if (!day.isBefore(start) && !day.isAfter(end)) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final cycleAsync = ref.watch(cycleControllerProvider);
    final workouts =
        ref.watch(workoutHistoryControllerProvider).valueOrNull ?? const [];
    final water = ref.watch(waterControllerProvider).valueOrNull;
    final foodEntries =
        ref.watch(foodScanControllerProvider).valueOrNull ?? const [];
    final facialEntries =
        ref.watch(facialScanControllerProvider).valueOrNull?.entries ??
        const [];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: Column(
          children: [
            SubScreenHeader(
              title: 'My Calendar',
              subtitle: 'Tap any date to open its notebook.',
              onBack: widget.onBack ?? () => Navigator.maybePop(context),
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
                  final cycleDay = state.currentCycleDay(_selected);
                  final notebook = state.notebookEntryFor(_selected);
                  final dayEntry = state.dayEntryFor(_selected);

                  final dayWorkouts = workouts
                      .where(
                        (w) => _sameDay(_dayOnly(w.completedAt), _selected),
                      )
                      .toList();
                  final waterMl = water?.totalOn(_selected) ?? 0;
                  final foodCount = foodEntries
                      .where(
                        (f) => _sameDay(_dayOnly(f.confirmedAt), _selected),
                      )
                      .length;
                  final skinCount = facialEntries
                      .where(
                        (f) => _sameDay(_dayOnly(f.confirmedAt), _selected),
                      )
                      .length;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _ModeButton(
                                label: 'My wellness',
                                selected: _myWellness,
                                onTap: () => setState(() => _myWellness = true),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ModeButton(
                                label: 'Cycle only',
                                selected: !_myWellness,
                                onTap: () =>
                                    setState(() => _myWellness = false),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Semantics(
                              button: true,
                              label: 'Previous month',
                              child: IconButton(
                                constraints: const BoxConstraints(
                                  minWidth: 40,
                                  minHeight: 40,
                                ),
                                padding: EdgeInsets.zero,
                                onPressed: () => setState(
                                  () => _visibleMonth = DateTime(
                                    _visibleMonth.year,
                                    _visibleMonth.month - 1,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.chevron_left,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                _monthTitle(_visibleMonth),
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.screenTitle.copyWith(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            Semantics(
                              button: true,
                              label: 'Next month',
                              child: IconButton(
                                constraints: const BoxConstraints(
                                  minWidth: 40,
                                  minHeight: 40,
                                ),
                                padding: EdgeInsets.zero,
                                onPressed: () => setState(
                                  () => _visibleMonth = DateTime(
                                    _visibleMonth.year,
                                    _visibleMonth.month + 1,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.chevron_right,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _WeekdayHeader(),
                        const SizedBox(height: 4),
                        _CalendarGrid(
                          visibleMonth: _visibleMonth,
                          selected: _selected,
                          isPeriodDay: (d) => _isPeriodDay(d, state.periods),
                          hasNotebookEntry: (d) =>
                              state.notebookEntryFor(d) != null,
                          onSelect: (d) => setState(() => _selected = d),
                        ),
                        const SizedBox(height: 20),
                        GlowCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_fullDate(_selected)}${cycleDay != null ? ' · CYCLE DAY $cycleDay' : ''}',
                                style: AppTextStyles.captionBold.copyWith(
                                  color: AppColors.purple,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _myWellness
                                    ? "Today's ecosystem"
                                    : 'Cycle details',
                                style: AppTextStyles.cardTitleLg.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 14),
                              if (_myWellness)
                                Row(
                                  children: [
                                    Expanded(
                                      child: _EcosystemStat(
                                        label: 'Workout',
                                        value: dayWorkouts.isEmpty
                                            ? 'None'
                                            : 'Completed',
                                        color: AppColors.blue,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _EcosystemStat(
                                        label: 'Water',
                                        value:
                                            '${(waterMl / 1000).toStringAsFixed(1)} L',
                                        color: AppColors.blue,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _EcosystemStat(
                                        label: 'Food',
                                        value:
                                            '$foodCount ${foodCount == 1 ? 'log' : 'logs'}',
                                        color: AppColors.orange,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _EcosystemStat(
                                        label: 'Skin',
                                        value:
                                            '$skinCount ${skinCount == 1 ? 'note' : 'notes'}',
                                        color: AppColors.success,
                                      ),
                                    ),
                                  ],
                                )
                              else
                                Text(
                                  dayEntry == null
                                      ? 'No cycle log for this day yet.'
                                      : [
                                          if (dayEntry.flow != null)
                                            'Flow: ${dayEntry.flow!.label}',
                                          if (dayEntry.symptoms.isNotEmpty)
                                            'Symptoms: ${dayEntry.symptoms.join(", ")}',
                                          if (dayEntry.mood != null)
                                            'Mood: ${dayEntry.mood}',
                                        ].join('\n'),
                                  style: AppTextStyles.subtitle.copyWith(
                                    fontSize: 14,
                                  ),
                                ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Text(
                                    notebook?.feeling?.emoji ?? '📝',
                                    style: const TextStyle(fontSize: 22),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          notebook == null
                                              ? 'No private note saved'
                                              : '${notebook.feeling?.label ?? "Note"} · private note saved',
                                          style: AppTextStyles.cardTitle
                                              .copyWith(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        Text(
                                          'Tap the date to open the notebook',
                                          style: AppTextStyles.caption.copyWith(
                                            fontSize: 12,
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
                        const SizedBox(height: 20),
                        GradientPillButton(
                          label: 'Open ${_shortDate(_selected)} notebook',
                          onPressed: () =>
                              widget.onOpenNotebook?.call(_selected),
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

  static const _months = [
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

  static String _monthTitle(DateTime m) =>
      '${_fullMonths[m.month - 1]} ${m.year}';
  static const _fullMonths = [
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

  static String _fullDate(DateTime d) =>
      '${_fullMonths[d.month - 1].toUpperCase()} ${d.day}';
  static String _shortDate(DateTime d) => '${_months[d.month - 1]} ${d.day}';
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? AppColors.purple : Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: selected ? AppColors.purple : AppColors.cardBorder,
              ),
            ),
            child: Text(
              label,
              style: AppTextStyles.captionBold.copyWith(
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const labels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    return Row(
      children: [
        for (final l in labels)
          Expanded(
            child: Center(
              child: Text(
                l,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.visibleMonth,
    required this.selected,
    required this.isPeriodDay,
    required this.hasNotebookEntry,
    required this.onSelect,
  });

  final DateTime visibleMonth;
  final DateTime selected;
  final bool Function(DateTime) isPeriodDay;
  final bool Function(DateTime) hasNotebookEntry;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(visibleMonth.year, visibleMonth.month, 1);
    final leadingBlanks = firstOfMonth.weekday % 7; // Sunday-first grid
    final gridStart = firstOfMonth.subtract(Duration(days: leadingBlanks));
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 42,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 4,
      ),
      itemBuilder: (context, i) {
        final day = gridStart.add(Duration(days: i));
        final inMonth = day.month == visibleMonth.month;
        final isSelected =
            day.year == selected.year &&
            day.month == selected.month &&
            day.day == selected.day;
        final isToday =
            day.year == today.year &&
            day.month == today.month &&
            day.day == today.day;
        final period = isPeriodDay(day);
        final hasNote = hasNotebookEntry(day);

        return Semantics(
          button: true,
          selected: isSelected,
          label: '${day.month}/${day.day}/${day.year}',
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => onSelect(DateTime(day.year, day.month, day.day)),
            child: Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.purple : Colors.transparent,
                border: !isSelected && period
                    ? Border.all(color: AppColors.ctaStart, width: 1.5)
                    : null,
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${day.day}',
                    style: AppTextStyles.cardTitle.copyWith(
                      fontSize: 14,
                      fontWeight: isToday || isSelected
                          ? FontWeight.w800
                          : FontWeight.w500,
                      color: inMonth
                          ? Colors.white
                          : AppColors.textSecondary.withValues(alpha: 0.4),
                    ),
                  ),
                  if (hasNote || isSelected)
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? AppColors.success : AppColors.blue,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EcosystemStat extends StatelessWidget {
  const _EcosystemStat({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text(label, style: AppTextStyles.caption.copyWith(fontSize: 11)),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: AppTextStyles.captionBold.copyWith(
              color: color,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
