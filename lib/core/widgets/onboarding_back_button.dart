import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A back affordance for the onboarding flow. Figma's frames don't design
/// an explicit back control (the assumption was OS-level back), but that
/// only exists on Android/iOS — there's no equivalent gesture on desktop
/// or web, which left "back" completely inert on those targets. This is a
/// deliberately low-visual-weight addition (no Figma asset exists for it,
/// so a standard platform glyph is used) shown only when there's actually
/// somewhere to go back to.
class OnboardingBackButton extends StatelessWidget {
  const OnboardingBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Navigator.canPop(context)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Semantics(
          button: true,
          label: 'Back',
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.maybePop(context),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 16,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
