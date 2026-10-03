-- Pet Blessing 2026, peran petugas tanpa nomor HP (4 Okt 2026).
-- Selama jam acara halaman pos dan goodie bag bisa dibuka tanpa login (api/tautan-petugas.js,
-- "pintu pos"), termasuk lewat internet. Karena itu peran web_petugas tidak lagi boleh membaca
-- nomor HP pendaftar. Petugas mencari peserta lewat nama, kode 8 karakter, atau nomor
-- pendaftaran; pencarian nomor HP tetap ada untuk superadmin.
-- Aman dijalankan ulang. Dijalankan di database lokal Mac dan di VPS, setelah migrasi 30:
--   docker exec -i <container-db> psql -U petblessing -d petblessing < 32-petugas-tanpa-nomor-hp.sql
revoke select (phone) on api.owners from web_petugas;
