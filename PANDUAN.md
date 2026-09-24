# Panduan Sistem Pendaftaran Pet Blessing & Fashion Pawrade Competition 2026

Paroki St. Vincentius a Paulo, Malang

Sistem ini terdiri dari beberapa halaman web, untuk dua acara: Pet Blessing dan Fashion Pawrade Competition 2026 (costume parade), keduanya bagian dari Colorful Carnival 2026. Semuanya dibuka lewat browser biasa (Chrome, Safari, atau browser bawaan HP), tidak perlu memasang aplikasi apa pun.

| Halaman | Alamat | Dipakai oleh |
|---|---|---|
| Pilihan acara | https://petblessings.vercel.app | Pengunjung, sebelum memilih acara |
| Form pendaftaran Pet Blessing | https://petblessings.vercel.app/petblessing.html | Pet owner (umum) |
| Form pendaftaran Fashion Pawrade Competition 2026 | https://petblessings.vercel.app/pawrade.html | Peserta lomba (umum) |
| Rekap Pet Blessing | https://petblessings.vercel.app/pendaftaran-masuk.html | Admin dan superadmin |
| Rekap Fashion Pawrade Competition 2026 | https://petblessings.vercel.app/pawrade-rekap.html | Admin dan superadmin |
| Dashboard superadmin | https://petblessings.vercel.app/superadmin.html | Superadmin saja |
| Check in Pet Blessing (scanner Pos A dan Pos B) | https://petblessings.vercel.app/checkin.html | Superadmin saja |
| Monitor check in Pet Blessing (layar tambahan) | https://petblessings.vercel.app/monitor-checkin.html | Superadmin saja |
| Reg ulang Fashion Pawrade Competition 2026 | https://petblessings.vercel.app/pawrade-checkin.html | Superadmin saja |
| Database QR | https://petblessings.vercel.app/qr-database.html | Superadmin saja |

Prinsip dasarnya: satu pendaftaran untuk satu pemilik, berapa pun jumlah hewannya. Pemilik mendapat satu QR yang mewakili dirinya dan semua hewannya. Di hari acara, QR itu di-scan saat check-in.

Panduan di bawah ini ditulis untuk Pet Blessing, tapi berlaku sama persis untuk Fashion Pawrade Competition 2026. Form, rekap, dan cara kerjanya identik, cuma alamatnya berbeda dan datanya terpisah. Bedanya cuma dua: form Fashion Pawrade Competition 2026 punya blok info "Kriteria Penilaian" di atas form, dan Fashion Pawrade Competition 2026 hanya punya satu titik scan, yaitu **Reg ulang** (tidak ada Pos 1 sampai 3 seperti Pet Blessing).

Semua halaman panitia memakai bilah navigasi yang sama di bagian atas: deretan tombol (bukan tautan teks) yang berisi chip level akun, tombol **Keluar** di kanan, dan tombol ke tiap halaman. Tombol halaman yang sedang dibuka berwarna ungu tua. Admin hanya melihat tombol Rekap Pet Blessing dan Rekap Fashion Pawrade Competition 2026; superadmin melihat semuanya: Dashboard, kedua rekap, Check-in Pet Blessing, Reg ulang Fashion Pawrade Competition 2026, dan Database QR. Karena sesi login dibagi antar halaman di browser yang sama, pindah halaman lewat tombol ini tidak perlu login lagi.

---

## Bagian 1. Panduan untuk pet owner

### Yang perlu disiapkan

- Nomor HP yang aktif WhatsApp. QR bukti pendaftaran akan dikirim ke nomor ini.
- Nama dan jenis tiap hewan yang ikut.
- Foto hewan (opsional).
- Bukti transfer donasi (opsional).

### Langkah mendaftar

