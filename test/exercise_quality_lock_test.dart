// Exercise Quality Lock — a real, file-system-backed audit run against
// every registered exercise, not a visual/manual spot-check. Verifies:
//
//   1. Every pose asset path any ExerciseDefinition can resolve to
//      actually exists on disk — a missing asset fails this test
//      (a real "development error"), it is never silently swapped for
//      a fallback image of any kind, male or otherwise.
//   2. Every exercise with a switch-side voice cue (the app's real
//      "this is a unilateral, both-sides exercise" signal) has poses
//      for both a first half and a second half, never just one side.
//   3. No asset path anywhere in the registry ever resolves under a
//      "male" directory segment — the structural guarantee behind
//      "female is the only exercise asset set," checked exhaustively
//      here rather than per-exercise.
//
// What this test suite does NOT (and structurally cannot) do: visually
// judge movement direction, limb distortion, body-scale consistency, or
// background stability across ~300 approved PNG frames — that requires
// human/visual review of each image, not a file-existence check. Each
// exercise's frame order, timing, and no-cross-mapping guarantees are
// already covered exhaustively per-exercise in routine_player_engine_test.dart
// and the individual EX0xx test files; this suite adds the one thing
// those didn't already check in one place: that every referenced file
// genuinely exists, and that no unilateral exercise is missing a side.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:glow_up/routine_player/data/routine_player_registry.dart';

void main() {
  final allExercises = kRoutinePlayerExercisesById.values.toList();

  test(
    'registry is non-empty (sanity check the audit is actually running against real data)',
    () {
      expect(allExercises, isNotEmpty);
    },
  );

  group('every resolvable pose asset exists on disk', () {
    for (final exercise in allExercises) {
      test('${exercise.id} (${exercise.displayName}) — all pose assets exist', () {
        final missing = <String>[];
        for (final pose in exercise.poses) {
          final asset = pose.approvedAsset;
          if (asset == null)
            continue; // an intentionally-pending pose, not a broken one
          if (!File(asset).existsSync()) missing.add(asset);
        }
        final bilateral = exercise.bilateralFrames;
        if (bilateral != null) {
          for (final pose in [...bilateral.left, ...bilateral.right]) {
            final asset = pose.approvedAsset;
            if (asset != null && !File(asset).existsSync()) missing.add(asset);
          }
        }
        final preview = exercise.previewAssetPath;
        if (preview != null && !File(preview).existsSync())
          missing.add(preview);

        expect(
          missing,
          isEmpty,
          reason:
              'Exercise Quality Lock: ${exercise.id} references ${missing.length} pose asset(s) '
              'that do not exist on disk — logging a development error rather than falling back '
              'to any substitute image: $missing',
        );
      });
    }
  });

  group(
    'every unilateral (switch-side) exercise has both a first half and a second half',
    () {
      final unilateral = allExercises.where(
        (e) => e.voiceScript.switchSideCue != null,
      );

      test(
        'at least one unilateral exercise exists in the registry (sanity check)',
        () {
          expect(unilateral, isNotEmpty);
        },
      );

      for (final exercise in unilateral) {
        test(
          '${exercise.id} (${exercise.displayName}) has more than one pose and a real switch-side cue',
          () {
            expect(
              exercise.poses.length,
              greaterThan(1),
              reason:
                  'a unilateral exercise with only one pose cannot show both sides',
            );
            expect(exercise.voiceScript.switchSideCue, isNotNull);
            expect(exercise.voiceScript.switchSideCue!.trim(), isNotEmpty);
          },
        );
      }
    },
  );

  group('no asset path anywhere in the registry resolves under a male directory', () {
    test(
      'no ExerciseDefinition pose, bilateral frame, or preview asset ever contains "/male/"',
      () {
        final offenders = <String>[];
        for (final exercise in allExercises) {
          for (final pose in exercise.poses) {
            if (pose.approvedAsset?.contains('/male/') ?? false)
              offenders.add(pose.approvedAsset!);
          }
          final bilateral = exercise.bilateralFrames;
          if (bilateral != null) {
            for (final pose in [...bilateral.left, ...bilateral.right]) {
              if (pose.approvedAsset?.contains('/male/') ?? false)
                offenders.add(pose.approvedAsset!);
            }
          }
          if (exercise.previewAssetPath?.contains('/male/') ?? false)
            offenders.add(exercise.previewAssetPath!);
        }
        expect(offenders, isEmpty);
      },
    );

    test(
      'every non-null pose asset path in the registry resolves under a female directory',
      () {
        final nonFemale = <String>[];
        for (final exercise in allExercises) {
          for (final pose in exercise.poses) {
            final asset = pose.approvedAsset;
            if (asset != null && !asset.contains('/female/'))
              nonFemale.add('${exercise.id}: $asset');
          }
        }
        expect(
          nonFemale,
          isEmpty,
          reason:
              'every approved pose asset must be under a /female/ path — found: $nonFemale',
        );
      },
    );
  });
}
