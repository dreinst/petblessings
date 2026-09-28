-- Pet Blessing 2026, migrasi tambahan: peran bot yang hanya boleh MEMBACA
-- data sertifikat secara langsung (live), misalnya untuk cek hewan mana yang
-- sudah punya tautan sertifikat dan mana yang belum.
--
-- Hak dibuat sesempit mungkin, per kolom, hanya baca:
--   owners: id, queue_number, name, is_test (TANPA no. HP, donasi, bukti transfer)
--   pets  : id, owner_id, name, type, mcfbooth_session_code, certificate_url
--           (TANPA foto, catatan, dan tabel lain)
-- Tidak ada hak tulis sama sekali. Yang menulis certificate_url tetap booth_worker.
--
-- JWT bot: {"role":"certificate_bot"} ditandatangani JWT_SECRET PostgREST,
-- disimpan di .env bot, tidak di repo. Cara membuatnya sama dengan token booth
-- (lihat 18-booth-worker.sql), hanya klaim role-nya beda.
-- Jalankan manual (setelah disetujui Andrew):
--   docker exec -i petblessing-db psql -U petblessing -d petblessing < 20-certificate-bot.sql
--   docker exec petblessing-db psql -U petblessing -d petblessing -c "notify pgrst, 'reload schema'"

create role certificate_bot nologin;
grant certificate_bot to authenticator;
grant usage on schema api to certificate_bot;

grant select (id, queue_number, name, is_test) on api.owners to certificate_bot;
grant select (id, owner_id, name, type, mcfbooth_session_code, certificate_url) on api.pets to certificate_bot;

create policy certbot_select_owners on api.owners for select to certificate_bot using (true);
create policy certbot_select_pets on api.pets for select to certificate_bot using (true);
