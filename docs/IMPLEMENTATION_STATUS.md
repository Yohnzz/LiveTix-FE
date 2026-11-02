# IMPLEMENTATION STATUS - LiveTix

## Legenda
- ✅ Selesai & teruji otomatis
- 🚧 Sebagian - UI & kontrak model siap, menunggu modul Produser / integrasi API backend
- ⏳ Belum dimulai

---

## Layar, Komponen, & Fitur Pengguna

| Fitur / Halaman | File | Status | Catatan |
|-----------------|------|--------|---------|
| **Splash Screen** | `lib/screens/splash_screen.dart` | ✅ | Menggunakan logo `livetix-logo.png`, berpindah ke Home Guest |
| **Persetujuan Sekali Tampil (Agreement)** | `lib/screens/home/widgets/agreement_dialog.dart`, `lib/utils/local_storage.dart` | ✅ | Status persetujuan disimpan ke `LocalStorage` & `DataService` sehingga tidak muncul lagi setelah pernah disetujui |
| **Home / Dashboard (Beranda)** | `lib/screens/home/home_screen.dart`, `lib/widgets/user_avatar.dart` | ✅ | Kartu profil header: **Guest** (`Guest`, `ID : -`, tombol `Masuk` di kanan dalam card) & **User** (nama lengkap + `ID : 6 karakter`). Relokasi notifikasi ke kartu profil header (sebelah kiri `>` dengan badge angka 3 belum dibaca membuka sheet notifikasi). Search & filter kategori ("Disukai" dual-filter), **Konser Trending** maks 5 item terfilter + tombol **"Lihat Semua konser yang ada"** ke tab Jelajah |
| **Highlight Carousel Beranda** | `lib/screens/home/widgets/featured_concert_card.dart` | ✅ | Geser manual & otomatis tiap 4 detik, indikator titik horizontal sebaris (*inline*) rata tengah (*center*), tanpa teks `1/5` dan tanpa tombol *pause*. Tombol favorit love interaktif (berubah pink `#E91E8C` saat disukai dan tersimpan di `DataService`) |
| **Komponen QR Code & Bagikan QR Gate Ber-Watermark** | `lib/widgets/qr_code_view.dart`, `lib/widgets/share_gate_qr_sheet.dart`, `lib/utils/gate_qr_image_generator.dart`, `lib/utils/qr_share.dart` | ✅ | Sementara memakai `assets/images/qrcode.png` dan siap menerima `qrCodeUrl`/`qrCodeBytes` dari backend; mendukung 1 QR untuk maks 4x scan + fitur Bagikan gambar PNG ber-watermark `LiveTix` ke aplikasi HP |
| **Sistem Media Konser (Banner & Logo Produser)** | `lib/widgets/concert_media.dart`, `lib/models/concert_model.dart` | 🚧 | Model & UI siap merender foto `bannerImage` (persegi panjang di Carousel & Header Detail) serta `logoImage` (persegi 1:1 di list Beranda & Jelajah); menunggu form unggah role Produser |
| **Halaman Jelajah (Explore)** | `lib/screens/explore/explore_screen.dart` | ✅ | Filter Tanggal (kalender penuh + `Today` & `Hapus`) & Harga (rentang lengkap), Kota Populer tanpa jumlah event dengan shadow `#C654C3`, filter "Disukai" ganda dengan genre (limit hasil maks 10 konser), thumbnail persegi |
| **Halaman Detail Konser** | `lib/screens/concert/concert_detail_screen.dart` | ✅ | Header paling atas diubah ke **Banner Highlight Persegi Panjang**, tombol love favorit pink `#E91E8C` sinkron dengan Beranda, info jadwal/lokasi aktual konser, kategori tiket, login guard untuk Guest |
| **Halaman Akun (Profile) & Global Dark Mode** | `lib/screens/profile/profile_screen.dart` | ✅ | Mode Guest hanya menampilkan kartu Guest + tombol "Masuk ke Akun". Mode User: Bahasa & Notifikasi dihapus (notifikasi pindah ke Beranda), switch "Mode tampilan" mengubah tema global ke seluruh aplikasi (Beranda, Jelajah, Tiket, Profil, Dialog, Bottom Nav), tersimpan di `LocalStorage`, dengan nilai awal tema Dark |
| **Metode Pembayaran di Profil (Khusus Refund & Cooldown 1 Minggu)** | `lib/screens/profile/refund_payment_method_screen.dart` | ✅ | Khusus menetapkan rekening/e-wallet penerima pencairan refund; menerapkan masa cooldown 1 minggu (7 hari) pasca pembaruan demi keamanan akun, dilengkapi tombol simulasi testing |
| **Halaman Edit Profil User** | `lib/screens/profile/edit_profile_screen.dart`, `lib/utils/photo_picker.dart` | ✅ | Edit Nama reaktif, Ganti Foto Profil (file perangkat & tema warna avatar), serta Ganti Password (alur password lama & alur Lupa Password via email + OTP) |
| **Login, Register, Forgot Password, OTP, Reset Password** | `lib/screens/auth/*.dart` | ✅ | Terintegrasi dengan `DataService`; alur Lupa Password mendukung pemulihan dari Login maupun langsung dari dalam halaman Edit Profil |
| **Alur Checkout Multi-Metode Pembayaran (QRIS, E-Wallet, Bank)** | `lib/screens/checkout/*.dart` | ✅ | Pilih Tiket, Ringkasan Pesanan, Pilih Metode (QRIS, E-Wallet, Bank). Setiap opsi mencantumkan perkiraan biaya admin transaksi dan otomatis menambahkannya ke total tagihan (biaya admin aman diatur dinamis oleh Admin). Simulasi E-Wallet dipakai untuk debug frontend sebelum integrasi Midtrans deeplink redirect di backend. Batas waktu 1 jam & penerbitan E-Tiket ke menu Tiket |
| **Alur Tiket Saya & Pengajuan Refund** | `lib/screens/ticket/ticket_screen.dart`, `lib/screens/refund/*.dart` | ✅ | Daftar tiket Aktif/Riwayat/Refund, detail pembatalan, form rekening bank/e-wallet, dan pelacakan status refund |
| **Data Access Layer & Dummy Database** | `lib/services/data_service.dart`, `lib/data/db_dummy.dart` | ✅ | Penyimpanan state reaktif terpusat untuk Konser, Kota, Akun User, Persetujuan, Tiket, dan pembaruan media konser |
