import 'package:flutter/material.dart';
import '../../core/tod/tod_period.dart';

/// The Coach family's own per-period accent (368:2303/2391/2485/2572's
/// Ambient-Glow fill, confirmed by downloading and diffing all 4 exported
/// glow SVGs). Distinct from both Today's and Routines' per-period
/// palettes — each screen family in this Figma file defines its own, per
/// the pattern already established for Routines.
class CoachVariantConfig {
  const CoachVariantConfig({required this.ambientGlow});

  final Color ambientGlow;

  static const navActiveColor = Color(0xFFFFD043);

  static const Map<TodPeriod, CoachVariantConfig> byPeriod = {
    TodPeriod.morning: CoachVariantConfig(ambientGlow: Color(0xFFFFD043)),
    TodPeriod.afternoon: CoachVariantConfig(ambientGlow: Color(0xFFFF5E97)),
    TodPeriod.evening: CoachVariantConfig(ambientGlow: Color(0xFFC084FC)),
    TodPeriod.night: CoachVariantConfig(ambientGlow: Color(0xFF8E54E9)),
  };
}
