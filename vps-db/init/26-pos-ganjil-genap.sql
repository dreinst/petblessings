-- Reg ulang 2 pos ganjil/genap (Donny, 1 Okt 2026), supaya dua meja tidak saling menunggu:
-- * Nomor pendaftaran ganjil antre di Pos A, genap di Pos B (diarahkan di checkin.html).
-- * Pos A membagikan nomor urut ganjil (1, 3, 5, ...), Pos B genap (2, 4, 6, ...).
-- * Meja selain A/B (atau kosong) memakai nomor berikutnya apa pun paritasnya.
-- Lantai serah terima tetap berlaku untuk kedua paritas, jadi setelah pindah server
-- nomor tidak pernah bentrok (boleh ada nomor yang dilompati).
create or replace function api.reg_ulang(p_owner uuid, p_desk text, p_hadir uuid[] default null)
returns json language plpgsql as $$
declare h api.hari_h; c api.checkins; n int;
  sisa int := case upper(coalesce(p_desk, '')) when 'A' then 1 when 'B' then 0 end;
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
  select greatest(coalesce(max(arrival_number) filter (where sisa is null or arrival_number % 2 = sisa), 0), h.lantai) + 1 into n
    from api.checkins where post = 'reg_ulang';
  if sisa is not null and n % 2 <> sisa then n := n + 1; end if;
  insert into api.checkins (owner_id, post, desk, arrival_number) values (p_owner, 'reg_ulang', p_desk, n);
  update api.pets set hadir = (p_hadir is null or id = any (p_hadir)) where owner_id = p_owner;
  return json_build_object('status', 'baru', 'nomor', n, 'meja', p_desk);
end $$;
