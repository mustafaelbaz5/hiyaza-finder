-- Documents `cities.association_type`/`association_subtype`, applied
-- directly against the live database by the Next.js dashboard project
-- (separate repo, same Supabase project) without a migration file in this
-- repo — this migration exists purely so this repo's migration history
-- matches the actual live schema going forward, per APP_PLAN.md's
-- convention of migrations being the shared source of truth between both
-- apps. Guarded with `if not exists`/`do $$ ... $$` checks so it is safe
-- to run even though the columns/type already exist in production.
--
-- `association_type` replaces the app's old client-side detection
-- (`CityTypeDetector`, which guessed a city's system by scanning parcel
-- اسم الجمعية text for a matching substring) — the database is now the
-- single source of truth. See `lib/features/cities/domain/entities/
-- association_type.dart` for the Dart-side mapping.
do $$
begin
  if not exists (select 1 from pg_type where typname = 'association_type') then
    create type association_type as enum ('agricultural_credit', 'agricultural_reform');
  end if;
end $$;

alter table cities
  add column if not exists association_type association_type,
  add column if not exists association_subtype text;

-- `association_subtype` is intentionally plain `text` with no CHECK
-- constraint (matches the live schema) — valid values are enforced by the
-- app/dashboard UI, not the database:
--   agricultural_credit -> 'ملك' | 'أوقاف'
--   agricultural_reform -> 'إصلاح مُملك' | 'إصلاح اشتراكي' | 'إصلاح قانون ثلاثة'
-- (see `Parcel.creditTypeOptions` / `Parcel.reformTypeOptions`).
