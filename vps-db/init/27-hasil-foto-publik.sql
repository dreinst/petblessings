-- Hasil foto dan sertifikat untuk peserta (Donny, 2 Okt 2026).
-- * pets.photo_folder_url: link folder Drive hewan (foto + salinan sertifikat),
--   ditulis booth (booth_worker) saat folder sesi terpasang.
-- * api.cari_hasil(p_q): dipakai hasil.html (publik, web_anon) dari QR poster.
--   Cari nomor urut (28 atau 028A) atau minimal 3 huruf nama pemilik. Hanya
--   peserta yang sudah reg ulang, tanpa data uji, paling banyak 10 pemilik.
--   Yang dikembalikan hanya nama pemilik, nomor urut, nama/jenis hewan, dan
--   dua link Drive (keduanya memang anyone-with-link). Tanpa nomor HP.
alter table api.pets add column if not exists photo_folder_url text;
grant update (photo_folder_url) on api.pets to booth_worker;

create or replace function api.cari_hasil(p_q text)
returns json language sql stable security definer set search_path = api, pg_temp as $$
  with q as (select trim(coalesce(p_q, '')) as t),
  o as (
    select ow.id, ow.name, c.arrival_number as nomor
    from q, api.owners ow
    join api.checkins c on c.owner_id = ow.id and c.post = 'reg_ulang'
    where not ow.is_test and c.arrival_number is not null and (
      (q.t ~ '^[0-9]{1,4}[A-Za-z]?$' and c.arrival_number = regexp_replace(q.t, '[^0-9]', '', 'g')::int)
      or (length(q.t) >= 3 and ow.name ilike '%' || q.t || '%'))
    order by c.arrival_number
    limit 10
  )
  select coalesce(json_agg(json_build_object(
    'nama', o.name, 'nomor', o.nomor,
    'hewan', (select coalesce(json_agg(json_build_object(
                'label', lpad(o.nomor::text, 3, '0') || coalesce(p.sticker_letter, ''),
                'nama', p.name, 'jenis', p.type,
                'foto', p.photo_folder_url, 'sertifikat', p.certificate_url) order by p.sticker_letter), '[]'::json)
              from api.pets p where p.owner_id = o.id and p.hadir is not false)
  ) order by o.nomor), '[]'::json)
  from o
$$;

revoke all on function api.cari_hasil(text) from public;
grant execute on function api.cari_hasil(text) to web_anon, web_panitia, web_admin, web_superadmin;
