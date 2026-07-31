-- holding_edits had no idempotency key, unlike added_holdings.client_id —
-- a sync retry after a lost response (network drops after the insert
-- succeeded but before the client saw the response) would insert a
-- duplicate edit row with no way to detect it. client_op_id is the same
-- client-generated uuid the sync outbox already carries as SyncOperation.id;
-- retrying an insert with the same client_op_id hits the unique index and
-- fails with a Postgrest 23505 conflict, which the sync runner treats as
-- "already applied" rather than a real failure.
alter table holding_edits add column client_op_id uuid;
create unique index holding_edits_client_op_id_unique
  on holding_edits (client_op_id) where client_op_id is not null;
