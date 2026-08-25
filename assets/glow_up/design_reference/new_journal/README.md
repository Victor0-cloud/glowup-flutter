# Glow Up New Journal Entry Design Handoff

Place this entire folder inside the Glow Up Flutter project at:

`assets/glow_up/design_reference/new_journal/`

## Approved module page

- `51_new_journal.png` — approved New Journal Entry editor, mood selection, prompt, tags, privacy controls and save actions.

## Current-app style references

- `today_morning.png` — morning/gold time-of-day variant.
- `today_afternoon.png` — afternoon/purple time-of-day variant.
- `today_evening.png` — evening/pink time-of-day variant.
- `workout_style.png` — existing flat card, typography, spacing and navigation style.

## Implementation rules

- Recreate the editor with responsive Flutter widgets; never display these PNGs as runtime UI.
- Use `51_new_journal.png` for content, hierarchy and editor controls.
- Use the Today and Workout references as the source of truth for the live app's flatter design language.
- This is a hierarchical editor screen and should not add a second bottom-navigation shell.
- Reuse the shared time-of-day controller; do not duplicate the editor for variants.
- Morning uses gold, afternoon purple/lavender, evening pink, night blue/purple, and auto uses local time.
- Private entry is ON by default. Share with AI Coach is OFF by default and requires explicit, revocable consent.
- Raw journal text must never enter model prompts, shared caches, analytics or logs without explicit consent.
- Saving, drafting, autosaving and safety state changes must work with every AI provider unavailable.
