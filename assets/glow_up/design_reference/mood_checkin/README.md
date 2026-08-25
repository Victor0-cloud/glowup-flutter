# Glow Up Mood Check-In Design Handoff

Place this entire folder inside the Glow Up Flutter project at:

`assets/glow_up/design_reference/mood_checkin/`

## Approved module page

- `45_mood_checkin.png` — approved Mood Check-In content hierarchy, controls, trends and insight sections.

## Current-app style references

- `today_morning.png` — morning/gold time-of-day variant.
- `today_afternoon.png` — afternoon/purple time-of-day variant.
- `today_evening.png` — evening/pink time-of-day variant.
- `workout_style.png` — existing flat card, typography, spacing and navigation style.

## Implementation rules

- Recreate the interface with responsive Flutter widgets; never display these PNGs as the runtime UI.
- Use `45_mood_checkin.png` for page content and hierarchy.
- Use the Today and Workout references as the source of truth for the live app's flatter design language.
- Preserve the existing live navigation architecture.
- Reuse the existing shared time-of-day controller; do not duplicate the page for each time.
- Morning uses gold, afternoon purple/lavender, evening pink, night blue/purple, and auto uses local time.
- The developer time selector is debug-only and hidden in release builds.
- Mood submission, safety transitions and Brain ingestion must not depend on an AI provider call.
- Free text is private by default and must not be sent to a model without explicit consent.
