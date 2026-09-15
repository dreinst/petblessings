# Arsitektur Sistem Pendaftaran Pet Blessing 2026

## 1. Ringkasan

Sistem ini dibangun bertahap. Tahap sekarang adalah form pendaftaran dan halaman pendaftaran masuk, berjalan sebagai web app statis dengan penyimpanan sementara. Tahap berikutnya menyambungkan form ini ke QR code, sistem check-in di 4 titik, integrasi photobooth mcfbooth, dan sertifikat digital per hewan.

Prinsip utamanya: bangun fondasi data yang rapi dulu (satu pemilik, banyak hewan, berelasi lewat ID), supaya semua fitur lanjutan tinggal menyambung ke data itu tanpa perlu rombak ulang struktur.

## 2. Prinsip Desain

- Fondasi dulu, skala belakangan. Form dan struktur datanya dibangun untuk menahan penambahan fitur, bukan cuma menyelesaikan kebutuhan hari ini
- Satu submission, satu pemilik, banyak hewan. Bukan satu hewan satu submission terpisah
- Satu QR per pemilik untuk kecepatan antrean, data tetap granular per hewan di baliknya untuk kebutuhan sertifikat
- Lapisan penyimpanan data terisolasi di satu fungsi, supaya gampang diganti tanpa mengubah bagian lain
- Custom web app, bukan Google Form, karena Google Form tidak punya fitur mengulang blok pertanyaan dinamis per hewan dan tidak bisa dipakai untuk scan QR lewat kamera di beberapa titik

## 3. Komponen Sistem (rencana penuh)

Alur yang direncanakan, dari pendaftaran sampai sertifikat:

1. Pendaftaran online, pemilik memilih hewan dan mengisi detail tiap ekor
2. Sistem membuat satu QR per pemilik, dikirim lewat WhatsApp
3. Hari-H, QR dipindai di 4 titik: reg ulang lalu tiga pos, tiap titik mencatat kehadiran lewat laptop atau tablet berkamera
4. Di pos terakhir, QR yang sama memicu sesi di mcfbooth untuk memotret tiap hewan
5. Setelah acara, sertifikat digital dibuat otomatis per hewan, memuat foto dari mcfbooth

Bagian yang sudah dibangun dan berjalan hanyalah langkah pertama, form pendaftaran. Bagian selanjutnya dijelaskan sebagai rencana di bawah, termasuk detail teknis yang sudah diselidiki, khususnya mcfbooth.

### 3.1 Form pendaftaran (sudah dibangun)

Sejak Pawrade ditambahkan, `index.html` jadi halaman pilihan acara (Pet Blessing / Pawrade), dan form Pet Blessing sendiri pindah ke `petblessing.html`. Lomba Pawrade (costume parade, bagian dari Colorful Carnival 2026) memakai struktur data dan kode yang sama persis (form, rekap, check-in) tapi tabel terpisah (`api.pawrade_*`, lihat `vps-db/init/12-pawrade.sql`) dan check-in satu titik saja (bukan 4 pos). Bot WhatsApp yang sama memproses kedua antrian.

Web app satu halaman (`petblessing.html`), mobile-first. Terdiri atas empat bagian: data pemilik, data hewan (kartu dinamis), donasi, dan syarat & ketentuan. Detail lengkap field ada di `prd.md`.

Validasi berjalan di sisi klien sebelum submit, dengan pesan kesalahan di dekat field yang bermasalah dan pembersihan pesan itu begitu pengguna memperbaiki isian.

### 3.2 Lapisan data

Satu fungsi, `saveRegistration()`, adalah satu-satunya tempat yang bicara ke penyimpanan data. Bentuk data yang disimpan:

```
{
  id,
  owner: { name, phone, isParishioner, parishOrigin, companions },
  pets: [ { name, type, hasPhoto, notes }, ... ],
  donation: { amount, hasProof },
  agreedTos,
  submittedAt
}
```

