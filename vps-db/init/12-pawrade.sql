-- Pet Blessing 2026 -- migrasi tambahan: tabel terpisah untuk lomba Pawrade
-- (Pet Parade), bagian dari Colorful Carnival 2026. Struktur, role, dan
-- kebijakan akses SENGAJA dibuat mencerminkan api.owners/api.pets/
-- api.wa_queue/api.checkins (01, 02, 06, 08, 10, 11) supaya semua kode
-- panitia (rekap, edit, foto, login, log login) bisa dipakai ulang dengan
-- sedikit perubahan. Data Pawrade terpisah total dari data Pet Blessing --
-- satu pemilik yang ikut dua acara akan punya dua baris terpisah, sengaja,
-- supaya panitia tiap lomba bisa bekerja independen.
-- Jalankan manual:
--   docker exec -i petblessing-db psql -U petblessing -d petblessing < 12-pawrade.sql
--   docker exec petblessing-db psql -U petblessing -d petblessing -c "notify pgrst, 'reload schema'"

create table api.pawrade_owners (
  id uuid primary key,
  name text not null,
  phone text not null,
  is_parishioner text not null check (is_parishioner in ('ya', 'bukan')),
  parish_origin text,
  companions integer not null default 0 check (companions between 0 and 20),
  donation_amount text,
  donation_has_proof boolean not null default false,
  donation_proof_base64 text,
  agreed_tos boolean not null default false,
  submitted_at timestamptz not null default now(),
  queue_number bigserial
);

create table api.pawrade_pets (
  id uuid primary key,
  owner_id uuid not null references api.pawrade_owners(id) on delete cascade,
  name text not null,
  type text not null,
  has_photo boolean not null default false,
  photo_base64 text,
  notes text
);

create index pawrade_pets_owner_id_idx on api.pawrade_pets(owner_id);

alter table api.pawrade_owners enable row level security;
alter table api.pawrade_pets enable row level security;

-- Sama seperti Pet Blessing: insert publik lewat /api/register-pawrade
-- (verifikasi captcha) memakai role web_registrant yang sudah ada.
grant insert on api.pawrade_owners, api.pawrade_pets to web_registrant;
grant usage on sequence api.pawrade_owners_queue_number_seq to web_registrant;
create policy registrant_insert_pawrade_owners on api.pawrade_owners for insert to web_registrant with check (true);
create policy registrant_insert_pawrade_pets on api.pawrade_pets for insert to web_registrant with check (true);

-- superadmin bebas baca/ubah. admin baca/ubah hanya kalau sesi login-nya
-- disetujui (fungsi api.session_ok(), sama seperti tabel Pet Blessing).
grant select, update on api.pawrade_owners, api.pawrade_pets to web_admin, web_superadmin;

create policy superadmin_select_pawrade_owners on api.pawrade_owners for select to web_superadmin using (true);
create policy superadmin_update_pawrade_owners on api.pawrade_owners for update to web_superadmin using (true) with check (true);
create policy superadmin_select_pawrade_pets on api.pawrade_pets for select to web_superadmin using (true);
create policy superadmin_update_pawrade_pets on api.pawrade_pets for update to web_superadmin using (true) with check (true);

create policy admin_select_pawrade_owners on api.pawrade_owners for select to web_admin using (api.session_ok());
create policy admin_update_pawrade_owners on api.pawrade_owners for update to web_admin using (api.session_ok()) with check (api.session_ok());
create policy admin_select_pawrade_pets on api.pawrade_pets for select to web_admin using (api.session_ok());
create policy admin_update_pawrade_pets on api.pawrade_pets for update to web_admin using (api.session_ok()) with check (api.session_ok());

-- Antrian WhatsApp Pawrade -- diproses bot yang sama (wa-bot/index.js),
-- nomor WhatsApp yang sama, cuma tabel dan caption-nya beda.
create table api.pawrade_wa_queue (
  id uuid primary key,
  owner_id uuid not null references api.pawrade_owners(id) on delete cascade,
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

alter table api.pawrade_wa_queue enable row level security;
create policy anon_insert_pawrade_wa_queue on api.pawrade_wa_queue for insert to web_registrant with check (true);
grant insert on api.pawrade_wa_queue to web_registrant;
grant select, update on api.pawrade_wa_queue to wa_worker, web_superadmin;
create policy worker_all_pawrade_wa_queue on api.pawrade_wa_queue for all to wa_worker using (true) with check (true);
create policy superadmin_select_pawrade_wa_queue on api.pawrade_wa_queue for select to web_superadmin using (true);

-- Check-in Pawrade -- satu titik saja (lomba berlangsung di satu
-- panggung/lokasi), jadi tanpa kolom "post" seperti Pet Blessing; satu
-- baris per pemilik sudah cukup untuk menandai "sudah check-in".
create table api.pawrade_checkins (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null unique references api.pawrade_owners(id) on delete cascade,
  checked_in_at timestamptz not null default now()
);

alter table api.pawrade_checkins enable row level security;
grant select, insert on api.pawrade_checkins to web_superadmin;
create policy superadmin_all_pawrade_checkins on api.pawrade_checkins for all to web_superadmin using (true) with check (true);
