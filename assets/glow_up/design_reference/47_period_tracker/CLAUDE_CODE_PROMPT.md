# Claude Code implementation prompt

Implement the `pages_xx_Period_Cycle` actual page pack inside the existing Glow Up Flutter application.

Before editing, inspect the current routing, design tokens, state management, authentication, persistence and Today Dashboard. Reuse the current architecture; do not create a parallel demo or web implementation.

Requirements:

- Implement all nine actual screens shown in `actual_pages_png/`, including the separate calendar and dated notebook pages.
- Treat the PNG pages as the visual source of truth. Match their Glow Up navy/indigo background, luminous purple bordered cards, white and lavender typography, accent colors, spacing, radii, headers and bottom navigation. Do not substitute GraceGather cream/rose styling.
- Persist the user-entered fields in `data_contract.json` using the existing backend and authenticated user identity.
- Keep onboarding cycle setup optional with Set up, Maybe later and Not applicable choices.
- Add the cycle summary card to Today only when tracking is enabled.
- Make the calendar an ecosystem calendar. Selecting a date must show linked cycle, mood, pain, workout, food, water, skin and journal records for that date.
- Add tappable Happy, Sad, Pain and Menstrual Pain emoji states. Tapping an emoji opens the private-note sheet, and the woman can save, edit or delete the note.
- Tapping any calendar date must transition to a full dated notebook view, not a tiny tooltip. Back returns to the same month and selected date. The notebook supports a feeling, private free-text note and optional attachments from workout, food, water, skin and cycle records.
- Saving a private note must not automatically grant AI access. Store AI-memory consent separately and allow it to be revoked without deleting the woman's note.
- Calculate estimates separately from raw period logs. Editing or deleting a log must safely recalculate estimates.
- Store prediction confidence and show the wellness-only disclaimer.
- Let the user export and permanently delete cycle records.
- Require explicit permission before cycle records affect Glow Up Brain recommendations or AI memory.
- Provide a screen where the user can inspect and delete derived AI memories.
- Do not put private symptoms or notes into lock-screen notification text.
- Do not reintroduce any male option, gender selector or male asset.
- Do not add fertility, ovulation, pregnancy or contraceptive claims in this MVP.
- Include loading, empty, offline, error and permission-denied states.
- Add unit, widget, navigation, persistence, recalculation, export, deletion and privacy-consent tests.
- Run `flutter analyze`, the full test suite and a production build.

Do not claim completion if any screen is a visual placeholder, if deletion is local-only while server data remains, or if cycle information reaches the Brain without explicit consent.

Return the files changed, migrations applied, test results, build result and any remaining limitation.
