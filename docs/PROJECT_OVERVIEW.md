# PROJECT OVERVIEW - LiveTix Concert Booking

## Tujuan Proyek
Membangun aplikasi **Concert Booking** menggunakan Flutter & Dart.
Tampilan mengikuti desain Figma dan pembaruan kebutuhan produk; backend direncanakan menggunakan Supabase + PostgreSQL + Supabase Storage.

## Nama Proyek
**LiveTix** (`livetix` - Flutter package name)

## Platform
- **Target utama:** Android & Flutter Web (pengujian pengembangan)
- **Framework:** Flutter / Dart (Null Safety, SDK >=3.0.0 <4.0.0)

## Status Saat Ini
Alur utama pengguna (Guest & User terautentikasi) telah berjalan di atas lapisan abstraksi data terpusat (`DataService` + `DbDummy` + `LocalStorage` tanpa paket eksternal tambahan), mencakup Beranda, Jelajah, Edit Profil lengkap, Pemesanan & Pembayaran Tiket, E-Tiket, serta Pengajuan Refund.

---

## Role & Hak Akses

| Role | Deskripsi |
|------|-----------|
| **User** | Mencari konser, memfilter jadwal/harga, membeli tiket, mengelola profil & refund |
| **Admin** | Pengelola operasional platform |
| **Produser** | Pengelola jadwal konser beserta unggahan aset visual konser miliknya |
| **Gate Kru** | Petugas lapangan verifikasi tiket masuk konser melalui pemindai QR gate |

> Role Admin tidak boleh bisa didaftarkan dari form publik.
> Role diverifikasi oleh backend, bukan hanya oleh frontend.

---

## Spesifikasi Aset Visual Konser (Panduan Integrasi Tim Produser & Backend)

Setiap entitas konser pada `ConcertModel` (`lib/models/concert_model.dart`) mendukung **2 jenis aset gambar terpisah** yang nantinya diatur/diunggah oleh pihak **Produser**:

| Jenis Aset | Field pada `ConcertModel` | Rasio & Resolusi Rekomendasi | Lokasi Tampil di Aplikasi User | Fallback Saat Belum Diunggah |
|------------|---------------------------|------------------------------|--------------------------------|------------------------------|
| **1. Gambar Highlight Persegi Panjang (Banner Landscape)** | `bannerImageUrl` (`String?`) / `bannerImageBytes` (`Uint8List?`) | Landscape `16:9` (rekomendasi `1280x720 px`), JPG/PNG/WebP | **Carousel Highlight Beranda** (*full-bleed* + scrim gelap) dan **Header Paling Atas Detail Konser** (`ConcertDetailScreen`) | Gradien panggung (`highlightGradientColors`) + motif piringan konsentris LiveTix |
| **2. Gambar Logo / Thumbnail Konser Persegi** | `logoImageUrl` (`String?`) / `logoImageBytes` (`Uint8List?`) | Persegi `1:1` (rekomendasi `400x400 px`), JPG/PNG/WebP | **Kartu List Konser** di **Beranda (`Konser Trending`)** dan di **Halaman Jelajah (`ExploreScreen`)** | Kotak persegi membulat dengan warna `iconBgColor` & ikon musik/vinyl |

- Komponen perender terpusat tersedia di `lib/widgets/concert_media.dart` (`ConcertHighlightBannerSurface` dan `ConcertSquareLogo`).
- Untuk pengujian modul Produser sebelum Supabase Storage aktif, tim dapat langsung memanggil `DataService().updateConcertMedia(...)` untuk memperbarui byte maupun URL kedua gambar secara reaktif.

---

## Spesifikasi QR Code Pembayaran & E-Tiket Gate (Siap Integrasi Backend)

