-- Pet Blessing 2026 -- migrasi tambahan: simpan foto hewan (data URL JPEG,
-- dikompres di browser maks 1024 px) supaya panitia bisa melihat dan
-- mengunduhnya dari halaman rekap. Seperti bukti transfer, kolom ini tidak
-- ikut di query daftar rekap; diambil per hewan saat tombol Foto ditekan.
-- Jalankan manual:
--   docker exec -i petblessing-db psql -U petblessing -d petblessing < 10-pet-photos.sql
--   docker exec petblessing-db psql -U petblessing -d petblessing -c "notify pgrst, 'reload schema'"

alter table api.pets add column if not exists photo_base64 text;
