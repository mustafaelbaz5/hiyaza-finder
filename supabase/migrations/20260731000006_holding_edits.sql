-- Append-only correction overlay. Mirrors the app's existing edit-snapshot model.
create table holding_edits (
  id               uuid primary key default gen_random_uuid(),
  holding_id       uuid not null references holdings(id) on delete cascade,
  city_id          uuid not null references cities(id) on delete cascade,
  payload          jsonb not null,        -- Parcel.toEditableJson() shape
  edited_by        uuid not null references profiles(id),
  edited_at        timestamptz not null default now(),
  client_edited_at timestamptz,           -- device clock; drives last-write-wins
  device_id        text
);
create index holding_edits_holding_idx on holding_edits (holding_id, edited_at desc);
create index holding_edits_city_idx    on holding_edits (city_id, edited_at desc);

-- Latest edit per holding — what the app downloads.
create view holding_edits_latest as
select distinct on (holding_id) * from holding_edits
order by holding_id, coalesce(client_edited_at, edited_at) desc;
