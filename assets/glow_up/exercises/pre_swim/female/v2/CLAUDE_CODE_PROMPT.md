# Claude Code prompt — wire the seven Pre-Swim sequences

Implement the supplied Pre-Swim exercise assets in the existing Flutter Glow Up routine system.

1. Read `sequence_index.json`, then read every exercise's `sequence_manifest.json`.
2. Map each routine-local ID (`PSW01`–`PSW07`) to an existing approved canonical exercise registry ID. Do not invent an `EX` number. If a canonical ID is missing, stop and report the exact missing mapping.
3. Copy/use the six files from each `app_frames_400x600` folder in exact numeric order. For PSW05 and PSW07, also use all six files from `opposite_side_app_frames_400x600` before marking the exercise complete.
4. Register the assets in `pubspec.yaml` using the repository's current asset convention.
5. Use the existing RoutinePlayer and approved sequence-loop component. Do not create a disconnected demo player.
6. Preserve women-only behavior. Delete/reject male model selection and male fallback logic for this module.
7. `BOTH_SIDES` requires both left and right completion. `ALTERNATING` requires the entire alternating cycle. Never auto-complete after one side or one frame.
8. Keep the original `source_sequence.png` as a QA reference only; never render it as the live animation.
9. Add tests for frame order, asset existence, both-side gating, alternating completion, background/resume between sides, and absence of male fallback.
10. Run `dart format`, `flutter analyze`, and relevant Flutter tests. Report exact registry mappings, changed files, and test results.

Do not declare completion if any of the 54 deployable frame files is missing, misordered, distorted, or unwired.
