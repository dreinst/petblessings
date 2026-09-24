-- Pet Blessing 2026 -- migrasi tambahan: catat POS TEMPAT SCAN dan tandai salah pos.
-- Reg ulang Pet Blessing berlangsung di 2 pos: nomor urut GANJIL di Pos A,
-- GENAP di Pos B. Kalau nomor dipindai di pos yang salah, reg ulang tetap
-- dicatat (tanpa peringatan di layar), tapi ditandai di sini supaya jadi
-- bahan evaluasi pengaturan antrean.
--   desk       : pos tempat perangkat scan ('A' atau 'B'), null untuk data lama
--   wrong_desk : true kalau desk tidak sesuai nomor urut pemilik
-- wrong_desk dihitung trigger di database dari queue_number (bukan dari
-- kiriman browser), jadi tidak bisa keliru atau dimanipulasi.
--
-- Jalankan manual:
--   docker exec -i petblessing-db psql -U petblessing -d petblessing < 16-checkin-desk.sql
--   docker exec petblessing-db psql -U petblessing -d petblessing -c "notify pgrst, 'reload schema'"

alter table api.checkins add column if not exists desk text check (desk in ('A','B'));
alter table api.checkins add column if not exists wrong_desk boolean not null default false;

create or replace function api.checkins_set_wrong_desk() returns trigger
language plpgsql as $$
declare q bigint;
begin
  if new.desk is not null then
    select queue_number into q from api.owners where id = new.owner_id;
    new.wrong_desk := (new.desk <> case when q % 2 = 1 then 'A' else 'B' end);
  else
    new.wrong_desk := false;
  end if;
  return new;
end $$;

drop trigger if exists checkins_wrong_desk on api.checkins;
create trigger checkins_wrong_desk before insert on api.checkins
  for each row execute function api.checkins_set_wrong_desk();
