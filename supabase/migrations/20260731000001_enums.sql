-- Extensions used by later migrations.
create extension if not exists pg_trgm;

create type user_role as enum ('admin', 'editor', 'viewer', 'field');
create type city_status as enum ('draft', 'published', 'archived');
create type record_status as enum ('pending', 'approved', 'rejected');
