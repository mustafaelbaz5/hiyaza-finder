-- IMPORTANT CONTEXT: this repo's local migration history and the live
-- "Hiyaza" Supabase project's actual applied-migration history have
-- diverged completely (different version numbers/filenames entirely — the
-- live project's migrations are named things like
-- `20260801190500_fix_city_top_holders_view`, none of which exist in this
-- directory). This file records, for reference, a fix that was applied
-- DIRECTLY to the live database via the Supabase MCP tooling on 2026-08-05,
-- not through this repo's normal migration-apply flow — it does not imply
-- `supabase/migrations/` is currently a source of truth for this project's
-- live schema.
--
-- The live `city_top_holders` view had lost `holding_id_number`: an
-- earlier local fix file in this same directory,
-- `20260802000013_city_top_holders_add_holding_id.sql`, was written to
-- solve this exact problem but was NEVER applied to the live project (it
-- only ever existed in this repo). Separately, the dashboard team's own
-- live migration `20260801190500_fix_city_top_holders_view` had redefined
-- the view without `holding_id_number`, re-breaking an earlier live fix
-- (`20260801162102_city_top_holders_add_holding_id`) that had briefly
-- restored it — causing the production error
-- `column city_top_holders.holding_id_number does not exist` in
-- `SupabaseCityDataSource.downloadHoldings`'s
-- `select('holding_id_number, holdings_count')` query.
--
-- Fix applied live: `create or replace view city_top_holders` adding
-- `holding_id_number` back to both SELECT and GROUP BY, alongside the
-- existing `holder_name`/`national_id` grouping and the dashboard's
-- `total_feddan` aggregate (kept, unused by this app). Verified against
-- the live project immediately after: `information_schema.columns` shows
-- the column present, and the app's exact query
-- (`holding_id_number, holdings_count`) returns rows successfully.
--
-- Re-running this file against the live project is idempotent
-- (CREATE OR REPLACE VIEW) and safe.
create or replace view city_top_holders as
select
  city_id,
  holder_name,
  national_id,
  count(*) as holdings_count,
  coalesce(sum(feddan), 0) as total_feddan,
  holding_id_number
from holdings
where is_stale = false and holder_name is not null
group by city_id, holding_id_number, holder_name, national_id;
