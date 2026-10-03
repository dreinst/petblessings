-- Pet Blessing 2026 -- migrasi tambahan: login admin langsung disetujui,
-- tanpa batas waktu. Menggantikan versi sementara di migrasi 19 (habis 1 Okt
-- 2026). Login tetap dicatat di Log login, dan superadmin tetap bisa menekan
-- Cabut untuk menutup akses satu perangkat.
-- Jalankan manual:
--   docker exec -i petblessing-db psql -U petblessing -d petblessing < 28-auto-approve-admin-tetap.sql
-- Untuk menyalakan lagi verifikasi superadmin:
--   drop trigger admin_sessions_auto_approve on api.admin_sessions;

create or replace function api.admin_sessions_auto_approve() returns trigger
  language plpgsql as $$
begin
  if new.level = 'admin' and new.status = 'pending' then
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
