-- Pet Blessing 2026 -- skema Postgres + PostgREST (ringan, di VPS)

create schema if not exists api;

-- Role yang dipakai PostgREST untuk connect, lalu SET ROLE sesuai request
create role authenticator noinherit login password '__AUTH_PW__';
create role web_anon nologin;
create role web_panitia nologin;

grant web_anon to authenticator;
grant web_panitia to authenticator;

grant usage on schema api to web_anon, web_panitia;

create table api.owners (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phone text not null,
  is_parishioner text not null check (is_parishioner in ('ya', 'bukan')),
  parish_origin text,
  donation_amount text,
  donation_has_proof boolean not null default false,
  agreed_tos boolean not null default false,
  submitted_at timestamptz not null default now()
);

create table api.pets (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references api.owners(id) on delete cascade,
  name text not null,
  type text not null,
  has_photo boolean not null default false,
  notes text,
  mcfbooth_session_code text,
  certificate_url text
);

create index pets_owner_id_idx on api.pets(owner_id);

alter table api.owners enable row level security;
alter table api.pets enable row level security;

-- Form publik (role web_anon lewat PostgREST) cuma boleh insert.
create policy anon_insert_owners on api.owners for insert to web_anon with check (true);
create policy anon_insert_pets on api.pets for insert to web_anon with check (true);

-- Panitia (role web_panitia, dari JWT hasil login) boleh baca semua.
create policy panitia_select_owners on api.owners for select to web_panitia using (true);
create policy panitia_select_pets on api.pets for select to web_panitia using (true);

grant insert on api.owners, api.pets to web_anon;
grant select on api.owners, api.pets to web_panitia;

-- web_anon sengaja TIDAK diberi grant select sama sekali (insert-only, murni).
-- Client men-generate id pemilik (crypto.randomUUID()) sebelum insert, dan
-- request pakai Prefer: return=minimal, supaya tidak butuh RETURNING/SELECT
-- untuk tahu id yang baru dibuat.
alter table api.owners alter column id drop default;
alter table api.pets alter column id drop default;
