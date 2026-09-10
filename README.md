# Pet Blessing 2026, form pendaftaran

Form pendaftaran untuk acara Pet Blessing 2026, Paroki St. Vincentius a Paulo, Malang.

## Isi proyek

- `index.html`, form pendaftaran publik. Satu pemilik bisa mendaftarkan beberapa hewan dalam satu submission (satu record pemilik, satu record per hewan, terhubung lewat ID pendaftaran).
- `pendaftaran-masuk.html`, halaman untuk melihat data yang sudah masuk, terpisah dari form publik.

## Status

Terhubung ke Supabase (proyek terpisah dari sistem 14-agent EO/WO yang sudah berjalan). `saveRegistration()` di `index.html` menulis ke tabel `owners` dan `pets` (skema di `supabase/schema.sql`). Halaman `pendaftaran-masuk.html` dikunci login Supabase Auth (khusus panitia) dan bisa export rekap ke `.xlsx`.

Foto (hewan, pemilik, bukti transfer) masih hanya dipratinjau di browser, belum diunggah ke storage — tahap ini sengaja dilewati dulu, menyusul di fase QR/sertifikat.

Nomor rekening di bagian donasi masih placeholder di `index.html` dan perlu diisi manual.

Sebelum form ini bisa dipakai, isi `supabase-config.js` dengan Project URL dan anon key dari project Supabase, jalankan `supabase/schema.sql` di SQL editor, dan buat minimal satu akun panitia lewat Supabase Auth untuk login ke halaman rekap.

## Rencana eskalasi

Langkah berikutnya, sesuai urutan prioritas: upload foto sungguhan ke Supabase Storage, QR per pendaftaran, integrasi photobooth (mcfbooth, lewat `POST /api/sessions` dengan kode referensi yang disisipkan di `guest_name`), lalu sertifikat digital per hewan.
