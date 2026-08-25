import 'package:flutter/material.dart';

import '../../core/tod/tod_period.dart';

/// Water Tracker's own per-time-of-day accent, following the exact same
/// shared-architecture pattern already used by `TodayVariantConfig`/
/// `CoachVariantConfig`/`RoutinesVariantConfig` — one shared [TodPeriod]
/// resolved from [currentTodPeriodProvider], each module supplying its own
/// palette rather than a second copy of the page per period. Per the
/// approved spec: Morning=gold, Afternoon=purple/lavender, Evening=pink,
/// Night=blue/purple — distinct from Today's own night treatment (muted
/// gray) since Water's night accent is explicitly spec'd as blue/purple,
/// a disclosed per-module variation exactly like Coach/Routines already
/// have their own distinct palettes.
///
/// This only ever colors *interactive/accent* surfaces (buttons, selected
/// chips, active nav, ring gradient). The water-drop identity itself
/// (icon, "brand" reference) stays [WaterColors.brandBlue] in every
/// period — "water blue remains the semantic hydration color" per the
/// approved spec — so hydration is always recognizable as hydration
/// regardless of time of day.
class WaterVariantConfig {
  const WaterVariantConfig({required this.accent, required this.ringGradient});

  final Color accent;
  final List<Color> ringGradient;

  static const Map<TodPeriod, WaterVariantConfig> byPeriod = {
    TodPeriod.morning: WaterVariantConfig(
      accent: Color(0xFFFFD043),
      ringGradient: [Color(0xFFFFD043), Color(0xFF07ABD6)],
    ),
    TodPeriod.afternoon: WaterVariantConfig(
      accent: Color(0xFFC084FC),
      ringGradient: [Color(0xFFC084FC), Color(0xFF07ABD6)],
    ),
    TodPeriod.evening: WaterVariantConfig(
      accent: Color(0xFFFF5E97),
      ringGradient: [Color(0xFFFF5E97), Color(0xFF07ABD6)],
    ),
    TodPeriod.night: WaterVariantConfig(
      accent: Color(0xFF8E54E9),
      ringGradient: [Color(0xFF07ABD6), Color(0xFF8E54E9)],
    ),
  };
}

/// The one hydration identity color, constant across every time-of-day
/// variant — see [WaterVariantConfig]'s doc.
class WaterColors {
  WaterColors._();
  static const Color brandBlue = Color(0xFF07ABD6);
}
