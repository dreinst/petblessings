-- Peran yang dipakai skema VPS (peran tidak ikut pg_dump --schema-only).
-- Password authenticator diisi siapkan.sh lewat psql -v auth_pw=...
create role authenticator noinherit login password :'auth_pw';
create role web_anon nologin;
create role web_panitia nologin;
create role web_admin nologin;
create role web_superadmin nologin;
create role web_registrant nologin;
create role wa_worker nologin;
create role booth_worker nologin;
create role certificate_bot nologin;
grant web_anon, web_panitia, web_admin, web_superadmin, web_registrant, wa_worker, booth_worker, certificate_bot to authenticator;
