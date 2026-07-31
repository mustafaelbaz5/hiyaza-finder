-- Authoritative Excel import. IMMUTABLE from the app's perspective.
create table holdings (
  id                uuid primary key default gen_random_uuid(),
  city_id           uuid not null references cities(id) on delete restrict,
  import_batch_id   uuid references import_batches(id) on delete set null,

  holding_id_number text,              -- A  رقم الحيازة   (not unique!)
  unified_number    text,              -- T  الرقم الموحد للحيازة
  holder_name       text,              -- B
  national_id       text,              -- C
  land_number       text,              -- D  (numeric in source → text here)
  page_number       text,              -- M  (numeric in source → text here)
  basin_name        text,              -- O
  basin_code        text default '-1', -- N  (numeric/blank in source → text here)
  association_name  text,              -- P
  administration    text,              -- Q
  directorate       text,              -- R
  border_east       text,              -- I
  border_west       text,              -- J
  border_south      text,              -- K
  border_north      text,              -- L
  feddan            int not null default 0,   -- E
  qirat             int not null default 0,   -- F
  sahm              int not null default 0,   -- G
  total_sqm         numeric(12,2),            -- H

  is_stale          boolean not null default false,  -- absent from the latest import
  imported_at       timestamptz not null default now()
);

create index holdings_city_idx        on holdings (city_id);
create index holdings_holding_id_idx  on holdings (city_id, holding_id_number);
create index holdings_basin_idx       on holdings (city_id, basin_name);
create index holdings_holder_trgm     on holdings using gin (holder_name gin_trgm_ops);
create unique index holdings_unified_unique
  on holdings (city_id, unified_number) where unified_number is not null;
