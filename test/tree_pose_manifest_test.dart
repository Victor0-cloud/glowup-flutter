// Verifies the Tree Pose asset manifest was correctly corrected from its
// original (colliding) EX025 draft to the real, non-colliding EX059 id —
// exerciseId, filenames in loopOrder, and every other field. The manifest
// itself isn't read by app code at runtime (it's asset-bundle metadata,
// not consumed by Dart) — this test exists purely to lock in that the
// on-disk correction actually happened and stays correct.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'tree_pose manifest.json uses EX059, never EX025, in every field and filename',
    () {
      final file = File(
        'assets/glow_up/exercises/tree_pose/female/v2/manifest.json',
      );
      expect(
        file.existsSync(),
        isTrue,
        reason:
            'manifest.json must still exist at the approved implementation path',
      );

      final manifest =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

      expect(manifest['exerciseId'], 'EX059');
      expect(manifest['exerciseName'], 'Tree Pose');
      expect(manifest['slug'], 'tree_pose');
      expect(manifest['category'], 'Flexibility');
      expect(manifest['level'], 'Beginner');
      expect(manifest['gender'], 'female');
      expect(manifest['version'], 'v2');
      expect(manifest['frameCount'], 6);
      expect(
        manifest['implementationPath'],
        'assets/glow_up/exercises/tree_pose/female/v2/',
      );

      final loopOrder = (manifest['loopOrder'] as List).cast<String>();
      expect(loopOrder, [
        'EX059_F_01_START.png',
        'EX059_F_02_WEIGHT_SHIFT.png',
        'EX059_F_03_KNEE_LIFT.png',
        'EX059_F_04_FOOT_PLACE.png',
        'EX059_F_05_HOLD.png',
        'EX059_F_06_RESET.png',
      ]);
      for (final filename in loopOrder) {
        expect(
          filename,
          isNot(contains('EX025')),
          reason: 'no filename may still reference the colliding draft id',
        );
        final assetFile = File(
          'assets/glow_up/exercises/tree_pose/female/v2/$filename',
        );
        expect(
          assetFile.existsSync(),
          isTrue,
          reason: '$filename listed in loopOrder must actually exist on disk',
        );
      }

      // No stray EX025-named file left behind from the rename.
      final dir = Directory('assets/glow_up/exercises/tree_pose/female/v2');
      final staleFiles = dir.listSync().whereType<File>().where(
        (f) => f.path.contains('EX025'),
      );
      expect(
        staleFiles,
        isEmpty,
        reason: 'no EX025-named file may remain in the tree_pose asset folder',
      );
    },
  );
}
