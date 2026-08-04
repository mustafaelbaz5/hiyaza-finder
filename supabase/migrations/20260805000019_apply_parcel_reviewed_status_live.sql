-- Records that migration 20260805000017_parcel_reviewed_status.sql, which
-- was written earlier in this repo's history, had NEVER actually been
-- applied to the live "Hiyaza" Supabase project -- same class of drift as
-- the city_top_holders incident recorded in
-- 20260805000018_restore_city_top_holders_holding_id_number.sql. This was
-- discovered live in production: the app crashed with
-- "Could not find the 'reviewed' column of 'holdings' in the schema cache."
--
-- This file records the live fix applied directly via Supabase MCP
-- tooling on 2026-08-05, using `if not exists` guards since 20260805000017
-- may or may not already be tracked as applied depending on how this
-- project's migration history is reconciled going forward. Verified live
-- immediately after: information_schema.columns shows all three columns
-- on both tables, and a representative
-- `select reviewed, reviewed_at, reviewed_by from holdings` succeeds.

alter table public.holdings
  add column if not exists reviewed boolean not null default false,
  add column if not exists reviewed_at timestamptz,
  add column if not exists reviewed_by uuid references public.profiles(id);

alter table public.added_holdings
  add column if not exists reviewed boolean not null default false,
  add column if not exists reviewed_at timestamptz,
  add column if not exists reviewed_by uuid references public.profiles(id);

create index if not exists holdings_reviewed_idx on public.holdings (city_id, reviewed);
create index if not exists added_holdings_reviewed_idx on public.added_holdings (city_id, reviewed);
