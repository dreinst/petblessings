# Pet Blessing 2026, form pendaftaran

Form pendaftaran untuk acara Pet Blessing 2026, Paroki St. Vincentius a Paulo, Malang.

## Isi proyek

- `index.html`, form pendaftaran publik. Satu pemilik bisa mendaftarkan beberapa hewan dalam satu submission (satu record pemilik, satu record per hewan, terhubung lewat ID pendaftaran).
- `pendaftaran-masuk.html`, halaman untuk melihat data yang sudah masuk, terpisah dari form publik.

## Status

Prototipe. Data disimpan lewat penyimpanan sementara di sisi klien, bukan database produksi. Foto (hewan, pemilik, bukti transfer) hanya dipratinjau di browser dan belum diunggah ke penyimpanan berkas.

Nomor rekening di bagian donasi masih placeholder di `index.html` dan perlu diisi manual.

## Rencana eskalasi

Fungsi `saveRegistration()` di `index.html` adalah satu-satunya tempat yang bicara ke penyimpanan data. Saat pindah ke backend sungguhan (rencana: Supabase, proyek terpisah dari sistem 14-agent EO/WO yang sudah berjalan), cukup ganti isi fungsi itu dengan panggilan API. Bagian form yang lain tidak perlu diubah.

Langkah berikutnya, sesuai urutan prioritas: QR per pendaftaran, integrasi photobooth (mcfbooth, lewat `POST /api/sessions` dengan kode referensi yang disisipkan di `guest_name`), lalu sertifikat digital per hewan.