Fungsi ini sekarang memanggil Supabase (`supabase-js`, project terpisah dari sistem 14-agent EO/WO yang sudah berjalan, supaya dua sistem tidak saling mengganggu): insert satu baris ke `owners`, ambil `id`-nya, lalu insert N baris ke `pets` dengan `owner_id` itu. Kredensial (Project URL + anon key) ada di `supabase-config.js`, dimuat lewat `<script>` sebelum kode form. anon key aman ditaruh di sisi klien karena akses dibatasi lewat Row Level Security (lihat `supabase/schema.sql`): anon cuma boleh insert, tidak boleh membaca data pemilik/hewan lain.

Bukti transfer donasi (maks 1280 px) dan foto hewan (maks 1024 px) dikompres di browser (canvas, JPEG) dan disimpan sebagai data URL di `owners.donation_proof_base64` dan `pets.photo_base64`; panitia melihatnya per pendaftar dari halaman rekap, dan foto hewan bisa diunduh dari sana.

### 3.3 Halaman pendaftaran masuk (sudah dibangun)

Halaman terpisah (`pendaftaran-masuk.html`), dikunci login Supabase Auth (email + password panitia, dibuat manual lewat dashboard Supabase) sebelum data ditampilkan. Query lewat `owners.select('*, pets(*)')`, dengan pencarian berdasarkan nama pemilik atau hewan di sisi klien. RLS membatasi SELECT hanya untuk role `authenticated`, jadi tanpa login data tidak bisa dibaca sama sekali lewat anon key.

Ada tombol "Export xlsx" (pakai SheetJS) yang mengunduh rekap: satu baris per hewan, lengkap dengan data pemilik, status umat, donasi, dan waktu daftar — untuk direkap panitia di luar aplikasi.

### 3.4 QR dan check-in (rencana)

Satu QR dibuat per pemilik saat pendaftaran diterima, mewakili pemilik dan seluruh hewannya sekaligus. QR dibuat di browser lewat qrcodejs (koreksi level H), berisi UUID pemilik. Alasan satu QR per pemilik, bukan per hewan: kalau satu keluarga membawa lima hewan dan tiap hewan punya QR sendiri, itu berarti lima kali scan di tiap titik. Dengan satu QR per pemilik, cukup satu kali scan di tiap titik, sementara data tiap hewan tetap tersimpan terpisah di baliknya untuk kebutuhan sertifikat nanti.

Ada 4 titik scan: reg ulang saat kedatangan, lalu tiga pos. Tiap titik pakai laptop atau tablet dengan kamera bawaan lewat browser biasa, tidak perlu alat scanner khusus atau aplikasi terinstal.

### 3.5 Integrasi photobooth, mcfbooth (rencana, sudah diselidiki)

mcfbooth sudah berjalan sebagai sistem terpisah (repo `dreinst/mcfbooth`, Python FastAPI, SQLite). Cara kerjanya: operator memasukkan nama tamu, sistem membuat `session_code` dari nama dan waktu, menyiapkan folder Google Drive dan QR sendiri untuk sesi itu, lalu operator memotret. Setiap foto otomatis tersalin ke dua tempat: Google Drive (untuk diunduh tamu lewat QR mcfbooth sendiri) dan folder lokal `local_archive/<session_code>/` di laptop operator. Satu laptop hanya bisa menjalankan satu sesi aktif dalam satu waktu, sesi berjalan berurutan.

mcfbooth punya REST API asli, `POST /api/sessions`, menerima satu field `guest_name` (teks bebas, 1 sampai 120 karakter) dan langsung memulai sesi. Ini berarti sesi bisa dipicu otomatis dari sistem lain, tidak harus operator mengetik manual di layar mcfbooth.

Rencana integrasi: di pos terakhir, aplikasi check-in kita berjalan di laptop yang sama dengan mcfbooth. Begitu QR pemilik dipindai, aplikasi memanggil `POST /api/sessions` dengan `guest_name` berisi nama hewan plus kode referensi singkat dari sistem kita, misalnya `"Shiro, A0482"`. Operator tinggal memotret dan menekan tombol selesai di mcfbooth seperti biasa. Karena tiap hewan butuh foto dan sertifikat sendiri, satu sesi mcfbooth dibuat per hewan, bukan per pemilik. Kalau satu pemilik punya beberapa hewan, sesinya berjalan berurutan untuk tiap ekor.

