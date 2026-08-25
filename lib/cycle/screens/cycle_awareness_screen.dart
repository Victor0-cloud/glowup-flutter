import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glow_card.dart';
import '../../core/widgets/gradient_pill_button.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/sub_screen_header.dart';
import '../models/cycle_models.dart';
import '../state/cycle_controller.dart';

/// PC01 Cycle Awareness — the optional opt-in consent screen. Cycle
/// tracking never blocks anything else in the app; "Maybe later" and "Not
/// applicable to me" are both fully valid, permanent choices.
class CycleAwarenessScreen extends ConsumerWidget {
  const CycleAwarenessScreen({
    super.key,
    this.onBack,
    this.onSetUp,
    this.onDismissed,
  });

  final VoidCallback? onBack;
  final VoidCallback? onSetUp;

  /// Called after "Maybe later" or "Not applicable to me" — both just
  /// leave/return without setting up tracking.
  final VoidCallback? onDismissed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: Column(
          children: [
            SubScreenHeader(
              title: 'Period & Cycle',
              subtitle: 'Optional, private and always under your control.',
              onBack: onBack ?? () => Navigator.maybePop(context),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: Column(
                  children: [
                    Icon(
                      Icons.water_drop_outlined,
                      size: 72,
                      color: AppColors.ctaStart,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Make your plan cycle-aware?',
                      style: AppTextStyles.screenTitle.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Glow Up can consider your cycle alongside how you actually feel each day.',
                      style: AppTextStyles.subtitle,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    GlowCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PRIVATE BY DESIGN',
                            style: AppTextStyles.captionBold.copyWith(
                              color: AppColors.purple,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your dates, symptoms and notes stay private. Review, export or delete them anytime.',
                            style: AppTextStyles.subtitle.copyWith(
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    GradientPillButton(
                      label: 'Set up cycle tracking',
                      onPressed: onSetUp,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: onDismissed,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.cardBorder),
                        ),
                        child: Text(
                          'Maybe later',
                          style: AppTextStyles.captionBold.copyWith(
                            color: Colors.white,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Semantics(
                      button: true,
                      label: 'Not applicable to me',
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () async {
                            await ref
                                .read(cycleControllerProvider.notifier)
                                .updateSettings(
                                  ref
                                          .read(cycleControllerProvider)
                                          .valueOrNull
                                          ?.settings
                                          .copyWith(trackingDeclined: true) ??
                                      const CycleSettings(
                                        trackingDeclined: true,
                                      ),
                                );
                            onDismissed?.call();
                          },
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 44),
                            alignment: Alignment.center,
                            child: Text(
                              'Not applicable to me',
                              style: AppTextStyles.captionBold.copyWith(
                                color: AppColors.purple,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
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
}
