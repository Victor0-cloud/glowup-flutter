# coach-chat Edge Function

Authenticated proxy between the Glow Up Flutter client's AI Coach (23e chat
thread) and a text-generation model provider. This function, plus the
`RemoteCoachBrainService` Flutter client and the context payload built by
`CoachBrainContext`, are fully implemented and unit-tested. It is **not
deployed** — this repository's working environment has no Supabase CLI/DB
access. This file is the exact checklist to activate real Coach replies.

## 1. Apply the rate-limit migration

```bash
supabase db push   # applies supabase/migrations/0005_coach_chat_requests.sql
```

(If the project already has migrations 0001-0004 applied, this only adds
`coach_chat_requests`.)

## 2. Deploy the function

```bash
supabase functions deploy coach-chat
```

## 3. Set the coach-provider secret (server-side only — never in the Flutter client)

```bash
supabase secrets set COACH_API_KEY=sk-...
# optional overrides, both have sane defaults in index.ts:
supabase secrets set COACH_API_URL=https://api.openai.com/v1/chat/completions
supabase secrets set COACH_MODEL=gpt-4o-mini
```

`COACH_API_KEY` is deliberately separate from `analyze-scan`'s
`VISION_API_KEY` — even if both point at the same provider account, this
keeps chat cost/usage trackable and independently rate-limitable from
image scans.

`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are injected automatically
for every Edge Function — do not set them manually.

## 4. Nothing else to enable

Unlike `analyze-scan`, this function authenticates using the user's real
signed-in session (AU01-AU06) — Coach is only reachable once already
authenticated, so no anonymous-sign-in provider setup is needed here.

## What's already real vs. what activation unlocks

| Already built & tested | Unlocked once deployed |
|---|---|
| Typed request/response contract + validation | Real, model-generated coaching replies |
| `RemoteCoachBrainService` (network call, auth, error mapping) | Context-aware suggestions grounded in real goals/routines/water/workout data |
| `UnconnectedCoachBrainService` fallback | |
| Edge Function source + rate limiting + safety net (diagnostic/extreme-advice/attractiveness filter + fixed crisis-message redirect) | |
| RLS-protected rate-limit table + migration | |

## Safety behavior (server-side, never trusts model output blindly)

- A user message matching a crisis/self-harm pattern is **never** sent to
  the model — it always gets the same fixed, caring redirect to a crisis
  line, and isn't rate-limited or logged as a normal request.
- Every model reply is checked against a pattern list (medical diagnosis,
  extreme calorie/fasting advice, purging, attractiveness scoring) before
  being returned; a match is replaced with a safe generic fallback rather
  than passed through.
- The system prompt itself instructs the model toward the same
  restrictions, but the server-side check is the actual enforcement layer
  — the prompt alone is never trusted.

## Rate limiting & retention

20 requests per authenticated user per 60 seconds (`RATE_LIMIT_MAX_REQUESTS`
/ `RATE_LIMIT_WINDOW_SECONDS` in `index.ts`) — higher than `analyze-scan`'s
5, since this is text chat rather than image analysis. The
`coach_chat_requests` table stores only `user_id` and `created_at` — never
the message, conversation, context, or reply. See the retention/purge note
at the bottom of `migrations/0005_coach_chat_requests.sql` for the optional
`pg_cron` cleanup job.
