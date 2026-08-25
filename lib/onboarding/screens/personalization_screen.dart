import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_icon.dart';
import '../models/onboarding_profile.dart';
import '../state/onboarding_controller.dart';
import '../widgets/onboarding_scaffold.dart';

/// 12_personalization (node 368:712). A processing state, not a form — no
/// new user input, so it auto-advances once the (simulated, local) save
/// step finishes. No external/live AI model is called here — this screen
/// is truthful about that: it shows real, locally-completed steps
/// (saving the goals/fitness/schedule/notifications/health-connection
/// choices already made on 07-11), never a claim that a live AI Coach is
/// actively "set up" or reachable yet (see `ai_personalization_screen.dart`
/// for the same honesty standard elsewhere in Profile).
class PersonalizationScreen extends ConsumerStatefulWidget {
  const PersonalizationScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  ConsumerState<PersonalizationScreen> createState() =>
      _PersonalizationScreenState();
}

class _PersonalizationScreenState extends ConsumerState<PersonalizationScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      ref
          .read(onboardingControllerProvider.notifier)
          .advanceStep(OnboardingStep.finishSetup);
      widget.onComplete();
    });
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      title: 'Almost There! ⚡',
      subtitle: 'Crafting a bespoke routine that aligns with your timeline.',
      progressIndex: 4,
      primaryLabel: 'Please wait...',
      primaryEnabled: false,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: AppColors.cardEnd,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.purple, width: 4),
              ),
              alignment: Alignment.center,
              child: const Text(
                '85%',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 28),
            const _Step(label: 'Analyzing your goals', done: true),
            const SizedBox(height: 16),
            const _Step(label: 'Building your routine plan', done: true),
            const SizedBox(height: 16),
            const _Step(label: 'Saving your preferences', done: true),
            const SizedBox(height: 16),
            const _Step(label: 'Preparing your dashboard...', done: false),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.label, required this.done});

  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: done
                ? AppColors.successSubtle
                : Colors.white.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: done
                ? const AppIcon('check', size: 14, color: AppColors.success)
                : const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.gold,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: done
                ? AppTextStyles.cardSubtitleMd.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  )
                : AppTextStyles.cardTitle.copyWith(fontSize: 15),
          ),
        ),
      ],
    );
  }
}
