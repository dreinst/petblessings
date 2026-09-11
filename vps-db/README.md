# Infra database Pet Blessing 2026

Postgres + PostgREST ringan (bukan full Supabase), dideploy manual lewat `docker compose` di VPS dreinst (187.53.129.205), terisolasi dari service lain di VPS itu (network Docker sendiri, cuma numpang jaringan `coolify` yang sudah ada untuk proxy Traefik).

- `docker-compose.yml` -- definisi container `petblessing-db` (Postgres 16) dan `petblessing-api` (PostgREST), plus label Traefik untuk HTTPS otomatis di `petblessing-api.187.53.129.205.sslip.io`.
- `init/01-init.sql` -- skema tabel `owners`/`pets`, role `web_anon` (insert-only, tanpa select sama sekali) dan `web_panitia` (select, diaktifkan lewat JWT dari `/api/login`).

**Kredensial (`DB_PW`, `AUTH_PW`, `JWT_SECRET`) TIDAK ada di repo ini.** Ada di file `.env` yang cuma ada di server (`/root/petblessing-db/.env`), tidak pernah di-commit. `JWT_SECRET` juga perlu sama persis dengan environment variable `PGRST_JWT_SECRET` di Vercel, supaya token yang diterbitkan `/api/login` dipercaya oleh PostgREST.

Untuk redeploy dari nol di server lain: copy folder ini, buat `.env` baru (lihat placeholder di `init/01-init.sql` dan variable di `docker-compose.yml`), lalu `docker compose up -d`.
