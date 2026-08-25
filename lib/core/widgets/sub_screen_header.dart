import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'app_icon.dart';

/// The "Back-And-Title" header pattern shared by 22e/22f/22g (368:1969,
/// 368:2070, 368:2172) — a 32px ghost back button, 24px Black title, and a
/// muted subtitle underneath. Reused rather than rebuilt per screen.
class SubScreenHeader extends StatelessWidget {
  const SubScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Semantics(
                      button: true,
                      label: 'Back',
                      child: Material(
                        color: Colors.transparent,
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: onBack ?? () => Navigator.maybePop(context),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.07),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: AppIcon('chevron-left', size: 16),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: AppTextStyles.screenTitle.copyWith(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 44),
                    child: Text(
                      subtitle!,
                      style: AppTextStyles.subtitle.copyWith(fontSize: 14),
                    ),
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// The wide gold->pink "Gradient-Button" style used for primary actions on
/// 22e/22f (Start Routine / Save Routine) — visually distinct from
/// onboarding's pink->purple pill (16px rounded rect, not a full pill;
/// dark #0A0B1E text, not white).
class RoutineGradientButton extends StatelessWidget {
  const RoutineGradientButton({super.key, required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.gold, AppColors.ctaStart],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF0A0B1E),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The calendar-check "Left-Visual" routine badge (368:1638/1650). Figma
/// exports this as two complete, self-contained assets — background tint
/// and icon stroke baked into the same file for each state — not one
/// asset meant to be recolored, so this picks between the two files rather
/// than tinting a single one (which would wrongly flatten the background's
/// low opacity to a solid fill).
class RoutineBadge extends StatelessWidget {
  const RoutineBadge({super.key, required this.highlighted, this.size = 48});

  final bool highlighted;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AppIcon(
      highlighted ? 'routine-badge-active' : 'routine-badge-inactive',
      size: size,
    );
  }
}
