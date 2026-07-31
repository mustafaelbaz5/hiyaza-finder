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
-- the transition tables instead, so the whole import bumps the version
-- exactly once (not once per row).
create function bump_city_version_statement() returns trigger
language plpgsql as $$
begin
  update cities c set data_version = c.data_version + 1, updated_at = now()
  where c.id in (
    select city_id from old_rows
    union
    select city_id from new_rows
  );
  return null;
end $$;

create trigger holdings_bump
  after insert or update or delete on holdings
  referencing old table as old_rows new table as new_rows
  for each statement execute function bump_city_version_statement();

create trigger holding_edits_bump  after insert on holding_edits
  for each row execute function bump_city_version_row();
create trigger added_holdings_bump after insert or update on added_holdings
  for each row execute function bump_city_version_row();
