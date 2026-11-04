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
| **Tiket Saya Status Aktif & Reffund** (`media_1792409324480_443089ec.png`) | `lib/screens/ticket/ticket_screen.dart` | ✅ | Segmented toggle Aktif/Riwayat; kartu tiket dengan left stripe (biru/magenta), icon konsentris, badge status "Aktif" (hijau) & "Reffund" (pink/merah), sisa hari, tombol "Lihat tiket", serta empty state box putus-putus. |
| **Detail Tiket Dibatalkan & Rincian Refund** (`media_1792409375620_fe2db6f1.png`) | `lib/screens/refund/cancelled_ticket_detail_screen.dart` | ✅ | Header ungu-magenta, badge amber "Event dibatalkan", kotak QR dinonaktifkan, rincian biaya tiket dasar + biaya layanan, total refund 100%, batas pengajuan, dan tombol magenta "Ajukan refund". |
| **Pilih Tujuan Refund (Bank & E-wallet)** (`media_1792409442282_71a4fb1e.png` / `media_1792409450696_6a525c2c.png`) | `lib/screens/refund/refund_destination_screen.dart` | ✅ | Tab Bank vs E-wallet, chips provider (BCA, Mandiri, BNI, BRI / GoPay, OVO, DANA, ShopeePay), form rekening/e-wallet, box peringatan kuning, checkbox konfirmasi, dan tombol "Lanjutkan". |
| **Modal Periksa Data Refund** (`media_1792409484624_447c7600.png` kiri) | `lib/screens/refund/refund_destination_screen.dart` (BottomSheet) | ✅ | Bottom sheet konfirmasi akhir dengan detail provider, nomor rekening, nominal refund, banner peringatan data permanen, tombol "Ya, data sudah benar" & "Ubah data". |
| **Tracking Status Refund** (`media_1792409484624_447c7600.png` kanan) | `lib/screens/refund/refund_status_screen.dart` | ✅ | Header status badge "Sedang diproses", ID Transaksi, vertical timeline stepper 4 langkah, info rekening tujuan transfer, tombol "Kembali Ke Beranda" & "Hubungi bantuan". |

---

## 5. Flow Portal Produser & Manajemen Konser

| Frame / Desain | File Implementasi | Status | Catatan Analisis & Detail Desain |
|----------------|-------------------|--------|-----------------------------------|
| **Portal Produser (Main 4 Tab)** | `lib/screens/promoter/promoter_main_screen.dart` | ✅ | Navigasi 4 Tab: Dasbor, Konser, Keuangan, Profil dengan tema adaptif Light/Dark dan status bar transparan bersih. |
| **Dasbor Produser** | `lib/screens/promoter/promoter_dashboard_screen.dart` | ✅ | Kartu metrik responsif (Total Konser, Tiket Terjual, Total Pendapatan +8.2%), Bar Chart Penjualan 7 Hari, dan kartu konser mendatang. |
| **Daftar Konser & Filter Status** | `lib/screens/promoter/promoter_concert_list_screen.dart` | ✅ | Banner kuota harian (2 dari 3), filter status pills (Semua, Draft, Menunggu, Disetujui, Ditolak), pencarian real-time, grid/list responsif, modal aksi, dan FAB Tambah Konser. |
| **Tambah Konser Step 1-4 (Wizard)** | `lib/screens/promoter/add_concert/` | ✅ | 4 langkah: (1) Detail & Poster, (2) Peta Venue interaktif & Pin, (3) Pricing & Tier tiket dinamis, (4) Ringkasan pengajuan konser. |
| **Halaman Pembayaran & Saldo** (`media_1793678812506_b4f7243d.png`) | `lib/screens/promoter/promoter_finance_screen.dart` | ✅ | Hero card Saldo Tersedia (Rp1.845.000.000), total pendapatan (Rp2.115.000.000), tombol magenta "Tarik Dana", filter "Semua Periode ▾", dan kartu hasil konser (Soundwave Fest & Java Jazz). |
| **Detail Pendapatan Konser** (`media_1793678823826_82c20640.png`) | `lib/screens/promoter/promoter_income_detail_screen.dart` | ✅ | Hero card pendapatan bersih (Rp997.500.000), status Payout Sukses Mandiri (***8842), rincian penjualan kotor & fee 5%, ID Transaksi Payout (#TX-PY9088312), dan tombol navigasi ke Riwayat Penarikan. |
| **Riwayat Penarikan Dana** (`media_1793678834544_f904a10c.png`) | `lib/screens/promoter/promoter_withdrawal_history_screen.dart` | ✅ | Daftar transaksi penarikan dana lengkap dengan 3 status: BERHASIL (hijau), MENUNGGU (kuning), dan DITOLAK (merah) dengan rincian alasan penolakan. |
| **Tarik Saldo & Otorisasi PIN** (`media_1793678844277_92da6327.png`) | `lib/screens/promoter/promoter_withdrawal_screen.dart` | ✅ | Card saldo tersedia, field nominal penarikan, dropdown rekening tujuan (BCA - Rafi Firmansyah), biaya admin Rp6.500, total dana diterima dinamis, serta otorisasi PIN Keamanan 6-Digit. |
| **Profil Mitra & Keamanan** | `lib/screens/promoter/promoter_profile_screen.dart` | ✅ | Info PT Harmoni Java Promosindo, modal rincian rekening BCA escrow, dialog info PIN 6-digit, switch tema tampilan, dan switch ke mode Attendee. |
| **Detail Status Konser & Kurasi** | `lib/screens/promoter/concert_status_detail_screen.dart` | ✅ | Dynamic 4-stage dots tracker (Draft -> Diajukan -> Ditinjau -> Disetujui/Ditolak), card alasan penolakan & cooldown, card proses review kurasi, dan integrasi CS. |
| **Live Chat Bantuan Kurasi Promotor** | `lib/screens/promoter/producer_customer_service_screen.dart` | ✅ | Ruang konsultasi kurasi & banding konser dengan upload lampiran izin keramaian / layout venue. |
| **Alur Verifikasi Produser** | `lib/screens/promoter/verification/` | ✅ | 4 tahap: Form data diri penanggung jawab, unggah KTP & dokumen legalitas, layar menunggu approval, dan layar approval ditolak beserta jeda waktu. |

