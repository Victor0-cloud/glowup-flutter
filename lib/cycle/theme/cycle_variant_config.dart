import 'package:flutter/material.dart';

import '../../core/tod/tod_period.dart';

/// Period & Cycle's own per-time-of-day accent — same shared-architecture
/// pattern as `WaterVariantConfig`/`ProfileVariantConfig`: one shared
/// [TodPeriod], each module supplies its own palette rather than a second
/// copy of the page per period. Per the approved spec: Morning=gold,
/// Afternoon=purple/lavender, Evening=pink/magenta, Night=deep
/// blue/purple — the same values Water/Profile already use. Content,
/// data and layout never change between variants — only these accent
/// colors do.
class CycleVariantConfig {
  const CycleVariantConfig({required this.accent, required this.glow});

  final Color accent;
  final Color glow;

  static const Map<TodPeriod, CycleVariantConfig> byPeriod = {
    TodPeriod.morning: CycleVariantConfig(
      accent: Color(0xFFFFD043),
      glow: Color(0xFFFFD043),
    ),
    TodPeriod.afternoon: CycleVariantConfig(
      accent: Color(0xFFC084FC),
      glow: Color(0xFFC084FC),
    ),
    TodPeriod.evening: CycleVariantConfig(
      accent: Color(0xFFFF5E97),
      glow: Color(0xFFFF5E97),
    ),
    TodPeriod.night: CycleVariantConfig(
      accent: Color(0xFF8E54E9),
      glow: Color(0xFF8E54E9),
    ),
  };
}
