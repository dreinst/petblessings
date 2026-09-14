# Bot WhatsApp Pet Blessing 2026

Kirim QR bukti pendaftaran otomatis lewat WhatsApp, dipasang di VPS dreinst (`/root/petblessing-wa-bot`), terpisah dari nomor Hermes.

- Baileys (bukan WhatsApp Cloud API resmi) -- scan QR sekali dari nomor khusus, session persisten di volume `./data`.
- Ambil pesan dari tabel `api.wa_queue` (diisi client lewat PostgREST saat submit form), kirim sebagai **dokumen** (bukan foto) supaya tidak dikompres ulang WhatsApp -- QR tetap tajam.
- Delay acak 2-5 menit antar kirim (jeda 10-20 menit tiap 10 pesan), 5+ variasi template caption dipilih acak, kadang kirim teks dulu baru dokumen terpisah -- semua supaya pola pengiriman tidak seragam/terdeteksi otomasi. Konsekuensinya: kalau ada lonjakan pendaftar (misal 10+ sekaligus), antriannya baru habis terkirim semua beberapa jam kemudian -- ini trade-off yang disengaja demi keamanan nomor.
- Nomor urut pendaftaran (`owners.queue_number`, auto-increment) disisipkan ke caption, diambil langsung oleh bot dari database (bukan dari payload client) lewat role `wa_worker` (akses baca terbatas, cuma `owners`, `wa_queue`, `wa_followup_queue`).
- Setiap caption blast (QR maupun susulan) menyertakan kontak panitia (Lala, Livvy) dengan tautan `wa.me`, supaya pendaftar yang butuh bantuan tidak membalas ke nomor bot ini.
- `api.wa_followup_queue` (migrasi `vps-db/init/09-wa-followup-queue.sql`) dipakai sekali untuk mengirim ulang **info kontak saja** (tanpa QR) ke pendaftar yang sudah menerima blast QR sebelum info kontak ditambahkan. Worker memproses `wa_queue` dulu, baru `wa_followup_queue` kalau `wa_queue` kosong, jadi tetap satu jalur pengiriman dengan delay anti-spam yang sama.

**Kredensial tidak ada di repo** (`.env` cuma di server). Auth session WhatsApp ada di `./data/auth` di server, jangan dihapus kecuali mau pairing ulang.

Redeploy: `cd /root/petblessing-wa-bot && docker compose up -d --build`
