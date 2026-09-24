-- Pet Blessing 2026 -- migrasi tambahan: data untuk halaman monitor check-in
-- (monitor-checkin.html), layar tambahan yang menampilkan nomor urut yang
-- baru check-in. Check-in Pet Blessing sekarang 1 titik dengan 2 pos:
-- nomor urut GANJIL di Pos A, GENAP di Pos B. Pos tidak disimpan di
-- kolom checkins.post (tetap 'reg_ulang'), karena pos selalu bisa dihitung
-- dari nomor urut pemilik (queue_number % 2).
--
-- Fungsi ini mengembalikan semuanya dalam SATU request supaya hemat: API
-- dibatasi request per menit, dan monitor memuat ulang data tiap beberapa
-- detik. Hasil JSON:
--   { odd:  { total, checked, next, skipped:[nomor], recent:[{queue_number,name,companions,checked_in_at,pets:[{name,type}]}] },
--     even: { ... } }
-- recent  = reg ulang terbaru dulu, paling banyak recent_limit per sisi.
-- next    = nomor berikutnya yang dipanggil di sisi itu: nomor terkecil yang
--           belum reg ulang DAN lebih besar dari nomor tertinggi yang sudah
--           reg ulang (null kalau tidak ada lagi). Antrean dipanggil berurutan,
--           jadi yang absen tidak menahan "berikutnya".
-- skipped = nomor yang belum reg ulang padahal nomor di atasnya sudah (yang
--           terlewat/absen), paling banyak 10 nomor terkecil.
-- Tidak mengembalikan nomor HP (layar monitor dilihat banyak orang).
--
-- SECURITY INVOKER (default): jalan sebagai web_superadmin, jadi RLS di
-- owners/pets/checkins tetap berlaku. Akses dicabut dari PUBLIC dan hanya
-- diberikan ke web_superadmin.
--
-- Jalankan manual:
--   docker exec -i petblessing-db psql -U petblessing -d petblessing < 15-checkin-monitor.sql
--   docker exec petblessing-db psql -U petblessing -d petblessing -c "notify pgrst, 'reload schema'"

create or replace function api.checkin_monitor(recent_limit int default 8)
returns json
language sql
stable
as $$
  with checked as (
    select o.id, o.queue_number, o.name, o.companions, c.checked_in_at
    from api.owners o
    join api.checkins c on c.owner_id = o.id and c.post = 'reg_ulang'
  ),
  unchecked as (
    select o.queue_number
    from api.owners o
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
      'total',   (select count(*) from api.owners where queue_number % 2 = 1),
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
      'total',   (select count(*) from api.owners where queue_number % 2 = 0),
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

revoke all on function api.checkin_monitor(int) from public;
grant execute on function api.checkin_monitor(int) to web_superadmin;
