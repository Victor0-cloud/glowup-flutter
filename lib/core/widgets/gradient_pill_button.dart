import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';

/// The pink -> purple "Button-Gradient-Pill" CTA used at the bottom of
/// every onboarding screen (Next / Continue / Get Started / Start My Glow Up).
class GradientPillButton extends StatelessWidget {
  const GradientPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool enabled;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final isEnabled = enabled && onPressed != null && !loading;
    return Opacity(
      opacity: isEnabled ? 1 : 0.5,
      child: Container(
        height: 56,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [AppColors.ctaStart, AppColors.ctaEnd],
          ),
          borderRadius: BorderRadius.circular(AppRadii.pill),
          boxShadow: isEnabled
              ? const [
                  BoxShadow(
                    color: AppColors.ctaShadow,
                    blurRadius: 12,
                    offset: Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            onTap: isEnabled ? onPressed : null,
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Text(label, style: AppTextStyles.buttonLabel),
            ),
          ),
        ),
      ),
    );
  }
}
