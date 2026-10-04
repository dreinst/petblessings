-- Pet Blessing 2026, tombol "Foto ulang" di rekap superadmin (4 Okt 2026).
-- Superadmin membandingkan foto hari H (sertifikat buatan meja pilah) dengan foto saat daftar di
-- pendaftaran-masuk.html. Kalau hewannya tidak sama, rekap mengisi kolom ini dengan kode sesi booth
-- yang harus dibatalkan. Penjaga di Mac booth (repo mcfbooth, alat/foto_ulang.py) membacanya,
-- membatalkan pemilahan itu supaya fotonya kembali ke kotak masuk meja pilah, lalu mengosongkan
-- kolom ini lagi.
-- web_admin dan web_superadmin sudah punya hak SELECT dan UPDATE tingkat tabel, jadi kolom baru
-- langsung bisa dipakai. booth_worker (token booth) diberi kolom ini, dan hak baca kode sesi yang
-- selama ini hanya boleh ditulisnya, supaya penjaga tahu permintaan mana yang sudah tidak berlaku.
-- Hanya dibutuhkan di VPS (rekap membaca VPS, penyelaras server lokal tidak membawa kolom ini).
-- Aman dijalankan ulang:
--   docker exec -i petblessing-db psql -U petblessing -d petblessing < 33-foto-ulang.sql
--   docker exec petblessing-db psql -U petblessing -d petblessing -c "notify pgrst, 'reload schema'"
alter table api.pets add column if not exists foto_ulang text;
grant select (foto_ulang, mcfbooth_session_code), update (foto_ulang) on api.pets to booth_worker;
