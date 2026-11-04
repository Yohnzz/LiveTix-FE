# USER FLOWS - LiveTix Concert Booking

Dokumen ini mendokumentasikan alur navigasi, aturan tampilan data, dan integrasi media konser pada aplikasi LiveTix untuk kebutuhan tim pengembang.

---

## 1. Alur Masuk Pengunjung & Persetujuan Sekali Tampil (Guest Flow)
1. **Splash Screen**
   - Menampilkan logo LiveTix di latar gelap (`#070B14`), lalu mengarahkan ke **Home Guest** (`HomeScreen(isGuest: true)`).
2. **Modal Permohonan & Persetujuan (`AgreementDialog`)**
   - Saat aplikasi dibuka dan pengguna **belum pernah menyetujui** (`DataService().hasAcceptedAgreement == false`), modal persetujuan ditampilkan.
   - Setelah kotak persetujuan dicentang dan tombol **Lanjutkan** ditekan, `DataService().acceptAgreement()` menyimpan status persetujuan ke `LocalStorage` (`livetix_agreement_accepted = true`) dan state sesi dummy.
   - Pada kunjungan berikutnya, saat berpindah kembali ke mode Guest, maupun saat halaman dimuat ulang di browser, modal persetujuan **tidak ditampilkan lagi**.
3. **Beranda (Dashboard)**
   - **Kartu Profil Header Guest**: Menggantikan teks sapaan lama dengan kartu identitas berisi logo profil siluet vektor navy (`GuestAvatarIcon`), nama **`Guest`**, keterangan **`ID : -`**, serta tombol **`Masuk`** di sebelah kanan di dalam card yang mengarahkan ke halaman Login.
   - **Highlight Carousel**: Menampilkan beberapa konser unggulan yang dapat digeser manual (*swipe/drag*) maupun bergeser otomatis setiap 4 detik. Indikator bulat/titik ditampilkan **berjajar horizontal sebaris (inline)** dan **rata tengah** (*center*) di bawah kartu tanpa penomoran `1/5` dan tanpa tombol *pause*.
   - **Seksi "Konser Trending"**:
     - Menampilkan **maksimal 5 konser** yang sesuai dengan filter kategori (`Semua`, `Pop`, `Rock`, `Indie`) maupun kata kunci pencarian aktif di Beranda.
     - Tepat di bawah daftar 5 konser tersebut terdapat tombol **"Lihat Semua konser yang ada"** yang langsung memindahkan pengguna ke tab **Jelajah** untuk melihat seluruh daftar konser.
4. **Tab Jelajah (`ExploreScreen`)**
   - Baris filter atas hanya memuat filter **Tanggal** (dialog pemilihan tanggal, bulan, dan tahun lengkap dengan tombol **Today** dan **Hapus**) serta filter **Harga** (`Semua Harga`, `Termurah (< Rp50.000)`, `Rp50.000 - Rp150.000`, `Rp151.000 - Rp200.000`, `Termahal (> Rp200.000)`).
   - Seksi **Kota Populer** menampilkan tombol kota tanpa keterangan jumlah event. Saat salah satu kota diklik, tombol kota menampilkan efek bayangan belakang (*shadow*) berwarna `#C654C3`.
5. **Tab Akun pada Mode Guest (`ProfileScreen`)**
   - Hanya menampilkan kartu identitas **Guest** dan tombol utama **"Masuk ke Akun"** tanpa statistik maupun menu pengaturan milik pengguna yang sudah login.

---

## 2. Alur Aset Gambar Konser dari Produser ke Tampilan User
Untuk mendukung fitur unggah konser oleh role **Produser**, alur penempatan gambar di sisi User telah distandarkan menjadi dua format:
1. **Gambar Highlight Persegi Panjang (`bannerImageUrl` / `bannerImageBytes`)**
   - Diunggah oleh Produser dalam proporsi persegi panjang (*landscape* ~`16:9`).
   - Ditampilkan penuh (*full-bleed*) pada kartu **Highlight Carousel** di Beranda.
   - Ketika pengguna mengklik konser dan masuk ke **Detail Konser** (`ConcertDetailScreen`), bagian **paling atas** layar menggunakan komponen **Banner Highlight Persegi Panjang** yang sama (`ConcertHighlightBannerSurface`).
   - Selama Produser belum mengunggah gambar, sistem menampilkan visual gradien panggung dan motif piringan konsentris secara otomatis.
