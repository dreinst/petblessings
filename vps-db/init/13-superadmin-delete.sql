-- Pet Blessing 2026 -- migrasi tambahan: superadmin boleh menghapus satu
-- pendaftaran secara permanen (mencegah redudansi/data ganda). Menghapus
-- baris di owners/pawrade_owners otomatis ikut menghapus semua hewannya,
-- antrian QR WhatsApp-nya (jadi QR yang sudah terkirim juga ikut hilang),
-- dan riwayat check-in-nya sekaligus, lewat "on delete cascade" yang
-- sudah ada di constraint foreign key (lihat 01-init.sql, 02-wa-queue-
-- and-checkins.sql, 12-pawrade.sql). Grant DELETE + policy tetap perlu
-- ditambahkan eksplisit di semua tabel yang ikut ke-cascade, supaya
-- penghapusannya tidak diblokir izin akses.
--
-- Sengaja HANYA untuk web_superadmin -- admin (web_admin) tetap cuma
-- boleh lihat dan ubah data, tidak boleh menghapus, sama seperti hak
-- check-in dan database QR yang juga superadmin-only.
--
-- Jalankan manual:
--   docker exec -i petblessing-db psql -U petblessing -d petblessing < 13-superadmin-delete.sql
--   docker exec petblessing-db psql -U petblessing -d petblessing -c "notify pgrst, 'reload schema'"

-- Pet Blessing
grant delete on api.owners to web_superadmin;
create policy superadmin_delete_owners on api.owners for delete to web_superadmin using (true);

grant delete on api.pets to web_superadmin;
create policy superadmin_delete_pets on api.pets for delete to web_superadmin using (true);

grant delete on api.wa_queue to web_superadmin;
create policy superadmin_delete_wa_queue on api.wa_queue for delete to web_superadmin using (true);

-- checkins sudah punya policy "for all" (superadmin_all_checkins, dari
-- 02-wa-queue-and-checkins.sql) yang otomatis mencakup delete; yang
-- belum ada cuma grant DELETE di level tabelnya.
grant delete on api.checkins to web_superadmin;

-- Pawrade (struktur tabel sama, lihat 12-pawrade.sql)
grant delete on api.pawrade_owners to web_superadmin;
create policy superadmin_delete_pawrade_owners on api.pawrade_owners for delete to web_superadmin using (true);

grant delete on api.pawrade_pets to web_superadmin;
create policy superadmin_delete_pawrade_pets on api.pawrade_pets for delete to web_superadmin using (true);

grant delete on api.pawrade_wa_queue to web_superadmin;
create policy superadmin_delete_pawrade_wa_queue on api.pawrade_wa_queue for delete to web_superadmin using (true);

-- pawrade_checkins sudah punya policy "for all" (superadmin_all_pawrade_checkins),
-- cuma perlu grant DELETE.
grant delete on api.pawrade_checkins to web_superadmin;