1. Buka https://petblessings.vercel.app di HP atau laptop.
2. Isi bagian **Data pemilik**: nama, nomor HP (WhatsApp), dan jawab apakah Anda umat Paroki St. Vincentius a Paulo Malang. Kalau bukan, isi asal paroki, gereja, atau daerah. Jawab juga apakah Anda membawa pendamping (pet handler, keluarga, atau teman). Kalau ya, isi jumlah orangnya, supaya panitia bisa memperkirakan jumlah yang hadir.
3. Isi bagian **Data hewan peliharaan** untuk hewan pertama: nama hewan, jenis hewan (Anjing, Kucing, Burung, Kelinci, Hamster, Reptil, atau Lainnya), foto (opsional), dan catatan kalau ada. Kalau memilih Lainnya, sebutkan jenisnya.
4. Kalau membawa lebih dari satu hewan, tekan **+ Tambah hewan** dan isi kartu berikutnya. Tombol **Hapus** membuang kartu hewan yang tidak jadi didaftarkan.
5. Bagian **Donasi** boleh dikosongkan. Kalau berdonasi, transfer ke rekening BCA 8161072001 a.n. Nicke Purnama Kartawiharja Kusumah (nomornya juga tertera di form), lalu isi jumlahnya dan lampirkan bukti transfer.
6. Centang pernyataan di bagian **Syarat & ketentuan**. Verifikasi anti-bot (captcha) berjalan otomatis, biasanya tanpa perlu apa-apa.
7. Tekan **Kirim pendaftaran**.

### Setelah berhasil

Layar berganti ke **Pendaftaran diterima**, berisi ringkasan data, gambar QR, dan kode pendek 8 karakter. Screenshot halaman ini, termasuk QR-nya. Ini bukti pendaftaran yang ditunjukkan ke panitia saat reg ulang di lokasi acara.

Beberapa menit kemudian QR yang sama dikirim ke WhatsApp Anda dari nomor khusus panitia, lengkap dengan kode pendek, nomor urut pendaftaran, dan kontak panitia. Nomor urut ini nanti dicocokkan dengan stiker nomor saat reg ulang.


Kalau mau mendaftarkan pemilik lain dari HP yang sama, tekan **Daftarkan pemilik lain**. Form kosong lagi dan pendaftaran sebelumnya tetap tersimpan.

### Hal yang sering ditanyakan

- Field yang wajib diisi: nama pemilik, nomor HP, asal paroki (bagi yang bukan umat), jawaban soal pendamping (dan jumlahnya kalau ya), nama dan jenis tiap hewan, serta centang syarat dan ketentuan. Kalau ada yang terlewat, pesan merah muncul di dekat kolom yang bermasalah.
- Pesan WhatsApp belum masuk? Screenshot halaman konfirmasi sudah cukup sebagai bukti. Panitia juga bisa mencari nama atau kode Anda di sistem.
- Punya tiga hewan, apakah perlu tiga QR? Tidak. Satu QR untuk satu pemilik, semua hewan sudah tercatat di baliknya.
- Foto hewan dan bukti transfer yang dilampirkan ikut tersimpan dalam ukuran yang sudah dikecilkan, jadi panitia bisa mengeceknya langsung.

---

## Bagian 2. Panduan panitia: rekap pendaftaran

Halaman: https://petblessings.vercel.app/pendaftaran-masuk.html

### Dua akun panitia

Ada dua akun, keduanya diberikan oleh koordinator dan jangan disebar di grup terbuka:

- **admin**: membuka rekap, mengubah data pendaftar, melihat bukti transfer, melihat dan mengunduh foto hewan, export xlsx. Tidak bisa membuka dashboard maupun halaman check-in.
- **superadmin**: semua yang bisa dilakukan admin, ditambah dashboard superadmin (ringkasan angka dan Log login untuk menyetujui atau menolak login admin) serta halaman check-in.

Isi username dan password lalu tekan **Masuk** atau tombol Enter. Sesi login berlaku 12 jam, setelah itu halaman kembali ke layar login. Tombol **Keluar** di kanan atas mengakhiri sesi.

### Login admin perlu persetujuan superadmin

Setiap kali seseorang masuk sebagai admin, halaman menampilkan "Menunggu verifikasi superadmin" beserta nama perangkat dan alamat IP-nya. Data belum bisa dibuka sampai superadmin menyetujuinya. Halaman itu mengecek sendiri tiap beberapa detik dan lanjut otomatis begitu disetujui. Kalau ditolak atau dicabut, halaman kembali ke layar login dengan pesan "Akses ditolak atau dicabut oleh superadmin."

