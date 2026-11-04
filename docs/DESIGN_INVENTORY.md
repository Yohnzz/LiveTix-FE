# DESIGN INVENTORY - LiveTix

Dokumen ini mencatat seluruh desain Figma, revisi antarmuka terbaru, dan komponen yang telah diimplementasikan.

## Status Legend
- ✅ Dianalisis + Diimplementasikan
- 🔍 Dianalisis, belum diimplementasikan
- ⏳ Menunggu desain / modul lanjutan

---

## 1. Flow Home, Highlight, Jelajah, & Profil (4 Tab Utama)

| Frame / Komponen | File Implementasi | Status | Catatan Analisis & Detail Desain |
|------------------|-------------------|--------|-----------------------------------|
| **Modal Permohonan & Persetujuan** | `lib/screens/home/widgets/agreement_dialog.dart` & `lib/utils/local_storage.dart` | ✅ | Muncul hanya jika pengguna belum pernah menyetujui. Status persetujuan disimpan di `LocalStorage` (`livetix_agreement_accepted`) serta `DataService` sehingga tidak muncul berulang saat pindah halaman atau muat ulang. |
| **Home / Dashboard (Beranda)** | `lib/screens/home/home_screen.dart`, `lib/widgets/user_avatar.dart`, & `lib/screens/home/widgets/featured_concert_card.dart` | ✅ | **Kartu Profil Header Beranda** menggantikan sapaan lama *"Halo, Guest / Malam ini ada apa?"*: menggunakan logo profil lingkaran abu-abu terang (`#F2F4F7`, border `#E4E7EC`) dengan ikon siluet vektor navy (`#1B2A8C`, kepala solid + lengkung bahu terbuka); pada **Guest** menampilkan nama `Guest`, `ID : -`, serta tombol **`Masuk`** di sisi kanan di dalam card; pada **User** menampilkan nama lengkap dan `ID : <6 karakter>` (misal `123456`) yang menuju tab Akun saat diketuk. Dilengkapi search bar, kategori pills, **Highlight Carousel** dengan indikator titik **horizontal sebaris (inline)** rata tengah tanpa angka `1/5` & tanpa tombol *pause*, serta seksi **"Konser Trending"** maks 5 konser terfilter + tombol **"Lihat Semua konser yang ada"** ke tab **Jelajah**. |
| **Media Konser Produser (Banner & Logo)** | `lib/widgets/concert_media.dart` & `lib/models/concert_model.dart` | ✅ | Mendukung 2 aset gambar Produser: `ConcertHighlightBannerSurface` (persegi panjang *full-bleed* untuk Carousel Highlight & Header Detail Konser) dan `ConcertSquareLogo` (persegi `1:1` untuk kartu list konser di Beranda & Jelajah), lengkap dengan visual fallback saat gambar belum diunggah. |
| **Halaman Jelajah (Explore)** | `lib/screens/explore/explore_screen.dart` | ✅ | Search bar + filter **Tanggal** (pemilih tanggal/bulan/tahun + tombol `Today` & `Hapus`) dan filter **Harga** (`Termurah < Rp50.000`, `Rp50.000 - Rp150.000`, `Rp151.000 - Rp200.000`, `Termahal > Rp200.000`); tombol **Kota Populer** tanpa jumlah event dengan efek *back-shadow* `#C654C3` saat dipilih; daftar semua konser dengan thumbnail persegi. |
| **Halaman Detail Konser** | `lib/screens/concert/concert_detail_screen.dart` | ✅ | Bagian paling atas menggunakan **Banner Highlight Persegi Panjang** (`ConcertHighlightBannerSurface`), kartu jadwal & lokasi aktual tiap konser, pilihan kategori tiket, total harga, serta tombol "Pesan tiket" dengan guard login untuk Guest. |
| **Halaman Tiket Saya (Tab 2)** | `lib/screens/ticket/ticket_screen.dart`, `lib/widgets/qr_code_view.dart`, & `lib/widgets/share_gate_qr_sheet.dart` | ✅ | Segmented toggle tab Aktif/Riwayat. **Guest**: box garis putus-putus dengan tautan masuk. **User**: daftar e-ticket aktif (`AppQrCodeView` berbasis `assets/images/qrcode.png` siap backend, 1 QR berlaku maks 4x scan sesuai jumlah tiket, tombol **Bagikan QR** ber-watermark `LiveTix` ke aplikasi HP) dan tiket refund. |
| **Halaman Akun Guest & User (Tab 3)** | `lib/screens/profile/profile_screen.dart` | ✅ | **Guest**: hanya menampilkan kartu Guest (`GuestAvatarIcon`) dan tombol **"Masuk ke Akun"** tanpa menu khusus user login. **User**: kartu profil reaktif, statistik (12/9/4), menu pengaturan, switch Light/Dark mode, dan keluar akun. |
| **Halaman Edit Profil User** | `lib/screens/profile/edit_profile_screen.dart` | ✅ | Mencakup **Ganti Foto Profil** (unggah foto perangkat via `PhotoPicker` + 5 tema warna avatar + hapus foto), **Edit Nama**, serta **Ganti Password** dengan 2 alur (verifikasi password lama & alur **Lupa Password** via email + OTP). |

---

## 2. Flow Autentikasi & Pemulihan Akun

