# DESIGN INVENTORY — LiveTix

Dokumen ini mencatat seluruh desain Figma dan frame yang telah diterima, dianalisis, dan diimplementasikan.

## Status Legend
- ✅ Dianalisis + Diimplementasikan
- 🔍 Dianalisis, belum diimplementasikan
- ⏳ Menunggu desain
- ❓ Perlu klarifikasi

---

## 1. Flow Home & Navigasi Utama (4 Tab)

| Frame / Desain | File Implementasi | Status | Catatan Analisis & Detail Desain |
|----------------|-------------------|--------|-----------------------------------|
| **Modal Permohonan & Persetujuan** | `lib/screens/home/widgets/agreement_dialog.dart` | ✅ | Ikon tameng navy + centang + titik oranye; box abu lavender scrollable; checkbox kustom; tombol "Lanjutkan". |
| **Home (Beranda)** | `lib/screens/home/home_screen.dart` | ✅ | Search TextField interaktif dengan live filtering; filter chips; featured banner; segera hadir; auto-navigasi ke 4 tab. |
| **Halaman Jelajah (Explore)** | `lib/screens/explore/explore_screen.dart` | ✅ | Search bar + tombol filter, dropdown chips (Kota, Tanggal, Genre, Harga), kota populer kartu berwarna, genre pills, daftar konser trending. |
| **Halaman Tiket Saya (Tab 2)** | `lib/screens/ticket/ticket_screen.dart` | ✅ | Segmented toggle tab Aktif/Riwayat. **Guest**: box garis putus-putus (*dashed border*) dengan tautan href *"Silahkan Login Terlebih Dahulu"*. **User**: e-ticket aktif dengan kode booking dan QR icon. |
| **Halaman Akun (Tab 3)** | `lib/screens/profile/profile_screen.dart` | ✅ | **User**: Profil RF, statistik (12/9/4), preferensi mode light/dark switch, logout. **Guest**: Profil Guest, statistik (0/0/0), tombol instan *"Masuk ke Akun"*. |
| **Halaman Detail Konser** | `lib/screens/concert/concert_detail_screen.dart` | ✅ | Header fest, jadwal & lokasi, pilihan kategori tiket, total harga, tombol "Pesan tiket" dengan guard login untuk guest. |

---

## 2. Flow Autentikasi & Pemulihan Akun

| Frame / Desain | File Implementasi | Status | Catatan Analisis & Detail Desain |
|----------------|-------------------|--------|-----------------------------------|
| **Splash Screen** | `lib/screens/splash_screen.dart` | ✅ | Menggunakan aset asli `assets/images/livetix-logo.png` dengan transisi ke Home Guest. |
| **Halaman Login (Selamat Datang)** | `lib/screens/auth/login_screen.dart` | ✅ | Form bersih kosongan, logo LiveTix, tombol Google dengan `assets/images/google-logo.png`, navigasi ke Home User. |
| **Halaman Registrasi (Buat Akun)** | `lib/screens/auth/register_screen.dart` | ✅ | Form bersih kosongan, dropdown role berikon bintang, checkbox persetujuan, Google logo aset asli. |
| **Lupa Kata Sandi** | `lib/screens/auth/forgot_password_screen.dart` | ✅ | Header dengan aset `assets/images/forgot-password-logo.png`, form email kosongan, tombol kirim OTP. |
| **Verifikasi OTP** | `lib/screens/auth/otp_screen.dart` | ✅ | Header dengan aset `assets/images/verification-otp-logo.png`, box 5 kolom underline, auto-fokus, lanjut ke Reset Password. |
| **Form Kata Sandi Baru** | `lib/screens/auth/reset_password_screen.dart` | ✅ | Form sandi baru & konfirmasi dengan toggle visibilitas, tombol "Kirim data", navigasi kembali ke login. |

---

## 3. Flow Pemesanan & Pembayaran Tiket (Checkout Flow)

