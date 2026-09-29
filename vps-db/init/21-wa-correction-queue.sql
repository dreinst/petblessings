-- Pet Blessing 2026 -- migrasi tambahan: antrian koreksi QR
-- Dipakai untuk mengirim ulang QR ke pendaftar yang datanya sempat digabung
-- (pendaftaran ganda, 29 Sep 2026: antrean 25->35, 66->73), supaya mereka
-- tahu QR mana yang berlaku di hari H. Sama strukturnya dengan wa_queue,
-- least-privilege sama seperti wa_followup_queue.
-- Jalankan manual:
--   docker exec -i petblessing-db psql -U petblessing -d petblessing < 21-wa-correction-queue.sql

create table if not exists api.wa_correction_queue (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references api.owners(id) on delete cascade,
  phone text not null,
  owner_name text not null,
  short_code text not null,
  qr_image_base64 text not null,
  status text not null default 'pending' check (status in ('pending','sent','failed')),
  attempts int not null default 0,
  error text,
  created_at timestamptz not null default now(),
  sent_at timestamptz
);

alter table api.wa_correction_queue enable row level security;

grant select, update on api.wa_correction_queue to wa_worker;
create policy worker_all_wa_correction_queue on api.wa_correction_queue for all to wa_worker using (true) with check (true);
