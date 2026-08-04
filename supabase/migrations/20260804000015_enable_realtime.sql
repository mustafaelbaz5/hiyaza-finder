-- Enables Supabase Realtime (postgres_changes) for the three tables the
-- Flutter app needs live multi-device updates on: `holdings` (imported/
-- promoted holdings), `holding_edits` (append-only correction log), and
-- `added_holdings` (field-created records + their review status).
--
-- No RLS changes accompany this — Supabase enforces the existing SELECT
-- policies (see 20260731000009_rls_policies.sql) on realtime subscriptions
-- exactly as it does on normal queries: a client only receives change
-- events for rows it could already `SELECT`. This was a deliberate,
-- explicitly-confirmed decision (not a default) since `holding_edits_read`/
-- `added_holdings_read` allow any authenticated user — including the
-- `field` role — to read every row, not just their own; a realtime
-- subscription therefore fans out every user's edits/additions to every
-- connected device on that table, same as a plain SELECT already would.
--
-- Client side: `lib/features/sync/data/realtime_sync_service.dart` opens
-- one subscription per table, filtered to the active city's `city_id`, and
-- patches only the affected `Parcel` into `HoldingsRepository` rather than
-- re-downloading the city.
alter publication supabase_realtime add table holdings;
alter publication supabase_realtime add table holding_edits;
alter publication supabase_realtime add table added_holdings;
