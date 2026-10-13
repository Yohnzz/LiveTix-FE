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
