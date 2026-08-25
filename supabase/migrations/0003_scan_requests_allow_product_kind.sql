-- Widens the scan_requests.kind check constraint to allow 'product', for
-- the Glow Shop Scanner's label-photo analysis path (analyze-scan Edge
-- Function, kind: 'product'). Additive only — 'food' and 'facial' keep
-- working exactly as before.

alter table public.scan_requests drop constraint if exists scan_requests_kind_check;

alter table public.scan_requests
  add constraint scan_requests_kind_check check (kind in ('food', 'facial', 'product'));
