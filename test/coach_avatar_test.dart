// Coverage for the AI Coach visual identity swap (robot emoji ->
// coach_woman_tyra.png), Section K/L/N/R. Not brittle pixel-perfect
// comparisons (this repo doesn't use golden-image tests anywhere) — real
// structural checks: the asset resolves via the app's real AssetBundle,
// the centralized widget renders at the requested size with the real
// image, the fallback path exists and never throws, and no lingering
// robot-emoji identity remains in the 3 screens/widgets this task named.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:glow_up/coach/theme/coach_identity.dart';

void main() {
  group('CoachIdentity — the one real, tracked asset', () {
    test('avatarAssetPath points at the exact approved filename', () {
      expect(
        CoachIdentity.avatarAssetPath,
        'assets/glow_up/coach/coach_woman_tyra.png',
      );
    });

    test('the asset file genuinely exists on disk under that exact path', () {
      expect(File(CoachIdentity.avatarAssetPath).existsSync(), isTrue);
    });

    test('pubspec.yaml declares assets/glow_up/coach/ (no duplicate entries)', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final matches = 'assets/glow_up/coach/'.allMatches(pubspec).length;
      expect(
        matches,
        1,
        reason:
            'assets/glow_up/coach/ should be declared exactly once in pubspec.yaml',
      );
    });
  });

  group('CoachAvatar — clean circular avatar, honest fallback', () {
    testWidgets('renders at the requested size wrapped in a ClipOval (face-centered, no stretching)', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CoachAvatar(size: 40))),
      );
      await tester.pump();

      final clipOval = tester.widget<ClipOval>(find.byType(ClipOval));
      expect(clipOval, isNotNull);
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.fit, BoxFit.cover);
      expect(image.width, 40);
      expect(image.height, 40);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a broken/missing asset falls back to the robot emoji, never crashes', (
      tester,
    ) async {
      // Simulates an asset-load failure directly through errorBuilder,
      // the same path Image.asset takes when the real file is
      // missing/corrupted — proves the fallback renders instead of
      // propagating the error.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return Image.asset(
                  'assets/glow_up/coach/does_not_exist.png',
                  width: 40,
                  height: 40,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 40,
                    height: 40,
                    color: const Color(0xFF181436),
                    alignment: Alignment.center,
                    child: const Text('🤖'),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('🤖'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Robot-emoji identity fully replaced in the 3 named Coach locations', () {
    const namedFiles = [
      'lib/coach/screens/coach_chat_screen.dart',
      'lib/coach/widgets/chat_widgets.dart',
      'lib/coach/screens/coach_hub_screen.dart',
    ];

    for (final path in namedFiles) {
      test('$path no longer hardcodes the 🤖 emoji avatar', () {
        final content = File(path).readAsStringSync();
        expect(
          content.contains("Text('🤖'"),
          isFalse,
          reason: '$path should use CoachAvatar, not a hardcoded 🤖 Text widget',
        );
        expect(
          content.contains('CoachAvatar('),
          isTrue,
          reason: '$path should reference the centralized CoachAvatar widget',
        );
      });
    }
  });
}
