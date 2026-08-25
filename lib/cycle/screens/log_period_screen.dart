import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/gradient_pill_button.dart';
import '../../core/widgets/sub_screen_header.dart';
import '../models/cycle_models.dart';
import '../state/cycle_controller.dart';

/// PC04 Log Period — flow level, whether the period started/ended today,
/// and a private note. Writes through the exact same
/// [CycleController.logDayEntry]/[logPeriodStart]/[logPeriodEnd] real data
/// operations the original Cycle screen already used.
class LogPeriodScreen extends ConsumerStatefulWidget {
  const LogPeriodScreen({super.key, this.onBack, this.onSaved});

  final VoidCallback? onBack;
  final VoidCallback? onSaved;

  @override
  ConsumerState<LogPeriodScreen> createState() => _LogPeriodScreenState();
}

class _LogPeriodScreenState extends ConsumerState<LogPeriodScreen> {
  FlowLevel? _flow;
  bool _startedToday = false;
  final _noteController = TextEditingController();
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _loadOnce(CycleState state) {
    if (_loaded) return;
    _loaded = true;
    final today = state.dayEntryFor(DateTime.now());
    _flow = today?.flow;
    if (today?.note != null) _noteController.text = today!.note!;
    _startedToday =
        state.hasActivePeriod &&
        state.mostRecentPeriod != null &&
        _isSameDay(state.mostRecentPeriod!.startDate, DateTime.now());
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _save() async {
    setState(() => _saving = true);
    final controller = ref.read(cycleControllerProvider.notifier);
    final now = DateTime.now();
    final note = _noteController.text.trim();
    final current = ref.read(cycleControllerProvider).valueOrNull;
    await controller.logDayEntry(
      CycleDayEntry(
        date: now,
        flow: _flow,
        symptoms: current?.dayEntryFor(now)?.symptoms ?? const {},
        mood: current?.dayEntryFor(now)?.mood,
        energyLevel: current?.dayEntryFor(now)?.energyLevel,
        sleepQuality: current?.dayEntryFor(now)?.sleepQuality,
        note: note.isEmpty ? null : note,
      ),
    );
    if (_startedToday && (current == null || !current.hasActivePeriod)) {
      await controller.logPeriodStart(now);
    } else if (!_startedToday && (current?.hasActivePeriod ?? false)) {
      await controller.logPeriodEnd(current!.mostRecentPeriod!.id, now);
    }
    if (!mounted) return;
    setState(() => _saving = false);
    widget.onSaved?.call();
  }

  @override
  Widget build(BuildContext context) {
    final cycleAsync = ref.watch(cycleControllerProvider);
    final today = DateTime.now();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: Column(
          children: [
            SubScreenHeader(
              title: 'Log Period',
              subtitle: '${_weekdayDate(today)} · Edit anytime',
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
                  _loadOnce(state);
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'How is your flow?',
                          style: AppTextStyles.screenTitle.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Choose what best describes today.',
                          style: AppTextStyles.subtitle.copyWith(fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.6,
                          children: [
                            for (final f in FlowLevel.values)
                              _FlowCard(
                                level: f,
                                selected: _flow == f,
                                onTap: () => setState(
                                  () => _flow = _flow == f ? null : f,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Period timing',
                          style: AppTextStyles.cardTitleLg.copyWith(
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _ToggleTile(
                          label: 'Period started today',
                          value: _startedToday,
                          onChanged: (v) => setState(() => _startedToday = v),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Private note',
                          style: AppTextStyles.cardTitleLg.copyWith(
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Semantics(
                          label: 'Private note',
                          textField: true,
                          child: TextField(
                            controller: _noteController,
                            minLines: 4,
                            maxLines: 8,
                            maxLength: 500,
                            style: AppTextStyles.subtitle.copyWith(
                              fontSize: 14,
                              color: Colors.white,
                            ),
                            decoration: InputDecoration(
                              hintText:
                                  'Jot down anything you want to remember...',
                              hintStyle: AppTextStyles.caption,
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.05),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.all(16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        GradientPillButton(
                          label: 'Save period log',
                          onPressed: _saving ? null : _save,
                          loading: _saving,
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

  static String _weekdayDate(DateTime d) {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
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
    return '${weekdays[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
  }
}

class _FlowCard extends StatelessWidget {
  const _FlowCard({
    required this.level,
    required this.selected,
    required this.onTap,
  });
  final FlowLevel level;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: level.label,
      child: Material(
        color: selected
            ? AppColors.ctaStart.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? AppColors.ctaStart : AppColors.cardBorder,
              ),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.water_drop, color: AppColors.ctaStart, size: 22),
                const SizedBox(height: 6),
                Text(
                  level.label,
                  style: AppTextStyles.cardTitle.copyWith(
                    fontSize: 14,
                    color: selected ? AppColors.ctaStart : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => onChanged(!value),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyles.cardTitle.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Switch(
                  value: value,
                  onChanged: onChanged,
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppColors.purple,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
