-- Pet Blessing 2026, PERBAIKAN migrasi 22 (1 Okt 2026).
-- Trigger pets_set_sticker_letter membaca api.pets untuk menghitung huruf
-- berikutnya. Pendaftar online (web_registrant) tidak punya hak SELECT pada
-- api.pets, jadi sejak migrasi 22 (30 Sep 18.59 WIB) setiap insert hewan dari
-- form gagal "permission denied for table pets": pemilik tersimpan tanpa hewan
-- dan tanpa QR, pendaftar mencoba ulang berkali-kali. Fungsi dijalankan dengan
-- hak pemiliknya (security definer) dan search_path dikunci.
--   docker exec -i petblessing-db psql -U petblessing -d petblessing < 24-perbaiki-trigger-huruf-stiker.sql

create or replace function api.pets_set_sticker_letter() returns trigger
language plpgsql security definer set search_path = api, pg_temp as $$
begin
  if new.sticker_letter is null then
    select chr(65 + count(*)::int) into new.sticker_letter from api.pets where owner_id = new.owner_id;
  end if;
  return new;
end $$;
revoke all on function api.pets_set_sticker_letter() from public;
