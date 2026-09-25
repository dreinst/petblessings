-- Pet Blessing 2026, migrasi tambahan: peran untuk laptop booth foto
-- (MCF Photobooth mode Pet Blessing). Booth memindai QR pendaftar, memilih
-- hewan, lalu menulis kode sesi foto dan tautan sertifikat (PDF di Drive).
--
-- Hak dibuat sesempit mungkin, per kolom:
--   owners: id, queue_number, name, is_test (TANPA no. HP, donasi, bukti transfer)
--   pets  : id, owner_id, name, type; ubah hanya mcfbooth_session_code dan certificate_url
--
-- JWT booth: {"role":"booth_worker"} ditandatangani JWT_SECRET PostgREST,
-- disimpan di .env laptop booth (PETBLESSING_BOOTH_TOKEN), tidak di repo.
-- Jalankan manual:
--   docker exec -i petblessing-db psql -U petblessing -d petblessing < 18-booth-worker.sql
--   docker exec petblessing-db psql -U petblessing -d petblessing -c "notify pgrst, 'reload schema'"

create role booth_worker nologin;
grant booth_worker to authenticator;
grant usage on schema api to booth_worker;

grant select (id, queue_number, name, is_test) on api.owners to booth_worker;
grant select (id, owner_id, name, type) on api.pets to booth_worker;
grant update (mcfbooth_session_code, certificate_url) on api.pets to booth_worker;

create policy booth_select_owners on api.owners for select to booth_worker using (true);
create policy booth_select_pets on api.pets for select to booth_worker using (true);
create policy booth_update_pets on api.pets for update to booth_worker using (true) with check (true);
