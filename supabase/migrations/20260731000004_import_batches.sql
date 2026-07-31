create table import_batches (
  id            uuid primary key default gen_random_uuid(),
  city_id       uuid not null references cities(id) on delete restrict,
  file_name     text not null,
  storage_path  text,
  status        text not null default 'pending',
  rows_total    int not null default 0,
  rows_imported int not null default 0,
  rows_rejected int not null default 0,
  rejection_log jsonb,
  mapping_used  jsonb,
  imported_by   uuid not null references profiles(id),
  created_at    timestamptz not null default now(),
  committed_at  timestamptz
);
