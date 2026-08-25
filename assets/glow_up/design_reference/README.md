# Glow Up — Paywall + Authentication Design Pack

## Purpose
This folder contains the individually separated visual references for Claude Code to reproduce in Flutter.

**Do not render the PNG files directly in the runtime app.**
Rebuild the pages with responsive Flutter widgets.

## Paywall pages
- `paywall/PW01_paywall_entry.png`
- `paywall/PW02_choose_plan.png`
- `paywall/PW03_premium_benefits.png`
- `paywall/PW04_restore_terms.png`
- `paywall/PW05_success.png`
- `paywall/PW06_features_overview.png`
- `paywall/PW07_plan_comparison.png`

## Authentication pages
- `auth/AU01_welcome.png`
- `auth/AU02_sign_in_method.png`
- `auth/AU03_email_sign_up.png`
- `auth/AU04_verify_email.png`
- `auth/AU05_profile_setup.png`
- `auth/AU06_auth_success.png`

## Authentication behavior
Glow Up must support:
1. Continue with Google.
2. Regular email/password sign up.
3. Regular email/password sign in.
4. Email verification where required.
5. Profile setup.
6. Existing-user sign-in.
7. Logout/account management through Profile.

Google Sign-In must use the real configured authentication provider. Do not fake Google success.

## Paywall behavior
The visual hierarchy is approved. Implement it with the existing Glow Up design system.

Skin & Acne Scan is a Premium feature and should remain available for development/testing.
Use centralized entitlements rather than scattered widget checks.

### Pricing warning
The prices visible in the generated design are **visual/example copy until the owner explicitly approves those exact prices**.
Do not silently hard-code billing products from the image.

## Time-of-day variants
All relevant Glow Up pages share the existing time-of-day controller:
- Morning — gold/yellow
- Afternoon — purple/lavender
- Evening — pink/magenta
- Night — blue/deep purple
- Auto — local time

Do not build four separate copies of a page. Keep the layout the same and vary shared theme tokens.

## Implementation target
`C:\Projects\glow_up`

## Security
- Never expose OAuth client secrets or service-role credentials in Flutter.
- Google OAuth must go through the approved Supabase/provider configuration.
- Do not fake paid status.
- Restore purchases must call the real platform billing implementation once configured.
- Do not store passwords manually.
