# Panduan untuk asisten AI (debugging Pet Blessing)

Baca ini dulu sebelum mengubah apa pun. Bahasa kerja tim: Indonesia.
Photobooth dan sertifikat ada di repo lain (`dreinst/mcfbooth`, lihat AGENTS.md di sana).

## Bagian sistem

| Bagian | Jalan di | Berkas |
|---|---|---|
| Website pendaftaran dan halaman panitia | Vercel (`petblessings.vercel.app`), auto-deploy dari `main` | `*.html`, `hari-h.js`, `hari-h.css`, `api-config.js`, `api/*.js` |
| Database + API (PostgREST) | VPS, `https://petblessing-api.187.53.129.205.sslip.io` | migrasi `vps-db/init/NN-*.sql` (urut nomor) |
| Server lokal hari-H (cadangan saat internet venue putus) | Mac panitia, `https://<ip-mac>:8443` dan `http://<ip-mac>:8080/rest` | `lokal/server.js`, `lokal/siapkan.sh`, `lokal/docker-compose.yml` |
| Bot WhatsApp (QR pendaftaran, pengingat) | VPS, container `petblessing-wa-bot` | `wa-bot/index.js` |

## Peta gejala ke berkas

| Gejala | Lihat dulu | Berkas |
|---|---|---|
| Form daftar gagal simpan | konsol browser, respons API | `petblessing.html`, `api/register.js`, trigger di `vps-db/init/` (migrasi 22, 24, 25) |
| Reg ulang: nomor urut tidak keluar / "server ini tidak memberi nomor" | halaman kendali: siapa pemberi nomor | `checkin.html`, `kendali.html`, fungsi `api.reg_ulang` (migrasi 26: Pos A ganjil, Pos B genap) |
| Peringatan salah pos | pos ditentukan nomor pendaftaran (nomor di QR) | `checkin.html` (`posSeharusnya`) |
| Monitor / layar panggil tidak update | fungsi `api.hari_h_status`, `api.panggil` | `monitor-checkin.html`, `layar-panggil.html`, `panggil.html`, migrasi 22 |
| Data lokal dan VPS tidak sama | log `node lokal/server.js`, status di halaman kendali | `lokal/server.js` (penyelaras, `PET_HARI_H`) |
| Halaman hasil (QR poster) tidak menemukan peserta | peserta harus sudah reg ulang; fungsi `api.cari_hasil` | `hasil.html`, migrasi 27 |
| Link foto/sertifikat kosong di hasil.html | booth belum menulis `pets.photo_folder_url` / `certificate_url` | repo mcfbooth (`app/sertifikat.py`, `app/watcher.py`) |
| Dashboard superadmin angka aneh | | `superadmin.html` (`loadStats`) |
| Goodie bag: peserta tidak muncul di layar petugas, atau statusnya beda antar server | penyerahan dicatat sebagai baris `checkins` dengan `post = 'pos1'` (satu per pemilik), dan hanya ada di server tempat dicatat (penyelaras tidak membawanya) | `goodie.html`, `checkin.html` (`POS_GOODIE`) |
| Undian: pemenang hilang atau beda antar perangkat | pemenang disimpan di browser perangkat yang memutar (localStorage), tidak di database | `undian.html` |
| Bot WA tidak membalas / logged out | `docker logs petblessing-wa-bot` di VPS | `wa-bot/index.js`; JANGAN tautkan ulang nomor tanpa izin |

## Menguji

- Server lokal + VPS tiruan (tidak menyentuh produksi): `bash lokal/uji/siapkan-vps-tiruan.sh`,
  `bash lokal/siapkan.sh`, `node lokal/server.js`, lalu `node lokal/uji/uji-hari-h.js` (36 cek).
  Syarat: `lokal/.env` berisi `VPS_API_URL=http://127.0.0.1:3102`.
  `uji-hari-h.js` mengosongkan data hari-H di kedua database. Jangan dijalankan saat `lokal/.env`
  menunjuk VPS asli atau terowongannya (misalnya `127.0.0.1:3103`); skrip menolak alamat selain port 3102.
- Halaman bisa dibuka lewat server lokal di `http://127.0.0.1:8080/<halaman>.html`.

## Jangan dilakukan tanpa izin panitia

- Menjalankan SQL di database VPS produksi (selalu backup dulu, uji di server lokal).
- `git push` ke `main` (langsung live di Vercel).
- Mengirim pesan WhatsApp massal atau mengubah antrean bot.
- Mengubah aturan nomor: nomor pendaftaran (di QR) menentukan pos, nomor urut (stiker) menentukan panggilan dan nama berkas.
