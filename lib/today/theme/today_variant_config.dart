import 'package:flutter/material.dart';
import '../../core/tod/tod_period.dart';

/// Every visual/copy value that differs between the 4 approved Today
/// frames, extracted directly from each frame's `get_design_context`
/// output (20a=368:885, 20b=368:980, 20c=368:1075, 20d=368:1170) — not
/// approximated. Confirmed by diffing the exported icon/gradient assets
/// across variants: quick-action icons, the Up-Next card border, the
/// active nav tab, and the ambient glow all recolor together per period;
/// the Glow Score ring gradient and progress bar fill use their own
/// (related but distinct) per-period colors; inactive nav icons and the
/// AI Coach Tip header stay constant across all four.
class TodayVariantConfig {
  const TodayVariantConfig({
    required this.greetingLine,
    required this.emoji,
    required this.accent,
    required this.progressBarColor,
    required this.scoreRingGradient,
    required this.ambientGlowColor,
    required this.planTitle,
    required this.planSubtitle,
    required this.coachTip,
    this.showMoonBadge = false,
  });

  final String greetingLine; // "Good Morning", "Good Afternoon", ...
  final String emoji;
  final Color accent; // quick-action icons, Up-Next border, active nav tab
  final Color progressBarColor;
  final List<Color> scoreRingGradient;
  final Color ambientGlowColor;
  final String planTitle;
  final String planSubtitle;
  final String coachTip;

  /// Night only — the small moon badge next to the greeting (368:1187).
  final bool showMoonBadge;

  static const _upNextSubtitle = 'Scheduled for your target window';

  static const Map<TodPeriod, TodayVariantConfig> byPeriod = {
    TodPeriod.morning: TodayVariantConfig(
      greetingLine: 'Good Morning',
      emoji: '☀️',
      accent: Color(0xFFFFD043),
      progressBarColor: Color(0xFFFFD043),
      scoreRingGradient: [Color(0xFFFFD043), Color(0xFFFF5E97)],
      ambientGlowColor: Color(0xFFFFD043),
      planTitle: 'Morning Yoga Flow — 20 min',
      planSubtitle: _upNextSubtitle,
      coachTip: 'Start your day with 5 minutes of stretching.',
    ),
    TodPeriod.afternoon: TodayVariantConfig(
      greetingLine: 'Good Afternoon',
      emoji: '🌤',
      accent: Color(0xFFC084FC),
      progressBarColor: Color(0xFF8E54E9),
      scoreRingGradient: [Color(0xFF07ABD6), Color(0xFF8E54E9)],
      ambientGlowColor: Color(0xFF8E54E9),
      planTitle: 'HIIT Cardio Blast — 30 min',
      planSubtitle: _upNextSubtitle,
      coachTip: 'Perfect time for a high-energy workout.',
    ),
    TodPeriod.evening: TodayVariantConfig(
      greetingLine: 'Good Evening',
      emoji: '🌅',
      accent: Color(0xFFFF5E97),
      progressBarColor: Color(0xFFFF5E97),
      scoreRingGradient: [Color(0xFFFF5E97), Color(0xFFC084FC)],
      ambientGlowColor: Color(0xFFFF5E97),
      planTitle: 'Evening Stretch — 15 min',
      planSubtitle: _upNextSubtitle,
      coachTip: 'Wind down with some gentle stretching.',
    ),
    TodPeriod.night: TodayVariantConfig(
      greetingLine: 'Good Night',
      emoji: '🌙',
      accent: Color(
        0xFFB0B5E3,
      ), // muted — night's active tab is not brand-colored in Figma
      progressBarColor: Color(0xFF8E54E9),
      scoreRingGradient: [Color(0xFF8E54E9), Color(0xFF161233)],
      ambientGlowColor: Color(0xFF251B4F),
      planTitle: 'Bedtime Meditation — 10 min',
      planSubtitle: _upNextSubtitle,
      coachTip: 'Set your sleep alarm for optimal rest.',
      showMoonBadge: true,
    ),
  };
}
