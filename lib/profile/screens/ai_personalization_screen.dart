import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../brain/events/learning_event_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glow_card.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/sub_screen_header.dart';
import '../../coach/widgets/settings_widgets.dart';
import '../state/profile_controller.dart';

/// AI Personalization. The real AI Coach reply generator is not connected
/// yet (see `UnconnectedCoachBrainService`) — this screen never claims
/// otherwise. It explains what real, structured data already feeds the
/// Brain pipeline (not raw conversation history), a real stored consent
/// toggle, and a real memory-reset action.
class AiPersonalizationScreen extends ConsumerWidget {
  const AiPersonalizationScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileControllerProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: Column(
          children: [
            SubScreenHeader(
              title: 'AI Personalization',
              subtitle: 'Coach memory and adaptive settings',
              onBack: onBack ?? () => Navigator.maybePop(context),
            ),
            Expanded(
              child: profileAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.purple),
                ),
                error: (e, st) => Center(
                  child: Text(
                    "Couldn't load this page.",
                    style: AppTextStyles.subtitle,
                  ),
                ),
                data: (profileState) {
                  final controller = ref.read(
                    profileControllerProvider.notifier,
                  );
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GlowCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 18,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'The AI Coach chat is not yet connected to a live AI model.',
                                      style: AppTextStyles.captionBold.copyWith(
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Once it is, it will use structured signals you\'ve generated in the app — goals, routines completed, water logged — never raw journal or chat text, and never without your consent below.',
                                style: AppTextStyles.subtitle.copyWith(
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        ToggleRow(
                          label: 'Allow AI personalization',
                          value: profileState.settings.aiPersonalizationEnabled,
                          onChanged: (v) => controller.updateSettings(
                            profileState.settings.copyWith(
                              aiPersonalizationEnabled: v,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'MEMORY',
                          style: AppTextStyles.captionBold.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Consumer(
                          builder: (context, ref, _) {
                            final events =
                                ref
                                    .watch(learningEventControllerProvider)
                                    .valueOrNull ??
                                const [];
                            return GlowCard(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      events.isEmpty
                                          ? 'No stored activity signals yet.'
                                          : '${events.length} stored activity signal${events.length == 1 ? '' : 's'}.',
                                      style: AppTextStyles.subtitle.copyWith(
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  Semantics(
                                    button: true,
                                    label: 'Reset AI memory',
                                    child: TextButton(
                                      onPressed: events.isEmpty
                                          ? null
                                          : () => _confirmReset(context, ref),
                                      child: Text(
                                        'Reset',
                                        style: AppTextStyles.captionBold
                                            .copyWith(
                                              color: AppColors.orange,
                                              fontSize: 13,
                                            ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
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

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardStart,
        title: const Text(
          'Reset AI memory?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'This permanently deletes every stored activity signal on this device. This cannot be undone.',
          style: AppTextStyles.subtitle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(learningEventControllerProvider.notifier).clearAll();
    }
  }
}
