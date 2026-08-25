# Glow Up Water Tracker Design Handoff

Place this entire folder inside the Glow Up Flutter project at:

`design_reference/water_tracker/`

## Approved page

- `40_water_tracker.png` — approved Water Tracker page and content hierarchy.

## Existing-app style references

- `today_morning.png` — morning/gold time-of-day variant.
- `today_afternoon.png` — afternoon/purple time-of-day variant.
- `today_evening.png` — evening/pink time-of-day variant.
- `workout_style.png` — existing flat card, typography, spacing and navigation style.

## Implementation rules

- Recreate the interface with Flutter widgets. Never display these PNGs as the app UI.
- Preserve the existing live navigation architecture.
- Reuse the existing shared time-of-day controller.
- The time variants change accent tokens; they do not create duplicate pages.
- Use the current live app's flat midnight-navy and deep-purple design system.
- Do not introduce glassmorphism, glossy 3D art or an unrelated navigation system.
- The developer time selector is debug-only and must be hidden in release builds.

## Time variants

- Morning: yellow/gold accent.
- Afternoon: purple/lavender accent.
- Evening: pink accent.
- Night: blue/purple accent.
- Auto: select from the user's local time.

Water blue remains a semantic hydration color. The shared time variant controls primary actions, selected states, progress highlights and active navigation styling.
