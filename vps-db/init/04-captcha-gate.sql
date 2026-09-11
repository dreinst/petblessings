-- Pet Blessing 2026 -- migrasi tambahan: tutup insert langsung ke API publik,
-- wajibkan lewat /api/register (Vercel) yang verifikasi captcha dulu.
-- Jalankan manual:
--   docker exec -i petblessing-db psql -U petblessing -d petblessing < 04-captcha-gate.sql

create role web_registrant nologin;
grant web_registrant to authenticator;
grant usage on schema api to web_registrant;
grant insert on api.owners, api.pets, api.wa_queue to web_registrant;
grant usage on sequence api.owners_queue_number_seq to web_registrant;

create policy registrant_insert_owners on api.owners for insert to web_registrant with check (true);
create policy registrant_insert_pets on api.pets for insert to web_registrant with check (true);
create policy registrant_insert_wa_queue on api.wa_queue for insert to web_registrant with check (true);

-- Cabut akses insert anonim langsung -- semua penulisan pendaftaran sekarang
-- WAJIB lewat /api/register (Vercel serverless function), yang memverifikasi
-- token Cloudflare Turnstile dulu sebelum menerbitkan JWT role web_registrant.
revoke insert on api.owners, api.pets, api.wa_queue from web_anon;
revoke usage on sequence api.owners_queue_number_seq from web_anon;
