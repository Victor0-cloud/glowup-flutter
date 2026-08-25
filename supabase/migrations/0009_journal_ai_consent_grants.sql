-- 0008 created journal_ai_consent with RLS policies but omitted the base
-- table GRANTs that every other per-user table in this schema has (see
-- journal_entries in 0007_journal.sql) — RLS policies alone don't grant
-- table-level privileges in Postgres, so `authenticated` had no access at
-- all until this migration.
revoke all on table public.journal_ai_consent from anon;

grant select, insert, update
  on table public.journal_ai_consent
  to authenticated;

grant all privileges
  on table public.journal_ai_consent
  to service_role;
