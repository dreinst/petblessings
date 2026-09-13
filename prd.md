# PRD: Sistem Pendaftaran Pet Blessing 2026

## 1. Latar Belakang

Pet Blessing 2026 adalah acara pemberkatan hewan peliharaan di Paroki St. Vincentius a Paulo, Malang. Tahun lalu pendaftaran memakai Google Form, tapi ada beberapa masalah: nama hewan dan jenisnya digabung dalam satu kotak teks bebas sehingga sulit dipilah saat data sudah terkumpul, dan tidak ada cara rapi menangani satu pemilik dengan banyak hewan sekaligus.

Untuk 2026, target pendaftar diperkirakan 500 pemilik (belum termasuk jumlah hewan, yang bisa 700 sampai 1000 lebih ekor). Di skala ini muncul kebutuhan baru: QR code otomatis sebagai bukti pendaftaran, integrasi dengan sistem photobooth yang sudah berjalan (mcfbooth), sertifikat digital per hewan, dan tiga pos checklist saat hari-H. Google Form tidak sanggup menangani kebutuhan ini karena tidak punya fitur mengulang blok pertanyaan secara dinamis per hewan.

## 2. Tujuan

- Data pendaftaran tersimpan terstruktur per hewan, bukan teks bebas gabungan
- Satu pemilik dengan banyak hewan tetap cukup satu kali mengisi form, satu kali submit
- Proses check-in dan pos saat hari-H cepat, tidak menimbulkan antrean panjang
- Sistem dibangun bertahap: form pendaftaran dulu sebagai fondasi, baru menyusul QR, integrasi photobooth, dan sertifikat digital
- Form semudah mengisi Google Form, tapi mampu menangani data dinamis per hewan dan berjalan baik di HP

## 3. Target Pengguna

| Peran | Deskripsi |
|---|---|
| Pet owner | Umat atau tamu yang mendaftarkan dirinya dan hewan peliharaannya, mengisi form dari HP sendiri |
| Panitia | Menjalankan reg ulang dan pos-pos saat hari-H, memeriksa data pendaftaran yang masuk |
| Operator photobooth | Menjalankan mcfbooth di pos terakhir, terhubung dengan sistem pendaftaran lewat QR pemilik |

## 4. User Stories

- Sebagai pet owner, saya ingin mendaftarkan beberapa hewan sekaligus dalam satu form, supaya tidak perlu mengisi form berkali-kali untuk tiap ekor.
- Sebagai pet owner, saya ingin diingatkan mengecek ulang data sebelum submit, terutama nama hewan, supaya tidak salah tulis di sertifikat nanti.
- Sebagai pet owner, saya ingin mencatat kalau hewan saya punya disabilitas atau kondisi khusus, supaya panitia bisa memperhatikan saat pemberkatan.
- Sebagai panitia, saya ingin satu QR mewakili satu keluarga dengan semua hewannya, supaya scan di tiap pos cepat dan tidak antre.
- Sebagai panitia, saya ingin tiap hewan tetap punya data dan sertifikat sendiri meskipun satu pemilik, supaya identitas tiap hewan jelas di catatan maupun sertifikat.
- Sebagai panitia, saya ingin melihat semua pendaftaran yang masuk di halaman terpisah dari form publik, supaya form tetap sederhana untuk pendaftar.

## 5. Ruang Lingkup

### Termasuk (tahap sekarang)

- Form pendaftaran custom, bukan Google Form, mobile-first
- Satu submission mencakup satu data pemilik dan banyak data hewan (kartu dinamis, tombol tambah hewan)
- Field tiap hewan: nama, jenis, foto (opsional), catatan (termasuk prompt disabilitas)
- Field donasi opsional dengan bukti transfer
- Notif cross-check data dan persetujuan syarat & ketentuan
- Halaman terpisah untuk memeriksa pendaftaran yang masuk

### Tidak termasuk (tahap sekarang, rencana lanjutan)

- QR code per pendaftaran
- Sistem check-in dan scan di 4 titik (reg ulang dan 3 pos)
- Integrasi photobooth (mcfbooth)
- Sertifikat digital per hewan
- Database produksi (Supabase), saat ini masih penyimpanan sementara di sisi klien
- Upload foto sungguhan ke penyimpanan berkas (saat ini hanya pratinjau di browser)

## 6. Requirement Fungsional

