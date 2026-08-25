import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_icon.dart';
import '../models/onboarding_profile.dart';
import '../state/onboarding_controller.dart';
import '../widgets/onboarding_scaffold.dart';

/// 09_schedule (node 368:560). Single-select; also seeds the app's
/// default time-of-day theme going forward.
class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key, required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);

    return OnboardingScaffold(
      title: 'Your Schedule 📅',
      subtitle:
          "When do you prefer to work out? We'll plan your reminder alerts.",
      progressIndex: 2,
      primaryLabel: 'Next',
      primaryEnabled: profile.scheduleWindow != null,
      onPrimaryPressed: profile.scheduleWindow != null
          ? () {
              controller.advanceStep(OnboardingStep.notifications);
              onNext();
            }
          : null,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            for (final window in ScheduleWindow.values) ...[
              _ScheduleCard(
                window: window,
                selected: profile.scheduleWindow == window,
                onTap: () => controller.setScheduleWindow(window),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.window,
    required this.selected,
    required this.onTap,
  });

  final ScheduleWindow window;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.xl),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: selected
                  ? const [AppColors.selectedStart, AppColors.selectedEnd]
                  : const [AppColors.cardStart, AppColors.cardEnd],
            ),
            borderRadius: BorderRadius.circular(AppRadii.xl),
            border: Border.all(
              color: selected ? AppColors.gold : AppColors.cardBorder,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.13),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: AppIcon(
                    window.icon,
                    size: 28,
                    // The Morning icon is the multi-color sun mascot art and
                    // is never recolored; the other three are line icons
                    // that Figma tints orange when unselected, dark when
                    // selected, same as the other single-select screens.
                    color: window == ScheduleWindow.morning
                        ? null
                        : (selected ? AppColors.onSelected : AppColors.orange),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    window.label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: selected ? AppColors.onSelected : Colors.white,
                      fontFamily: AppTextStyles.cardTitle.fontFamily,
                    ),
                  ),
                  Text(
                    window.timeRange,
                    style: TextStyle(
                      fontSize: 12,
                      color: selected
                          ? AppColors.onSelected.withValues(alpha: 0.67)
                          : AppColors.textSecondary,
                      fontFamily: AppTextStyles.cardSubtitleMd.fontFamily,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
