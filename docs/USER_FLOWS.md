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

---

## 5. Alur Pemesanan & Pembayaran Tiket (Checkout Flow)
1. **Pemicu Alur**:
   - Pengguna membuka **Detail Konser** (`ConcertDetailScreen`).
   - Jika Guest menekan tombol *"Pesan tiket"*, muncul modal dialog *"Wajib Masuk"* yang meminta pengguna untuk login terlebih dahulu.
   - Jika User terautentikasi menekan tombol *"Pesan tiket"*, aplikasi langsung mengarahkan ke halaman **Pilih Tiket** (`SelectTicketScreen`).
2. **Langkah 1: Pilih Tiket & Data Pemesan** (`SelectTicketScreen`):
   - Menampilkan **Denah Venue Interaktif**: Visual panggung konser, area FESTIVAL (depan panggung), TRIBUN A, dan TRIBUN B dengan indikator warna status (Hijau = Dipilih, Putih = Tersedia, Abu-abu = Penuh).
   - **Pemilihan Jumlah Tiket**: Counter interaktif `[-] [ 2 ] [+]` dengan batasan maksimal 4 tiket per akun dan sisa kuota (214 tiket).
   - **Data Pemesan**: Form Nama Lengkap dan Email terisi otomatis sesuai akun yang sedang login dan dapat disesuaikan.
   - **Ringkasan Harga Dinamis**: Menghitung subtotal tiket, biaya layanan (Rp15.000), dan total sementara.
   - Tombol *"Lanjut ke pembayaran"* membawa pengguna ke Ringkasan Pesanan.
3. **Langkah 2: Ringkasan Pesanan** (`OrderSummaryScreen`):
   - Stepper 3-tahap berada di tahap **1. Ringkasan** (Aktif).
   - Menampilkan kartu info konser dengan badge tanggal ungu (OKT 12), waktu, venue, serta tag "2 tiket festival", "Gate B", dan "FEST-04".
   - Rincian pembayaran lengkap: Tiket, Biaya Layanan (Rp15.000), Pajak & Admin (Rp91.500), serta Total Tagihan (Rp1.006.500).
   - Banner jaminan keamanan & proteksi tiket resmi promotor 100% valid.
   - Tombol *"Pilih Metode"* melanjutkan ke halaman pembayaran.
4. **Langkah 3: Selesaikan Pembayaran** (`PaymentScreen`):
   - Stepper 3-tahap berada di tahap **2. Bayar** (Aktif).
   - **Hitung Mundur Pembayaran (Live Countdown)**: Menghitung mundur waktu pembayaran (23 Jam : 59 Menit : 12 Detik) secara real-time.
   - Kartu BCA Virtual Account dengan status badge *"Menunggu pembayaran"*, nomor VA `8808 1234 5678 9012`, nominal tagihan `Rp1.006.500`, nama akun `Soundwave Fest Official`, dan tombol *Salin* ke clipboard.
   - Petunjuk 3 langkah cara membayar via BCA Mobile / KlikBCA / ATM BCA.
   - Banner peringatan kuning agar tidak menutup halaman sebelum transaksi diverifikasi.
   - Tombol *"Saya Sudah Bayar"* memicu simulasi verifikasi perbankan otomatis dan menerbitkan tiket.
5. **Langkah 4: E-Tiket & Bukti Pembayaran Berhasil** (`PaymentSuccessScreen`):
   - Stepper 3-tahap berada di tahap **3. E-Tiket** (Selesai).
   - Ikon centang hijau dengan aura bersinar dan pesan *"Pembayaran berhasil! Tiket resmi telah diterbitkan"*.
   - **Kartu Tiket Fisik Digital**: Berbentuk tiket konser dengan lekukan notch (*half-circle cutout*) kiri-kanan dan garis putus-putus (*dashed separator*).
   - Berisi badge *TIKET RESMI*, rincian nama pemesan, kategori & jumlah tiket, Gate B, Blok FEST-04, graphic QR Code berstandar verifikasi gate, dan Kode Booking unik `SWF-8891-2A`.
   - Tombol aksi *"Unduh"* dan *"Bagikan"*.
   - Tombol utama *"Kembali ke Home"*: Secara dinamis mendaftarkan e-tiket baru ini ke `DummyDataService` (sehingga langsung masuk ke tab **Tiket Saya**) dan mengembalikan pengguna ke beranda.

---

## 6. Alur Pembatalan Konser & Pengajuan Refund Dana
1. **Status Tiket di Tab Tiket Saya** (`TicketScreen`):
   - Tiket konser memiliki status yang jelas:
     - **Aktif**: Badge hijau (`#ECFDF5` / `#10B981`) untuk tiket yang siap digunakan saat konser berlangsung.
     - **Reffund**: Badge merah muda (`#FEE2E2` / `#EF4444`) untuk tiket konser yang dibatalkan oleh pihak produser/penyelenggara.
   - Kartu tiket menampilkan garis tepi warna (biru/magenta), icon konsentris, sisa hari, dan tombol **Lihat tiket**.
2. **Detail Tiket Dibatalkan & Rincian Refund** (`CancelledTicketDetailScreen`):
   - Ketika pengguna menekan **Lihat tiket** pada tiket konser yang dibatalkan:
   - Muncul header festival dengan badge **Event dibatalkan**.
   - Menampilkan kartu QR code yang dimatikan dengan pesan *"QR tidak berlaku · tiket dibatalkan"*.
   - Menampilkan kartu **Rincian refund**: Nilai tiket dasar, biaya layanan, dan **Total refund 100%** (misal Rp1.006.500).
   - Keterangan batas akhir pengajuan (30 Nov 2026) dan estimasi pencairan (3–7 hari kerja).
   - Tombol **Ajukan refund** untuk melanjutkan ke pemilihan rekening/e-wallet.
3. **Pemilihan Tujuan Refund** (`RefundDestinationScreen`):
   - Pengguna dapat memilih pengembalian dana melalui **Bank** (BCA, Mandiri, BNI, BRI) atau **E-wallet** (GoPay, OVO, DANA, ShopeePay).
   - Form memasukkan nama pemilik rekening dan nomor rekening / nomor e-wallet.
   - Banner peringatan kuning agar memastikan kebenaran nomor rekening agar dana tidak hilang.
   - Kotak centang persetujuan *"Saya memastikan data di atas sudah benar"*.
   - Tombol **Lanjutkan** membuka modal konfirmasi.
4. **Pemeriksaan Data (Bottom Sheet)**:
   - Modal konfirmasi akhir menampilkan rincian nama bank/e-wallet, nomor rekening, nama pemilik, dan jumlah refund.
   - Terdapat pilihan **Ubah data** untuk memperbaiki jika ada kesalahan, dan **Ya, data sudah benar** untuk mengirim pengajuan.
5. **Tracking Status Refund** (`RefundStatusScreen`):
   - Header ungu-magenta menampilkan badge **Sedang diproses**, nominal refund, dan ID Transaksi (misal `ID RFD-20261019-0042`).
   - Vertical Stepper Timeline 4 tahap:
     - Tahap 1: *Refund diajukan* (Selesai).
     - Tahap 2: *Diverifikasi penyelenggara* (Selesai).
     - Tahap 3: *Dana sedang dikirim* (Sedang aktif: menunggu transfer ke rekening user).
     - Tahap 4: *Refund selesai* (Menunggu notifikasi).
   - Kartu informasi rekening/e-wallet tujuan transfer.
   - Tombol **Kembali Ke Beranda** dan tombol **Hubungi bantuan** untuk bantuan customer service 24 jam.
