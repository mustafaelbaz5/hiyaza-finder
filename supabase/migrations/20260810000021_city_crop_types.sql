-- Per-city نوع الزرع options — previously a single hardcoded list
-- (Parcel.cropTypeOptions) shared by every city. Lets field-tools admins
-- (admin/editor) manage the crop-type choices offered to field workers on a
-- per-city basis, via the new "أدوات المدينة" -> "أنواع الزرع" screen.

create table if not exists public.city_crop_types (
  id uuid primary key default gen_random_uuid(),
  city_id uuid not null references public.cities(id) on delete cascade,
  crop_type text not null,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  unique (city_id, crop_type)
);

alter table public.city_crop_types enable row level security;

-- Readable by any authenticated user (needed for the offline city-dataset
-- download, same as `cities`/`holdings`); writable by admin/editor only,
-- consistent with `cities_write`/`holdings_write` above.
create policy city_crop_types_read on public.city_crop_types for select
  using (auth.uid() is not null);
create policy city_crop_types_write on public.city_crop_types for all
  using (current_role_is(array['admin','editor']::user_role[]))
  with check (current_role_is(array['admin','editor']::user_role[]));

-- Seed every existing city with the previous hardcoded list so no city
-- starts empty — mirrors Parcel.cropTypeOptions at the time this migration
-- was written.
insert into public.city_crop_types (city_id, crop_type, sort_order)
select c.id, t.crop_type, t.sort_order
from public.cities c
cross join (
  values
    ('قمح', 0), ('ارز', 1), ('ذرة', 2), ('فول', 3), ('برسيم', 4),
    ('فول صويا', 5), ('بنجر', 6), ('قطن', 7), ('قصب', 8), ('عنب', 9),
    ('باذنجان', 10), ('اخرى', 11)
) as t(crop_type, sort_order)
on conflict (city_id, crop_type) do nothing;
