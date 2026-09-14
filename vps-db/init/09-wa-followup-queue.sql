-- Pet Blessing 2026 -- migrasi tambahan: antrian susulan info kontak panitia
-- Dipakai sekali untuk pendaftar yang sudah menerima blast QR sebelum caption-nya
-- diperbarui dengan info kontak panitia (Lala, Livvy). Bukan untuk pendaftar baru --
-- pendaftar baru sudah dapat info kontak langsung di blast QR utamanya.
-- Jalankan manual:
--   docker exec -i petblessing-db psql -U petblessing -d petblessing < 09-wa-followup-queue.sql

create table if not exists api.wa_followup_queue (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references api.owners(id) on delete cascade,
  phone text not null,
  owner_name text not null,
  status text not null default 'pending' check (status in ('pending','sent','failed')),
  attempts int not null default 0,
  error text,
  created_at timestamptz not null default now(),
  sent_at timestamptz
);

alter table api.wa_followup_queue enable row level security;

-- Worker bot WhatsApp pakai role yang sama seperti wa_queue, least-privilege.
grant select, update on api.wa_followup_queue to wa_worker;
create policy worker_all_wa_followup_queue on api.wa_followup_queue for all to wa_worker using (true) with check (true);

-- Isi sekali dari pendaftar yang antrian QR-nya sudah berstatus terkirim,
-- supaya tidak dobel dengan yang masih pending/gagal (mereka akan dapat versi baru
-- lewat wa_queue biasa begitu terkirim).
insert into api.wa_followup_queue (owner_id, phone, owner_name)
select owner_id, phone, owner_name from api.wa_queue where status = 'sent';