| Frame / Desain | File Implementasi | Status | Catatan Analisis & Detail Desain |
|----------------|-------------------|--------|-----------------------------------|
| **Splash Screen** | `lib/screens/splash_screen.dart` | ✅ | Menggunakan aset asli `assets/images/livetix-logo.png` dengan transisi ke Home Guest. |
| **Halaman Login (Selamat Datang)** | `lib/screens/auth/login_screen.dart` | ✅ | Form bersih kosongan, validasi kecocokan kata sandi akun terdaftar di `DataService`, tombol Google `assets/images/google-logo.png`, navigasi ke Home User. |
| **Halaman Registrasi (Buat Akun)** | `lib/screens/auth/register_screen.dart` | ✅ | Form bersih kosongan, dropdown role (`User` / `Produser`), checkbox persetujuan, registrasi sinkron ke `DataService`. |
| **Lupa Kata Sandi** | `lib/screens/auth/forgot_password_screen.dart` | ✅ | Mendukung akses dari halaman Login maupun dari dalam **Edit Profil -> Ganti Password -> Lupa Password?** (`returnToCaller: true`) dengan verifikasi kesesuaian email akun aktif. |
| **Verifikasi OTP** | `lib/screens/auth/otp_screen.dart` | ✅ | Input 5 kolom digit OTP auto-fokus, meneruskan alur ke pembuatan kata sandi baru. |
| **Form Kata Sandi Baru** | `lib/screens/auth/reset_password_screen.dart` | ✅ | Memperbarui kata sandi akun di `DataService`; kembali ke halaman Edit Profil jika dipicu oleh user yang sedang login, atau kembali ke Login jika dipicu dari luar sesi. |

---

## 3. Flow Pemesanan & Pembayaran Tiket (Checkout Flow)

| Frame / Desain | File Implementasi | Status | Catatan Analisis & Detail Desain |
|----------------|-------------------|--------|-----------------------------------|
| **Pilih Tiket** | `lib/screens/checkout/select_ticket_screen.dart` | ✅ | Denah venue interaktif (Panggung Utama, VIP Lounge, Festival, Tribun A/B), counter tiket maks 4, data pemesan otomatis dari profil akun aktif, total konsisten termasuk layanan & biaya admin. |
| **Ringkasan Pesanan** | `lib/screens/checkout/order_summary_screen.dart` | ✅ | Stepper tahap 1 (Ringkasan), kartu konser dengan badge tanggal aktual, rincian pembayaran tiket + layanan + pajak admin, tombol **"Pilih Metode"** menuju pemilihan metode pembayaran. |
| **Pilih Metode Pembayaran** | `lib/screens/checkout/payment_method_screen.dart` | ✅ | Menyediakan 3 kategori metode: **QRIS** (1 jenis, langsung ke barcode QRIS), dropdown **E-Wallet** (**GoPay**, **DANA**, **ShopeePay**), dan dropdown **Bank** (**BCA**, **Mandiri**, **BRI**, **SeaBank**). |
| **Selesaikan Pembayaran & Simulasi PIN E-Wallet** | `lib/screens/checkout/payment_screen.dart` & `lib/screens/checkout/ewallet_app_screen.dart` | ✅ | Stepper tahap 2 (Bayar), hitung mundur batas waktu **1 Jam (`01:00:00`)**, rincian harga total + daftar pembayaran + biaya admin. Mendukung Barcode QRIS (`assets/images/qrcode.png`), pengalihan aplikasi **GoPay/DANA/ShopeePay** dengan nominal otomatis terkunci + input PIN 6 digit + 2 tombol saat kembali (**`Cek Pembayaran`** & **`Lanjut ke Aplikasi`**), serta instruksi khusus tiap aplikasi bank (**m-BCA/myBCA**, **Livin' Multipayment 89022**, **BRImo BRIVA 77889**, **SeaBank VA**). |
| **E-Tiket & Bagikan QR Ber-Watermark** | `lib/screens/checkout/payment_success_screen.dart`, `lib/utils/gate_qr_image_generator.dart`, & `lib/utils/qr_share.dart` | ✅ | Stepper tahap 3 (E-Tiket selesai), kartu tiket digital dengan 1 QR Code (`assets/images/qrcode.png` siap backend) untuk hingga 4x scan di gate, tombol **Bagikan QR** yang menghasilkan gambar PNG ber-watermark `LiveTix` berisi nama & tanggal konser melalui fitur *Share* bawaan perangkat, serta navigasi langsung ke menu **Tiket**. |

---

## 4. Flow Status Tiket & Pengajuan Refund Dana

| Frame / Desain | File Implementasi | Status | Catatan Analisis & Detail Desain |
|----------------|-------------------|--------|-----------------------------------|
| **Tiket Saya Status Aktif & Refund** | `lib/screens/ticket/ticket_screen.dart` | ✅ | Kartu tiket dengan indikator status Aktif & Refund serta navigasi detail. |
| **Detail Tiket Dibatalkan & Rincian Refund** | `lib/screens/refund/cancelled_ticket_detail_screen.dart` | ✅ | Header status pembatalan, QR dinonaktifkan, rincian pengembalian dana 100%, tombol "Ajukan refund". |
| **Pilih Tujuan Refund & Modal Konfirmasi** | `lib/screens/refund/refund_destination_screen.dart` | ✅ | Pilihan Bank vs E-wallet, chips provider, validasi rekening, dan bottom sheet konfirmasi akhir. |
| **Tracking Status Refund** | `lib/screens/refund/refund_status_screen.dart` | ✅ | Timeline stepper 4 tahap, rincian rekening tujuan, dan akses pusat bantuan. |
