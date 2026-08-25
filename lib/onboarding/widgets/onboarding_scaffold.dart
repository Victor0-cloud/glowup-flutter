import 'package:flutter/material.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/gradient_pill_button.dart';
import '../../core/widgets/onboarding_back_button.dart';
import '../../core/widgets/progress_dots.dart';

/// Shared "Top-Section / content / Bottom-Action" layout used by every
/// 00-13 onboarding screen in Figma. Content is wrapped in a scroll view
/// so the flow stays responsive across device sizes instead of overflowing
/// on shorter screens.
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.titleStyle,
    this.centerTitle = false,
    required this.body,
    this.progressIndex,
    required this.primaryLabel,
    this.onPrimaryPressed,
    this.primaryLoading = false,
    this.primaryEnabled = true,
    this.belowButton,
    this.headerLeading,
  });

  final String title;
  final String? subtitle;
  final TextStyle? titleStyle;
  final bool centerTitle;
  final Widget body;
  final int? progressIndex;
  final String primaryLabel;
  final VoidCallback? onPrimaryPressed;
  final bool primaryLoading;
  final bool primaryEnabled;
  final Widget? belowButton;
  final Widget? headerLeading;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: Column(
          children: [
            const OnboardingBackButton(),
            ?headerLeading,
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Column(
                crossAxisAlignment: centerTitle
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    textAlign: centerTitle ? TextAlign.center : TextAlign.start,
                    style: titleStyle ?? AppTextStyles.screenTitle,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      subtitle!,
                      textAlign: centerTitle
                          ? TextAlign.center
                          : TextAlign.start,
                      style: AppTextStyles.subtitle,
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 16),
                child: body,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Column(
                children: [
                  if (progressIndex != null) ...[
                    ProgressDots(activeIndex: progressIndex!),
                    const SizedBox(height: 20),
                  ],
                  GradientPillButton(
                    label: primaryLabel,
                    onPressed: onPrimaryPressed,
                    enabled: primaryEnabled,
                    loading: primaryLoading,
                  ),
                  ?belowButton,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
