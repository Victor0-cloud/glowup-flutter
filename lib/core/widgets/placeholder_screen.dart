import 'package:flutter/material.dart';
import '../theme/app_text_styles.dart';
import 'gradient_background.dart';
import 'onboarding_back_button.dart';

/// A properly-named shell for a destination that isn't built yet, so
/// navigation architecture stays valid without faking a finished feature.
/// Named after its target Figma family (e.g. "31 Workout") so it's obvious
/// what's supposed to replace it.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.figmaFamily,
  });

  final String title;
  final String figmaFamily;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: Column(
          children: [
            const OnboardingBackButton(),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.screenTitle,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Figma family "$figmaFamily" — not built yet in this pass.',
                        style: AppTextStyles.subtitle,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