- Seluruh tampilan QR Code pada alur User (Barcode **QRIS** di `PaymentScreen`, **E-Tiket** di `PaymentSuccessScreen` & `TicketScreen`, kartu **Bagikan QR Gate**, serta QR nonaktif pada `CancelledTicketDetailScreen`) dirender menggunakan komponen `AppQrCodeView` (`lib/widgets/qr_code_view.dart`).
- Selama masa pengujian sebelum backend aktif, `AppQrCodeView` otomatis merender aset `assets/images/qrcode.png` dengan `FilterQuality.none` agar piksel QR tetap tajam.
- Saat backend terhubung, cukup isi field `qrCodeUrl` (`String?`) atau `qrCodeBytes` (`Uint8List?`) pada `OrderModel` / `UserTicketModel` tanpa mengubah kode UI.
- **Aturan Multi-Scan Gate**: Pembelian hingga maksimal 4 tiket per transaksi menerbitkan **1 QR Code** dengan `qrScanQuota = quantity` (dapat dipindai hingga 4 kali di gate). Fitur **`Bagikan QR`** menghasilkan gambar PNG ber-watermark `LiveTix` yang memuat nama konser dan tanggal konser melalui `GateQrImageGenerator` dan membagikannya lewat Web Share API perangkat (`QrShare`).
- **Pencantuman Kode Tiket di Bawah QR Code**: Setiap tampilan QR Code tiket otomatis merender kode tiket unik di bawah gambar QR Code lengkap dengan badge visual dan tombol salin cepat ke clipboard untuk memudahkan penonton maupun petugas gate saat pemeriksaan.

---

## Arsitektur Payment Gateway Midtrans & Kebijakan Rekening Refund

1. **Simulasi E-Wallet & Target Integrasi Midtrans di Backend**:
   - Layar simulasi aplikasi e-wallet (`EWalletPaymentAppScreen`) saat ini digunakan khusus untuk kebutuhan debug / pengujian alur interaksi frontend.
   - Pada tahap implementasi backend, sistem akan menghubungkan Payment Gateway Midtrans untuk memperoleh deeplink redirect langsung ke masing-masing aplikasi e-wallet (GoPay, DANA, ShopeePay) di smartphone pengguna.
2. **Transparansi Biaya Admin Transaksi & Fleksibilitas Admin**:
   - Pada setiap metode pembayaran tiket (QRIS, E-Wallet, dan Virtual Account Bank), sistem mencantumkan perkiraan biaya admin transaksi secara transparan dan otomatis menambahkannya ke total tagihan pesanan.
   - Besaran biaya admin transaksi ini aman dan dapat dikonfigurasi dinamis oleh Admin platform melalui `DataService().setTransactionFee`.
3. **Metode Pembayaran di Profil Khusus Penerimaan Refund & Cooldown 1 Minggu**:
   - Menu metode pembayaran pada profil pengguna (`RefundPaymentMethodScreen`) khusus difungsikan untuk mendaftarkan rekening bank atau akun e-wallet penerima pencairan dana refund tiket.
   - Demi perlindungan akun pengguna dari penarikan dana tanpa izin, penambahan atau perubahan rekening refund menerapkan masa cooldown selama 1 minggu (7 hari) pasca pembaruan terakhir. Pengguna baru dapat memperbarui rekening setelah masa cooldown selesai.

---

## Spesifikasi & Arsitektur Gate Kru (Kru Lapangan)

1. **Tugas & Autentikasi Gate Kru**:
   - Gate Kru bertugas memvalidasi tiket masuk penonton di gate acara (pintu masuk fisik).
   - Login menggunakan halaman masuk utama (`LoginScreen`). Sistem mendeteksi role pengguna dan otomatis mengarahkan akun petugas ke `GateCrewHomeScreen`. Akun demo pengujian: `budi@livetix.com` / `123456`.
2. **Pembagian Gate Otomatis & Konfigurasi Produser**:
   - Sistem menetapkan penugasan gate secara otomatis berdasarkan data akun petugas (`DataService().getGateForCrew(user.id)`).
   - Struktur gate (`GateModel`) menampung `gateId`, `concertId`, `gateName` (contoh: `GATE B - FESTIVAL`), `assignedCrewId`, jam buka, dan status gate (`buka`/`tutup`).
   - Pihak **Produser** memegang kendali untuk menentukan jumlah gate yang dibutuhkan serta pembagian gate ketika membuat atau memperbarui acara konser.
