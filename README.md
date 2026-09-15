# Pet Blessing 2026, form pendaftaran

Form pendaftaran untuk acara Pet Blessing 2026, Paroki St. Vincentius a Paulo, Malang.

## Isi proyek

- `index.html`, form pendaftaran publik. Satu pemilik bisa mendaftarkan beberapa hewan dalam satu submission (satu record pemilik, satu record per hewan, terhubung lewat ID pendaftaran). Setelah submit, tampil QR + kode pendek sebagai bukti pendaftaran (untuk di-screenshot), dan otomatis dikirim juga lewat WhatsApp.
- `pendaftaran-masuk.html`, halaman rekap panitia (login `admin` atau `superadmin`): daftar pendaftar, ubah data, lihat bukti transfer, export `.xlsx`.
- `superadmin.html`, dashboard superadmin: ringkasan angka (pemilik, hewan, pendamping, check-in per pos), log login panitia dengan tombol setujui/tolak login admin, tautan ke rekap dan check-in.
- `checkin.html`, halaman scan check-in hari-H (kamera live, khusus login `superadmin`) untuk 4 pos: reg ulang, pos 1-3. Ada pencarian manual (kode 8 karakter, nama, atau no. HP) untuk pemilik yang QR-nya tidak terbaca atau tidak menerima WhatsApp.
- `api/register.js`, satu-satunya jalur menulis data pendaftaran -- verifikasi captcha (Cloudflare Turnstile) dulu sebelum insert ke database.
- `api/login.js`, login panitia: dua akun dari env Vercel (`PANITIA_*` = admin, `SUPERADMIN_*` = superadmin), JWT membawa role Postgres `web_admin` / `web_superadmin`.
- `wa-bot/`, bot WhatsApp (Baileys) yang jalan terus-menerus di VPS, kirim QR bukti pendaftaran dengan delay acak.
- `vps-db/`, skema + docker-compose database (Postgres + PostgREST ringan) yang jalan di VPS.

## Status

**Live**: https://petblessings.vercel.app

Database Postgres + PostgREST ringan (bukan Supabase, lihat `vps-db/README.md` untuk alasannya) jalan di VPS dreinst.

**Keamanan yang sudah dipasang:**
- Semua penulisan data pendaftaran wajib lewat `/api/register`, yang memverifikasi captcha (Cloudflare Turnstile) dulu -- akses insert langsung ke database publik sudah dicabut total (role `web_anon` tidak lagi punya izin insert).
- Rate limit 15 request/menit per IP di level Traefik (VPS) untuk endpoint API publik.
- QR check-in divalidasi format UUID ketat sebelum dipakai untuk query apapun -- data QR mentah tidak pernah dipakai langsung ke URL/DOM.
- Halaman rekap & check-in dikunci login panitia. Dua level: `admin` (role `web_admin`: baca + ubah owners/pets) dan `superadmin` (role `web_superadmin`: semua hak admin + check-in). Batasannya berlaku di database lewat PostgREST (`vps-db/init/06-roles.sql`), bukan hanya di tampilan.

Bukti transfer donasi (maks 1280 px) dan foto hewan (maks 1024 px) dikompres di browser menjadi JPEG lalu disimpan di `owners.donation_proof_base64` dan `pets.photo_base64`. Panitia melihat bukti transfer dan melihat serta mengunduh foto hewan dari rekap, per pendaftar (kolom gambar tidak ikut di query daftar).

## Rencana eskalasi

Langkah berikutnya, sesuai urutan prioritas: upload foto sungguhan (dengan kompresi di sisi browser), integrasi photobooth (mcfbooth, lewat `POST /api/sessions` dengan kode referensi yang disisipkan di `guest_name`), lalu sertifikat digital per hewan.
