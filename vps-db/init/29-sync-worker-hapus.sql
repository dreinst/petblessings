-- Pet Blessing 2026, perbaikan penyelaras server lokal (4 Okt 2026).
-- lokal/server.js menghapus di database lokal pendaftar yang sudah dihapus di VPS, misalnya
-- pendaftaran ganda yang dilebur migrasi 25. Peran sync_worker hanya punya select, insert,
-- update di api.owners (migrasi 22), jadi permintaan hapus itu ditolak 403 dan seluruh putaran
-- sinkron berhenti: hewan pendaftar baru tidak tersalin ke lokal dan nomor reg ulang tidak
-- terkirim ke VPS. Terjadi 4 Okt 2026 02.39 WIB saat satu pendaftar mendaftar ulang.
-- Hewan, checkins, dan antrean WA milik pendaftar itu ikut terhapus lewat on delete cascade.
-- Hanya dibutuhkan di database lokal Mac (VPS tidak pernah menghapus lewat penyelaras):
--   docker exec -i pblokal-db psql -U petblessing -d petblessing < 29-sync-worker-hapus.sql
grant delete on api.owners to sync_worker;
