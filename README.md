# Pet Blessing 2026, form pendaftaran

Form pendaftaran untuk acara Pet Blessing 2026, Paroki St. Vincentius a Paulo, Malang.

## Isi proyek

- `index.html`, form pendaftaran publik. Satu pemilik bisa mendaftarkan beberapa hewan dalam satu submission (satu record pemilik, satu record per hewan, terhubung lewat ID pendaftaran). Setelah submit, tampil QR + kode pendek sebagai bukti pendaftaran (untuk di-screenshot), dan otomatis dikirim juga lewat WhatsApp.
- `pendaftaran-masuk.html`, halaman rekap panitia (login diperlukan), dengan export `.xlsx`.
- `checkin.html`, halaman scan check-in hari-H (kamera live, login diperlukan) untuk 4 pos: reg ulang, pos 1-3.
- `api/register.js`, satu-satunya jalur menulis data pendaftaran -- verifikasi captcha (Cloudflare Turnstile) dulu sebelum insert ke database.
- `api/login.js`, login panitia.
- `wa-bot/`, bot WhatsApp (Baileys) yang jalan terus-menerus di VPS, kirim QR bukti pendaftaran dengan delay acak.
- `vps-db/`, skema + docker-compose database (Postgres + PostgREST ringan) yang jalan di VPS.

## Status

**Live**: https://petblessings.vercel.app

Database Postgres + PostgREST ringan (bukan Supabase, lihat `vps-db/README.md` untuk alasannya) jalan di VPS dreinst.

**Keamanan yang sudah dipasang:**
- Semua penulisan data pendaftaran wajib lewat `/api/register`, yang memverifikasi captcha (Cloudflare Turnstile) dulu -- akses insert langsung ke database publik sudah dicabut total (role `web_anon` tidak lagi punya izin insert).
- Rate limit 15 request/menit per IP di level Traefik (VPS) untuk endpoint API publik.
- QR check-in divalidasi format UUID ketat sebelum dipakai untuk query apapun -- data QR mentah tidak pernah dipakai langsung ke URL/DOM.
- Halaman rekap & check-in dikunci login panitia (JWT, role `web_panitia`, akses baca terbatas).

Foto (hewan, pemilik, bukti transfer) masih hanya dipratinjau di browser, belum diunggah ke storage — tahap ini sengaja dilewati dulu, menyusul di fase sertifikat.

Nomor rekening di bagian donasi masih placeholder di `index.html` dan perlu diisi manual.

## Rencana eskalasi

Langkah berikutnya, sesuai urutan prioritas: upload foto sungguhan (dengan kompresi di sisi browser), integrasi photobooth (mcfbooth, lewat `POST /api/sessions` dengan kode referensi yang disisipkan di `guest_name`), lalu sertifikat digital per hewan.
