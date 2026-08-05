-- Persist a stable person-level grouping id for app-created records.
-- Imported rows keep this null and continue grouping by holding_id_number.

alter table public.added_holdings
  add column if not exists person_client_id uuid;

alter table public.holdings
  add column if not exists person_client_id uuid;

-- Promote the grouping id alongside the row when an added_holding has
-- already been superseded into holdings.
update public.holdings h
set person_client_id = ah.client_id
from public.added_holdings ah
where ah.promoted_holding_id = h.id
  and h.person_client_id is null
  and ah.client_id is not null;

-- For rows that were created as brand-new people, the logical person id is
-- their own client-generated id.
update public.added_holdings
set person_client_id = client_id
where parent_holding_id is null
  and person_client_id is null;

