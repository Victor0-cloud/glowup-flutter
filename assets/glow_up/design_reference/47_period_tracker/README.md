# Glow Up — Period & Cycle actual page pack

This folder contains the actual 853×1844 mobile page assets for the women-only Glow Up Period & Cycle MVP module. The pages use the approved Glow Up dark navy/indigo background, luminous purple card system, white rounded typography, wellness accent colors and Glow Up bottom navigation.

## Included pages

1. `PC01_cycle_awareness.png` — optional onboarding consent
2. `PC02_cycle_setup.png` — last start date and typical lengths
3. `PC03_cycle_home.png` — current estimate, next period and Brain suggestion
4. `PC04_log_period.png` — date, flow, start/end and note
5. `PC05_daily_checkin.png` — energy, mood, symptoms and intensity
6. `PC06_ecosystem_calendar.png` — cycle plus workout, water, food, skin and journal history
7. `PC07_daily_notebook.png` — the full notebook produced when a calendar date is tapped
8. `PC08_cycle_insights.png` — permission-based observed patterns
9. `PC09_cycle_privacy.png` — consent, export, AI memory and deletion

PNG pages are in `actual_pages_png/`; editable SVG sources are in `actual_pages_svg/`. Claude Code should use the PNGs as the visual source and the SVGs only for inspecting exact geometry and colors.

## Product rules

- Cycle tracking is optional and must never block onboarding.
- Basic logging, calendar, history, export and deletion remain available without Premium.
- Recommendations prioritize actual energy, symptoms and preferences rather than stereotypes about cycle phase.
- Predictions are estimates only and must not be presented as contraception, diagnosis or medical advice.
- The user can review, edit and delete every record and every AI memory derived from it.
- Never use cycle data for advertising.
- Do not expose private notes in notification copy or on a locked-screen preview.
- Do not add male models, male options or gender selectors.

## Integration

- Add the Today Dashboard cycle card only when tracking is enabled.
- Link daily cycle check-ins to the Glow Up Brain through explicit consent.
- Recalculate estimates after period dates are edited or deleted.
- Keep raw logs separate from derived predictions so estimates never overwrite user records.
- Each calendar date is an ecosystem hub linking cycle, mood, pain, workout, food, water, skin and journal records.
- Happy, sad, pain and menstrual-pain emoji selections open a private daily note. Saving AI-memory consent is separate from saving the note.
- Tapping any calendar date transitions into that date's full notebook page. The woman can jot a note, choose a feeling and attach workout, food, water, skin and cycle records before saving.
- Use the existing app design tokens and state architecture when implementing. The HTML/CSS is a visual reference, not a request to introduce a web layer into Flutter.

See `routes.json`, `data_contract.json`, and `CLAUDE_CODE_PROMPT.md`.
