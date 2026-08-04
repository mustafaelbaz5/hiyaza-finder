-- Adds per-parcel "reviewed/completed" status to both holdings and
-- added_holdings, applied identically to both tables. Plain UPDATE columns
-- (not routed through holding_edits) since a boolean+timestamp UPDATE is
-- naturally idempotent. Indexes are cheap now and directly useful for a
-- future "unreviewed" filter/report.

alter table public.holdings
  add column reviewed boolean not null default false,
  add column reviewed_at timestamptz,
  add column reviewed_by uuid references public.profiles(id);

alter table public.added_holdings
  add column reviewed boolean not null default false,
  add column reviewed_at timestamptz,
  add column reviewed_by uuid references public.profiles(id);

create index if not exists holdings_reviewed_idx on public.holdings (city_id, reviewed);
create index if not exists added_holdings_reviewed_idx on public.added_holdings (city_id, reviewed);
