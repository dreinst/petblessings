-- Pet Blessing 2026, migrasi tambahan: reg ulang hari-H dengan NOMOR KEDATANGAN.
--
-- Konsep (Donny, 30 Sep 2026):
--   * nomor pendaftaran (owners.queue_number) tidak lagi jadi urutan panggil,
--     cuma identitas untuk mencari data;
--   * siapa pun yang reg ulang duluan dapat nomor kedatangan 1, 2, 3, ...
--     (checkins.arrival_number), satu nomor per pemilik; tiap hewan dapat
--     huruf tetap (pets.sticker_letter), jadi label stiker = 27A, 27B;
--   * dua meja (A dan B) mengambil nomor dari satu penghitung, dikunci
--     pg_advisory_xact_lock supaya tidak ada nomor ganda;
--   * server lokal di Mac = pemberi nomor utama, VPS = cadangan. Di satu
--     waktu hanya SATU database yang boleh memberi nomor (hari_h.pemberi_nomor).
--     Saat pindah ke cadangan, nomor dilanjutkan dari lantai = nomor tertinggi
--     yang diketahui + 10 supaya tidak bertabrakan dengan nomor yang belum
--     sempat tersinkron. Nomor yang terlewat tidak pernah dipanggil.
--
-- File ini dijalankan di DUA database: VPS dan server lokal di Mac.
--   docker exec -i petblessing-db psql -U petblessing -d petblessing < 22-hari-h.sql
--   docker exec petblessing-db psql -U petblessing -d petblessing -c "notify pgrst, 'reload schema'"

-- === Kolom baru ===
alter table api.checkins add column if not exists arrival_number int;
create unique index if not exists checkins_arrival_number_key
  on api.checkins (arrival_number) where post = 'reg_ulang';

alter table api.pets add column if not exists sticker_letter text;
alter table api.pets add column if not exists hadir boolean; -- null = pemiliknya belum reg ulang
alter table api.owners add column if not exists is_walkin boolean not null default false;

-- Huruf stiker per hewan, urut sesuai urutan masuk ke database. Diisi sekali,
-- setelah itu tetap (stiker dicetak dari sini).
update api.pets p set sticker_letter = x.letter
from (
  select id, chr(64 + row_number() over (partition by owner_id order by ctid)::int) as letter
  from api.pets
) x
where p.id = x.id and p.sticker_letter is null;

-- Hewan yang masuk setelah ini (pendaftar baru, walk-in) langsung dapat huruf berikutnya.
create or replace function api.pets_set_sticker_letter() returns trigger language plpgsql as $$
begin
  if new.sticker_letter is null then
    select chr(65 + count(*)::int) into new.sticker_letter from api.pets where owner_id = new.owner_id;
  end if;
  return new;
end $$;
drop trigger if exists pets_sticker_letter on api.pets;
create trigger pets_sticker_letter before insert on api.pets
  for each row execute function api.pets_set_sticker_letter();

-- Pembagian ganjil/genap per pos dihapus: peserta boleh ke meja mana saja.
drop trigger if exists checkins_wrong_desk on api.checkins;

-- === Penanda pemberi nomor (satu baris) ===
create table if not exists api.hari_h (
  id int primary key default 1 check (id = 1),
  pemberi_nomor boolean not null default false,
  lantai int not null default 0,          -- nomor berikutnya minimal lantai + 1
  lokal_terakhir timestamptz,             -- detak terakhir dari server lokal (diisi di VPS)
  diubah_at timestamptz not null default now()
);
-- VPS memberi nomor sampai server lokal mengambil alih di hari-H. Di server
-- lokal baris ini di-set false oleh skrip setup sampai "Ambil alih" ditekan.
insert into api.hari_h (id, pemberi_nomor) values (1, true) on conflict (id) do nothing;

-- === Panggilan di ruang tunggu ===
create table if not exists api.panggilan (
  arrival_number int primary key,
  called_at timestamptz not null default now(),
  jumlah int not null default 1           -- berapa kali dipanggil
);

-- === Fungsi ===

-- Reg ulang: beri nomor kedatangan (atau kembalikan nomor lama kalau sudah).
-- p_hadir = id hewan yang dibawa; null = semua hewan hadir.
create or replace function api.reg_ulang(p_owner uuid, p_desk text, p_hadir uuid[] default null)
returns json language plpgsql as $$
declare h api.hari_h; c api.checkins; n int;
begin
  perform pg_advisory_xact_lock(20261004);
  select * into c from api.checkins where owner_id = p_owner and post = 'reg_ulang';
  if found then
    return json_build_object('status', 'sudah', 'nomor', c.arrival_number, 'meja', c.desk, 'waktu', c.checked_in_at);
  end if;
  if not exists (select 1 from api.owners where id = p_owner) then
    raise exception 'Pendaftaran tidak ditemukan' using errcode = 'P0002';
  end if;
  select * into h from api.hari_h where id = 1;
  if not coalesce(h.pemberi_nomor, false) then
    raise exception 'Server ini sedang tidak memberi nomor. Pakai alamat server utama.' using errcode = 'P0001';
  end if;
  select greatest(coalesce(max(arrival_number), 0), h.lantai) + 1 into n
    from api.checkins where post = 'reg_ulang';
  insert into api.checkins (owner_id, post, desk, arrival_number) values (p_owner, 'reg_ulang', p_desk, n);
  update api.pets set hadir = (p_hadir is null or id = any (p_hadir)) where owner_id = p_owner;
  return json_build_object('status', 'baru', 'nomor', n, 'meja', p_desk);