Setelah acara, `session_code` di database mcfbooth dibaca untuk mengambil kode referensi yang disisipkan tadi, dicocokkan ke data pendaftaran kita, lalu foto diambil langsung dari `local_archive/`. Ini menghindari kebutuhan mengintegrasikan Google Drive API di sisi sistem kita sama sekali.

Kalau pemanggilan API otomatis gagal karena sebab apa pun, operator tetap bisa mengetik nama secara manual di mcfbooth seperti alur aslinya, karena mcfbooth sendiri tidak diubah kodenya sama sekali oleh integrasi ini.

Catatan kapasitas: karena satu sesi mcfbooth mewakili satu hewan bukan satu pemilik, throughput pos ini dihitung dari jumlah hewan (perkiraan 700 sampai 1000 lebih ekor), bukan dari 500 pemilik. Ini jadi pertimbangan apakah satu titik photobooth cukup untuk durasi acara, atau perlu dua titik. Belum diputuskan.

### 3.6 Sertifikat digital (rencana)

Satu sertifikat per hewan, memakai template yang sama, dengan data (nama hewan, jenis, nama pemilik) dan foto dari mcfbooth yang berbeda tiap sertifikat. Dibuat otomatis setelah acara selesai, memakai foto yang sudah dicocokkan lewat langkah di atas.

## 4. Skema Data (rencana produksi)

Struktur yang sudah dipakai di prototipe (dalam satu objek JSON) diusulkan jadi dua tabel berelasi di Supabase:

```
owners
  id (uuid, pk)
  name
  phone
  is_parishioner
  parish_origin
  donation_amount
  donation_proof_url
  agreed_tos
  submitted_at

pets
  id (uuid, pk)
  owner_id (fk, owners.id)
  name
  type
  photo_url
  notes
  mcfbooth_session_code   (diisi belakangan, saat integrasi photobooth)
  certificate_url          (diisi belakangan, saat sertifikat dibuat)
```

Satu baris `owners` berelasi ke banyak baris `pets`, sesuai keputusan satu submission untuk satu pemilik dan banyak hewan.

## 5. Struktur Proyek

```
petblessings/
├── index.html                 form pendaftaran publik
├── pendaftaran-masuk.html     halaman lihat data masuk, terpisah dari form
├── README.md                  ringkasan status dan rencana eskalasi
├── prd.md                     kebutuhan produk dan user story
└── architecture.md            dokumen ini
```

## 6. Tech Stack

| Bagian | Sekarang (prototipe) | Rencana (produksi) |
|---|---|---|
| Frontend | HTML, CSS, JS satu berkas | Bisa tetap, atau dirapikan jadi proyek terstruktur |
| Data | Supabase (Postgres), sudah tersambung | — |
| Penyimpanan foto | Pratinjau di browser saja | Supabase Storage |
| Hosting | Belum dideploy | Vercel |
| Kode sumber | GitHub, `dreinst/petblessings`, sudah di-push | — |

## 7. Rencana Eskalasi

Urutan yang disepakati, dikerjakan lewat asisten pengkodean karena butuh kredensial GitHub, Supabase, dan Vercel yang ada di perangkat Donny:

1. Push kode ke `dreinst/petblessings`
2. Bikin proyek Supabase, tabel `owners` dan `pets` sesuai skema di atas
3. Ganti isi `saveRegistration()` di `index.html` dari `window.storage` ke panggilan Supabase
4. Sambungkan repo ke Vercel, atur environment variable untuk URL dan anon key Supabase
5. Deploy
6. Lanjut ke QR per pemilik, sistem check-in 4 titik, integrasi mcfbooth, sertifikat digital, sesuai urutan di bagian 3

## 8. Referensi

Kebutuhan produk dan user story ada di `prd.md`. Detail mcfbooth ada di repo `dreinst/mcfbooth`, khususnya `prd-sistem-photobooth.md` dan `arsitektur-sistem-photobooth.md`.
