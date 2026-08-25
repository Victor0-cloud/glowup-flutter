import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../coach/widgets/settings_widgets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glow_card.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/gradient_pill_button.dart';
import '../../core/widgets/sub_screen_header.dart';
import '../../mood/models/mood_models.dart';
import '../models/journal_entry.dart';
import '../state/journal_controller.dart';

/// The real Journal — synced entries via [journalControllerProvider], not
/// a placeholder. Free-form reflection, optionally tagged with a mood
/// (reusing Mood Check-In's own [MoodLevel] vocabulary). Entry text is
/// only ever sent to the AI Coach — as a bounded, extracted signal summary,
/// never the raw text itself — when the user has explicitly turned on
/// "Allow AI Coach to use my journal for personalized guidance" below
/// (`JournalState.aiConsentEnabled`, enforced server-side, defaults off —
/// see `supabase/migrations/0008_journal_ai_consent.sql`). When that's off,
/// the Brain only ever learns that a real entry was logged (and the short
/// mood tag), never the text (see `JournalController.addEntry`).
class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(journalControllerProvider.notifier).loadMore();
    }
  }

  Future<void> _openComposer({JournalEntry? editing}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _JournalComposerSheet(editing: editing),
    );
  }

  Future<void> _confirmDelete(JournalEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF181436),
        title: const Text(
          'Delete entry?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text('This can\'t be undone.', style: AppTextStyles.subtitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete', style: TextStyle(color: AppColors.ctaStart)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(journalControllerProvider.notifier).deleteEntry(entry.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(journalControllerProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              SubScreenHeader(
                title: 'Journal',
                subtitle: 'Your private space to reflect',
                onBack: widget.onBack ?? () => Navigator.maybePop(context),
              ),
              Expanded(
                child: async.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.gold),
                  ),
                  error: (e, st) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      "Couldn't load your journal. Please check you're signed in and try again.",
                      style: AppTextStyles.subtitle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  data: (journalState) {
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
                          child: ToggleRow(
                            label: 'Allow AI Coach to use my journal',
                            value: journalState.aiConsentEnabled,
                            onChanged: (v) => ref
                                .read(journalControllerProvider.notifier)
                                .setAiConsent(v),
                          ),
                        ),
                        Expanded(
                          child: journalState.entries.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(32),
                                    child: Text(
                                      'No journal entries yet. Tap + to write your first one.',
                                      style: AppTextStyles.subtitle,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                )
                              : _JournalEntryList(
                                  scrollController: _scrollController,
                                  entries: journalState.entries,
                                  onEdit: (entry) =>
                                      _openComposer(editing: entry),
                                  onDelete: _confirmDelete,
                                ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Semantics(
        button: true,
        label: 'New journal entry',
        child: FloatingActionButton(
          backgroundColor: AppColors.gold,
          onPressed: () => _openComposer(),
          child: const Icon(Icons.add, color: AppColors.onSelected),
        ),
      ),
    );
  }
}

String _dateLabel(DateTime utc) {
  final local = utc.toLocal();
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
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  return '${months[local.month - 1]} ${local.day} · $hour:$minute $period';
}

class _JournalEntryList extends StatelessWidget {
  const _JournalEntryList({
    required this.scrollController,
    required this.entries,
    required this.onEdit,
    required this.onDelete,
  });

  final ScrollController scrollController;
  final List<JournalEntry> entries;
  final ValueChanged<JournalEntry> onEdit;
  final ValueChanged<JournalEntry> onDelete;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 96),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final entry = entries[i];
        return GlowCard(
          onTap: () => onEdit(entry),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (entry.mood != null) ...[
                    Text(
                      entry.mood!.emoji,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      _dateLabel(entry.createdAt),
                      style: AppTextStyles.caption.copyWith(fontSize: 12),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Delete entry',
                    child: InkWell(
                      onTap: () => onDelete(entry),
                      borderRadius: BorderRadius.circular(16),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                entry.content,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.subtitle.copyWith(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _JournalComposerSheet extends ConsumerStatefulWidget {
  const _JournalComposerSheet({this.editing});

  final JournalEntry? editing;

  @override
  ConsumerState<_JournalComposerSheet> createState() =>
      _JournalComposerSheetState();
}

class _JournalComposerSheetState extends ConsumerState<_JournalComposerSheet> {
  late final TextEditingController _controller;
  MoodLevel? _mood;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.editing?.content ?? '');
    _mood = widget.editing?.mood;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _saving) return;
    setState(() => _saving = true);
    final notifier = ref.read(journalControllerProvider.notifier);
    final ok = widget.editing == null
        ? await notifier.addEntry(content: text, mood: _mood)
        : await notifier.editEntry(
            id: widget.editing!.id,
            content: text,
            mood: _mood,
          );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not save — check your connection and try again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF181436),
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.lg),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.editing == null ? 'New Entry' : 'Edit Entry',
              style: AppTextStyles.screenTitle.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final level in MoodLevel.values)
                  _MoodChip(
                    level: level,
                    selected: _mood == level,
                    onTap: () =>
                        setState(() => _mood = _mood == level ? null : level),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              maxLines: 6,
              minLines: 3,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'What\'s on your mind?',
                hintStyle: AppTextStyles.subtitle,
                filled: true,
                fillColor: Colors.black.withValues(alpha: 0.2),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            GradientPillButton(
              label: _saving ? 'Saving...' : 'Save',
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _MoodChip extends StatelessWidget {
  const _MoodChip({
    required this.level,
    required this.selected,
    required this.onTap,
  });

  final MoodLevel level;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: level.label,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.gold.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.gold : AppColors.cardBorder,
            ),
          ),
          child: Text(level.emoji, style: const TextStyle(fontSize: 18)),
        ),
      ),
    );
  }
}