end $$;

-- Peserta yang belum daftar online. p_pets = [{"name":"Boba","type":"Anjing"}, ...]
create or replace function api.walkin(p_name text, p_phone text, p_umat text, p_pets json, p_desk text)
returns json language plpgsql as $$
declare oid uuid := gen_random_uuid(); r json; i int := 0;
begin
  if coalesce(trim(p_name), '') = '' then raise exception 'Nama pemilik wajib diisi' using errcode = 'P0001'; end if;
  if json_array_length(coalesce(p_pets, '[]'::json)) = 0 then raise exception 'Minimal satu hewan' using errcode = 'P0001'; end if;
  -- queue_number diisi eksplisit: sequence di server lokal tidak ikut maju saat data disalin dari VPS.
  insert into api.owners (id, name, phone, is_parishioner, agreed_tos, is_walkin, queue_number)
  values (oid, trim(p_name), coalesce(trim(p_phone), ''), case when p_umat = 'bukan' then 'bukan' else 'ya' end, true, true,
          (select coalesce(max(queue_number), 0) + 1 from api.owners));
  for r in select * from json_array_elements(p_pets) loop
    i := i + 1;
    insert into api.pets (id, owner_id, name, type, sticker_letter)
    values (gen_random_uuid(), oid, trim(r->>'name'), coalesce(nullif(trim(r->>'type'), ''), 'Lainnya'), chr(64 + i));
  end loop;
  return (api.reg_ulang(oid, p_desk, null)::jsonb || jsonb_build_object('owner_id', oid))::json;
end $$;

-- Panggil nomor di ruang tunggu. p_nomor null = nomor terkecil yang belum dipanggil.
create or replace function api.panggil(p_nomor int default null, p_uji boolean default false)
returns json language plpgsql as $$
declare n int;
begin
  n := p_nomor;
  if n is null then
    select min(c.arrival_number) into n
    from api.checkins c join api.owners o on o.id = c.owner_id
    where c.post = 'reg_ulang' and o.is_test = p_uji
      and not exists (select 1 from api.panggilan p where p.arrival_number = c.arrival_number);
  end if;
  if n is null then return json_build_object('nomor', null); end if;
  insert into api.panggilan (arrival_number) values (n)
  on conflict (arrival_number) do update set called_at = now(), jumlah = api.panggilan.jumlah + 1;
  return json_build_object('nomor', n);
end $$;

-- Satu paket data untuk halaman meja, monitor, pemanggil, dan layar ruang tunggu.
-- Tanpa nomor HP (layar dilihat banyak orang).
create or replace function api.hari_h_status(p_uji boolean default false, p_recent int default 10)
returns json language sql stable as $$
  with reg as (
    select c.arrival_number as nomor, c.desk as meja, c.checked_in_at as waktu, o.id, o.name, o.companions, o.is_walkin
    from api.checkins c join api.owners o on o.id = c.owner_id
    where c.post = 'reg_ulang' and o.is_test = p_uji and c.arrival_number is not null
  ),
  pets_of as (
    select r.nomor, coalesce(json_agg(json_build_object('label', r.nomor::text || coalesce(p.sticker_letter, ''), 'name', p.name, 'type', p.type)
             order by p.sticker_letter) filter (where p.hadir is not false), '[]'::json) as pets
    from reg r left join api.pets p on p.owner_id = r.id group by r.nomor
  ),
  called as (
    select p.* from api.panggilan p join reg r on r.nomor = p.arrival_number
  )
  select json_build_object(
    'pemberi_nomor', (select pemberi_nomor from api.hari_h where id = 1),
    'terdaftar', (select count(*) from api.owners where is_test = p_uji and not is_walkin),
    'hadir', (select count(*) from reg),
    'walkin', (select count(*) from reg where is_walkin),
    'hewan_hadir', (select count(*) from reg r join api.pets p on p.owner_id = r.id where p.hadir is not false),
    'terakhir_per_meja', (select coalesce(json_object_agg(meja, nomor), '{}'::json) from (
        select distinct on (meja) meja, nomor from reg where meja is not null order by meja, waktu desc) m),
    'recent', (select coalesce(json_agg(x order by x.waktu desc), '[]'::json) from (
        select r.nomor, r.meja, r.waktu, r.name, r.companions, po.pets
        from reg r join pets_of po on po.nomor = r.nomor order by r.waktu desc limit p_recent) x),
    'dipanggil', (select json_build_object('nomor', r.nomor, 'name', r.name, 'pets', po.pets, 'called_at', c.called_at, 'jumlah', c.jumlah)
        from called c join reg r on r.nomor = c.arrival_number join pets_of po on po.nomor = r.nomor
        order by c.called_at desc limit 1),
    'riwayat_panggil', (select coalesce(json_agg(x order by x.called_at desc), '[]'::json) from (
        select c.arrival_number as nomor, c.called_at, c.jumlah from called c order by c.called_at desc limit 12) x),
    'menunggu', (select coalesce(json_agg(x order by x.nomor), '[]'::json) from (
        select r.nomor, r.name, po.pets from reg r join pets_of po on po.nomor = r.nomor
        where not exists (select 1 from api.panggilan p where p.arrival_number = r.nomor)
        order by r.nomor) x)
  )
