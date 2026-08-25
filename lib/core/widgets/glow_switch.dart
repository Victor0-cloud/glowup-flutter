import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The 10_notifications toggle. Figma exports each state as a complete
/// static 48x28 track+knob image (Switch-Track: green #4ADE80 track /
/// white knob on the right when on, translucent-white track / white knob
/// on the left when off) — this renders those exact assets and crossfades
/// between them, wrapped in a tap target so it stays functional.
class GlowSwitch extends StatelessWidget {
  const GlowSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: SizedBox(
        width: 48,
        height: 28,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: SvgPicture.asset(
            value
                ? 'assets/glow_up/icons/switch-track-on.svg'
                : 'assets/glow_up/icons/switch-track-off.svg',
            key: ValueKey(value),
            width: 48,
            height: 28,
          ),
        ),
      ),
    );
  }
}
