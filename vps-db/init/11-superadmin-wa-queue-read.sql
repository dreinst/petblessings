-- Pet Blessing 2026 -- migrasi tambahan: superadmin boleh membaca wa_queue,
-- supaya bisa menampilkan/mengunduh QR yang SUNGGUH-SUNGGUH sudah dikirim
-- ke WhatsApp pendaftar (bukan QR yang dibuat ulang di client), untuk
-- keperluan uji coba scan yang akurat. admin (web_admin) TIDAK diberi akses
-- ini -- tabel ini juga memuat nomor HP, jadi dibatasi ke superadmin saja.
-- Jalankan manual:
--   docker exec -i petblessing-db psql -U petblessing -d petblessing < 11-superadmin-wa-queue-read.sql
--   docker exec petblessing-db psql -U petblessing -d petblessing -c "notify pgrst, 'reload schema'"

grant select on api.wa_queue to web_superadmin;
create policy superadmin_select_wa_queue on api.wa_queue for select to web_superadmin using (true);
