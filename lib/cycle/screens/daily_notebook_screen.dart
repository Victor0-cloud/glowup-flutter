import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../coach/widgets/settings_widgets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/gradient_pill_button.dart';
import '../../core/widgets/sub_screen_header.dart';
import '../models/cycle_models.dart';
import '../state/cycle_controller.dart';

/// PC07 Daily Notebook — a private free-text note for one calendar day,
/// plus which same-day real records from other modules to link (a boolean
/// flag only, never a copy of that module's data) and per-entry, revocable
/// AI-memory consent. Writes through [CycleController.logNotebookEntry].
class DailyNotebookScreen extends ConsumerStatefulWidget {
  const DailyNotebookScreen({
    super.key,
    required this.date,
    this.initialFeeling,
    this.onBack,
    this.onSaved,
  });

  final DateTime date;
  final Feeling? initialFeeling;
  final VoidCallback? onBack;
  final VoidCallback? onSaved;

  @override
  ConsumerState<DailyNotebookScreen> createState() =>
      _DailyNotebookScreenState();
}

class _DailyNotebookScreenState extends ConsumerState<DailyNotebookScreen> {
  Feeling? _feeling;
  final _noteController = TextEditingController();
  bool _linkedWorkout = false;
  bool _linkedFood = false;
  bool _linkedWater = false;
  bool _linkedSkin = false;
  bool _linkedCycle = false;
  bool _aiMemoryConsent = false;
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _feeling = widget.initialFeeling;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _loadOnce(CycleState state) {
    if (_loaded) return;
    _loaded = true;
    final existing = state.notebookEntryFor(widget.date);
    if (existing == null) return;
    _feeling = existing.feeling;
    if (existing.note != null) _noteController.text = existing.note!;
    _linkedWorkout = existing.linkedWorkout;
    _linkedFood = existing.linkedFood;
    _linkedWater = existing.linkedWater;
    _linkedSkin = existing.linkedSkin;
    _linkedCycle = existing.linkedCycle;
    _aiMemoryConsent = existing.aiMemoryConsent;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final controller = ref.read(cycleControllerProvider.notifier);
    final note = _noteController.text.trim();
    await controller.logNotebookEntry(
      DailyNotebookEntry(
        date: widget.date,
        feeling: _feeling,
        note: note.isEmpty ? null : note,
        aiMemoryConsent: _aiMemoryConsent,
        linkedWorkout: _linkedWorkout,
        linkedFood: _linkedFood,
        linkedWater: _linkedWater,
        linkedSkin: _linkedSkin,
        linkedCycle: _linkedCycle,
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    widget.onSaved?.call();
  }

  @override
  Widget build(BuildContext context) {
    final cycleAsync = ref.watch(cycleControllerProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: Column(
          children: [
            SubScreenHeader(
              title: 'Daily Notebook',
              subtitle: '${_weekdayDate(widget.date)} · Private journal',
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
                          'How did this day feel?',
                          style: AppTextStyles.cardTitleLg.copyWith(
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 10),
                        GridView.count(
                          crossAxisCount: 4,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.58,
                          children: [
                            for (final f in Feeling.values)
                              _FeelingChip(
                                feeling: f,
                                selected: _feeling == f,
                                onTap: () => setState(
                                  () => _feeling = _feeling == f ? null : f,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Jot down your note',
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
                            minLines: 8,
                            maxLines: 14,
                            maxLength: 2000,
                            style: AppTextStyles.subtitle.copyWith(
                              fontSize: 14,
                              color: Colors.white,
                            ),
                            decoration: InputDecoration(
                              hintText: 'What happened today?',
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
                        const SizedBox(height: 20),
                        Text(
                          "Attach today's records",
                          style: AppTextStyles.cardTitleLg.copyWith(
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _LinkChip(
                              label: 'Workout',
                              color: AppColors.blue,
                              selected: _linkedWorkout,
                              onTap: () => setState(
                                () => _linkedWorkout = !_linkedWorkout,
                              ),
                            ),
                            _LinkChip(
                              label: 'Food',
                              color: AppColors.orange,
                              selected: _linkedFood,
                              onTap: () =>
                                  setState(() => _linkedFood = !_linkedFood),
                            ),
                            _LinkChip(
                              label: 'Water',
                              color: AppColors.blue,
                              selected: _linkedWater,
                              onTap: () =>
                                  setState(() => _linkedWater = !_linkedWater),
                            ),
                            _LinkChip(
                              label: 'Skin',
                              color: AppColors.success,
                              selected: _linkedSkin,
                              onTap: () =>
                                  setState(() => _linkedSkin = !_linkedSkin),
                            ),
                            _LinkChip(
                              label: 'Cycle',
                              color: AppColors.ctaStart,
                              selected: _linkedCycle,
                              onTap: () =>
                                  setState(() => _linkedCycle = !_linkedCycle),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        ToggleRow(
                          label: 'Let Glow Up Brain use this note',
                          value: _aiMemoryConsent,
                          onChanged: (v) =>
                              setState(() => _aiMemoryConsent = v),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Optional · change or revoke anytime. Only the fact that a note exists is ever shared — never its text.',
                          style: AppTextStyles.caption.copyWith(fontSize: 12),
                        ),
                        const SizedBox(height: 28),
                        GradientPillButton(
                          label: 'Save notebook entry',
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

class _FeelingChip extends StatelessWidget {
  const _FeelingChip({
    required this.feeling,
    required this.selected,
    required this.onTap,
  });
  final Feeling feeling;
  final bool selected;
  final VoidCallback onTap;

  Color get _color => switch (feeling) {
    Feeling.happy => AppColors.ctaStart,
    Feeling.sad => AppColors.purple,
    Feeling.pain => AppColors.orange,
    Feeling.menstrualPain => AppColors.ctaStart,
  };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: feeling.label,
      child: Material(
        color: selected
            ? _color.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? _color : AppColors.cardBorder,
              ),
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(feeling.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(height: 6),
                Text(
                  feeling.label,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.cardTitle.copyWith(
                    fontSize: 11,
                    color: selected ? _color : Colors.white,
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

class _LinkChip extends StatelessWidget {
  const _LinkChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected
            ? color.withValues(alpha: 0.9)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? color : AppColors.cardBorder,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: AppTextStyles.captionBold.copyWith(
                fontSize: 13,
                color: selected ? Colors.white : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
