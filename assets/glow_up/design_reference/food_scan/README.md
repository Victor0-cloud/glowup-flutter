# Glow Up Food Scan Design Handoff

Place this entire folder inside the Glow Up Flutter project at:

`assets/glow_up/design_reference/food_scan/`

## Approved module page

- `xx_food_scan.png` — approved Food Scan content hierarchy: capture/result preview, recognized meal, editable items, estimated nutrition, Coach insight, review and save actions.

## Current-app style references

- `today_morning.png` — morning/gold time-of-day variant.
- `today_afternoon.png` — afternoon/purple time-of-day variant.
- `today_evening.png` — evening/pink time-of-day variant.
- `workout_style.png` — existing flat card, typography, spacing and navigation style.

## Implementation rules

- Recreate the interface with responsive Flutter widgets; never display these PNGs as runtime UI.
- Use `xx_food_scan.png` for content, hierarchy and scan-result states.
- Use the Today and Workout references as the source of truth for the live app's flatter visual system and current navigation.
- Do not copy the older five-tab navigation visible in the Food Scan concept if it conflicts with the live app.
- Reuse the shared time-of-day controller; do not duplicate the page for variants.
- Morning uses gold, afternoon purple/lavender, evening pink, night blue/purple, and auto uses local time.
- Camera/gallery permission and photo analysis require a clear user action. Never trigger scanning from event ingestion.
- Food recognition, portions, calories and nutrients are estimates. The user must be able to edit, remove and confirm every item before saving.
- Do not make medical claims or present results as a diagnosis or prescribed diet.
- Do not retain or reuse meal photos beyond the disclosed purpose without explicit consent.
- Persist only the user-confirmed meal and corrected nutrition data to the daily log and Brain event contract.
- Provider failure, offline state or budget cutoff must not fabricate results; show retry/manual-entry options.
