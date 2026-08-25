// Phase 1 Strength routine asset-cleanup audit. Locks in the findings:
// no orphaned/unused legacy asset files exist under any Strength exercise
// id (confirmed by direct filesystem check during the audit — nothing to
// archive/delete this pass), every Strength exercise with real Tier 1
// (RoutinePlayer) coverage resolves only to its own approved folder, and
// kStrengthAssetPendingApproval accurately reflects which Strength
// exercises still have no approved production asset set.

import 'package:flutter_test/flutter_test.dart';

import 'package:glow_up/routine_player/data/routine_player_registry.dart';
import 'package:glow_up/workout/data/exercise_catalog.dart';
import 'package:glow_up/workout/models/exercise_models.dart';

const _strengthIds = [
  'EX007',
  'EX008',
  'EX010',
  'EX018',
  'EX019',
  'EX020',
  'EX021',
  'EX022',
  'EX023',
  'EX024',
];

void main() {
  test(
    'kStrengthAssetPendingApproval contains only real Strength-category exercises with no Tier 1 definition',
    () {
      for (final id in kStrengthAssetPendingApproval) {
        final exercise = exerciseById(id);
        expect(
          exercise,
          isNotNull,
          reason: '$id must be a real legacy catalog exercise',
        );
        expect(
          exercise!.primaryCategory,
          ExerciseCategory.strength,
          reason:
              '$id must actually be Strength — this pass never touches other categories',
        );
        expect(
          routinePlayerExerciseById(id),
          isNull,
          reason:
              '$id is marked pending approval but already has a Tier 1 definition — the marker is stale',
        );
      }
    },
  );

  test(
    'every Strength exercise with Tier 1 coverage is NOT in the pending-approval set (no contradictory marking)',
    () {
      for (final id in _strengthIds) {
        final tier1 = routinePlayerExerciseById(id);
        if (tier1 != null) {
          expect(
            kStrengthAssetPendingApproval,
            isNot(contains(id)),
            reason:
                '$id has real Tier 1 assets — must not be marked pending approval',
          );
        }
      }
    },
  );

  test(
    'all 10 Strength exercises are accounted for: either Tier 1-approved or explicitly pending approval, never silently unresolved',
    () {
      for (final id in _strengthIds) {
        final hasTier1 = routinePlayerExerciseById(id) != null;
        final isPending = kStrengthAssetPendingApproval.contains(id);
        expect(
          hasTier1 || isPending,
          isTrue,
          reason:
              '$id is neither Tier 1-approved nor marked pending — an unaccounted-for gap',
        );
        expect(
          hasTier1 && isPending,
          isFalse,
          reason: '$id cannot be both approved and pending at the same time',
        );
      }
    },
  );

  test(
    'Tier 1 Strength exercises (Squat, Lunges, Push-Ups, Glute Bridge, Calf Raises, Wall Push-Ups, Tricep Dips, Donkey Kicks, Shoulder Taps, Superman) resolve only to their own approved folder, never a legacy or cross-mapped path',
    () {
      const tier1StrengthIds = [
        'EX007',
        'EX008',
        'EX010',
        'EX018',
        'EX020',
        'EX019',
        'EX021',
        'EX022',
        'EX023',
        'EX024',
      ];
      const expectedFolder = {
        'EX007': 'exercises/squat/female/v2/',
        'EX008': 'exercises/lunges/female/v2/',
        'EX010': 'exercises/pushups/female/v2/',
        'EX018': 'exercises/glute_bridge/female/v1/',
        'EX020': 'exercises/calf_raises/female/v2/',
        'EX019': 'exercises/wall_push_ups/female/v2/',
        'EX021': 'exercises/tricep_dips/female/v2/',
        'EX022': 'exercises/donkey_kicks/female/v2/',
        'EX023': 'exercises/shoulder_taps/female/v2/',
        'EX024': 'exercises/superman/female/v2/',
      };
      for (final id in tier1StrengthIds) {
        final definition = routinePlayerExerciseById(id)!;
        final assets = <String>[
          ...definition.poses.map((p) => p.approvedAsset).whereType<String>(),
          if (definition.bilateralFrames case final bilateral?) ...[
            ...bilateral.left.map((p) => p.approvedAsset).whereType<String>(),
            ...bilateral.right.map((p) => p.approvedAsset).whereType<String>(),
          ],
        ];
        expect(assets, isNotEmpty);
        for (final asset in assets) {
          expect(
            asset,
            contains(expectedFolder[id]!),
            reason:
                '$id (${definition.displayName}) resolved to an unexpected path: $asset',
          );
        }
      }
    },
  );
}
