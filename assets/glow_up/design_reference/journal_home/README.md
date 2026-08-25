# Glow Up Journal Home Design Handoff

Place this entire folder inside the Glow Up Flutter project at:

`assets/glow_up/design_reference/journal_home/`

## Approved module page

- `50_journal_home.png` — approved Journal Home content hierarchy and navigation.

## Current-app style references

- `today_morning.png` — morning/gold time-of-day variant.
- `today_afternoon.png` — afternoon/purple time-of-day variant.
- `today_evening.png` — evening/pink time-of-day variant.
- `workout_style.png` — existing flat card, typography, spacing and navigation style.

## Implementation rules

- Recreate the interface with responsive Flutter widgets; never display these PNGs as runtime UI.
- Use `50_journal_home.png` for the page content, cards and hierarchy.
- Use the Today and Workout references as the source of truth for the live app's flatter visual system.
- Preserve the existing navigation architecture and shared time-of-day controller.
- Do not duplicate the page for time variants: morning gold, afternoon purple/lavender, evening pink, night blue/purple, auto local time.
- Developer time controls are debug-only and hidden in release builds.
- Journal entries and previews are private by default.
- Raw journal text must never enter model prompts, shared caches or analytics without explicit user consent.
- Opening Journal Home and saving metadata must not depend on an AI provider call.
