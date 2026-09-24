# Pet Blessing & Fashion Pawrade Competition 2026, form pendaftaran

Form pendaftaran untuk Pet Blessing dan Fashion Pawrade Competition 2026 (bagian dari Colorful Carnival 2026), Paroki St. Vincentius a Paulo, Malang. Dua acara, dua alur pendaftaran terpisah, dipilih dari satu halaman depan.

## Isi proyek

- `index.html`, halaman pilihan acara (seperti Linktree): Pet Blessing atau Fashion Pawrade Competition 2026.
- `petblessing.html`, form pendaftaran Pet Blessing. Satu pemilik bisa mendaftarkan beberapa hewan dalam satu submission (satu record pemilik, satu record per hewan, terhubung lewat ID pendaftaran). Setelah submit, tampil QR + kode pendek sebagai bukti pendaftaran (untuk di-screenshot), dan otomatis dikirim juga lewat WhatsApp.
- `pawrade.html`, form pendaftaran Fashion Pawrade Competition 2026 -- struktur dan alur sama persis dengan `petblessing.html`, ditambah blok info "Kriteria Penilaian". Data tersimpan terpisah (`api.pawrade_owners`/`api.pawrade_pets`), lewat `/api/register-pawrade`.
- `pendaftaran-masuk.html`, halaman rekap Pet Blessing untuk panitia (login `admin` atau `superadmin`): daftar pendaftar, ubah data, lihat/unggah foto hewan, lihat bukti transfer, lihat QR asli (superadmin), export `.xlsx`.
- `pawrade-rekap.html`, halaman rekap Fashion Pawrade Competition 2026 -- fungsinya sama persis dengan `pendaftaran-masuk.html`, hanya tabel datanya beda.
- `superadmin.html`, dashboard superadmin: ringkasan angka (pemilik, hewan, pendamping, donasi, check-in per pos, reg ulang Fashion Pawrade Competition 2026), log login panitia dengan tombol setujui/tolak login admin.
- `checkin.html`, halaman scan check in Pet Blessing hari-H (kamera live, khusus login `superadmin`): 1 titik dengan 2 pos, nomor urut ganjil di Pos A dan genap di Pos B (pos dihitung dari `queue_number`, kolom `checkins.post` tetap `reg_ulang`). Salah pos tetap tercatat tanpa peringatan di layar; kolom `checkins.desk` menyimpan pos tempat scan dan `checkins.wrong_desk` (dihitung trigger, `vps-db/init/16-checkin-desk.sql`) menandai salah pos, ditampilkan di dashboard untuk evaluasi.
- `monitor-checkin.html`, layar monitor tambahan check in: kiri Pos A (ganjil), kanan Pos B (genap), menampilkan nomor terbaru, nama, hewan. Datanya satu request ke fungsi database `api.checkin_monitor()` (`vps-db/init/15-checkin-monitor.sql`), tanpa nomor HP. Ada pencarian manual (kode 8 karakter, nama, atau no. HP) untuk pemilik yang QR-nya tidak terbaca atau tidak menerima WhatsApp.
- `pawrade-checkin.html`, reg ulang Fashion Pawrade Competition 2026: scan QR di satu titik saja (lomba di satu lokasi/panggung), tanpa pilihan pos. Cara kerjanya sama dengan `checkin.html`.
- `qr-database.html`, halaman superadmin untuk mengunduh semua QR pendaftar sebagai ZIP.
- `panitia-nav.js`, bilah navigasi tombol yang dipakai bersama oleh semua halaman panitia. Menampilkan tombol sesuai level akun (admin cuma rekap, superadmin semua halaman), menandai halaman aktif, dan tombol Keluar.
- `api/register.js`, satu-satunya jalur menulis data pendaftaran Pet Blessing -- verifikasi captcha (Cloudflare Turnstile) dulu sebelum insert ke database.
- `api/register-pawrade.js`, jalur yang sama untuk pendaftaran Fashion Pawrade Competition 2026, menulis ke tabel `api.pawrade_*`.
- `api/login.js`, login panitia: dua akun dari env Vercel (`PANITIA_*` = admin, `SUPERADMIN_*` = superadmin), JWT membawa role Postgres `web_admin` / `web_superadmin`.
- `wa-bot/`, bot WhatsApp (Baileys) yang jalan terus-menerus di VPS, kirim QR bukti pendaftaran dengan delay acak -- satu bot, satu nomor, memproses antrian Pet Blessing dan Fashion Pawrade Competition 2026 sekaligus (tabel beda, caption beda).
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

**Mode uji:** `owners.is_test` menandai pendaftar uji ("Testing Nomor N"), lihat `vps-db/init/17-test-owners.sql`. Alamat scanner dan monitor dengan `?uji=1` hanya memakai data uji; tanpa parameter data uji diabaikan. Hapus sebelum acara: `delete from api.owners where is_test;`.
