-- Any data change bumps the city's data_version, which is the app's staleness signal.

-- Row-level variant, for triggers that fire per-row (holding_edits,
-- added_holdings — one insert/update at a time in normal use).
create function bump_city_version_row() returns trigger
language plpgsql as $$
begin
  update cities set data_version = data_version + 1, updated_at = now()
  where id = coalesce(new.city_id, old.city_id);
  return coalesce(new, old);
end $$;

-- Statement-level variant, for holdings: a bulk import inserts hundreds of
-- rows for one city in a single statement, and a statement-level trigger
-- has no NEW/OLD record to read — it must read the affected city ids from
-- a transition table instead, so the whole import bumps the version
-- exactly once (not once per row).
--
-- Split into one single-event trigger per operation (rather than one
-- combined INSERT/UPDATE/DELETE trigger referencing both OLD TABLE and
-- NEW TABLE) — each transition table is only ever populated by the event
-- that actually produces it, which keeps this unambiguous.
create function bump_city_version_from_new_rows() returns trigger
language plpgsql as $$
begin
  update cities c set data_version = c.data_version + 1, updated_at = now()
  where c.id in (select distinct city_id from new_rows);
  return null;
end $$;

create function bump_city_version_from_old_rows() returns trigger
language plpgsql as $$
begin
  update cities c set data_version = c.data_version + 1, updated_at = now()
  where c.id in (select distinct city_id from old_rows);
  return null;
end $$;

create trigger holdings_bump_insert
  after insert on holdings
  referencing new table as new_rows
  for each statement execute function bump_city_version_from_new_rows();

create trigger holdings_bump_update
  after update on holdings
  referencing new table as new_rows
  for each statement execute function bump_city_version_from_new_rows();

create trigger holdings_bump_delete
  after delete on holdings
  referencing old table as old_rows
  for each statement execute function bump_city_version_from_old_rows();

create trigger holding_edits_bump  after insert on holding_edits
  for each row execute function bump_city_version_row();
create trigger added_holdings_bump after insert or update on added_holdings
  for each row execute function bump_city_version_row();
