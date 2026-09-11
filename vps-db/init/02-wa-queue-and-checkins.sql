-- Pet Blessing 2026 -- migrasi tambahan: antrian WhatsApp + check-in hari-H
-- Jalankan manual (bukan lewat docker-entrypoint-initdb.d, karena DB sudah ada isinya):
--   docker exec -i petblessing-db psql -U petblessing -d petblessing < 02-wa-queue-and-checkins.sql

-- === Antrian pengiriman WhatsApp ===
create table if not exists api.wa_queue (
  id uuid primary key,
  owner_id uuid not null references api.owners(id) on delete cascade,
  phone text not null,
  short_code text not null,
  qr_image_base64 text not null,
  owner_name text not null,
  pet_summary text not null,
  status text not null default 'pending' check (status in ('pending','sent','failed')),
  attempts int not null default 0,
  error text,
  created_at timestamptz not null default now(),
  sent_at timestamptz
);

alter table api.wa_queue enable row level security;

-- Form publik (web_anon) cuma boleh menambah antrian, tidak boleh baca/ubah.
create policy anon_insert_wa_queue on api.wa_queue for insert to web_anon with check (true);
grant insert on api.wa_queue to web_anon;

-- Worker bot WhatsApp pakai role sendiri, akses langsung (bukan lewat PostgREST),
-- least-privilege: cuma boleh baca+update tabel ini, tidak ada akses ke owners/pets.
create role wa_worker noinherit login password '__WA_WORKER_PW__';
grant usage on schema api to wa_worker;
grant select, update on api.wa_queue to wa_worker;
create policy worker_all_wa_queue on api.wa_queue for all to wa_worker using (true) with check (true);

-- === Check-in hari-H ===
create table if not exists api.checkins (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references api.owners(id) on delete cascade,
  post text not null check (post in ('reg_ulang','pos1','pos2','pos3')),
  checked_in_at timestamptz not null default now(),
  unique (owner_id, post)
);

alter table api.checkins enable row level security;

-- Hanya panitia yang login (role web_panitia lewat JWT) yang boleh baca/tulis check-in.
create policy panitia_all_checkins on api.checkins for all to web_panitia using (true) with check (true);
grant select, insert on api.checkins to web_panitia;
