-- Free-text short identifier per city, manageable from أدوات المدينة. Not
-- unique/constrained — just a reference code the association uses
-- internally, distinct from cities.id (uuid) and unrelated to
-- Parcel.basinCode (كود الحوض, a per-parcel field).

alter table public.cities add column if not exists code text;
