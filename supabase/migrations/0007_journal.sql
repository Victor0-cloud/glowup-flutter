-- Real, synced Journal entries — same architecture pattern as the Glow Up
-- Brain tables (0006_glow_up_brain.sql): RLS-protected, owned entirely by
-- the authenticated user, never touched by service_role except for the
-- grants below (no Edge Function is involved — Journal entries are never
-- sent to an AI provider; the Coach Brain only ever learns a bounded,
-- content-free signal that an entry was logged, via brain_events — see
-- BrainEventRepository call sites in the Flutter client).

create table if not exists public.journal_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  content text not null,
  -- A short, optional mood tag (e.g. matching MoodLevel.name) — never a
  -- second free-text field; the entry's own `content` is the one place
  -- for that.
  mood text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists journal_entries_user_created_idx
  on public.journal_entries (user_id, created_at desc);

alter table public.journal_entries enable row level security;

-- Ownership: a user can only ever see/insert/update/delete their own
-- entries — full CRUD, unlike coach_messages (which is append-only from
-- the client's perspective). A journal is the user's own private record;
-- there is no "assistant" role or backend writer here at all.
drop policy if exists "users read own journal entries" on public.journal_entries;
create policy "users read own journal entries"
  on public.journal_entries for select
  to authenticated
  using (user_id = auth.uid());

drop policy if exists "users create own journal entries" on public.journal_entries;
create policy "users create own journal entries"
  on public.journal_entries for insert
  to authenticated
  with check (user_id = auth.uid());

drop policy if exists "users update own journal entries" on public.journal_entries;
create policy "users update own journal entries"
  on public.journal_entries for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "users delete own journal entries" on public.journal_entries;
create policy "users delete own journal entries"
  on public.journal_entries for delete
  to authenticated
  using (user_id = auth.uid());

-- Keeps updated_at honest on every edit — reuses the same trigger
-- function 0006 already created (no reason for a second copy).
drop trigger if exists journal_entries_set_updated_at on public.journal_entries;
create trigger journal_entries_set_updated_at
  before update on public.journal_entries
  for each row execute function public.set_updated_at();

revoke all on table public.journal_entries from anon;

grant select, insert, update, delete
  on table public.journal_entries
  to authenticated;

grant all privileges
  on table public.journal_entries
  to service_role;