2. **Gambar Logo / Poster Persegi (`logoImageUrl` / `logoImageBytes`)**
   - Diunggah oleh Produser dalam proporsi persegi (`1:1`).
   - Ditampilkan pada kotak thumbnail di sebelah kiri kartu daftar konser, baik di daftar **"Konser Trending"** pada Beranda (`ConcertCard`) maupun di daftar konser pada halaman **Jelajah** (`ExploreScreen`).

---

## 3. Alur Pengguna Terautentikasi & Edit Profil (`EditProfileScreen`)
1. **Beranda & Kartu Profil Reaktif (ID 6 Karakter)**
   - Menampilkan kartu identitas berisi avatar profil (`UserAvatar`, default menggunakan siluet vektor navy yang sama hingga pengguna mengunggah foto atau memilih tema warna inisial), nama lengkap pengguna, dan **`ID : <6 karakter>`** (selalu tepat 6 karakter alfanumerik/angka lewat `UserModel.displayId`, contoh `ID : 123456`). Mengetuk kartu profil langsung membuka tab **Akun**.
2. **Edit Profil (`ProfileScreen` -> `EditProfileScreen`)**
   - **Ganti Foto Profil**: Pengguna dapat memilih foto langsung dari perangkat (`PhotoPicker`), mengganti tema warna avatar inisial (5 pilihan warna kontras tinggi), atau menghapus foto kembali ke inisial.
   - **Edit Nama**: Mengubah nama lengkap pengguna, memvalidasi input, dan memperbarui `DataService.currentUserNotifier` secara instan.
   - **Ganti Password (2 Skenario)**:
     - **Skenario 1 (Ingat Password Lama)**: Klik tombol **Ganti Password** -> muncul form `[Masukkan Password Lama, Password Baru, Confirm Password]` -> validasi password lama terhadap akun aktif -> klik **Simpan Password** -> kata sandi diperbarui (*Done*).
     - **Skenario 2 (Lupa Password)**: Klik tombol **Ganti Password** -> pengguna lupa password lamanya -> klik tombol **Lupa Password?** -> masuk ke halaman **Lupa Kata Sandi** (`ForgotPasswordScreen`) untuk verifikasi email akun aktif -> lanjut ke **Verifikasi OTP** (`OtpScreen`, 5 digit kode verifikasi) -> lanjut ke **Buat Kata Sandi Baru** (`ResetPasswordScreen`) -> kata sandi baru tersimpan di `DataService` dan pengguna kembali langsung ke halaman **Edit Profil** dengan pesan konfirmasi (*Done*).

---

## 4. Alur Pemesanan, Multi-Metode Pembayaran (1 Jam), QR Multi-Scan, & Refund
1. **Detail Konser -> Pilih Tiket -> Ringkasan Pesanan (`SelectTicketScreen` -> `OrderSummaryScreen`)**:
   - Guest yang menekan *"Pesan tiket"* diarahkan lewat dialog *"Wajib Masuk"* ke halaman Login.
   - User terautentikasi memilih area panggung (VIP Lounge, Festival, Tribun A/B) dan jumlah tiket (**maksimal 4 tiket per transaksi**), lalu menekan **Pilih Metode** pada halaman Ringkasan Pesanan.
