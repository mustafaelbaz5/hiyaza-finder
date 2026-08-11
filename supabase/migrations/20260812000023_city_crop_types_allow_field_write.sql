-- The original city_crop_types_write policy (20260810000021) only allowed
-- admin/editor, but this table is managed from "أدوات المدينة" — a screen
-- every field-role user sees and uses. Every add/delete from the app was
-- being silently rejected by RLS: a delete matches zero rows (no error, so
-- the UI's local state update masked the failure until the next fetch), an
-- insert/upsert throws 42501 ("row-level security policy"), surfaced to the
-- user as a generic "حدث خطأ غير متوقع".

drop policy city_crop_types_write on public.city_crop_types;
create policy city_crop_types_write on public.city_crop_types for all
  using (current_role_is(array['admin','editor','field']::user_role[]))
  with check (current_role_is(array['admin','editor','field']::user_role[]));
