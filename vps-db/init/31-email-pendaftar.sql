-- Pet Blessing 2026, email pendaftar (4 Okt 2026).
-- Form Pet Blessing dan Fashion Pawrade mewajibkan email, supaya panitia bisa mengirim
-- info acara (yang perlu dibawa, tata tertib) lewat email. Kolomnya boleh kosong karena
-- pendaftar sebelum perubahan ini dan peserta walk-in tidak punya email. Kewajiban mengisi
-- dijaga di form dan di api/register.js serta api/register-pawrade.js.
-- web_registrant sudah punya hak INSERT tingkat tabel, jadi kolom baru ikut bisa diisi.
-- Aman dijalankan ulang. Hanya dibutuhkan di VPS (server lokal tidak menyimpan email):
--   docker exec -i petblessing-db psql -U petblessing -d petblessing < 31-email-pendaftar.sql
--   docker exec petblessing-db psql -U petblessing -d petblessing -c "notify pgrst, 'reload schema'"
alter table api.owners add column if not exists email text;
alter table api.pawrade_owners add column if not exists email text;
