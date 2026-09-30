-- Pet Blessing 2026, migrasi tambahan: pesan info "nomor urut dibagikan saat
-- reg ulang" untuk pendaftar yang sudah menerima QR dengan teks lama
-- ("Nomor urut pendaftaran ... cocokkan dengan stiker"). Memakai antrian
-- susulan yang sudah ada, dibedakan lewat kolom jenis. Bot hanya mengirim
-- jenis 'info_nomor' pukul 07.00 sampai 21.00 WIB.
--   docker exec -i petblessing-db psql -U petblessing -d petblessing < 23-wa-info-nomor.sql

alter table api.wa_followup_queue add column if not exists jenis text not null default 'kontak';

-- Satu pesan per nomor HP, hanya pendaftar asli (bukan data uji, bukan walk-in).
insert into api.wa_followup_queue (owner_id, phone, owner_name, jenis)
select distinct on (regexp_replace(o.phone, '\D', '', 'g')) o.id, o.phone, o.name, 'info_nomor'
from api.owners o
where not o.is_test and not o.is_walkin and length(regexp_replace(o.phone, '\D', '', 'g')) >= 9
  and not exists (select 1 from api.wa_followup_queue f where f.owner_id = o.id and f.jenis = 'info_nomor')
order by regexp_replace(o.phone, '\D', '', 'g'), o.submitted_at;
