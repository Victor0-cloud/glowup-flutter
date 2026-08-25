import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/ambient_glow.dart';
import '../../core/widgets/app_icon.dart';
import '../theme/today_variant_config.dart';

/// 368:897 "Header-Area" + 368:896 "Ambient-Glow". The night variant adds
/// a moon badge (368:1187) next to the greeting that no other variant has.
class TodayHeader extends StatelessWidget {
  const TodayHeader({super.key, required this.name, required this.variant});

  final String name;
  final TodayVariantConfig variant;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: -60,
          left: 0,
          right: 0,
          child: Center(child: AmbientGlow(color: variant.ambientGlowColor)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hi, $name ✨',
                    style: AppTextStyles.screenTitle.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${variant.greetingLine}, $name ${variant.emoji}',
                    style: AppTextStyles.subtitle.copyWith(fontSize: 15),
                  ),
                ],
              ),
              if (variant.showMoonBadge)
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1A3C),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Center(
                    child: AppIcon('moon', size: 20, color: AppColors.gold),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