3. **Pemindai Kamera Viewfinder Gelap (`GateScannerScreen`)**:
   - Menampilkan viewfinder kamera gelap dengan garis laser animasi, corner bracket, ringkasan kuota kehadiran, dan dock kontrol cepat (Senter/Flash, Input Manual Kode Tiket, Balik Kamera).
   - Dilengkapi tombol simulasi instan untuk menguji hasil scan tiket valid, tiket duplikat (sudah dipakai), tiket salah gate, dan format tiket tidak valid tanpa kamera fisik.
4. **Hasil Validasi Tiket (`GateScanResultScreen`)**:
   - **Tiket Valid** (Hijau `#00B368`): Menampilkan rincian penonton, kategori tiket, nomor pintu, dan waktu scan, dengan auto-advance 2 detik disertai progress bar menuju pemindaian berikutnya.
   - **Tiket Sudah Pernah Dipakai** (Merah `#E53935`): Menolak masuk, menampilkan waktu dan gate tempat tiket pertama kali dipindai beserta nama petugas pencatat, serta opsi kontak koordinator gate.
   - **Tiket Salah Gate** (Oranye `#F59E0B`): Memberitahukan gate yang seharusnya dituju penonton.
   - **Tiket Tidak Valid** (Merah `#DC2626`): Menolak kode barcode yang tidak terdaftar.
5. **Dukungan Multi-Scan untuk Pembelian Rombongan**:
   - Sesuai spesifikasi pembelian tiket (1 QR untuk 1 sampai 4 tiket), gate scanner mencatat sisa pemindaian (`scannedCount` vs `qrScanQuota`). Tiket tetap berstatus valid hingga kuota seluruh penonton terpenuhi.
6. **Layar Input Manual (`GateManualCheckinScreen`)**:
   - Mendukung pencarian tiket manual berdasarkan Kode Booking (`SWF-8891-2A`), NIK/KTP, atau Nama, disertai verifikasi KTP fisik dan tombol check-in manual penonton.
7. **Layar Peringatan Salah Gate & Tiket Dibatalkan (`GateScanResultScreen`)**:
   - Menampilkan layar oranye tegas dengan petunjuk gate tujuan resmi penonton atau instruksi penolakan tiket yang telah dibatalkan karena refund dana.
8. **Tab Riwayat Scan & Profil Gate Kru**:
   - Tab Riwayat menyajikan 3 metrik kehadiran (Valid, Ditolak, Belum hadir) dan daftar 20 scan terakhir; Tab Profil menyediakan informasi akun kru, penugasan konser, dan aksi keluar akun.

---

## Keputusan Teknis

| Aspek | Keputusan |
|-------|-----------|
| Font | Poppins (Google Fonts) untuk body; Playfair Display untuk nama brand di splash |
| Warna utama | `AppColors.primary` `#1B2A8C` (navy) |
| Warna aksen | `AppColors.accent` `#C2185B` (magenta) |
| Highlight kota aktif | `AppColors.citySelectedShadow` `#C654C3` (shadow tombol kota populer) |
| Tombol favorit love | `AppColors.favoritePink` `#E91E8C` (pink cerah saat disukai) |
| Tema visual | Global Dark & Light Mode (`DataService.isDarkModeNotifier`, default awal: Dark `#0B1120`) |
| Splash BG | `#070B14` (dark) |
| Header gradient | `#271C80 -> #971C91` |
| Logo gradient | `#A020F0 -> #2D6BFF` |
| State & Data Layer | Singleton `DataService` dengan `ValueNotifier` reaktif + penyimpanan lokal lintas platform (`lib/utils/local_storage.dart`) |
| Routing | Menggunakan `Navigator.push` / `MaterialPageRoute` |
| Backend | Supabase (direncanakan) |
| Autentikasi | Supabase Auth (direncanakan), saat ini disimulasikan melalui `DataService` |

---

## Dependensi Aktif

```yaml
dependencies:
  flutter: sdk
  google_fonts: ^6.2.1

dev_dependencies:
  flutter_test: sdk
  flutter_lints: ^4.0.0
```

---

## Catatan Penting Tim
- Jangan tambah dependency baru ke `pubspec.yaml` tanpa diskusi terlebih dahulu.
- Backend dan schema database belum final, jaga semua akses data tetap melalui `DataService` agar migrasi ke Supabase tidak merombak kode layar UI.
- Harga dan role wajib divalidasi di sisi server saat integrasi backend.
