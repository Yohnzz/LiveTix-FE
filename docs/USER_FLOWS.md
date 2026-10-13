# USER FLOWS — LiveTix Concert Booking

Dokumen ini mendokumentasikan alur navigasi dan interaksi pengguna di aplikasi LiveTix berdasarkan prototype dan desain Figma yang telah diimplementasikan.

---

## 1. Alur Masuk Pertama Kali (Guest Flow)
1. **Splash Screen**
   - Muncul logo LiveTix (`assets/images/livetix-logo.png`) di latar gelap (`#070B14`).
   - Otomatis berpindah ke **Home Guest** (`HomeScreen(isGuest: true)`).
2. **Modal Permohonan & Persetujuan (Agreement Dialog)**
   - Saat Home Guest terbuka untuk pertama kali, modal/overlay persetujuan langsung muncul.
   - Tombol **Lanjutkan** terkunci (*disabled*) sampai kotak checkbox *"Saya sudah membaca dan setuju..."* dicentang.
   - Setelah dicentang dan tombol ditekan, modal tertutup dan Guest dapat menjelajah konser di Home.
3. **Pencarian Konser Interaktif (Homepage Search)**
   - Kolom pencarian di beranda kini berupa `TextField` interaktif dengan auto-filter konser secara real-time berdasarkan judul artis/konser, venue, maupun kategori musik.
4. **Navigasi 4 Tab untuk Guest**:
   - **Beranda**: Menjelajah banner festival pilihan dan daftar konser segera hadir.
   - **Jelajah**: Menjelajahi kota populer, filter genre, dan konser trending.
   - **Tiket**: Menampilkan kotak bergaris putus-putus (*dashed border*) bertuliskan *"Tidak Ada Tiket"* dan tautan interaktif (*href*) *"Silahkan Login Terlebih Dahulu"* yang langsung mengarahkan ke halaman login.
   - **Akun**: Menampilkan profil Guest dengan statistik 0, dan tombol langsung *"Masuk ke Akun"* di bawah kartu profil tanpa langkah berbelit.

---

## 2. Alur Pemulihan Kata Sandi & OTP
1. **Halaman Lupa Kata Sandi** (`ForgotPasswordScreen`)
   - Header festival ungu bergradasi dengan ilustrasi gembok & kunci (`assets/images/forgot-password-logo.png`).
   - Form email pemulihan (dimulai kosongan).
   - Tombol **Masuk** (pemicu OTP) memvalidasi email dan membawa pengguna ke verifikasi OTP.
2. **Halaman Verifikasi OTP** (`OtpScreen`)
   - Header festival dengan ilustrasi smartphone & tameng verifikasi (`assets/images/verification-otp-logo.png`).
   - Box rounded berisi 5 kolom bergaris bawah (*underline*) untuk input 5 digit OTP secara otomatis berpindah fokus antar kotak.
   - Tombol **Masuk** memverifikasi kode 5 digit, lalu membawa pengguna ke form reset kata sandi baru.
3. **Halaman Kata Sandi Baru** (`ResetPasswordScreen`)
   - Menampilkan input kata sandi baru dan konfirmasi kata sandi dengan toggle visibilitas mata.
   - Tombol **Kirim data**: memvalidasi kecocokan kedua sandi, menampilkan notifikasi sukses, lalu kembali ke **Halaman Login**.

---

## 3. Alur Autentikasi (Login & Register)
1. **Halaman Login**
   - Form input Email & Kata Sandi **bersih/kosong saat pertama kali dibuka** (tanpa data default).
   - Tombol **Masuk** memvalidasi dan langsung membawa pengguna ke **Home User (Logged-in)**.
   - Tombol Google Sign-in dengan aset logo asli (`assets/images/google-logo.png`).
2. **Halaman Registrasi**
   - Form input Nama, Email, Nomor HP, Kata Sandi, Role dropdown, dan Checkbox **bersih/kosong saat dibuka**.
   - Tombol **Daftar** berhasil mendaftarkan akun dan langsung masuk ke **Home User**.

---

## 4. Alur Pengguna Terautentikasi (User Flow)
1. **Beranda & Profil Header**:
   - Salam personal (*"Halo, Rafi - Malam ini ada apa?"*), tombol tema, dan avatar inisial RF. Klik avatar langsung membuka tab **Akun**.
2. **Tab Tiket User**:
   - Tab "Aktif": Kartu e-ticket aktif lengkap dengan kode booking (`#LTX-2026-9881`), status, detail venue, dan ikon QR code.
   - Tab "Riwayat": Daftar tiket konser yang telah selesai dihadiri.
3. **Tab Akun User**:
   - Kartu profil lengkap dengan nama, email, inisial RF, dan tombol edit.
   - Statistik riil: **12 Tiket dibeli**, **9 Konser dihadiri**, **4 Ulasan**.
   - Menu pengaturan Akun (Edit profil, Metode pembayaran, Notifikasi).
   - Preferensi (Switch mode tampilan Light/Dark, Bahasa Indonesia).
   - Menu Bantuan, Syarat & Ketentuan, Kebijakan Privasi, serta tombol **Keluar dari akun** untuk kembali ke mode Guest.
