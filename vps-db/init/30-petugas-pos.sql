-- Pet Blessing 2026, peran petugas pos (4 Okt 2026).
-- Petugas reg ulang dan goodie bag membuka halamannya lewat tautan dari superadmin, tanpa
-- login (lihat api/tautan-petugas.js dan halaman kendali). Token di tautan itu memakai peran
-- web_petugas: cukup untuk scan, memberi nomor urut, mencatat walk-in, dan mencatat goodie
-- bag. Peran ini tidak bisa membuka rekap (donasi, bukti transfer, foto), mengubah atau
-- menghapus pendaftar, menghapus reg ulang, memanggil nomor, atau memindah pemberi nomor.
-- Aman dijalankan ulang. Dijalankan di database lokal Mac dan di VPS:
--   docker exec -i <container-db> psql -U petblessing -d petblessing < 30-petugas-pos.sql
do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'web_petugas') then
    create role web_petugas nologin;
  end if;
end $$;
grant web_petugas to authenticator;
grant usage on schema api to web_petugas;

-- Baca: hanya kolom yang tampil di pop up reg ulang dan layar goodie bag.
grant select (id, queue_number, name, phone, companions, is_test, is_walkin, submitted_at) on api.owners to web_petugas;
grant select (id, owner_id, name, type, sticker_letter, hadir) on api.pets to web_petugas;
grant select on api.checkins, api.hari_h, api.panggilan to web_petugas;

-- Tulis: yang dikerjakan fungsi reg_ulang dan walkin (keduanya berjalan dengan hak
-- pemanggil), ditambah catatan goodie bag (checkins dengan post = 'pos1').
grant insert, delete on api.checkins to web_petugas;
grant update (hadir) on api.pets to web_petugas;
grant insert (id, name, phone, is_parishioner, agreed_tos, is_walkin, queue_number) on api.owners to web_petugas;
grant insert (id, owner_id, name, type, sticker_letter) on api.pets to web_petugas;
grant execute on function api.reg_ulang(uuid, text, uuid[]), api.walkin(text, text, text, json, text),
  api.hari_h_status(boolean, int) to web_petugas;

drop policy if exists petugas_select_owners on api.owners;
drop policy if exists petugas_insert_owners on api.owners;
drop policy if exists petugas_select_pets on api.pets;
drop policy if exists petugas_update_pets on api.pets;
drop policy if exists petugas_insert_pets on api.pets;
drop policy if exists petugas_select_checkins on api.checkins;
drop policy if exists petugas_insert_checkins on api.checkins;
drop policy if exists petugas_delete_checkins on api.checkins;
drop policy if exists petugas_select_hari_h on api.hari_h;
drop policy if exists petugas_select_panggilan on api.panggilan;

create policy petugas_select_owners on api.owners for select to web_petugas using (true);
-- pemilik baru dari petugas hanya boleh walk-in
create policy petugas_insert_owners on api.owners for insert to web_petugas with check (is_walkin);
create policy petugas_select_pets on api.pets for select to web_petugas using (true);
create policy petugas_update_pets on api.pets for update to web_petugas using (true) with check (true);
create policy petugas_insert_pets on api.pets for insert to web_petugas
  with check (exists (select 1 from api.owners o where o.id = owner_id and o.is_walkin));
create policy petugas_select_checkins on api.checkins for select to web_petugas using (true);
create policy petugas_insert_checkins on api.checkins for insert to web_petugas with check (post in ('reg_ulang', 'pos1'));
-- reg ulang tidak bisa dihapus petugas, hanya catatan goodie bag yang salah tekan
create policy petugas_delete_checkins on api.checkins for delete to web_petugas using (post = 'pos1');
create policy petugas_select_hari_h on api.hari_h for select to web_petugas using (true);
create policy petugas_select_panggilan on api.panggilan for select to web_petugas using (true);
