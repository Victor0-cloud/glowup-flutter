-- Rate-limiting table for the analyze-scan Edge Function.
--
-- No image bytes, base64 data, or analysis results are ever written here
-- — this table exists purely to let the Edge Function count how many
-- scan requests one authenticated user has made recently, per the
-- approved spec's "rate-limit scan requests" requirement. Each row is
-- deleted (or simply ages out of the rate-limit window) rather than kept
-- indefinitely; see the retention note at the bottom.

create table if not exists public.scan_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  kind text not null check (kind in ('food', 'facial')),
  created_at timestamptz not null default now()
);

create index if not exists scan_requests_user_id_created_at_idx
  on public.scan_requests (user_id, created_at desc);

alter table public.scan_requests enable row level security;

-- Ownership: a user can only ever see/insert their own rate-limit rows.
-- The Edge Function itself runs with the service-role key (bypasses RLS)
-- for the count/insert it performs on the caller's behalf, but RLS is
-- still defined here so this table is never silently readable/writable
-- by a different authenticated user through any other client path
-- (e.g. PostgREST) if one were ever added later.
create policy "scan_requests_select_own"
  on public.scan_requests for select
  using (auth.uid() = user_id);

create policy "scan_requests_insert_own"
  on public.scan_requests for insert
  with check (auth.uid() = user_id);

-- Retention: rows older than 24h carry no further purpose (the rate
-- limit window used by the Edge Function is much shorter — see
-- RATE_LIMIT_WINDOW_SECONDS in index.ts). Run this periodically (e.g. via
-- a Supabase scheduled Cron job / pg_cron) once the project is live:
--
--   select cron.schedule(
--     'purge-old-scan-requests',
--     '0 * * * *', -- hourly
--     $$ delete from public.scan_requests where created_at < now() - interval '24 hours'; $$
--   );
--
-- Not enabled by this migration automatically — pg_cron must be enabled
-- on the project first (`create extension if not exists pg_cron;`), which
-- is an explicit opt-in left to deployment, not assumed here.
