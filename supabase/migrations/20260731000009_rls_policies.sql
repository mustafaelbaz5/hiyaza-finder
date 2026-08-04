-- Every table gets RLS. The UI hiding a button is not security.

alter table profiles       enable row level security;
alter table cities         enable row level security;
alter table holdings       enable row level security;
alter table holding_edits  enable row level security;
alter table added_holdings enable row level security;
alter table import_batches enable row level security;

create function current_role_is(roles user_role[]) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from profiles
    where id = auth.uid() and is_active and role = any(roles)
  );
$$;

-- profiles: read own; admins read/write all
create policy profiles_self_read on profiles for select
  using (id = auth.uid() or current_role_is(array['admin','editor','viewer']::user_role[]));
create policy profiles_admin_write on profiles for all
  using (current_role_is(array['admin']::user_role[]))
  with check (current_role_is(array['admin']::user_role[]));

-- cities: field users see published only; staff see all
create policy cities_read on cities for select using (
  status = 'published'
  or current_role_is(array['admin','editor','viewer']::user_role[])
);
create policy cities_write on cities for all
  using (current_role_is(array['admin','editor']::user_role[]))
  with check (current_role_is(array['admin','editor']::user_role[]));

-- holdings: everyone authenticated reads published cities; only staff write
create policy holdings_read on holdings for select using (
  exists (select 1 from cities c where c.id = city_id and (
    c.status = 'published'
    or current_role_is(array['admin','editor','viewer']::user_role[])))
);
create policy holdings_write on holdings for all
  using (current_role_is(array['admin','editor']::user_role[]))
  with check (current_role_is(array['admin','editor']::user_role[]));

-- holding_edits: any active user may append; nobody may update or delete (append-only)
create policy holding_edits_read on holding_edits for select using (auth.uid() is not null);
create policy holding_edits_insert on holding_edits for insert
  with check (edited_by = auth.uid());

-- added_holdings: field users insert/update their own pending rows; staff manage all
create policy added_holdings_read on added_holdings for select using (auth.uid() is not null);
create policy added_holdings_insert on added_holdings for insert
  with check (created_by = auth.uid());
create policy added_holdings_update_own on added_holdings for update
  using (created_by = auth.uid() and status = 'pending');
create policy added_holdings_staff on added_holdings for all
  using (current_role_is(array['admin','editor']::user_role[]))
  with check (current_role_is(array['admin','editor']::user_role[]));

create policy import_batches_staff on import_batches for all
  using (current_role_is(array['admin','editor']::user_role[]))
  with check (current_role_is(array['admin','editor']::user_role[]));
