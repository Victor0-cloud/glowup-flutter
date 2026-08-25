# Glow Up — 91 Settings Claude Code Handoff

Copy this entire folder to:

`assets/glow_up/design_reference/settings/`

## Files

- `91_settings.png` — authoritative design reference for the Settings page.
- `today_morning.png` — existing morning variant and shared visual-system reference.
- `today_afternoon.png` — existing afternoon variant and primary color reference.
- `today_evening.png` — existing evening variant and shared visual-system reference.
- `workout_style.png` — existing flat card, typography, spacing, and navigation reference.

## Claude Code implementation contract

Implement `91_settings.png` as responsive Flutter widgets. The PNG is a design reference only and must never be displayed as the runtime UI.

### Navigation

- Settings is opened from Profile and is a hierarchical page.
- Use the circular back button shown in the reference.
- Do not add a bottom navigation bar or create a second navigation shell.
- Preserve the app's existing four root destinations: Home, Plan, Coach, and Profile.

### Shared design system

- Reuse the current Glow Up theme, typography, spacing, cards, borders, icons, controls, and route conventions.
- Keep the established flat midnight-navy and deep-purple style. Do not introduce glossy 3D art, glassmorphism, mascots, or heavy glow.
- Build shared settings section and row widgets instead of duplicating markup.
- Meet accessible contrast and touch-target requirements and support text scaling without clipping.

### Time-of-day variants

- Use the existing shared time-of-day theme controller; do not create a settings-only theme system.
- Supported variants remain `morning`, `afternoon`, `evening`, `night`, and `auto`.
- `auto` follows the user's local time and updates all shared accent tokens together while layout stays identical.
- The production screen must not display `DEV TOD` controls.

### Data and behavior

- Load and persist every editable preference through the project's existing controller/repository patterns. Do not hardcode saved values.
- The Appearance & Time of Day row controls the shared app variant and shows the current selection.
- Units and Language rows show the saved preference.
- Notification toggles must represent both the saved preference and actual operating-system permission state. Never show a reminder as enabled when permission is denied.
- Quiet Hours stores start and end times and is applied to all non-critical reminders.
- Opening Settings and changing ordinary preferences are deterministic local operations and must not invoke an AI provider.

### Privacy and safety

- AI Personalization must expose understandable controls for Coach memory, personalization consent, and deletion. Do not grant the model unrestricted raw journal history.
- Permissions must explain camera, photos, notifications, microphone, motion/fitness, and health-data access only when the app uses them.
- Export My Data creates a user-readable export through the existing privacy/data layer.
- Manage My Data provides review and deletion controls.
- Sign Out requires confirmation and preserves locally queued data safely.
- Delete Account is a separate destructive flow with re-authentication, explicit confirmation, progress/error states, and server-side deletion handling. Do not delete an account from a single tap.

### Required states and tests

- Loading, ready, save-in-progress, saved, validation failure, permission denied, offline, and persistence failure states.
- Back navigation returns to the existing Profile page without resetting unrelated state.
- Preference persistence survives controller recreation/app restart.
- Time variant changes update shared tokens without changing page layout.
- Notification switches remain accurate when OS permission is denied or revoked.
- Sign-out confirmation and account-deletion re-authentication are tested.
- No AI provider call occurs while opening Settings or changing deterministic preferences.
- Widget tests cover narrow phones, large text, scrolling to the destructive actions, and no bottom-navigation duplication.

## Acceptance rule

Do not report completion until the screen is reachable from the live Profile page, all rows have real behavior or an explicitly documented unavailable state, tests pass, `flutter analyze` is clean, and the release build succeeds.
