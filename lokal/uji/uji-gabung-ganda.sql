-- Uji penggabungan pendaftaran ganda (migrasi 25) di VPS tiruan.
--   docker exec -i pbuji-vps-db psql -v ON_ERROR_STOP=1 -U petblessing -d petblessing < lokal/uji/uji-gabung-ganda.sql
-- Semua di dalam transaksi yang dibatalkan di akhir; data uji tidak tertinggal.
begin;
create temp table hasil (cek text, ok boolean);
grant all on hasil to public;

-- A: pendaftaran lama lengkap, QR sudah terkirim, ada bukti transfer dan foto.
insert into api.owners (id, name, phone, is_parishioner, agreed_tos, donation_amount, donation_proof_base64, donation_has_proof, submitted_at)
values ('aaaaaaaa-0000-4000-8000-00000000000a', 'Budi Santoso', '0812-7777-0001', 'ya', true, '50000', 'data:image/png;base64,BUKTI', true, now() - interval '2 hour');
insert into api.pets (id, owner_id, name, type, photo_base64, has_photo)
values ('aaaaaaaa-0000-4000-8000-0000000000a1', 'aaaaaaaa-0000-4000-8000-00000000000a', 'Boba', 'Anjing', 'data:image/png;base64,FOTO', true),
       ('aaaaaaaa-0000-4000-8000-0000000000a2', 'aaaaaaaa-0000-4000-8000-00000000000a', 'Kiko', 'Kucing', null, false);
insert into api.wa_queue (id, owner_id, phone, short_code, qr_image_base64, owner_name, pet_summary, status, sent_at)
values (gen_random_uuid(), 'aaaaaaaa-0000-4000-8000-00000000000a', '0812-7777-0001', 'AAAAAAAA', 'QR-A', 'Budi Santoso', 'Boba, Kiko', 'sent', now());

-- C: percobaan gagal (tanpa hewan, tanpa QR), di antara A dan B.
insert into api.owners (id, name, phone, is_parishioner, agreed_tos, submitted_at)
values ('cccccccc-0000-4000-8000-00000000000c', 'budi santoso', '+62 812 7777 0001', 'ya', true, now() - interval '1 hour');

-- B: pendaftaran baru lewat form (peran web_registrant), format HP dan huruf beda.
set role web_registrant;
insert into api.owners (id, name, phone, is_parishioner, agreed_tos)
values ('bbbbbbbb-0000-4000-8000-00000000000b', ' BUDI  santoso', '+62 812-7777-0001', 'ya', true);
insert into api.pets (id, owner_id, name, type)
values ('bbbbbbbb-0000-4000-8000-0000000000b1', 'bbbbbbbb-0000-4000-8000-00000000000b', 'boba', 'Anjing');
insert into api.wa_queue (id, owner_id, phone, short_code, qr_image_base64, owner_name, pet_summary)
values (gen_random_uuid(), 'bbbbbbbb-0000-4000-8000-00000000000b', '+62 812-7777-0001', 'BBBBBBBB', 'QR-B', 'BUDI santoso', 'boba');
reset role;

insert into hasil select 'A dan C terhapus, B tersisa',
  (select count(*) from api.owners where api.kunci_ganda(phone, name) = api.kunci_ganda('0812 7777 0001', 'budi santoso')) = 1
  and exists (select 1 from api.owners where id = 'bbbbbbbb-0000-4000-8000-00000000000b');
insert into hasil select 'bukti transfer + nominal pindah ke B',
  (select donation_proof_base64 = 'data:image/png;base64,BUKTI' and donation_has_proof and donation_amount = '50000'
   from api.owners where id = 'bbbbbbbb-0000-4000-8000-00000000000b');
insert into hasil select 'foto Boba pindah ke boba (nama beda huruf)',
  (select photo_base64 = 'data:image/png;base64,FOTO' and has_photo from api.pets where id = 'bbbbbbbb-0000-4000-8000-0000000000b1');
insert into hasil select 'huruf stiker B terisi A',
  (select sticker_letter = 'A' from api.pets where id = 'bbbbbbbb-0000-4000-8000-0000000000b1');
