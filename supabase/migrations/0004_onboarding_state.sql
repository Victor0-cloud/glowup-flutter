-- Authenticated source of truth for onboarding progress (07_goals through
-- 13_finish_setup — "Option C" of the approved canonical onboarding
-- audit). One row per user. Local SharedPreferences storage
-- (OnboardingRepository) remains a cache/fallback the app keeps working
-- from when this table is unreachable; this table is the source of truth
-- once reachable.
--
-- NOT YET APPLIED — no Supabase CLI/DB access was available to run this
-- migration from the coding session that wrote it. Apply via
-- `supabase db push` (with the project linked) or by pasting this file's
-- contents into the Supabase SQL editor before onboarding progress can
-- sync remotely. Until applied, `OnboardingRemoteRepository` calls fail
-- silently and the app falls back to local-only storage automatically —
-- no code changes are needed after applying it.

create table if not exists public.onboarding_state (
  user_id uuid primary key references auth.users (id) on delete cascade,
  goals jsonb not null default '[]'::jsonb,
  fitness_level text,
  schedule_window text,
  notification_preferences jsonb not null default '{}'::jsonb,
  health_connections jsonb not null default '{}'::jsonb,
  personalization_preferences jsonb not null default '{}'::jsonb,
  onboarding_step text not null default 'goals',
  onboarding_completed_at timestamptz,
  updated_at timestamptz not null default now()
);

alter table public.onboarding_state enable row level security;

-- Ownership: a user can only ever see/insert/update their own onboarding
-- row. No policy grants any cross-user access, and no policy references
-- service_role — this table is read/written only by the public anon
-- client, authenticated as the row's own owner.
create policy "onboarding_state_select_own"
  on public.onboarding_state for select
  using (auth.uid() = user_id);

create policy "onboarding_state_insert_own"
  on public.onboarding_state for insert
  with check (auth.uid() = user_id);

create policy "onboarding_state_update_own"
  on public.onboarding_state for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Keeps `updated_at` honest on every upsert without relying on the client
-- to set it correctly.
create or replace function public.onboarding_state_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists onboarding_state_touch_updated_at on public.onboarding_state;
create trigger onboarding_state_touch_updated_at
  before update on public.onboarding_state
  for each row execute function public.onboarding_state_set_updated_at();
