import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Renders an SVG icon exported straight from the approved Figma file
/// (assets/glow_up/icons/&lt;name&gt;.svg). Never hand-drawn.
class AppIcon extends StatelessWidget {
  const AppIcon(this.name, {super.key, this.size = 24, this.color});

  final String name;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    // Figma reuses the exact same "sun" vector symbol both as the large
    // mascot art and as small in-context icons (09_schedule's Morning
    // card, 10_notifications' mini bubble) — same source, one file.
    final path = name == 'sun-mascot'
        ? 'assets/glow_up/mascot/sun-mascot.svg'
        : 'assets/glow_up/icons/$name.svg';
    return SvgPicture.asset(
      path,
      width: size,
      height: size,
      colorFilter: color != null
          ? ColorFilter.mode(color!, BlendMode.srcIn)
          : null,
    );
  }
}

/// The Glow Up "sun" mascot illustration (assets/glow_up/mascot/sun-mascot.svg),
/// used at multiple sizes across onboarding — never recolored, always its
/// native multi-color art.
class AppMascot extends StatelessWidget {
  const AppMascot({super.key, this.size = 100});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/glow_up/mascot/sun-mascot.svg',
      width: size,
      height: size,
    );
  }
}
