import 'package:flutter/material.dart';

/// Color tokens read directly off the approved production Figma screens
/// (node 368:2), not off the Design System page (271:2) — the two
/// diverge (see architecture report) and the live screens win.
class AppColors {
  AppColors._();

  // App shell background — 180deg 3-stop gradient used on every screen.
  static const Color bgTop = Color(0xFF0B0C24);
  static const Color bgMid = Color(0xFF161233);
  static const Color bgBottom = Color(0xFF090A1A);
  static const List<Color> backgroundGradient = [bgTop, bgMid, bgBottom];

  // Card surface gradient, left-to-right.
  static const Color cardStart = Color(0xFF251B4F);
  static const Color cardEnd = Color(0xFF181436);
  static const Color cardBorder = Color(0x14FFFFFF); // rgba(255,255,255,0.08)

  // Primary CTA pill gradient (pink -> purple) + its drop shadow.
  static const Color ctaStart = Color(0xFFFF5E97);
  static const Color ctaEnd = Color(0xFF8E54E9);
  static const Color ctaShadow = Color(0x4D8E54E9); // rgba(142,84,233,0.3)

  // Selected / highlighted state gradient (gold -> pink), text goes dark.
  static const Color selectedStart = Color(0xFFFFD043);
  static const Color selectedEnd = Color(0xFFFF5E97);
  static const Color onSelected = Color(0xFF0A0B1E);

  // Gold accent — active progress dot, links, highlight text.
  static const Color gold = Color(0xFFFFD043);

  // Text.
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFB0B5E3);

  // Status / brand accents reused across onboarding cards.
  static const Color success = Color(0xFF4ADE80);
  static const Color successSubtle = Color(0x214ADE80); // 0.13 alpha
  static const Color purple = Color(0xFF8E54E9);
  static const Color purpleSubtle = Color(0x218E54E9);
  static const Color lavenderAccent = Color(0xFFC084FC);
  static const Color pinkSubtle = Color(0x1CFF5E97); // 0.11 alpha
  static const Color orange = Color(0xFFFFB03A);
  static const Color blue = Color(0xFF07ABD6);

  static const Color dotInactive = Color(0x33FFFFFF); // rgba(255,255,255,0.2)
}
