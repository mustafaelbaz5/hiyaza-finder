-- Materialized view for top holders per city with holding counts
-- Used by the app to display "عدد القطع في الحيازة" (number of parcels in holding)
-- This view counts the number of parcels for each holding_id_number per city
create materialized view city_top_holders as
select
  c.id as city_id,
  c.name as city_name,
  h.holding_id_number,
  h.holder_name,
  h.national_id,
  count(*) as holdings_count,
  max(h.imported_at) as last_updated
from cities c
left join holdings h on c.id = h.city_id and not h.is_stale
group by c.id, c.name, h.holding_id_number, h.holder_name, h.national_id
with data;

create unique index city_top_holders_unique
  on city_top_holders (city_id, holding_id_number, holder_name, national_id);
create index city_top_holders_city_idx on city_top_holders (city_id);
create index city_top_holders_holding_id_idx on city_top_holders (city_id, holding_id_number);