Superadmin melihat permintaan ini di panel **Log login** di dashboard superadmin (lihat Bagian 3). Tiap baris berisi level akun, nama perangkat (misalnya "iPhone, Safari" atau "Android SM-S911B, Chrome"), waktu, alamat IP, dan status. Tombol **Setujui** membuka akses, **Tolak** menolaknya, dan **Cabut** menutup akses yang sudah berjalan. Panel ini memuat ulang sendiri tiap 15 detik. Tidak ada notifikasi ke HP, jadi superadmin perlu membuka dashboard untuk melihat permintaan yang menunggu.

### Yang ditampilkan

Di bawah judul ada angka ringkasan, misalnya "42 pemilik, 61 hewan, 30 pendamping". Daftar pendaftar diurutkan dari yang paling baru. Tiap kartu berisi:

- Nama pemilik dan waktu daftar.
- Kode pendaftaran 8 karakter (sama dengan yang diterima pemilik).
- Nomor HP.
- Asal paroki atau daerah, kalau bukan umat paroki.
- Jumlah pendamping yang ikut, kalau ada.
- Daftar hewan: nama, jenis, catatan, dan tombol **Foto** kalau pemilik melampirkan foto hewan itu.
- Donasi: jumlah dan penanda ada tidaknya bukti transfer.
- Tombol **Ubah data**, dan tombol **Lihat bukti transfer** kalau pendaftar melampirkannya.

### Mencari data

Ketik di kotak **Cari nama, hewan, atau kode QR**. Daftar tersaring otomatis sambil mengetik. Bisa dicari berdasarkan nama pemilik, nama hewan, atau kode 8 karakter. Ini cara paling cepat mengecek seseorang yang mengaku sudah daftar tapi tidak bisa menunjukkan QR.

### Memuat ulang

Data tidak diperbarui otomatis. Tekan **Muat ulang** untuk mengambil pendaftaran terbaru dari database.

### Mengubah data pendaftar

Tekan **Ubah data** di kartu pendaftar. Kartu berubah menjadi form berisi nama pemilik, nomor HP, status umat, asal paroki, jumlah pendamping, donasi, dan untuk tiap hewan: nama, jenis, catatan. Perbaiki yang salah lalu tekan **Simpan**; tekan **Batal** untuk membatalkan. Nama pemilik, nomor HP, serta nama dan jenis tiap hewan tidak boleh kosong. Setelah tersimpan, daftar dimuat ulang dan muncul pesan "Perubahan untuk ... tersimpan." Menambah atau menghapus hewan belum bisa lewat halaman ini.

### Melihat bukti transfer

Tekan **Lihat bukti transfer** di kartu pendaftar. Gambar yang diunggah pendaftar (sudah dikecilkan, maksimal 1280 piksel) tampil di jendela kecil; tekan **Tutup** atau area gelap untuk menutupnya. Pendaftar yang mendaftar sebelum fitur ini ada bisa saja ditandai "ada bukti transfer" tanpa gambar tersimpan; jendela akan menjelaskannya.

### Melihat dan mengunduh foto hewan

Tekan tombol **Foto** di baris hewan. Fotonya (sudah dikecilkan, maksimal 1024 piksel) tampil di jendela kecil bersama tombol **Unduh foto**, yang menyimpan file JPEG dengan nama seperti `foto-shiro-budi.jpg` ke perangkat panitia. Bukti transfer hanya bisa dilihat, tidak ada tombol unduh.

### Export ke Excel

Tekan **Export xlsx**. Browser mengunduh file bernama `pet-blessing-2026-pendaftaran-<tanggal>.xlsx`. Isinya satu baris per hewan, dengan kolom:

Nama pemilik, No. HP, Status umat, Asal paroki/daerah, Pendamping, Nama hewan, Jenis hewan, Ada foto, Catatan hewan, Donasi, Ada bukti transfer, Waktu daftar.

Export selalu mengambil seluruh data, bukan hanya hasil pencarian yang sedang tampil.

### Catatan

