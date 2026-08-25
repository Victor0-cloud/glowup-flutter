// Regression guard for the "Deep Breathing shows the old photo" report:
// confirms every exercise RoutinePlayer knows about (kRoutinePlayerPhase1Qa
// plus the Core-Crusher-only additions) resolves exclusively to its own
// dedicated, approved asset folder — never the legacy Exercise Sequence
// Library images (`assets/glow_up/exercises/EX0XX/female/0N.png`), which
// only the separate `lib/workout` module still shows for workouts not yet
// wired to RoutinePlayer.

import 'package:flutter_test/flutter_test.dart';

import 'package:glow_up/routine_player/data/routine_player_registry.dart';

final _legacyAssetPattern = RegExp(
  r'^assets/glow_up/exercises/EX\d{3}/female/\d{2}\.png$',
);

void main() {
  test(
    'no RoutinePlayer exercise pose ever resolves to a legacy EX0XX/female/0N.png asset',
    () {
      for (final exercise in kRoutinePlayerExercisesById.values) {
        for (final pose in exercise.poses) {
          final asset = pose.approvedAsset;
          if (asset == null) continue;
          expect(
            _legacyAssetPattern.hasMatch(asset),
            isFalse,
            reason:
                '${exercise.displayName} pose ${pose.label} resolves to a legacy asset ($asset) instead of its own approved folder',
          );
        }
        final bilateral = exercise.bilateralFrames;
        if (bilateral != null) {
          for (final pose in [...bilateral.left, ...bilateral.right]) {
            final asset = pose.approvedAsset;
            if (asset == null) continue;
            expect(
              _legacyAssetPattern.hasMatch(asset),
              isFalse,
              reason:
                  '${exercise.displayName} bilateral pose ${pose.label} resolves to a legacy asset ($asset)',
            );
          }
        }
      }
    },
  );

  test(
    'Deep Breathing specifically resolves only to the approved V2 photorealistic set, never the retired V1 illustrated set or the old legacy EX001 set',
    () {
      final deepBreathing = kRoutinePlayerExercisesById['EX001']!;
      expect(deepBreathing.poses.length, 6);
      for (final pose in deepBreathing.poses) {
        expect(
          pose.approvedAsset,
          contains('assets/glow_up/exercises/deep_breathing/female/v2/'),
        );
        expect(
          pose.approvedAsset,
          isNot(contains('deep_breathing/female/v1/')),
          reason: 'must never reference the retired V1 set',
        );
        expect(
          pose.approvedAsset,
          isNot(contains('exercises/EX001/')),
          reason:
              'must never reference the legacy Exercise Sequence Library folder',
        );
      }
    },
  );
}
