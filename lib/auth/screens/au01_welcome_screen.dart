import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';

/// AU01 Welcome — the real, unauthenticated entry point.
///
/// The hero photograph (woman facing a sunset over mountains) is a REAL
/// crop taken directly from the approved reference at
/// `assets/glow_up/design_reference/auth/AU01_welcome.png` — no standalone
/// source photograph exists anywhere in this repository (confirmed by a
/// full search of `assets/glow_up/`), so the only genuine way to recover
/// the approved artwork was to extract it from that flattened reference
/// image rather than substitute a placeholder/gradient/icon.
///
/// Crop: the reference PNG is 138x360px. Pixels y=0-57 (the baked-in
/// "Glow Up ✨" title) and y=225-360 (the baked-in headline/subtitle/
/// buttons) are excluded — only the clean photographic band, y=58-225
/// (138x167), survives into `assets/glow_up/auth/au01_hero_derived.png`.
/// Every other pixel on this screen — the title, headline, subtitle, both
/// buttons — is real Flutter UI, never a screenshot.
///
/// Because the source is a small flattened mockup (not a full-resolution
/// photo asset), `BoxFit.cover` at near-full-screen size necessarily
/// upscales it well beyond its native resolution — the image will read as
/// soft rather than crisp. That's an honest, disclosed limitation of
/// there being no higher-resolution source, not a rendering bug.
///
/// "Get Started" and "I already have an account" both lead to AU02
/// (sign-in method), which already offers both a "Create an account" path
/// and real sign-in options — matching the approved reference exactly, no
/// invented screen. This screen changes AU01's presentation only; it does
/// not touch auth logic/routing.
class AuthWelcomeScreen extends StatelessWidget {
  const AuthWelcomeScreen({
    super.key,
    required this.onGetStarted,
    required this.onSignIn,
  });

  final VoidCallback onGetStarted;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBottom,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/glow_up/auth/au01_hero_derived.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              filterQuality: FilterQuality.high,
            ),
          ),
          // The approved "photograph continues behind the text while
          // gradually darkening toward the bottom" treatment — a smooth
          // multi-stop fade, never a hard rectangular panel.
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Color(0x33090A1A),
                    Color(0xCC090A1A),
                    Color(0xFF090A1A),
                  ],
                  stops: [0.0, 0.38, 0.58, 0.8, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Glow Up ✨',
                    style: AppTextStyles.heroTitle.copyWith(
                      fontSize: 28,
                      shadows: const [
                        Shadow(
                          color: Color(0x99000000),
                          blurRadius: 12,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Your journey to a\nhealthier, happier you.',
                    style: AppTextStyles.screenTitle.copyWith(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                      shadows: const [
                        Shadow(
                          color: Color(0xB3000000),
                          blurRadius: 10,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Start today. Glow every day.',
                    style: AppTextStyles.subtitleLg.copyWith(
                      color: const Color(0xFFDCD3F5),
                    ),
                  ),
                  const SizedBox(height: 28),
                  _GoldPillButton(
                    label: 'Get Started',
                    onPressed: onGetStarted,
                  ),
                  const SizedBox(height: 12),
                  _OutlinePillButton(
                    label: 'I already have an account',
                    onPressed: onSignIn,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The approved warm gold/yellow primary CTA — deliberately NOT the pink
/// -> purple `GradientPillButton` used elsewhere in onboarding, since
/// AU01's reference specifically calls for gold with dark text.
class _GoldPillButton extends StatelessWidget {
  const _GoldPillButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.gold,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66FFD043),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            onTap: onPressed,
            child: Center(
              child: Text(
                label,
                style: AppTextStyles.buttonLabel.copyWith(
                  color: AppColors.onSelected,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OutlinePillButton extends StatelessWidget {
  const _OutlinePillButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadii.pill),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            onTap: onPressed,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.pill),
                border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: AppTextStyles.captionBold.copyWith(
                  color: Colors.white,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
