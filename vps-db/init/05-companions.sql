-- Pet Blessing 2026 -- migrasi tambahan: jumlah pendamping (pet handler,
-- keluarga, teman) yang ikut datang bersama pemilik, untuk perkiraan jumlah
-- orang hadir di hari-H. Grant insert/select sudah level tabel, jadi kolom
-- baru otomatis ikut.
-- Jalankan manual:
--   docker exec -i petblessing-db psql -U petblessing -d petblessing < 05-companions.sql
--   docker exec petblessing-db psql -U petblessing -d petblessing -c "notify pgrst, 'reload schema'"

alter table api.owners
  add column if not exists companions integer not null default 0
  check (companions between 0 and 20);
