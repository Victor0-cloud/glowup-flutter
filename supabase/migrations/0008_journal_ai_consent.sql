-- Explicit, per-user consent gate for AI Coach use of Journal content.
-- Separate from journal_entries itself (private source material) and from
-- coach_memory (durable facts) — this table holds exactly one boolean: has
-- the user opted in to the Coach reading a bounded, extracted summary of
-- their recent journal entries. Enforced SERVER-SIDE (coach-chat/index.ts
-- checks this table, never trusts a client-sent flag) since a modified
-- client could otherwise claim consent it doesn't have. Default is OFF —
-- journal free text is more sensitive than the structured cycle/workout
-- data this app already gates more loosely, so this follows the stricter,
-- opt-in-only default.
create table if not exists public.journal_ai_consent (
  user_id uuid primary key references auth.users (id) on delete cascade,
  enabled boolean not null default false,
  updated_at timestamptz not null default now()
);

alter table public.journal_ai_consent enable row level security;

-- Ownership: a user can only ever see/set their own consent flag.
drop policy if exists "journal_ai_consent_select_own" on public.journal_ai_consent;
create policy "journal_ai_consent_select_own"
  on public.journal_ai_consent for select
  to authenticated
  using (user_id = auth.uid());

drop policy if exists "journal_ai_consent_insert_own" on public.journal_ai_consent;
create policy "journal_ai_consent_insert_own"
  on public.journal_ai_consent for insert
  to authenticated
  with check (user_id = auth.uid());

drop policy if exists "journal_ai_consent_update_own" on public.journal_ai_consent;
create policy "journal_ai_consent_update_own"
  on public.journal_ai_consent for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- The Edge Function reads this table with the user's own authenticated
-- client (same pattern as journal_entries/brain_events), so no
-- service_role grant is needed here.

create or replace function public.journal_ai_consent_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists journal_ai_consent_touch_updated_at on public.journal_ai_consent;
create trigger journal_ai_consent_touch_updated_at
  before update on public.journal_ai_consent
  for each row execute function public.journal_ai_consent_set_updated_at();