- Foto hewan dan bukti transfer tersimpan dan bisa dilihat lewat tombol di kartu. Pendaftar yang masuk sebelum fitur ini ada bisa saja ditandai "ada foto" tanpa gambar tersimpan.
- Halaman rekap tidak menampilkan status check-in. Jumlah yang sudah hadir dilihat di dashboard superadmin atau di halaman check-in, per pos.
- Pesan "Sesi habis, silakan login lagi" berarti 12 jam sudah lewat. Login ulang saja.
- Pesan "Belum bisa memuat data" biasanya soal koneksi internet. Cek koneksi lalu tekan Muat ulang.
- Tombol **Dashboard**, **Check-in Pet Blessing**, **Reg ulang Fashion Pawrade Competition 2026**, dan **Database QR** di bilah navigasi atas hanya tampil untuk superadmin. Admin tidak melihat tombol itu dan memang tidak bisa membuka halaman tersebut.

---

## Bagian 3. Dashboard superadmin

Halaman: https://petblessings.vercel.app/superadmin.html

Hanya akun superadmin yang bisa masuk; akun admin ditolak dengan pesan yang jelas. Isinya:

- Bilah navigasi tombol di bagian atas menuju semua halaman panitia. Karena sesi login dibagi antar halaman di browser yang sama, tidak perlu login lagi di sana.
- Ringkasan pendaftaran Pet Blessing dan Fashion Pawrade Competition 2026: jumlah pemilik, hewan, pendamping, dan total donasi atau biaya yang masuk.
- Ringkasan check in hari-H: jumlah pemilik Pet Blessing yang sudah dan belum check in, dipecah per Pos A (nomor ganjil) dan Pos B (nomor genap), serta jumlah peserta Fashion Pawrade Competition 2026 yang sudah reg ulang. Ini cara termudah memantau antrean dari mana saja saat acara.
- Panel **Log login** dengan tombol Setujui, Tolak, dan Cabut untuk login admin, seperti dijelaskan di Bagian 2.

Semua angka dan log memuat ulang sendiri tiap 15 detik; tombol **Muat ulang** memaksa pembaruan segera.

---

## Bagian 4. Panduan panitia: check-in hari-H

Halaman: https://petblessings.vercel.app/checkin.html

### Persiapan perangkat

- HP, tablet, atau laptop yang punya kamera dan koneksi internet. Di HP dipakai kamera belakang, di laptop dipakai webcam.
- Satu perangkat untuk satu pos. Check in Pet Blessing berlangsung di satu titik dengan dua pos: **Pos A** melayani nomor urut ganjil, **Pos B** melayani nomor urut genap.
- Saat pertama membuka halaman, browser meminta izin kamera. Pilih **Izinkan**.
- Login hanya bisa dengan akun superadmin. Akun admin ditolak di halaman ini.

### Memilih pos

Tekan **Pos A** (nomor ganjil, hijau) atau **Pos B** (nomor genap, oranye) di bagian atas. Pilihan ini tersimpan di perangkat tersebut, jadi cukup dipilih sekali di awal acara. Pos hanya menentukan nomor mana yang seharusnya dilayani perangkat itu, pembagiannya tetap ganjil dan genap.

Di bawah tombol pos tampil angka "X dari Y nomor sudah check in" untuk pos ini, dan angka pos satunya. Angka ini naik setiap ada scan yang berhasil.

Kalau perangkat di Pos A memindai nomor genap (atau sebaliknya), check in **tetap tercatat**, tapi layar menampilkan kotak kuning "Nomor genap seharusnya di Pos B" dan bunyinya berbeda. Arahkan pemilik ke pos yang benar. Pos yang benar juga tampil sebagai label hijau (Pos A) atau oranye (Pos B) di lembar hasil dan di tiap baris hasil pencarian manual.

### Alur scan

