import 'package:flutter/material.dart';

import '../../core/tod/tod_period.dart';

/// Profile's own per-time-of-day accent — same shared-architecture
/// pattern as `WaterVariantConfig`/`CoachVariantConfig`/
/// `TodayVariantConfig`: one shared [TodPeriod], each module supplies its
/// own palette rather than a second copy of the page per period. Per the
/// approved Profile spec: Morning=gold, Afternoon=purple/lavender,
/// Evening=pink/magenta, Night=deep blue/purple — the same values Water
/// already uses, and (for Night specifically) a deliberate divergence
/// from Today's own muted-gray night treatment, exactly the kind of
/// disclosed per-module variation Water's own config already documents.
class ProfileVariantConfig {
  const ProfileVariantConfig({required this.accent, required this.glow});

  final Color accent;
  final Color glow;

  static const Map<TodPeriod, ProfileVariantConfig> byPeriod = {
    TodPeriod.morning: ProfileVariantConfig(
      accent: Color(0xFFFFD043),
      glow: Color(0xFFFFD043),
    ),
    TodPeriod.afternoon: ProfileVariantConfig(
      accent: Color(0xFFC084FC),
      glow: Color(0xFFC084FC),
    ),
    TodPeriod.evening: ProfileVariantConfig(
      accent: Color(0xFFFF5E97),
      glow: Color(0xFFFF5E97),
    ),
    TodPeriod.night: ProfileVariantConfig(
      accent: Color(0xFF8E54E9),
      glow: Color(0xFF8E54E9),
    ),
  };
}