2. **Pemilihan Metode Pembayaran (`PaymentMethodScreen`) & Batas Waktu 1 Jam (`PaymentScreen`)**:
   - Pengguna diberikan 3 kategori metode pembayaran dengan batas waktu kedaluwarsa **1 Jam (`01:00:00`)**:
     - **QRIS (1 Jenis)**:
       - Menampilkan perkiraan biaya admin transaksi (contoh: `Rp1.000`) yang langsung ditambahkan ke total tagihan.
       - Masuk ke halaman **Barcode QRIS** (`assets/images/qrcode.png` untuk testing, siap diganti URL/byte backend), memperlihatkan rincian item, biaya layanan, biaya admin transaksi, dan total pembayaran -> konfirmasi pembayaran -> **Pembayaran Berhasil**.
     - **E-Wallet (Dropdown: `GoPay`, `DANA`, `ShopeePay`)**:
       - Menampilkan perkiraan biaya admin transaksi (contoh: `Rp1.500`) pada masing-masing provider yang langsung ditambahkan ke total pesanan.
       - Masuk ke halaman **Detail Pembayaran** yang menampilkan harga total, rincian item tiket, biaya layanan, biaya admin platform, biaya admin transaksi provider, status **`Menunggu pembayaran`**, hitung mundur **1 Jam**, dan tombol **`Lanjut ke Aplikasi <GoPay / DANA / ShopeePay>`**.
       - Menekan **`Lanjut ke Aplikasi <Provider>`** mengarahkan ke halaman simulasi aplikasi E-Wallet (`EWalletPaymentAppScreen`) dengan nominal tagihan yang sudah terkunci otomatis, sehingga pengguna cukup memasukkan **6 digit PIN E-Wallet**.
       - **Catatan Arsitektur Midtrans**: Tampilan redirect ke aplikasi e-wallet ini (`EWalletPaymentAppScreen`) saat ini digunakan khusus untuk kebutuhan debug / simulasi testing frontend. Pada arsitektur backend produksi, integrasi akan menghubungkan Payment Gateway Midtrans dengan mengambil deeplink redirect langsung ke masing-masing aplikasi e-wallet di smartphone pengguna.
       - Saat pengguna kembali ke halaman Detail Pembayaran di LiveTix, tersedia **2 tombol**: **`Cek Pembayaran`** dan **`Lanjut ke Aplikasi`**.
       - Apabila pembayaran sudah diselesaikan lewat PIN, menekan **`Cek Pembayaran`** langsung mengarahkan pengguna ke **Menu `Tiket`** (`HomeScreen(initialNavIndex: 2)`) dan memunculkan tiket yang baru terbeli. Apabila belum dibayar, status tetap **`Menunggu pembayaran`** mengikuti sisa waktu **1 Jam**.
     - **Bank (Dropdown: `BCA`, `Mandiri`, `BRI`, `SeaBank`)**:
       - Menampilkan perkiraan biaya admin transaksi (contoh: `Rp2.500`) yang langsung ditambahkan ke total tagihan.
       - Menampilkan kode/nomor Virtual Account dan panduan yang disesuaikan dengan aturan aplikasi masing-masing bank: **BCA** (`m-Transfer > BCA Virtual Account` kode `8808`), **Mandiri** (`Livin' by Mandiri > Bayar > Multipayment` kode penyedia jasa `89022`), **BRI** (`BRImo > Tagihan > BRIVA` kode `77889`), dan **SeaBank** (`Aplikasi SeaBank > Transfer > Virtual Account` kode `7821`).
   - **Fleksibilitas Pengaturan Biaya Admin oleh Admin**: Besaran perkiraan biaya admin transaksi per kanal (QRIS, GoPay, DANA, ShopeePay, BCA, Mandiri, BRI, SeaBank) dikelola secara terpusat dan aman diatur atau diubah dinamis oleh pihak Admin melalui `DataService.setTransactionFee`.
3. **Sistem 1 QR Code Multi-Scan (Maks 4x) & Fitur `Bagikan QR` Ber-Watermark `LiveTix`**:
   - Seluruh tampilan QR Code di aplikasi menggunakan komponen terpusat `AppQrCodeView` (`lib/widgets/qr_code_view.dart`) yang merender sementara `assets/images/qrcode.png` untuk pengujian user, dan siap menerima `qrCodeUrl` / `qrCodeBytes` langsung dari backend saat integrasi selesai.
   - Pembelian hingga 4 tiket dalam satu pesanan menerbitkan **1 QR Code tunggal** yang dapat dipindai sebanyak jumlah tiket (`qrScanQuota`, maksimal 4 kali scan di gate).
   - Tombol **`Bagikan QR`** pada E-Tiket menghasilkan gambar PNG kartu tiket gate (`GateQrImageGenerator`) yang memuat **Nama Konser**, **Tanggal Konser**, **Gambar QR Code**, kuota scan gate, serta **Watermark `LiveTix`**, lalu memanggil fitur **Bagikan (*Share*)** bawaan perangkat agar pengguna dapat mengirimkannya ke chat teman satu rombongan.
4. **Pengajuan Refund (`CancelledTicketDetailScreen`, `RefundDestinationScreen`, `RefundStatusScreen`)**:
   - Apabila konser dibatalkan penyelenggara, QR tiket dinonaktifkan dan pengguna dapat mengajukan pengembalian dana 100% ke rekening Bank atau E-wallet serta memantau statusnya melalui timeline 4 tahap.

---

