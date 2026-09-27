-- Pet Blessing 2026 -- migrasi tambahan: verifikasi superadmin DIMATIKAN
-- sementara. Selama 3 hari (sampai 1 Okt 2026 05.20 WIB) setiap login admin
-- baru langsung berstatus 'approved', jadi admin bisa masuk tanpa menunggu
-- superadmin klik Setujui. Lewat batas waktu itu trigger tidak berbuat apa
-- apa dan verifikasi kembali normal tanpa perlu diubah lagi.
-- Jalankan manual:
--   docker exec -i petblessing-db psql -U petblessing -d petblessing < 19-auto-approve-admin-sementara.sql
-- Untuk menyalakan verifikasi lebih cepat:
--   drop trigger admin_sessions_auto_approve on api.admin_sessions;

create or replace function api.admin_sessions_auto_approve() returns trigger
  language plpgsql as $$
begin
  if new.level = 'admin' and new.status = 'pending'
     and now() < timestamptz '2026-10-01 05:20:00+07' then
    new.status := 'approved';
    new.decided_at := now();
  end if;
  return new;
end
$$;

drop trigger if exists admin_sessions_auto_approve on api.admin_sessions;
create trigger admin_sessions_auto_approve before insert on api.admin_sessions
  for each row execute function api.admin_sessions_auto_approve();

-- Login admin yang sedang menunggu (token masih berlaku 12 jam) ikut disetujui.
update api.admin_sessions set status = 'approved', decided_at = now()
  where level = 'admin' and status = 'pending' and created_at > now() - interval '12 hours';
