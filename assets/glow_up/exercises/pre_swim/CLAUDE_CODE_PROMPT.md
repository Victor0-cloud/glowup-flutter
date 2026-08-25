# Claude Code implementation prompt — Glow Up Pre-Swim

Implement the supplied Pre-Swim module in the existing Flutter Glow Up repository. Treat the PNG pages as visual truth, the SVG pages as editable masters, and `routine_manifest.json` as the behavioral contract.

## Non-negotiable product rules

1. Glow Up is women-only. Do not add a gender question, male copy, male models, male assets, or a male fallback path.
2. Use the existing Glow Up design tokens and shared components. Do not introduce GraceGather colors, cream backgrounds, or a second navigation system.
3. Connect the page to the existing routines system and real RoutinePlayer. Do not build an isolated demo route.
4. Resolve each manifest key to an existing approved exercise ID in the exercise registry. Do not invent IDs. Fail the build with a clear message if any approved mapping is missing.
5. Preserve the exact seven-exercise order in the manifest.

## Fix the one-side exercise bug

For `BOTH_SIDES`, completion requires `leftCompleted == true && rightCompleted == true`.

For `ALTERNATING`, completion requires the configured complete alternating sequence, not a single frame or one arm/side.

The player must show the active side, announce the side through voice coaching, return through center where the asset sequence requires it, and refuse Next/auto-advance until the full side contract is satisfied. Persist partial progress safely if the app is backgrounded.

Add automated tests covering:

- left completed but right missing → cannot complete exercise;
- right completed but left missing → cannot complete exercise;
- both sides completed → may advance;
- app background/resume between sides → remaining side is preserved;
- alternating reach completes the full sequence;
- no male asset can be selected through registry fallback.

## Safety and feedback

Add Easy, Okay, Tight, and Pain feedback. Pain stops auto-advance and presents the existing safe-stop guidance. Never diagnose or claim injury prevention. If a user reports shoulder tightness, the ecosystem may recommend only approved shoulder-mobility actions and must explain the reason.

## Ecosystem integration

Emit the existing typed events for routine start, side completion, exercise feedback, routine completion, and abandonment. Save session feedback and optional notes so they appear in Journal/records, Progress, and the Glow Up Brain evidence trail. Do not create a separate AI memory store.

## Deliverable and verification

- Add all three routes from `routes.json`.
- Use real responsive Flutter widgets; screenshots are references, not full-screen background images.
- Keep 853 × 1844 reference proportions while supporting small and large Android screens.
- Run `dart format`, `flutter analyze`, and the relevant test suite.
- Report files changed, registry mappings used, tests added, commands run, and any blocker. Do not claim completion when an asset or approved registry ID is unresolved.

