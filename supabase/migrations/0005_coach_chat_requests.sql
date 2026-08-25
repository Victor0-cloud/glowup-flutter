-- Rate-limiting table for the coach-chat Edge Function — same pattern as
-- 0001_scan_requests.sql, with the service-role grants folded in from the
-- start (0002 had to add those as a follow-up fix for scan_requests; no
-- reason to repeat that omission here).
--
-- No conversation text, coaching context, or AI reply is ever written here
-- — this table exists purely to let the Edge Function count how many chat
-- requests one authenticated user has made recently.
--
-- NOT YET APPLIED — no Supabase CLI/DB access was available to run this
-- migration from the coding session that wrote it. Apply via
-- `supabase db push` (with the project linked) or by pasting this file's
-- contents into the Supabase SQL editor before real Coach replies can go
-- live. Until applied, the coach-chat function cannot be deployed
-- (it depends on this table for rate limiting) and
-- `RemoteCoachBrainService` keeps falling back to its honest
-- "not connected yet" message automatically — no code changes are needed
-- after applying it.

create table if not exists public.coach_chat_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

create index if not exists coach_chat_requests_user_id_created_at_idx
  on public.coach_chat_requests (user_id, created_at desc);

alter table public.coach_chat_requests enable row level security;

-- Ownership: a user can only ever see/insert their own rate-limit rows.
-- The Edge Function itself runs with the service-role key (bypasses RLS)
-- for the count/insert it performs on the caller's behalf, but RLS is
-- still defined here so this table is never silently readable/writable by
-- a different authenticated user through any other client path (e.g.
-- PostgREST) if one were ever added later.
create policy "coach_chat_requests_select_own"
  on public.coach_chat_requests for select
  using (auth.uid() = user_id);

create policy "coach_chat_requests_insert_own"
  on public.coach_chat_requests for insert
  with check (auth.uid() = user_id);

-- Least-privilege grants for the service-role rate-limit check (see
-- 0002_scan_requests_service_role_grants.sql for why RLS policies alone
-- are not enough) — exactly SELECT + INSERT, nothing more.
grant usage on schema public to service_role;
grant select, insert on table public.coach_chat_requests to service_role;

-- Retention: rows older than 24h carry no further purpose (the rate limit
-- window used by the Edge Function is much shorter — see
-- RATE_LIMIT_WINDOW_SECONDS in index.ts). Run this periodically once the
-- project is live, same as scan_requests:
--
--   select cron.schedule(
--     'purge-old-coach-chat-requests',
--     '0 * * * *', -- hourly
--     $$ delete from public.coach_chat_requests where created_at < now() - interval '24 hours'; $$
--   );
--
-- Not enabled by this migration automatically — pg_cron must be enabled
-- on the project first, which is an explicit opt-in left to deployment,
-- not assumed here.
