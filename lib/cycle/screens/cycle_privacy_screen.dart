import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../coach/widgets/settings_widgets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glow_card.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/sub_screen_header.dart';
import '../state/cycle_controller.dart';

/// Copies the plain-text export to the clipboard — a real, working
/// "export" with no new dependency, since there is no share/file-export
/// package in this project yet.
Future<void> copyCycleExportToClipboard(WidgetRef ref) async {
  final text = ref.read(cycleControllerProvider.notifier).exportSummaryText();
  await Clipboard.setData(ClipboardData(text: text));
}

/// PC09 Cycle Privacy — the real settings + real data controls. "Review AI
/// memories" and "Notification privacy" from the design reference aren't
/// backed by any real screen or stored data in this app yet, so they're
/// intentionally left out rather than wired to a dead button.
class CyclePrivacyScreen extends ConsumerWidget {
  const CyclePrivacyScreen({super.key, this.onBack, this.onEditBasics});

  final VoidCallback? onBack;
  final VoidCallback? onEditBasics;

  Future<void> _confirmDeleteAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardStart,
        title: const Text(
          'Delete all cycle data?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'This permanently deletes every period, day entry and notebook entry. This cannot be undone.',
          style: AppTextStyles.subtitle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(cycleControllerProvider.notifier).deleteAllData();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cycleAsync = ref.watch(cycleControllerProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: Column(
          children: [
            SubScreenHeader(
              title: 'Cycle Privacy',
              subtitle:
                  'Your sensitive wellness data stays under your control.',
              onBack: onBack ?? () => Navigator.maybePop(context),
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
                  final settings = state.settings;
                  final controller = ref.read(cycleControllerProvider.notifier);

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ToggleRow(
                          label: 'Cycle-aware suggestions',
                          value: settings.cycleAwareSuggestions,
                          onChanged: (v) => controller.updateSettings(
                            settings.copyWith(cycleAwareSuggestions: v),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ToggleRow(
                          label: 'Period reminders',
                          value: settings.remindersEnabled,
                          onChanged: (v) => controller.updateSettings(
                            settings.copyWith(remindersEnabled: v),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ToggleRow(
                          label: 'AI memory',
                          value: settings.aiMemoryConsent,
                          onChanged: (v) => controller.updateSettings(
                            settings.copyWith(aiMemoryConsent: v),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'AI memory lets the Glow Up Brain remember structured signals (like a symptom trend), never your private notes\' text.',
                          style: AppTextStyles.caption.copyWith(fontSize: 12),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Your controls',
                          style: AppTextStyles.cardTitleLg.copyWith(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        GlowCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              _ControlRow(
                                label: 'Export cycle data',
                                onTap: () async {
                                  await copyCycleExportToClipboard(ref);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Export copied to clipboard',
                                        ),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                },
                              ),
                              const Divider(
                                height: 1,
                                color: AppColors.cardBorder,
                              ),
                              _ControlRow(
                                label: 'Edit cycle basics',
                                onTap: onEditBasics,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Semantics(
                          button: true,
                          label: 'Delete all cycle data',
                          child: Material(
                            color: AppColors.ctaStart.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _confirmDeleteAll(context, ref),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppColors.ctaStart.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Delete all cycle data',
                                      style: AppTextStyles.cardTitle.copyWith(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.ctaStart,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Permanently remove logs, notes and derived cycle memories.',
                                      style: AppTextStyles.subtitle.copyWith(
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.blue.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            'Cycle estimates support wellness planning only. They are not contraception or medical advice.',
                            style: AppTextStyles.subtitle.copyWith(
                              fontSize: 13,
                            ),
                          ),
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
}

class _ControlRow extends StatelessWidget {
  const _ControlRow({required this.label, this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textSecondary,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
