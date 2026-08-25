-- Least-privilege fix: the analyze-scan Edge Function's rate-limit check
-- runs as service_role, but service_role had no table privileges on
-- public.scan_requests (RLS policies alone do not grant privileges —
-- they only restrict rows once a privilege already exists). This grants
-- exactly the two operations the function actually performs (SELECT for
-- the rate-limit count, INSERT for recording a request) and nothing more
-- — no UPDATE/DELETE/TRUNCATE/REFERENCES/TRIGGER, no grant to anon or
-- authenticated, no grant on any other table.

grant usage on schema public to service_role;
grant select, insert on table public.scan_requests to service_role;
