-- Restores `holding_id_number` on `city_top_holders`, which the dashboard's
-- rewrite of this view (shared across this repo and the Next.js admin
-- dashboard, same Supabase project) dropped while adding `total_feddan`,
-- breaking the Flutter app's `SupabaseCityDataSource.downloadHoldings`
-- lookup (`select('holding_id_number, holdings_count')`) with a Postgres
-- "column does not exist" error.
--
-- Adds `holding_id_number` to both SELECT and GROUP BY, alongside the
-- existing `holder_name`/`national_id` grouping and the dashboard's
-- `total_feddan` aggregate — this app never reads `total_feddan` but keeps
-- it so the dashboard's shape isn't disturbed. `holding_id_number` is
-- appended last (not inserted where the old materialized-view column order
-- had it) because `CREATE OR REPLACE VIEW` can only add columns at the end
-- without erroring `cannot change name of view column`; this app selects
-- columns by name, not position, so the order doesn't matter here.
-- `CREATE OR REPLACE VIEW` preserves existing grants
-- (anon/authenticated/service_role) automatically — no re-grant needed.
--
-- Note: this changes grouping granularity from "one row per (city, holder,
-- national_id)" to "one row per (city, holding_id_number, holder,
-- national_id)" — a holder with multiple رقم حيازة in one city now
-- produces multiple rows instead of one combined row. Confirmed
-- intentional/acceptable for this app's needs; the dashboard team should
-- independently confirm this doesn't change their "top holders" semantics.
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
