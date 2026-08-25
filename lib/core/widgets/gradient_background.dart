import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

/// The dark navy/violet 3-stop vertical gradient used behind every screen
/// in the approved Figma file. This replaces the Figma "phone mockup"
/// frame (fake status bar, rounded 40px bezel) with a real full-bleed
/// screen + [SafeArea], since a real device already draws its own chrome.
class GradientBackground extends StatelessWidget {
  const GradientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: AppColors.backgroundGradient,
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(child: child),
      ),
    );
  }
}
