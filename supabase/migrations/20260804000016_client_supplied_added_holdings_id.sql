-- Allow the app's client-generated UUID to become added_holdings.id directly
-- (previously only captured as the separate client_id column, while id was
-- always server-generated via gen_random_uuid()) so the same id is stable
-- across app + database + holding_edits, enabling a single join for
-- dashboard export. See `lib/features/sync/data/supabase_sync_api.dart`
-- (`pushAddRecord`), which now sends `id: operation.id` on insert.
--
-- Existing rows keep their current (already-diverged) id — this is
-- forward-looking for records created after this migration.
alter table added_holdings alter column id drop default;
create unique index if not exists added_holdings_client_id_key on added_holdings (client_id);