| Frame / Desain | File Implementasi | Status | Catatan Analisis & Detail Desain |
|----------------|-------------------|--------|-----------------------------------|
| **Pilih Tiket** (`media_1791946880646_308d6e93.png`) | `lib/screens/checkout/select_ticket_screen.dart` | ✅ | Denah venue interaktif (Panggung, Festival hijau, Tribun A/B), kuota sisa 214 tiket, counter [-] 2 [+], form data pemesan, rincian biaya dinamis. |
| **Ringkasan Pesanan** (`media_1791946889365_9713f75c.png`) | `lib/screens/checkout/order_summary_screen.dart` | ✅ | Stepper 3-tahap (Ringkasan aktif), kartu konser dengan date badge ungu OKT 12, rincian pembayaran tiket + layanan + pajak admin, banner garansi keamanan promotor. |
| **Selesaikan Pembayaran** (`media_1791946904639_b885703c.png`) | `lib/screens/checkout/payment_screen.dart` | ✅ | Stepper tahap 2 (Bayar), live countdown timer (23:59:12), kartu BCA Virtual Account dengan nomor VA `8808 1234 5678 9012` & tombol salin, petunjuk bayar 3 tahap, banner peringatan, tombol "Saya Sudah Bayar". |
| **E-Tiket & Pembayaran Berhasil** (`media_1791946917786_2df48570.png`) | `lib/screens/checkout/payment_success_screen.dart` | ✅ | Stepper tahap 3 (E-Tiket selesai), centang hijau dengan glowing aura, kartu tiket fisik dengan side notch cutout & dashed line separator, QR Code, kode booking `SWF-8891-2A`, tombol Unduh & Bagikan, tombol "Kembali ke Home" (auto-simpan tiket ke akun). |

---

## 4. Flow Status Tiket & Pengajuan Refund Dana

| Frame / Desain | File Implementasi | Status | Catatan Analisis & Detail Desain |
|----------------|-------------------|--------|-----------------------------------|
| **Tiket Saya Status Aktif & Reffund** (`media_1792409324480_443089ec.png`) | `lib/screens/ticket/ticket_screen.dart` | ✅ | Segmented toggle Aktif/Riwayat; kartu tiket dengan left stripe (biru/magenta), icon konsentris, badge status "Aktif" (hijau) & "Reffund" (pink/merah), sisa hari, tombol "Lihat tiket", serta empty state box putus-putus. |
| **Detail Tiket Dibatalkan & Rincian Refund** (`media_1792409375620_fe2db6f1.png`) | `lib/screens/refund/cancelled_ticket_detail_screen.dart` | ✅ | Header ungu-magenta, badge amber "Event dibatalkan", kotak QR dinonaktifkan, rincian biaya tiket dasar + biaya layanan, total refund 100%, batas pengajuan, dan tombol magenta "Ajukan refund". |
| **Pilih Tujuan Refund (Bank & E-wallet)** (`media_1792409442282_71a4fb1e.png` / `media_1792409450696_6a525c2c.png`) | `lib/screens/refund/refund_destination_screen.dart` | ✅ | Tab Bank vs E-wallet, chips provider (BCA, Mandiri, BNI, BRI / GoPay, OVO, DANA, ShopeePay), form rekening/e-wallet, box peringatan kuning, checkbox konfirmasi, dan tombol "Lanjutkan". |
| **Modal Periksa Data Refund** (`media_1792409484624_447c7600.png` kiri) | `lib/screens/refund/refund_destination_screen.dart` (BottomSheet) | ✅ | Bottom sheet konfirmasi akhir dengan detail provider, nomor rekening, nominal refund, banner peringatan data permanen, tombol "Ya, data sudah benar" & "Ubah data". |
| **Tracking Status Refund** (`media_1792409484624_447c7600.png` kanan) | `lib/screens/refund/refund_status_screen.dart` | ✅ | Header status badge "Sedang diproses", ID Transaksi, vertical timeline stepper 4 langkah, info rekening tujuan transfer, tombol "Kembali Ke Beranda" & "Hubungi bantuan". |

