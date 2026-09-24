-- Pet Blessing 2026 -- migrasi tambahan: data UJI terpisah dari data asli.
-- Supaya panitia bisa mencoba reg ulang, layar monitor, "berikutnya dipanggil"
-- dan "terlewat" tanpa mengacaukan nomor urut pendaftar sungguhan, pemilik uji
-- ditandai owners.is_test = true (nama "Testing Nomor N", queue_number 1..N,
-- yang sengaja boleh sama dengan nomor asli karena queue_number tidak unik).
--   * monitor dan scanner MODE BIASA mengabaikan data uji,
--   * mode uji (alamat dengan ?uji=1) HANYA memakai data uji,
--   * dashboard superadmin tidak menghitung data uji dan mengingatkan kalau
--     masih ada (harus dihapus sebelum acara).
-- Hapus semua data uji (hewan, QR, reg ulang ikut terhapus lewat cascade):
--   delete from api.owners where is_test;
--
-- api.checkin_monitor sekarang punya parameter only_test. Fungsi lama
-- (satu parameter) dihapus supaya PostgREST tidak bingung memilih.
--
-- Jalankan manual:
--   docker exec -i petblessing-db psql -U petblessing -d petblessing < 17-test-owners.sql
--   docker exec petblessing-db psql -U petblessing -d petblessing -c "notify pgrst, 'reload schema'"

alter table api.owners add column if not exists is_test boolean not null default false;

drop function if exists api.checkin_monitor(int);

create or replace function api.checkin_monitor(recent_limit int default 8, only_test boolean default false)
returns json
language sql
stable
as $$
  with own as (
    select * from api.owners where is_test = only_test
  ),
  checked as (
    select o.id, o.queue_number, o.name, o.companions, c.checked_in_at
    from own o
    join api.checkins c on c.owner_id = o.id and c.post = 'reg_ulang'
  ),
  unchecked as (
    select o.queue_number
    from own o
    where not exists (select 1 from api.checkins c where c.owner_id = o.id and c.post = 'reg_ulang')
  ),
  side(odd) as (values (true), (false)),
  recent as (
    select s.odd, r.*
    from side s
    cross join lateral (
      select ch.id, ch.queue_number, ch.name, ch.companions, ch.checked_in_at
      from checked ch
      where (ch.queue_number % 2 = 1) = s.odd
      order by ch.checked_in_at desc
      limit greatest(recent_limit, 1)
    ) r
  )
  select json_build_object(
    'odd',  json_build_object(
      'total',   (select count(*) from own where queue_number % 2 = 1),
      'checked', (select count(*) from checked where queue_number % 2 = 1),
      'next',    (select min(u.queue_number) from unchecked u
                  where u.queue_number % 2 = 1
                    and u.queue_number > coalesce((select max(queue_number) from checked where queue_number % 2 = 1), 0)),
      'skipped', coalesce((select json_agg(x.n order by x.n) from (
                    select u.queue_number as n from unchecked u
                    where u.queue_number % 2 = 1
                      and u.queue_number < coalesce((select max(queue_number) from checked where queue_number % 2 = 1), 0)
                    order by 1 limit 10) x), '[]'::json),
      'recent',  coalesce((
        select json_agg(json_build_object(
          'queue_number', r.queue_number, 'name', r.name, 'companions', r.companions,
          'checked_in_at', r.checked_in_at,
          'pets', (select coalesce(json_agg(json_build_object('name', p.name, 'type', p.type)), '[]'::json)
                   from api.pets p where p.owner_id = r.id)
        ) order by r.checked_in_at desc)
        from recent r where r.odd), '[]'::json)
    ),
    'even', json_build_object(
      'total',   (select count(*) from own where queue_number % 2 = 0),
      'checked', (select count(*) from checked where queue_number % 2 = 0),
      'next',    (select min(u.queue_number) from unchecked u
                  where u.queue_number % 2 = 0
                    and u.queue_number > coalesce((select max(queue_number) from checked where queue_number % 2 = 0), 0)),
      'skipped', coalesce((select json_agg(x.n order by x.n) from (
                    select u.queue_number as n from unchecked u
                    where u.queue_number % 2 = 0
                      and u.queue_number < coalesce((select max(queue_number) from checked where queue_number % 2 = 0), 0)
                    order by 1 limit 10) x), '[]'::json),
      'recent',  coalesce((
        select json_agg(json_build_object(
          'queue_number', r.queue_number, 'name', r.name, 'companions', r.companions,
          'checked_in_at', r.checked_in_at,
          'pets', (select coalesce(json_agg(json_build_object('name', p.name, 'type', p.type)), '[]'::json)
                   from api.pets p where p.owner_id = r.id)
        ) order by r.checked_in_at desc)
        from recent r where not r.odd), '[]'::json)
    )
  );
$$;

revoke all on function api.checkin_monitor(int, boolean) from public;
grant execute on function api.checkin_monitor(int, boolean) to web_superadmin;
