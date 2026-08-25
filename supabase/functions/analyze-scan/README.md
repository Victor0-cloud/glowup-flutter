# analyze-scan Edge Function

Authenticated proxy between the Glow Up Flutter client and a vision-capable
model provider, for both Food Scan and Facial Scan. This function, plus the
`RemoteScanAnalysisProvider` Flutter client and the typed request/response
models in `lib/scan/models/scan_analysis_models.dart`, are fully implemented
and unit-tested. It is **not deployed** — no Supabase project exists for
this app yet. This file is the exact checklist to activate real scans.

## 1. Create a Supabase project

If one doesn't already exist for Glow Up, create it at supabase.com (or
self-host). Note the project's URL and its **anon** (public) key from
Project Settings → API.

## 2. Link and deploy

```bash
supabase login
supabase link --project-ref YOUR-PROJECT-REF
supabase db push                      # applies supabase/migrations/0001_scan_requests.sql
supabase functions deploy analyze-scan
```

## 3. Set the vision-provider secret (server-side only — never in the Flutter client)

```bash
supabase secrets set VISION_API_KEY=sk-...
# optional overrides, both have sane defaults in index.ts:
supabase secrets set VISION_API_URL=https://api.openai.com/v1/chat/completions
supabase secrets set VISION_MODEL=gpt-4o-mini
```

`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are injected automatically by
the Supabase platform for every Edge Function — do not set them manually.

## 4. Enable anonymous sign-ins

The Flutter client authenticates every request via Supabase's anonymous
auth (a real, verifiable `auth.uid()` bound to the install, with no
account/login screen). In the Supabase Dashboard: Authentication →
Providers → enable **Anonymous Sign-Ins**.

## 5. Build the Flutter app with the backend enabled

```bash
flutter build windows --release \
  --dart-define=SUPABASE_URL=https://YOUR-PROJECT-REF.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR-ANON-KEY
```

Without both `--dart-define` values, `ScanBackendConfig.isConfigured` is
false and the app correctly, honestly falls back to
`UnavailableScanAnalysisProvider` — this is the current state of every
build in this repository today.

## What's already real vs. what activation unlocks

| Already built & tested | Unlocked once deployed |
|---|---|
| Typed request/response models + validation | Real food-item detection |
| `RemoteScanAnalysisProvider` (network call, auth, error mapping) | Real portion/calorie/macro estimates |
| `UnavailableScanAnalysisProvider` fallback | Real facial wellness observations |
| Edge Function source + rate limiting + non-diagnostic post-filter | |
| RLS-protected rate-limit table + migration | |

## Rate limiting & retention

5 requests per authenticated user per 60 seconds (`RATE_LIMIT_MAX_REQUESTS`
/ `RATE_LIMIT_WINDOW_SECONDS` in `index.ts`). The `scan_requests` table
stores only `user_id`, `kind`, and `created_at` — never image bytes or
results. See the retention/purge note at the bottom of
`migrations/0001_scan_requests.sql` for the optional `pg_cron` cleanup job.

No uploaded image is ever persisted to Supabase Storage by this function —
it is processed in memory and discarded once the vision provider responds.
