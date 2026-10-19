# IMPLEMENTATION STATUS — LiveTix

## Legenda
- ✅ Selesai & dapat dijalankan
- 🚧 Sebagian — UI ada, integrasi API belum
- ⏳ Belum dimulai
- ❌ Bermasalah / perlu perbaikan

---

## Layar & Fitur Pengguna

| Fitur / Halaman | File | Status | Catatan |
|-----------------|------|--------|---------|
| **Splash Screen** | `lib/screens/splash_screen.dart` | ✅ | Menggunakan logo `livetix-logo.png`, otomatis berpindah ke Home Guest |
| **Modal Persetujuan (Agreement)** | `lib/screens/home/widgets/agreement_dialog.dart` | ✅ | Dialog interaktif dengan checkbox validasi, auto-popup di Home Guest |
| **Home (Beranda)** | `lib/screens/home/home_screen.dart` | ✅ | Search TextField interaktif dengan live filtering judul & venue; kategori filter; featured card |
| **Halaman Jelajah (Explore)** | `lib/screens/explore/explore_screen.dart` | ✅ | Sesuai desain: Search bar + filter, chip dropdown, kota populer, genre, trending konser |
| **Halaman Tiket Saya (Tickets)** | `lib/screens/ticket/ticket_screen.dart` | ✅ | Tab Aktif/Riwayat; dashed box untuk Guest dengan login link href; e-ticket card untuk User |
| **Halaman Akun (Profile)** | `lib/screens/profile/profile_screen.dart` | ✅ | Mode User (stats 12/9/4, switch mode tampilan, logout) & Mode Guest (stats 0/0/0, tombol instan Masuk Akun) |
| **Halaman Detail Konser** | `lib/screens/concert/concert_detail_screen.dart` | ✅ | Header fest, kartu jadwal/lokasi, pilihan kategori tiket, tombol Pesan Tiket dengan login guard |
| **Login Screen** | `lib/screens/auth/login_screen.dart` | ✅ | Form dimulai bersih/kosong, Google button `google-logo.png`, validasi form, navigasi ke Home User |
| **Register Screen** | `lib/screens/auth/register_screen.dart` | ✅ | Form dimulai bersih/kosong, dropdown role, checkbox syarat ketentuan, Google logo aset asli |
| **Lupa Kata Sandi** | `lib/screens/auth/forgot_password_screen.dart` | ✅ | Menggunakan `forgot-password-logo.png`, form email bersih, navigasi ke OTP |
| **Verifikasi OTP** | `lib/screens/auth/otp_screen.dart` | ✅ | Menggunakan `verification-otp-logo.png`, 5 underline field, auto-fokus, lanjut ke Reset Password |
| **Kata Sandi Baru (Reset Password)** | `lib/screens/auth/reset_password_screen.dart` | ✅ | Form sandi baru & konfirmasi, tombol "Kirim data", navigasi kembali ke login |
| **Pilih Tiket (Checkout Step 1)** | `lib/screens/checkout/select_ticket_screen.dart` | ✅ | Denah venue (Panggung, Festival, Tribun A/B), counter kuota, data pemesan, kalkulasi harga |
| **Ringkasan Pesanan (Checkout Step 2)** | `lib/screens/checkout/order_summary_screen.dart` | ✅ | Stepper 3-tahap, info konser + badge OKT 12, rincian biaya lengkap, banner proteksi |
| **Selesaikan Pembayaran (Checkout Step 3)** | `lib/screens/checkout/payment_screen.dart` | ✅ | Live countdown timer (23:59:12), kartu BCA VA + tombol salin, petunjuk bayar, simulasi verifikasi |
| **E-Tiket Berhasil (Checkout Step 4)** | `lib/screens/checkout/payment_success_screen.dart` | ✅ | Aura centang hijau, tiket notch cutout & dashed line, QR Code & booking code, auto-simpan ke akun |
| **Layanan Dummy Terpusat** | `lib/services/dummy_data_service.dart` | ✅ | In-memory singleton reactive store untuk User, Konser, Tiket riil, dan submission Refund |
| **Tiket Saya (Status Aktif & Reffund)** | `lib/screens/ticket/ticket_screen.dart` | ✅ | Kartu tiket dengan left stripe warna, badge status Aktif (hijau) & Reffund (pink), hari tersisa, dan tombol Lihat tiket |
| **Detail Tiket Dibatalkan** | `lib/screens/refund/cancelled_ticket_detail_screen.dart` | ✅ | Event dibatalkan badge, placeholder QR mati, rincian pengembalian dana 100%, batas pengajuan, dan tombol Ajukan refund |
| **Pilih Tujuan Refund** | `lib/screens/refund/refund_destination_screen.dart` | ✅ | Segmented Bank vs E-wallet, chips provider, form nama & nomor rekening/HP, box peringatan, dan checkbox konfirmasi |
| **Modal Periksa Data Refund** | `lib/screens/refund/refund_destination_screen.dart` | ✅ | Modal BottomSheet konfirmasi akhir data rekening/e-wallet sebelum diajukan ke sistem |
| **Tracking Status Refund** | `lib/screens/refund/refund_status_screen.dart` | ✅ | Header status Sedang diproses, nominal refund, vertical stepper timeline 4 tahap, kartu tujuan, dan tombol aksi |


