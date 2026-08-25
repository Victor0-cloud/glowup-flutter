import 'package:flutter/material.dart';
import '../../core/tod/tod_period.dart';

/// Per-period accent for the Routines family (22a-22g). Confirmed by
/// diffing the exported assets across 22a/22b/22c/22d: this does NOT match
/// Today's per-period accent (Today's afternoon is purple #C084FC; here
/// it's teal #2DD4BF) — each screen family has its own palette in Figma,
/// so this is intentionally a separate config from
/// `today/theme/today_variant_config.dart`.
///
/// The bottom nav's active "Routines" tab is always gold on every 22-series
/// frame regardless of period (unlike Today, where the active tab follows
/// the period accent) — confirmed identical across all 4 hub frames.
class RoutinesVariantConfig {
  const RoutinesVariantConfig({required this.emoji, required this.accent});

  final String emoji;
  final Color accent;

  static const navActiveColor = Color(0xFFFFD043);

  static const Map<TodPeriod, RoutinesVariantConfig> byPeriod = {
    TodPeriod.morning: RoutinesVariantConfig(
      emoji: '☀️',
      accent: Color(0xFFFFD043),
    ),
    TodPeriod.afternoon: RoutinesVariantConfig(
      emoji: '🌤',
      accent: Color(0xFF2DD4BF),
    ),
    TodPeriod.evening: RoutinesVariantConfig(
      emoji: '🌅',
      accent: Color(0xFFFF5E97),
    ),
    TodPeriod.night: RoutinesVariantConfig(
      emoji: '🌙',
      accent: Color(0xFF8E54E9),
    ),
  };
}