| ID | Requirement |
|---|---|
| FR1 | Pet owner dapat mengisi data diri (nama, no. HP, status umat paroki, jumlah pendamping yang ikut) dalam satu form |
| FR2 | Jika bukan umat Paroki St. Vincentius, form menampilkan field asal paroki/daerah |
| FR3 | Pet owner dapat menambah kartu hewan sebanyak yang dibutuhkan lewat tombol "Tambah hewan" |
| FR4 | Tiap kartu hewan berisi nama, jenis (pilihan atau isi manual lewat opsi Lainnya), foto opsional, dan catatan |
| FR5 | Pet owner dapat menghapus kartu hewan selama masih tersisa minimal satu |
| FR6 | Form memvalidasi field wajib sebelum submit dan menunjukkan kesalahan di dekat field yang bermasalah |
| FR7 | Form menampilkan notif pengingat cross-check data, terutama nama hewan, sebelum submit |
| FR8 | Satu submit menyimpan satu record pemilik dan N record hewan yang berelasi lewat ID pendaftaran yang sama |
| FR9 | Setelah submit berhasil, form menampilkan ringkasan pendaftaran sebagai konfirmasi |
| FR10 | Panitia dapat membuka halaman terpisah untuk melihat daftar pendaftaran yang masuk, lengkap dengan hewan tiap pemilik |
| FR11 | Halaman pendaftaran masuk mendukung pencarian berdasarkan nama pemilik atau nama hewan |

## 7. Requirement Non-Fungsional

| ID | Requirement |
|---|---|
| NFR1 | Form berjalan baik di layar HP sebagai target utama, bukan cuma desktop |
| NFR2 | Input di form berukuran cukup besar untuk disentuh dan tidak memicu auto-zoom di browser HP |
| NFR3 | Lapisan penyimpanan data terisolasi dalam satu fungsi, supaya gampang diganti ke backend produksi tanpa mengubah bagian form lain |
| NFR4 | Form tidak memerlukan akun atau login untuk pet owner |
| NFR5 | Kode sumber siap dipindahkan ke repositori git dan dilanjutkan lewat asisten pengkodean untuk tahap integrasi backend dan deployment |

## 8. Alur Pengguna

1. Pet owner membuka link form dari HP, kemungkinan besar dibagikan lewat WhatsApp
2. Mengisi data pemilik, memilih status umat paroki
3. Menambah satu kartu per hewan, mengisi nama, jenis, foto opsional, dan catatan tiap ekor
4. Mengisi donasi opsional
5. Mencentang persetujuan syarat & ketentuan setelah membaca notif cross-check
6. Submit, sistem menyimpan satu record pemilik dan seluruh record hewan yang terhubung
7. Pet owner melihat ringkasan sebagai konfirmasi pendaftaran diterima

## 9. Requirement UI

- Warna dan tipografi mencerminkan suasana acara komunitas paroki, bukan tampilan generik formulir korporat
- Kartu hewan diberi nomor urut (Hewan 1, Hewan 2, dan seterusnya) karena memang berupa daftar yang bertambah
- Field kondisional (asal paroki) hanya muncul saat relevan, dengan transisi halus
- Notif cross-check data ditampilkan berdekatan dengan tombol submit

## 10. Asumsi & Ketergantungan

- Sebagian besar pet owner mengisi form dari HP mereka sendiri, bukan dibantu panitia
- Panitia menyediakan nomor rekening untuk field donasi, saat ini masih placeholder di kode
- mcfbooth sudah berjalan dan siap diintegrasikan pada tahap berikutnya
- Perpindahan ke backend produksi (Supabase) dan deployment (Vercel) dilakukan lewat asisten pengkodean karena butuh kredensial yang hanya ada di perangkat Donny

## 11. Keputusan yang sudah diambil

- Custom web app dipilih dibanding Google Form, karena kebutuhan kartu hewan dinamis dan scan QR kamera di beberapa titik tidak bisa dilayani Google Form sama sekali, bukan cuma soal preferensi
- Satu QR mewakili satu pemilik dengan semua hewannya, bukan satu QR per hewan, supaya scan di tiap pos tidak berkali-kali untuk satu keluarga
- Data tiap hewan tetap tersimpan terpisah di balik satu QR itu, sebagai dasar sertifikat per hewan
- Field per hewan disederhanakan jadi nama, jenis, foto, dan catatan saja, tanpa langkah terpisah pilih jenis dan jumlah di depan
- Tiap hewan mendapat sertifikat sendiri meskipun satu pemilik, memakai template yang sama dengan data dan foto berbeda
- Backend produksi direncanakan pakai Supabase, di proyek terpisah dari sistem 14-agent EO/WO yang sudah berjalan, supaya tidak saling mengganggu
- Halaman pendaftaran masuk dipisah dari form publik

## 12. Pertanyaan terbuka

- Apakah foto gabungan pemilik dan hewan tetap dimasukkan sebagai field opsional, atau dilewatkan. Saat ini dibuat opsional sebagai asumsi kerja
- Apakah satu titik photobooth cukup untuk volume 700 sampai 1000 lebih ekor hewan dalam durasi acara, atau perlu dua titik
- Apakah sertifikat memakai template desain yang sama untuk semua jenis hewan, atau ada variasi desain per jenis
- Nomor rekening resmi untuk field donasi

## 13. Referensi

Detail arsitektur, skema data, dan rencana integrasi mcfbooth ada di `architecture.md`.
