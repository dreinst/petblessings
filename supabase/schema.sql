-- Pet Blessing 2026 -- skema Supabase
-- Jalankan di SQL Editor project Supabase (Settings > SQL Editor > New query)

create extension if not exists "pgcrypto";

create table if not exists owners (
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

create table if not exists pets (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references owners(id) on delete cascade,
  name text not null,
  type text not null,
  has_photo boolean not null default false,
  notes text,
  mcfbooth_session_code text,
  certificate_url text
);

create index if not exists pets_owner_id_idx on pets(owner_id);

alter table owners enable row level security;
alter table pets enable row level security;

-- Form publik (anon key) boleh menambah data, tapi tidak boleh membaca/mengubah/menghapus.
create policy "anon dapat insert owners" on owners
  for insert to anon
  with check (true);

create policy "anon dapat insert pets" on pets
  for insert to anon
  with check (true);

-- Halaman rekap panitia (login lewat Supabase Auth) boleh membaca semua data.
create policy "panitia login dapat baca owners" on owners
  for select to authenticated
  using (true);

create policy "panitia login dapat baca pets" on pets
  for select to authenticated
  using (true);
