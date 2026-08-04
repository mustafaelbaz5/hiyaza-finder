-- Records created in the field. Same shape as holdings + provenance + review status.
create table added_holdings (
  id                uuid primary key default gen_random_uuid(),
  city_id           uuid not null references cities(id) on delete cascade,
  client_id         uuid not null,          -- generated offline; makes sync idempotent
  parent_holding_id uuid references holdings(id) on delete set null,  -- set for "add parcel to person"

  holding_id_number text,                   -- null for a brand-new person
  unified_number    text,
  holder_name       text not null,
  owner_name        text,
  national_id       text,
  land_number       text default '-1',
  page_number       text,
  basin_name        text,
  basin_code        text default '-1',
  association_name  text,
  administration    text,
  directorate       text,
  border_east       text,
  border_west       text,
  border_south      text,
  border_north      text,
  feddan            int not null default 0,
  qirat             int not null default 0,
  sahm              int not null default 0,
  total_sqm         numeric(12,2),
  crop_type         text,
  notes             text,
  credit_type       text not null default 'ملك',
  usage_type        text not null default 'زراعة',
  is_inheritance    boolean not null default false,
  is_delegate       boolean not null default false,

  status              record_status not null default 'pending',
  rejection_reason    text,
  promoted_holding_id uuid references holdings(id) on delete set null,
  created_by          uuid not null references profiles(id),
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);
create unique index added_holdings_client_id_unique on added_holdings (client_id);
create index added_holdings_review_idx on added_holdings (city_id, status, created_at desc);