insert into hasil select 'QR B ditandai koreksi karena QR A sudah terkirim',
  (select bool_and(koreksi) from api.wa_queue where owner_id = 'bbbbbbbb-0000-4000-8000-00000000000b');
insert into hasil select 'QR lama tidak menumpuk (hanya satu QR tersisa)',
  (select count(*) from api.wa_queue w join api.owners o on o.id = w.owner_id
   where api.kunci_ganda(o.phone, o.name) = api.kunci_ganda('0812 7777 0001', 'budi santoso')) = 1;
insert into hasil select 'log mencatat Kiko hanya di data lama',
  exists (select 1 from api.gabungan_log where dihapus = 'aaaaaaaa-0000-4000-8000-00000000000a'
          and rincian->'hewan_hanya_di_data_lama' ? 'Kiko' and (rincian->>'qr_lama_terkirim')::boolean);

-- D lalu E: dua-duanya sudah terkirim QR-nya, digabung manual (gabung_semua).
insert into api.owners (id, name, phone, is_parishioner, agreed_tos, submitted_at)
values ('dddddddd-0000-4000-8000-00000000000d', 'Sari', '0813-1', 'ya', true, now() - interval '3 hour'),
       ('eeeeeeee-0000-4000-8000-00000000000e', 'Sari', '0813-1', 'ya', true, now() - interval '2 hour'),
       ('ffffffff-0000-4000-8000-00000000000f', 'sari', '62813 1', 'ya', true, now() - interval '1 hour');
insert into api.pets (id, owner_id, name, type) values
  (gen_random_uuid(), 'dddddddd-0000-4000-8000-00000000000d', 'Momo', 'Kucing'),
  (gen_random_uuid(), 'eeeeeeee-0000-4000-8000-00000000000e', 'Momo', 'Kucing');
-- Matikan pemicu sementara supaya keadaan "dua QR sudah terkirim" bisa dibuat.
alter table api.wa_queue disable trigger wa_queue_gabung_ganda;
insert into api.wa_queue (id, owner_id, phone, short_code, qr_image_base64, owner_name, pet_summary, status, sent_at) values
  (gen_random_uuid(), 'dddddddd-0000-4000-8000-00000000000d', '0813-1', 'DDDDDDDD', 'QR-D', 'Sari', 'Momo', 'sent', now()),
  (gen_random_uuid(), 'eeeeeeee-0000-4000-8000-00000000000e', '0813-1', 'EEEEEEEE', 'QR-E', 'Sari', 'Momo', 'sent', now());
alter table api.wa_queue enable trigger wa_queue_gabung_ganda;
insert into api.checkins (owner_id, post, desk, arrival_number) values ('dddddddd-0000-4000-8000-00000000000d', 'reg_ulang', 'A', 77);

insert into hasil select 'gabung_semua menghapus 2 data lama', (select api.gabung_semua()) = 2;
insert into hasil select 'yang tersisa E (terbaru yang punya hewan), bukan F yang gagal',
  exists (select 1 from api.owners where id = 'eeeeeeee-0000-4000-8000-00000000000e')
  and not exists (select 1 from api.owners where id in ('dddddddd-0000-4000-8000-00000000000d', 'ffffffff-0000-4000-8000-00000000000f'));
insert into hasil select 'nomor kedatangan 77 pindah ke E',
  exists (select 1 from api.checkins where owner_id = 'eeeeeeee-0000-4000-8000-00000000000e' and arrival_number = 77);
insert into hasil select 'QR E (sudah terkirim) dikirim ulang lewat antrian koreksi',
  exists (select 1 from api.wa_correction_queue where owner_id = 'eeeeeeee-0000-4000-8000-00000000000e' and short_code = 'EEEEEEEE' and status = 'pending');
insert into hasil select 'gabung_semua kedua kali tidak mengubah apa pun', (select api.gabung_semua()) = 0;

select case when ok then 'ok   ' else 'GAGAL' end || ' ' || cek from hasil;
select count(*) filter (where ok) || ' lulus, ' || count(*) filter (where not ok or ok is null) || ' gagal' from hasil;
rollback;
