import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../theme/water_variant_config.dart';

/// A flat, non-photorealistic water-level visualization — the second
/// "Today's Goal" visual the approved `40_water_tracker.png` reference
/// pairs with the progress ring. Deliberately simple: a rounded outline
/// with a solid fill, no gloss/3D/gradient sheen, matching the app's flat
/// design system. Purely decorative/redundant with [WaterProgressRing]'s
/// own accessible percentage announcement, so this is excluded from the
/// semantics tree rather than announced a second time.
class WaterBottleLevel extends StatelessWidget {
  const WaterBottleLevel({
    super.key,
    required this.progress,
    this.width = 56,
    this.height = 148,
  });

  /// 0.0-1.0, already clamped by the caller (matches [WaterProgressRing]'s
  /// own `progress` contract).
  final double progress;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final capWidth = width * 0.4;

    return ExcludeSemantics(
      child: SizedBox(
        width: width,
        height: height + 14,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: capWidth,
              height: 10,
              decoration: BoxDecoration(
                color: WaterColors.brandBlue,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(3),
                ),
                border: Border.all(color: AppColors.cardBorder),
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(width * 0.22),
                child: Container(
                  width: width,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(width * 0.22),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(
                        begin: 0,
                        end: progress.clamp(0, 1).toDouble(),
                      ),
                      duration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 500),
                      curve: Curves.easeOutCubic,
                      builder: (context, animatedProgress, child) {
                        return FractionallySizedBox(
                          heightFactor: animatedProgress,
                          widthFactor: 1,
                          child: Container(
                            color: WaterColors.brandBlue.withValues(
                              alpha: 0.85,
                            ),
                          ),
                        );
                      },
                    ),
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
