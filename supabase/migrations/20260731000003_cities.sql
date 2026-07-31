create table cities (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,                    -- اسم الجمعية / القرية
  directorate text,                             -- المديرية
  administration text,                          -- الإدارة
  status      city_status not null default 'draft',
  data_version bigint not null default 1,       -- bumped on any data change; app compares this
  created_by  uuid references profiles(id),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create unique index cities_name_unique on cities (lower(name));