$$;

-- Serah terima pemberi nomor. serahkan() dipanggil ke database yang BERHENTI
-- memberi nomor, ambil_alih(lantai) ke database yang MULAI.
create or replace function api.serahkan()
returns json language plpgsql as $$
declare m int;
begin
  perform pg_advisory_xact_lock(20261004);
  update api.hari_h set pemberi_nomor = false, diubah_at = now() where id = 1;
  select coalesce(max(arrival_number), 0) into m from api.checkins where post = 'reg_ulang';
  return json_build_object('nomor_tertinggi', m);
end $$;

create or replace function api.ambil_alih(p_lantai int)
returns json language plpgsql as $$
declare m int;
begin
  perform pg_advisory_xact_lock(20261004);
  select coalesce(max(arrival_number), 0) into m from api.checkins where post = 'reg_ulang';
  update api.hari_h set pemberi_nomor = true, lantai = greatest(p_lantai, m), diubah_at = now() where id = 1;
  return json_build_object('lantai', greatest(p_lantai, m));
end $$;

-- === Hak akses ===
alter table api.hari_h enable row level security;
alter table api.panggilan enable row level security;

grant select on api.hari_h to web_superadmin;
grant select, insert, update, delete on api.panggilan to web_superadmin;
create policy superadmin_select_hari_h on api.hari_h for select to web_superadmin using (true);
create policy superadmin_update_hari_h on api.hari_h for update to web_superadmin using (true) with check (true);
create policy superadmin_all_panggilan on api.panggilan for all to web_superadmin using (true) with check (true);
grant update (pemberi_nomor, lantai, diubah_at) on api.hari_h to web_superadmin;
grant insert on api.owners, api.pets to web_superadmin;
grant usage on sequence api.owners_queue_number_seq to web_superadmin;
create policy superadmin_insert_owners on api.owners for insert to web_superadmin with check (true);
create policy superadmin_insert_pets on api.pets for insert to web_superadmin with check (true);
grant execute on function api.reg_ulang(uuid, text, uuid[]), api.walkin(text, text, text, json, text),
  api.panggil(int, boolean), api.hari_h_status(boolean, int), api.serahkan(), api.ambil_alih(int) to web_superadmin;

-- Laptop booth foto dan bot sertifikat butuh nomor kedatangan + huruf stiker.
grant select (id, owner_id, post, arrival_number) on api.checkins to booth_worker, certificate_bot;
create policy booth_select_checkins on api.checkins for select to booth_worker using (true);
create policy certbot_select_checkins on api.checkins for select to certificate_bot using (true);
grant select (sticker_letter, hadir) on api.pets to booth_worker, certificate_bot;

-- Penyelaras server lokal <-> VPS (JWT {"role":"sync_worker"}, disimpan di Mac).
do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'sync_worker') then
    create role sync_worker nologin;
  end if;
end $$;
grant sync_worker to authenticator;
grant usage on schema api to sync_worker;
grant select, insert, update on api.owners, api.pets, api.checkins, api.panggilan to sync_worker;
grant select, update on api.hari_h to sync_worker;
create policy sync_all_owners on api.owners for all to sync_worker using (true) with check (true);
create policy sync_all_pets on api.pets for all to sync_worker using (true) with check (true);
create policy sync_all_checkins on api.checkins for all to sync_worker using (true) with check (true);
create policy sync_all_panggilan on api.panggilan for all to sync_worker using (true) with check (true);
create policy sync_all_hari_h on api.hari_h for all to sync_worker using (true) with check (true);
grant execute on function api.serahkan(), api.ambil_alih(int) to sync_worker;
