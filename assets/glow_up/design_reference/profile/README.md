# Glow Up Profile Design Handoff

Place this entire folder inside the Glow Up Flutter project at:

`assets/glow_up/design_reference/profile/`

## Approved module page

- `90_profile.png` — approved Profile hierarchy: identity summary, profile completion, statistics, Glow Up preferences, health profile, AI personalization, connected apps, account links and privacy control.

## Current-app style references

- `today_morning.png` — morning/gold time-of-day variant.
- `today_afternoon.png` — afternoon/purple time-of-day variant.
- `today_evening.png` — evening/pink time-of-day variant.
- `workout_style.png` — existing flat card, typography, spacing and navigation style.

## Implementation rules

- Recreate the interface with responsive Flutter widgets; never display these PNGs as runtime UI.
- Use `90_profile.png` for content and hierarchy.
- Use the Today and Workout references as the source of truth for the live app's flatter visual system.
- Preserve the existing four-item navigation and keep Profile selected on this page.
- Reuse the shared time-of-day controller; do not duplicate the page for variants.
- Morning uses gold, afternoon purple/lavender, evening pink, night blue/purple, and auto uses local time.
- Profile values, completion percentage, streak, workouts and Glow Score must come from stored user data or honest empty states; never fabricate them.
- AI Personalization must expose understandable memory/preferences controls, consent and deletion—not unrestricted raw history.
- Privacy & Data must provide access, export and deletion entry points consistent with the existing storage architecture.
- Connected Apps must show truthful connection state and never claim a platform is connected without verified authorization.
- Opening Profile must not call an AI provider.
