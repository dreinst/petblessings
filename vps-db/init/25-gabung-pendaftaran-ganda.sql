-- Pet Blessing 2026, migrasi tambahan: penggabungan OTOMATIS pendaftaran ganda.
--
-- Aturan (Donny, 1 Okt 2026):
--   * Ganda = nomor HP sama (0857..., 62857..., +62 857... dianggap sama) DAN
--     nama sama (huruf besar/kecil dan spasi diabaikan). Data uji tidak ikut.
--   * Yang dipertahankan = pendaftaran TERBARU yang punya hewan. Pendaftaran
--     gagal tanpa hewan tidak pernah mengalahkan data yang lengkap.
--   * Dari data lama dipindahkan ke data terbaru kalau data terbaru belum punya:
--     bukti transfer (+ nominal donasi), foto hewan (dicocokkan per nama hewan),
--     nomor kedatangan / reg ulang, serta sertifikat dan kode sesi booth.
--     Hewan yang hanya ada di data lama dicatat di api.gabungan_log.
--   * Data lama lalu dihapus. QR-nya yang belum terkirim ikut terhapus (tidak
--     menumpuk). Kalau QR lama SUDAH pernah terkirim, QR data terbaru dikirim
--     dengan teks koreksi ("ini QR yang fix"): lewat wa_queue.koreksi kalau QR
--     terbaru belum terkirim, atau lewat wa_correction_queue kalau sudah.
--   * Berjalan otomatis saat QR pendaftaran baru masuk api.wa_queue (sebelum
--     bot mengirimnya), dan bisa dijalankan manual: select api.gabung_semua();
--
--   docker exec -i petblessing-db psql -U petblessing -d petblessing < 25-gabung-pendaftaran-ganda.sql

alter table api.wa_queue add column if not exists koreksi boolean not null default false;
-- Pesan susulan dengan teks khusus (misal permintaan maaf + ajakan daftar ulang).
alter table api.wa_followup_queue add column if not exists pesan text;

create table if not exists api.gabungan_log (
  id bigserial primary key,
  dipertahankan uuid not null,
  dihapus uuid not null,
  dihapus_nomor bigint,
  rincian jsonb not null default '{}',
  waktu timestamptz not null default now()
);
alter table api.gabungan_log enable row level security;
grant select on api.gabungan_log to web_superadmin;
drop policy if exists superadmin_select_gabungan_log on api.gabungan_log;
create policy superadmin_select_gabungan_log on api.gabungan_log for select to web_superadmin using (true);

create or replace function api.kunci_ganda(p_phone text, p_name text) returns text
language sql immutable as $$
  select regexp_replace(regexp_replace(regexp_replace(coalesce(p_phone, ''), '\D', '', 'g'), '^62', ''), '^0+', '')
         || '|' || lower(regexp_replace(trim(coalesce(p_name, '')), '\s+', ' ', 'g'))
$$;

-- Gabungkan semua pendaftaran ganda milik orang yang sama dengan p_owner.
-- Mengembalikan jumlah data lama yang dihapus.
create or replace function api.gabung_ganda(p_owner uuid) returns int
language plpgsql security definer set search_path = api, pg_temp as $$
declare
  kunci text; simpan api.owners; lama api.owners; p record; q record;
  n int := 0; lama_terkirim boolean := false; dipindah jsonb; tertinggal jsonb;
