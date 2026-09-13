-- Pet Blessing 2026 -- migrasi tambahan: dua level akun panitia.
--   web_admin      : baca + ubah data pendaftaran (halaman rekap)
--   web_superadmin : semua hak admin + check-in hari-H
-- /api/login menerbitkan JWT dengan klaim role = salah satu di atas, jadi
-- pembatasan berlaku di level database lewat PostgREST, bukan hanya di
-- tampilan. Role lama web_panitia tidak dipakai lagi oleh /api/login.
-- Jalankan manual:
--   docker exec -i petblessing-db psql -U petblessing -d petblessing < 06-roles.sql
--   docker exec petblessing-db psql -U petblessing -d petblessing -c "notify pgrst, 'reload schema'"

create role web_admin nologin;
create role web_superadmin nologin;
grant web_admin, web_superadmin to authenticator;
grant usage on schema api to web_admin, web_superadmin;

grant select, update on api.owners, api.pets to web_admin, web_superadmin;
grant select, insert on api.checkins to web_superadmin;

create policy admin_select_owners on api.owners for select to web_admin, web_superadmin using (true);
create policy admin_update_owners on api.owners for update to web_admin, web_superadmin using (true) with check (true);
create policy admin_select_pets on api.pets for select to web_admin, web_superadmin using (true);
create policy admin_update_pets on api.pets for update to web_admin, web_superadmin using (true) with check (true);
create policy superadmin_all_checkins on api.checkins for all to web_superadmin using (true) with check (true);