## 5. Metode Pembayaran di Profil Khusus Penerimaan Refund & Kebijakan Cooldown 1 Minggu
1. **Fungsi Khusus Penerimaan Refund**
   - Menu **Metode pembayaran** pada tab Akun / Profil pengguna (`RefundPaymentMethodScreen`) ditetapkan secara eksklusif untuk mendaftarkan dan menyimpan rekening bank atau akun e-wallet penerima pencairan dana refund (bukan sebagai metode pembayaran checkout pembelian tiket).
2. **Kebijakan Keamanan Cooldown 1 Minggu (7 Hari)**
   - Demi melindungi dana pengguna dari pengambilalihan akun yang tidak sah, setiap kali pengguna menambahkan atau memperbarui rekening refund, sistem mengaktifkan masa perlindungan **cooldown selama 1 minggu (7 hari)**.
   - Selama masa cooldown aktif, tombol ubah rekening berada dalam kondisi terkunci (*disabled*) dan kartu status menampilkan sisa hari cooldown serta tanggal pembaruan terakhir.
   - Pengguna baru dapat mengubah rekening refund kembali setelah masa cooldown 7 hari selesai.
   - Tersedia tombol simulasi testing developer (*bypass cooldown*) untuk memudahkan verifikasi pengujian otomatis dan QA.

---

## 6. Relokasi Notifikasi, Tombol Favorit (Love), Filter Disukai (Maks 10), & Global Dark Mode
1. **Pembersihan Halaman Profil & Relokasi Notifikasi ke Dashboard Beranda**:
   - Menu **Bahasa** dan **Notifikasi** telah dihapus dari halaman Profil (`ProfileScreen`).
   - Ikon notifikasi direlokasi ke kartu profil header pada Dashboard Beranda (`HomeScreen`), ditempatkan tepat di sebelah kiri tanda panah `>` pada kartu User atau di baris aksi pada kartu Guest.
   - Ikon notifikasi dilengkapi badge penomoran di atas titik yang menampilkan angka `3` (menandakan 3 notifikasi belum dibaca).
   - Mengetuk ikon notifikasi menampilkan modal bottom sheet daftar notifikasi interaktif (pemberitahuan tiket terbit, pengingat konser, dan promo).
2. **Tombol Favorit (Love) & Warna Pink (`#E91E8C`)**:
   - Tombol berbentuk hati (`Icons.favorite_border_rounded`) disematkan pada kartu Highlight Carousel di Beranda (`FeaturedConcertCard`) dan pada top bar halaman Detail Konser (`ConcertDetailScreen`).
   - Ketika diklik, ikon berganti menjadi terisi (`Icons.favorite_rounded`) dengan warna pink cerah `#E91E8C` (`AppColors.favoritePink`).
   - Status konser favorit tersimpan secara terpusat di `DataService.favoriteConcertIdsNotifier` dan disimpan ke penyimpanan lokal (`LocalStorage.getStringList` / `setStringList`), sehingga tersinkronisasi otomatis di seluruh halaman.
3. **Filter Kategori "Disukai" di Beranda & Jelajah (Dual-Filtering & Limit 10 Konser)**:
   - Ditambahkan opsi filter "Disukai" pada baris kategori / genre di Beranda (`HomeScreen`) dan Jelajah (`ExploreScreen`).
   - Bekerja secara filter ganda (*dual-filtering*):
     - Saat "Disukai" aktif dan pengguna memilih genre tertentu (misal: "Rock"), sistem menyaring konser yang bergenre Rock DAN berstatus disukai (favorit).
     - Saat "Disukai" di-unclick, sistem kembali ke filter tunggal genre ("Rock").
   - Jumlah konser hasil filter dibatasi maksimal 10 konser (`limit: 10`) untuk menjaga kerapian tata letak antarmuka.
4. **Arsitektur Tema Global Dark Mode (Default Dark pada Data Dummy)**:
   - Opsi switch "Mode tampilan" pada halaman Profil mengendalikan tema global seluruh aplikasi melalui `DataService.isDarkModeNotifier` dan `ValueListenableBuilder` di `main.dart`.
   - Mengubah tema di Profil langsung memperbarui seluruh tampilan aplikasi secara instan (Beranda, Jelajah, Tiket, Profil, Dialog, Bottom Navigation Bar / homebar, dan halaman checkout).
   - Preferensi tema tersimpan di `LocalStorage` (`livetix_theme_dark`).
   - Pada data awal (dummy state), tema diatur default ke **Dark** dengan latar gelap `#0B1120`, kartu `#1E293B`, border `#334155`, teks `#F8FAFC`, dan teks sekunder `#94A3B8` yang memenuhi standar kontras WCAG AA.
