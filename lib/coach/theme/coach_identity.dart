import 'package:flutter/material.dart';

/// Centralized AI Coach visual identity — the one place that names which
/// asset represents "the AI Coach" today, so a future multi-coach feature
/// (different personas/voices) only ever needs to change this file, never
/// every screen that shows a Coach avatar. Deliberately not building
/// coach-selection now — this exists solely so today's single approved
/// female Coach identity (assets/glow_up/coach/coach_woman_tyra.png,
/// confirmed the exact tracked filename) isn't hardcoded in N places.
class CoachIdentity {
  CoachIdentity._();

  static const String avatarAssetPath =
      'assets/glow_up/coach/coach_woman_tyra.png';
}

/// A circular AI Coach avatar — face-centered BoxFit.cover, real aspect
/// ratio preserved (no stretching/squashing, no odd forehead/chin crop
/// since the source image is already a clean portrait). Falls back to the
/// original robot-emoji identity if the asset ever fails to load
/// (corrupted/missing file), so a broken image can never crash a Coach
/// screen — see the Web/asset-loading safety audit that added this.
class CoachAvatar extends StatelessWidget {
  const CoachAvatar({super.key, this.size = 40, this.emojiFallbackSize});

  final double size;
  final double? emojiFallbackSize;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Image.asset(
        CoachIdentity.avatarAssetPath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: size,
          height: size,
          color: const Color(0xFF181436),
          alignment: Alignment.center,
          child: Text(
            '🤖',
            style: TextStyle(fontSize: emojiFallbackSize ?? size * 0.5),
          ),
        ),
      ),
    );
  }
}
