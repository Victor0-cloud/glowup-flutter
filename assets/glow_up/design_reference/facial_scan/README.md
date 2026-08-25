# Glow Up Facial Scan Design Handoff

Place this entire folder inside the Glow Up Flutter project at:

`assets/glow_up/design_reference/facial_scan/`

## Approved module page

- `xx_facial_scan.png` — approved privacy-first Facial Scan page. The Start Scan action is disabled until explicit consent is checked.

## Current-app style references

- `today_morning.png` — morning/gold time-of-day variant.
- `today_afternoon.png` — afternoon/purple time-of-day variant.
- `today_evening.png` — evening/pink time-of-day variant.
- `workout_style.png` — existing flat card, typography, spacing and navigation style.

## Implementation rules

- Recreate the interface with responsive Flutter widgets; never display these PNGs as runtime UI.
- Use `xx_facial_scan.png` for content, consent gating, capture guidance, tracked wellness indicators and progress comparison.
- Use the Today and Workout references as the source of truth for the live app's flatter visual system and current navigation.
- Do not copy older five-tab navigation if it conflicts with the live app.
- Reuse the shared time-of-day controller; do not duplicate the page for variants.
- Morning uses gold, afternoon purple/lavender, evening pink, night blue/purple, and auto uses local time.
- Camera/gallery access and photo processing require an explicit user action and clear, revocable consent. Start Scan must remain disabled until consent is granted.
- Facial photos and derived measurements are sensitive data. Apply least retention, secure storage, ownership authorization, deletion and export rules.
- Never upload, reuse, train on, share or retain a photo beyond the disclosed purpose without separate explicit consent.
- Track only non-diagnostic wellness appearance indicators such as visible hydration appearance, texture change, visible redness and routine progress.
- Never diagnose acne, disease or another medical condition, and never present skincare suggestions as medical treatment.
- Do not trigger scan analysis from event ingestion. Provider failure, offline state or budget cutoff must show retry/use-photo-later behavior and never fabricate a result.
- Persist only user-confirmed derived results and required audit metadata to the Brain event contract; never send raw photos to generative-expression prompts or shared caches.
