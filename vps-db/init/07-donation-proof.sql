-- Pet Blessing 2026 -- migrasi tambahan: simpan gambar bukti transfer donasi
-- (data URL JPEG, dikompres di browser maks 1280 px) supaya panitia bisa
-- mengecek langsung di halaman rekap. Kolom ini sengaja TIDAK ikut di query
-- daftar rekap (berat), hanya diambil per pendaftar saat tombol "Lihat bukti
-- transfer" ditekan.
-- Jalankan manual:
--   docker exec -i petblessing-db psql -U petblessing -d petblessing < 07-donation-proof.sql
--   docker exec petblessing-db psql -U petblessing -d petblessing -c "notify pgrst, 'reload schema'"

alter table api.owners add column if not exists donation_proof_base64 text;
