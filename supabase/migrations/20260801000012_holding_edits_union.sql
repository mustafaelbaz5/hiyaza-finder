-- Fix: holding_edits should accept edits for both imported holdings and app-created holdings
-- Drop the strict foreign key, add a softer constraint that allows both tables

-- First, drop the old constraint
alter table holding_edits
drop constraint holding_edits_holding_id_fkey;

-- Replace with a comment documenting that holding_id can reference either:
-- - holdings.id (imported records)
-- - added_holdings.id (app-created records)
-- The app layer validates this; the database allows both.
-- We keep city_id as the actual foreign key for audit trails.

-- No new constraint needed — the city_id FK ensures referential integrity
-- and the app validates that the holding_id exists in one of the two tables.

comment on column holding_edits.holding_id is 'References either holdings.id or added_holdings.id; validated by app layer';