begin
  select api.kunci_ganda(phone, name) into kunci from api.owners where id = p_owner and not is_test;
  if kunci is null or split_part(kunci, '|', 1) = '' then return 0; end if;
  perform pg_advisory_xact_lock(hashtext('gabung:' || kunci));

  -- Yang dipertahankan: terbaru yang punya hewan, kalau tidak ada: terbaru.
  select o.* into simpan from api.owners o
  where not o.is_test and api.kunci_ganda(o.phone, o.name) = kunci
  order by exists (select 1 from api.pets x where x.owner_id = o.id) desc, o.submitted_at desc, o.queue_number desc
  limit 1;

  for lama in
    select o.* from api.owners o
    where not o.is_test and api.kunci_ganda(o.phone, o.name) = kunci and o.id <> simpan.id
    order by o.submitted_at
  loop
    dipindah := '[]'; tertinggal := '[]';
    if exists (select 1 from api.wa_queue w where w.owner_id = lama.id and w.status = 'sent') then
      lama_terkirim := true;
    end if;

    -- Bukti transfer dan nominal donasi.
    if lama.donation_proof_base64 is not null and simpan.donation_proof_base64 is null then
      update api.owners set donation_proof_base64 = lama.donation_proof_base64, donation_has_proof = true,
        donation_amount = coalesce(nullif(simpan.donation_amount, ''), lama.donation_amount)
      where id = simpan.id;
      simpan.donation_proof_base64 := lama.donation_proof_base64;
      dipindah := dipindah || '"bukti transfer"';
    elsif coalesce(simpan.donation_amount, '') = '' and coalesce(lama.donation_amount, '') <> '' then
      update api.owners set donation_amount = lama.donation_amount where id = simpan.id;
      simpan.donation_amount := lama.donation_amount;
    end if;

    -- Hewan: foto, sertifikat, kode sesi booth, status hadir, dicocokkan per nama.
    for p in select * from api.pets where owner_id = lama.id loop
      select * into q from api.pets
      where owner_id = simpan.id and lower(trim(name)) = lower(trim(p.name)) limit 1;
      if not found then
        tertinggal := tertinggal || to_jsonb(p.name);
        continue;
      end if;
      if p.photo_base64 is not null and q.photo_base64 is null then
        update api.pets set photo_base64 = p.photo_base64, has_photo = true where id = q.id;
        dipindah := dipindah || to_jsonb('foto ' || p.name);
      end if;
      update api.pets set
        certificate_url = coalesce(q.certificate_url, p.certificate_url),
        mcfbooth_session_code = coalesce(q.mcfbooth_session_code, p.mcfbooth_session_code),
        hadir = coalesce(q.hadir, p.hadir)
      where id = q.id;
    end loop;

    -- Reg ulang (nomor kedatangan) pindah kalau data terbaru belum reg ulang.
    if not exists (select 1 from api.checkins where owner_id = simpan.id and post = 'reg_ulang') then
      update api.checkins set owner_id = simpan.id where owner_id = lama.id and post = 'reg_ulang';
      if found then dipindah := dipindah || '"nomor kedatangan"'; end if;
    end if;

    insert into api.gabungan_log (dipertahankan, dihapus, dihapus_nomor, rincian)
    values (simpan.id, lama.id, lama.queue_number, jsonb_build_object(
      'nama', lama.name, 'dipindah', dipindah, 'hewan_hanya_di_data_lama', tertinggal,
      'qr_lama_terkirim', exists (select 1 from api.wa_queue w where w.owner_id = lama.id and w.status = 'sent')));

    -- Hapus data lama; QR, antrian WA, hewan, dan reg ulangnya ikut terhapus (cascade).
    delete from api.owners where id = lama.id;
    n := n + 1;
  end loop;

  -- QR lama pernah terkirim: pastikan QR yang berlaku dikirim dengan teks koreksi.
  if lama_terkirim then
    if exists (select 1 from api.wa_queue where owner_id = simpan.id and status <> 'sent') then
      update api.wa_queue set koreksi = true where owner_id = simpan.id and status <> 'sent';
    elsif exists (select 1 from api.wa_queue where owner_id = simpan.id and status = 'sent')
      and not exists (select 1 from api.wa_correction_queue where owner_id = simpan.id and status = 'pending') then
      insert into api.wa_correction_queue (owner_id, phone, owner_name, short_code, qr_image_base64)
      select owner_id, phone, owner_name, short_code, qr_image_base64
      from api.wa_queue where owner_id = simpan.id and status = 'sent'
      order by created_at desc limit 1;
    end if;
  end if;
  return n;
end $$;
revoke all on function api.gabung_ganda(uuid) from public;
grant execute on function api.gabung_ganda(uuid) to web_superadmin;

-- Jalankan untuk seluruh data (manual / dari dashboard).
create or replace function api.gabung_semua() returns int
language plpgsql security definer set search_path = api, pg_temp as $$
declare r record; total int := 0;
begin
  for r in
    select (array_agg(id order by submitted_at desc))[1] as id
    from api.owners where not is_test
    group by api.kunci_ganda(phone, name) having count(*) > 1
  loop
    total := total + api.gabung_ganda(r.id);
  end loop;
  return total;
end $$;
revoke all on function api.gabung_semua() from public;
grant execute on function api.gabung_semua() to web_superadmin;

-- Otomatis: begitu QR pendaftaran baru masuk antrian (langkah terakhir form),
-- gabungkan dulu. Kalau penggabungan gagal, pendaftaran tetap tersimpan.
create or replace function api.wa_queue_gabung_ganda() returns trigger
language plpgsql security definer set search_path = api, pg_temp as $$
begin
  begin
    perform api.gabung_ganda(new.owner_id);
  exception when others then
    raise warning 'gabung_ganda gagal untuk %: %', new.owner_id, sqlerrm;
  end;
  return null;
end $$;
drop trigger if exists wa_queue_gabung_ganda on api.wa_queue;
create trigger wa_queue_gabung_ganda after insert on api.wa_queue
  for each row execute function api.wa_queue_gabung_ganda();
