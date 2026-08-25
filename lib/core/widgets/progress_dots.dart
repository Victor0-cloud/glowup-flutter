import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// The 5-dot onboarding progress indicator (active dot = gold 24x8 pill,
/// inactive = 8x8 white-20%). Figma reuses a 5-dot track across the whole
/// 00-13 flow rather than one dot per screen.
class ProgressDots extends StatelessWidget {
  const ProgressDots({super.key, required this.activeIndex, this.count = 5});

  final int activeIndex;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? AppColors.gold : AppColors.dotInactive,
            borderRadius: BorderRadius.circular(100),
          ),
        );
      }),
    );
  }
}
