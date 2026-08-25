You are implementing the owner-approved Glow Up Paywall and Authentication designs.

Repository:
C:\Projects\glow_up

Read this design pack completely before modifying code:
assets/glow_up/design_reference/paywall_auth/

Use the PNGs only as visual references. Recreate them with responsive Flutter widgets.

AUTH:
- Continue with Google
- email/password sign up
- email/password sign in
- verification
- profile setup
- authenticated entry
- existing user login
- honest loading/error states
- no fake Google success

PAYWALL:
- reproduce PW01-PW07 hierarchy
- Skin & Acne Scan is Premium
- centralized entitlements
- development testing may keep Skin & Acne Scan accessible
- do not fake premium status
- restore purchases must be truthful
- do not hard-code the example image prices unless separately approved by the owner

TIME OF DAY:
Use the existing shared Glow Up theme/time-of-day controller:
morning gold, afternoon purple, evening pink, night blue/deep-purple, auto local-time.
Do not duplicate pages per theme.

Do not touch PrayerLock, RosaryLock, GraceGather, or Grace Place.
Do not commit, push, deploy, or run production migrations without explicit approval.

Before implementation, audit current auth/subscription architecture and report the files/routes to be modified.
