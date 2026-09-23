-- Pet Blessing 2026 -- migrasi tambahan: bot WhatsApp (role wa_worker) perlu
-- bisa membaca nomor urut pendaftar dari owners dan pawrade_owners.
--
-- Dua masalah yang ditemukan di log bot:
-- 1. pawrade_owners: wa_worker tidak punya grant SELECT sama sekali, jadi
--    kirim QR Pawrade gagal dengan "permission denied for table
--    pawrade_owners" (2 antrian sempat macet di status failed).
-- 2. owners: wa_worker sudah punya grant SELECT (03-queue-number.sql), tapi
--    RLS aktif di tabel itu dan tidak ada policy untuk wa_worker, jadi
--    query bot selalu mengembalikan 0 baris. Akibatnya baris "Nomor urut
--    pendaftaran" diam-diam tidak pernah muncul di caption WhatsApp Pet
--    Blessing (kode bot melewati baris itu kalau nomor urutnya null).
--
-- Perbaikan: policy SELECT untuk wa_worker di kedua tabel. Untuk
-- pawrade_owners grant dibuat per kolom (id, queue_number) saja, sesuai
-- kebutuhan bot (least privilege); grant tabel penuh di owners dibiarkan
-- seperti aslinya dari migrasi 03.
--
-- Jalankan manual:
--   docker exec -i petblessing-db psql -U petblessing -d petblessing < 14-wa-worker-read-owners.sql
--   docker exec petblessing-db psql -U petblessing -d petblessing -c "notify pgrst, 'reload schema'"

create policy worker_select_owners on api.owners for select to wa_worker using (true);

grant select (id, queue_number) on api.pawrade_owners to wa_worker;
create policy worker_select_pawrade_owners on api.pawrade_owners for select to wa_worker using (true);
