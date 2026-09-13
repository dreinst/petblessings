-- Pet Blessing 2026 -- migrasi tambahan: log login panitia + verifikasi
-- superadmin (konsep "find my device"). Setiap login dicatat (perangkat,
-- IP, waktu). Login admin berstatus 'pending' sampai superadmin menyetujui;
-- login superadmin langsung 'approved'. Klaim "sid" di JWT admin menunjuk
-- ke baris di tabel ini, dan policy web_admin di owners/pets hanya lolos
-- kalau sesi itu berstatus approved, jadi pembatasan berlaku di database.
-- Jalankan manual:
--   docker exec -i petblessing-db psql -U petblessing -d petblessing < 08-admin-sessions.sql
--   docker exec petblessing-db psql -U petblessing -d petblessing -c "notify pgrst, 'reload schema'"

create table if not exists api.admin_sessions (
  id uuid primary key,
  level text not null check (level in ('admin','superadmin')),
  device text not null,
  user_agent text,
  ip text,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  created_at timestamptz not null default now(),
  decided_at timestamptz
);

alter table api.admin_sessions enable row level security;

-- Superadmin: lihat semua log, setujui/tolak. Insert dilakukan /api/login
-- (Vercel) memakai JWT role web_superadmin berumur pendek.
grant select, insert, update on api.admin_sessions to web_superadmin;
create policy superadmin_all_admin_sessions on api.admin_sessions for all to web_superadmin using (true) with check (true);

-- Admin: hanya boleh melihat status sesinya sendiri (untuk menunggu persetujuan).
grant select on api.admin_sessions to web_admin;
create policy admin_own_admin_session on api.admin_sessions for select to web_admin
  using (id::text = current_setting('request.jwt.claims', true)::json->>'sid');

-- Benar/salah: apakah sesi di klaim "sid" JWT saat ini sudah disetujui.
create or replace function api.session_ok() returns boolean
  language sql stable security definer set search_path = api, pg_temp as $$
  select exists (
    select 1 from api.admin_sessions s
    where s.id::text = current_setting('request.jwt.claims', true)::json->>'sid'
      and s.status = 'approved'
  )
$$;
grant execute on function api.session_ok() to web_admin, web_superadmin;

-- Policy owners/pets dipisah per role: superadmin bebas, admin hanya kalau
-- sesinya disetujui. Menggantikan policy gabungan dari 06-roles.sql.
drop policy if exists admin_select_owners on api.owners;
drop policy if exists admin_update_owners on api.owners;
drop policy if exists admin_select_pets on api.pets;
drop policy if exists admin_update_pets on api.pets;

create policy superadmin_select_owners on api.owners for select to web_superadmin using (true);
create policy superadmin_update_owners on api.owners for update to web_superadmin using (true) with check (true);
create policy superadmin_select_pets on api.pets for select to web_superadmin using (true);
create policy superadmin_update_pets on api.pets for update to web_superadmin using (true) with check (true);

create policy admin_select_owners on api.owners for select to web_admin using (api.session_ok());
create policy admin_update_owners on api.owners for update to web_admin using (api.session_ok()) with check (api.session_ok());
create policy admin_select_pets on api.pets for select to web_admin using (api.session_ok());
create policy admin_update_pets on api.pets for update to web_admin using (api.session_ok()) with check (api.session_ok());
