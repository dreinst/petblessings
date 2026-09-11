-- Pet Blessing 2026 -- migrasi tambahan: nomor urut pendaftaran (sinkron stiker check-in)
-- Jalankan manual:
--   docker exec -i petblessing-db psql -U petblessing -d petblessing < 03-queue-number.sql

alter table api.owners add column if not exists queue_number bigserial;

-- web_anon perlu izin pakai sequence ini supaya bisa insert (default nextval()
-- dipanggil atas nama web_anon, bukan cuma butuh privilege di kolom/tabel).
grant usage on sequence api.owners_queue_number_seq to web_anon;

-- Bot WhatsApp perlu baca nomor urut (dan nama/telepon untuk caption) supaya bisa
-- disisipkan ke pesan -- form publik (web_anon) TETAP tidak dikasih akses baca sama
-- sekali, jadi nomor urut hanya bisa diketahui pemilik lewat WhatsApp, bukan lewat form.
grant select on api.owners to wa_worker;