1. Minta pemilik menunjukkan QR-nya (dari screenshot, dari pesan WhatsApp, atau dari halaman bukti pendaftaran).
2. Arahkan kamera ke QR sampai masuk kotak putih di layar. Tidak ada tombol yang perlu ditekan, pembacaan berjalan otomatis. 
3. Begitu terbaca, sistem memeriksa data dan mencatat check-in. Hasilnya muncul sebagai lembar di bagian bawah layar, disertai bunyi dan getar:
   - Hijau, tanda centang, "Check in berhasil". Tampil pos yang seharusnya melayani nomor itu, nomor urut (#), nama pemilik, nomor HP, jumlah pendamping kalau ada, dan daftar hewannya. Bunyi beep tinggi pendek.
   - Kuning, tanda seru, "Sudah check in". Pemilik ini sudah pernah di-scan sebelumnya. Tidak dicatat dua kali. Bunyi beep sedang.
   - Merah, tanda silang, "Tidak valid". QR bukan dari sistem ini, data tidak ditemukan, atau gagal tersimpan. Bunyi beep rendah.
4. Tekan **Lanjut scan berikutnya** untuk menutup lembar hasil. Selama lembar hasil masih terbuka, kamera berhenti membaca, jadi tidak akan terjadi scan ganda.

### Check-in tanpa QR (pencarian manual)

Di bawah kotak kamera ada bagian **Tanpa QR? Cari manual**. Dipakai kalau QR pemilik rusak atau tidak terbaca, atau pemilik tidak menerima pesan WhatsApp dan tidak sempat screenshot.

1. Ketik kode 8 karakter, nama pemilik, atau nomor HP. Boleh sebagian, minimal 2 karakter. Tekan **Cari**.
2. Hasil tampil sebagai daftar: nomor urut, nama, nomor HP, dan nama hewannya. Paling banyak 10 hasil, jadi kalau namanya umum, tambahkan kata lagi supaya lebih spesifik.
3. Pastikan orangnya cocok, misalnya dengan menanyakan nomor HP atau nama hewan, lalu tekan barisnya. Check-in tercatat lewat jalur yang sama dengan scan, dan lembar hasil hijau, kuning, atau merah muncul seperti biasa.
4. Kalau tidak ada hasil, kemungkinan pemilik belum mendaftar. Arahkan ke meja pendaftaran untuk mengisi form lewat HP-nya.

### Yang perlu diperhatikan

- Cocokkan nomor urut (#) yang tampil di layar dengan stiker nomor yang diberikan ke pemilik.
- Pemilik dengan beberapa hewan cukup di-scan satu kali di tiap pos. Semua hewannya ikut tampil di lembar hasil.
- QR sulit terbaca: minta pemilik memperbesar screenshot atau menaikkan kecerahan layar HP-nya, lalu dekatkan ke kamera.
- QR tidak ada sama sekali, atau tetap tidak terbaca setelah dicoba: pakai pencarian manual di bawah kotak kamera (lihat bagian di atas).
- Kamera tidak muncul: cek izin kamera di pengaturan browser, lalu muat ulang halaman. Pesan "Library pembaca QR gagal dimuat" berarti koneksi internet terputus saat halaman dibuka. Sambungkan lagi lalu muat ulang.
- Halaman tiba-tiba kembali ke layar login: sesi 12 jam habis. Login lagi sebagai superadmin, pilihan pos tetap tersimpan.
- Tombol **Dashboard** di bilah navigasi atas kembali ke dashboard superadmin tanpa login ulang.

### Layar monitor tambahan

Untuk ditampilkan di layar kedua atau monitor besar: tekan tombol **Buka layar monitor** di halaman check in (atau buka https://petblessings.vercel.app/monitor-checkin.html langsung, login superadmin). Layar dibagi dua: **kiri Pos A (nomor ganjil), kanan Pos B (nomor genap)**. Tiap sisi menampilkan nomor urut terbaru dalam ukuran besar, nama pemilik, nama dan jenis hewan, jumlah pendamping, daftar beberapa check in sebelumnya, dan progres "X dari Y nomor sudah check in". Nomor HP tidak ditampilkan.

- Tekan **Layar penuh** (atau tombol F) untuk memenuhi monitor. Seret jendelanya ke monitor tambahan dulu sebelum layar penuh.
- Layar memuat ulang sendiri sekitar tiap 3 detik. Kalau scanner dibuka di browser yang sama dengan monitor, layar langsung berubah begitu ada scan. Lampu hijau di pojok kanan atas menandakan tersambung.
- Layar ini tidak memerlukan panitia menyentuhnya selama acara.

### Urutan hari-H

Pemilik datang ke titik check in, panitia memindai QR-nya (Pos A untuk nomor ganjil, Pos B untuk genap), lalu mencocokkan stiker nomor. Nomor yang baru dipindai langsung muncul di layar monitor.

---

Sistem dibuat oleh dreinst dan dikelola oleh D'Production Event Organizer. Kendala teknis di luar panduan ini disampaikan ke koordinator panitia.
