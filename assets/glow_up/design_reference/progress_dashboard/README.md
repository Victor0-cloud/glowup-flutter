# Glow Up Progress Dashboard Design Handoff

Place this entire folder inside the Glow Up Flutter project at:

`assets/glow_up/design_reference/progress_dashboard/`

## Approved module page

- `70_progress_dashboard.png` — approved Progress Dashboard hierarchy: period selector, Glow Score, weekly metrics, consistency chart, goal progress, milestone and evidence-backed insight.

## Current-app style references

- `today_morning.png` — morning/gold time-of-day variant.
- `today_afternoon.png` — afternoon/purple time-of-day variant.
- `today_evening.png` — evening/pink time-of-day variant.
- `workout_style.png` — existing flat card, typography, spacing and navigation style.

## Implementation rules

- Recreate the interface with responsive Flutter widgets; never display these PNGs as runtime UI.
- Use `70_progress_dashboard.png` for content, charts and hierarchy.
- Use the Today and Workout references as the source of truth for the live app's flatter visual system and current navigation.
- Preserve the existing live navigation; do not add a fifth Progress tab if the current shell uses four items.
- Reuse the shared time-of-day controller; do not duplicate the page for variants.
- Morning uses gold, afternoon purple/lavender, evening pink, night blue/purple, and auto uses local time.
- The `DEV TOD` selector shown in the concept is debug-only and must be hidden in release builds.
- All displayed metrics, milestones and comparisons must come from stored data or an explicitly labeled empty/development state. Never fabricate progress.
- Opening or rebuilding Progress must not call an AI provider. Use deterministic aggregation and stored typed insights.
- Load bounded history using configured event-count, lookback and active-pattern limits.
- Show a cross-module insight only when sufficient evidence exists; otherwise show an honest empty state.
- Safety constraints outrank celebratory messages, milestones and ordinary recommendations.
