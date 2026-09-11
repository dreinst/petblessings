# Pet Blessing 2026, form pendaftaran

Form pendaftaran untuk acara Pet Blessing 2026, Paroki St. Vincentius a Paulo, Malang.

## Isi proyek

- `index.html`, form pendaftaran publik. Satu pemilik bisa mendaftarkan beberapa hewan dalam satu submission (satu record pemilik, satu record per hewan, terhubung lewat ID pendaftaran).
- `pendaftaran-masuk.html`, halaman untuk melihat data yang sudah masuk, terpisah dari form publik.

## Status

**Live**: https://petblessings.vercel.app -- form publik di `/index.html`, rekap panitia (login diperlukan) di `/pendaftaran-masuk.html`.

Database Postgres + PostgREST ringan (bukan Supabase, lihat `vps-db/README.md` untuk alasannya) jalan di VPS dreinst, `saveRegistration()` di `index.html` insert langsung lewat fetch. Halaman rekap dikunci login (`/api/login`, Vercel serverless function) dan bisa export rekap ke `.xlsx`.

Foto (hewan, pemilik, bukti transfer) masih hanya dipratinjau di browser, belum diunggah ke storage — tahap ini sengaja dilewati dulu, menyusul di fase QR/sertifikat.

Nomor rekening di bagian donasi masih placeholder di `index.html` dan perlu diisi manual.

## Rencana eskalasi

Langkah berikutnya, sesuai urutan prioritas: upload foto sungguhan (dengan kompresi di sisi browser sebelum upload, supaya aman untuk beban ~500 pemilik/700-1000 hewan), QR per pendaftaran, integrasi photobooth (mcfbooth, lewat `POST /api/sessions` dengan kode referensi yang disisipkan di `guest_name`), lalu sertifikat digital per hewan.
