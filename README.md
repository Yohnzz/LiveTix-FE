# LiveTix Mobile — Sistem Manajemen Konser & Penjualan Tiket

LiveTix adalah platform tiket konser berbasis Flutter (Frontend) dan Supabase (Backend PostgreSQL, RLS, Edge Functions) dengan integrasi Midtrans Payment Gateway (Snap & Iris Sandbox).

Aplikasi ini mendukung 4 role utama: **User (Penonton)**, **Produser (Promotor)**, **Admin (Super Admin)**, dan **Gate Crew (Petugas Pintu Masuk)**.

---

## 👥 Alur & Fitur Berdasarkan Role

### 1. 🎟️ Role User (Penonton / Pembeli Tiket)
Alur penonton mulai dari eksplorasi event hingga kehadiran di venue atau pengajuan refund:

1. **Autentikasi & Akun**:
   - Pendaftaran akun dengan verifikasi data & OTP.
   - Login via email & password atau Google Sign-In.
   - Manajemen profil, riwayat pesanan, dan metode pengembalian dana.
2. **Eksplorasi & Pemilihan Konser**:
   - Beranda interaktif: pencarian konser, filter genre, lokasi venue via peta interaktif (OpenStreetMap / Mapbox).
   - Halaman detail konser: deskripsi artis, jadwal acara, countdown, dan pemilihan tier tiket (Festival, VIP, VVIP).
3. **Checkout & Pembayaran Transparan (Fase 1, 2, 3)**:
   - Pemilihan jumlah tiket (maksimal 4 tiket per transaksi).
   - Rincian harga 5 baris transparan:
     - `Harga Tiket`: Rp (Harga Satuan x Jumlah)
     - `Pajak Hiburan Daerah (10%)`: Rp (10% x Harga Tiket)
     - `Biaya Layanan Aplikasi (2%)`: Rp (2% x Harga Tiket)
     - `Subtotal`: Harga Tiket + Pajak + Biaya Aplikasi
     - `Pembulatan (Ratusan ke Ribuan)`: Menjadikan total kelipatan Rp 1.000 ke atas
     - `Total Pembayaran`: Nilai final yang ditagihkan ke user
   - Integrasi Midtrans Snap Sandbox: pembayaran via QRIS, Virtual Account (BCA, Mandiri, BRI, BNI), atau E-Wallet (GoPay, ShopeePay).
4. **Penerbitan E-Tiket Aman (Fase 4)**:
   - Setelah pembayaran sukses (`settlement`), sistem menerbitkan e-tiket dengan kode unik dan QR Code bertanda tangan digital HMAC-SHA256 (`v1.<ticket_id>.<kode_tiket>.<signature>`).
   - Tidak membocorkan NIK atau data pribadi plaintext di dalam QR Code.
5. **Check-in di Hari Konser**:
   - Menunjukkan e-tiket di pintu masuk venue untuk di-scan oleh Gate Crew.
6. **Alur Refund 100% jika Konser Batal (Fase 7)**:
   - Jika konser dibatalkan oleh promotor/admin, e-tiket otomatis bertanda "Dibatalkan" dan QR Code dinonaktifkan.
   - User mengakses halaman detail tiket batal dan mengisi rekening tujuan refund (Bank Transfer atau E-Wallet).
   - Pengembalian dana 100% dari total yang dibayar (termasuk pajak dan biaya layanan).

---

### 2. 🎪 Role Produser (Promotor Penyelenggara Konser)
Alur promotor dari perancangan konser hingga pencairan pendapatan:

1. **Pendaftaran & Verifikasi Legalitas Promotor**:
   - Pengajuan verifikasi profil produser (KTP, NPWP, NIB, rekening bank operasional).
   - Status verifikasi dipantau secara real-time hingga disetujui Super Admin.
2. **Manajemen & Publikasi Konser**:
   - Pembuatan event konser baru: informasi umum, tanggal & waktu pelaksanaan, penentuan koordinat venue pada peta.
   - Konfigurasi tier tiket: nama tier, kuota tiket, dan harga satuan.
   - Pengajuan konser ke Admin untuk approval publikasi.
3. **Dasbor Penjualan & Pemantauan Kuota**:
   - Grafik penjualan tiket real-time, sisa kuota per tier, dan total pendapatan kotor.
4. **Penarikan Dana / Payout (Fase 5)**:
   - **Saldo Tertahan (Held Balance)**: Dana dari konser yang belum berlangsung ditahan di server dan belum dapat ditarik untuk melindungi hak penonton.
   - **Saldo Tersedia (Available Balance)**: Dana otomatis siap ditarik setelah waktu mulai konser (`start_time <= NOW()`) dan konser tidak dalam status dibatalkan.
   - Form penarikan dana dengan validasi minimum Rp 50.000 dan proteksi anti-penarikan ganda.
   - Pencairan via Midtrans Iris Sandbox: jika transfer bank gagal, sistem otomatis melakukan pembalikan kredit (*credit reversal*) ke saldo produser.
5. **Pengajuan Pembatalan Konser (Fase 7)**:
   - Form pembatalan resmi: kategori alasan (Perizinan, Venue, Keamanan, Force Majeure), penjelasan tertulis, dan unggahan surat pemberitahuan.
   - Setelah diajukan atau disetujui admin, seluruh dana konser dikunci untuk dialokasikan ke refund penonton 100%.

---

### 3. 🛡️ Role Admin (Super Admin LiveTix)
Alur pengawasan platform, verifikasi, pendapatan aplikasi, dan monitoring refund:

1. **Moderasi & Approval Konser**:
   - Meninjau pengajuan konser baru dari produser (verifikasi kelayakan, dokumen, dan tier harga).
   - Menyetujui (*Approve*) atau menolak (*Reject*) pengajuan konser beserta alasannya.
2. **Monitoring Transaksi & Pembatalan**:
   - Dasbor pengawasan transaksi paid, pending, dan cancelled di seluruh platform.
   - Evaluasi dan persetujuan pengajuan pembatalan konser dari produser.
3. **Penarikan Dana Admin / Fee Platform (Fase 6)**:
   - Saldo fee admin terdiri dari 2 komponen terpisah:
     - **Biaya Layanan Aplikasi (2%)** dari setiap penjualan tiket.
     - **Pendapatan Pembulatan Ribuan**.
   - Admin dapat menarik dana fee ini **kapan saja** tanpa harus menunggu konser selesai.
   - Form penarikan khusus akun berwenang (*server-side role guard* & RLS) dengan pencatatan mutasi debit ke ledger admin.
4. **Monitoring Refund Masal (Fase 7)**:
   - Dasbor pemantauan progres refund per konser: jumlah tiket selesai direfund, sedang diproses di bank, atau menunggu rekening pembeli.
5. **Audit Rekonsiliasi Keuangan (Fase 8)**:
   - Menjalankan audit otomatis melalui RPC database untuk memastikan invarian pembagian pendapatan:
     $$\text{Bagian Produser} + \text{Bagian Admin} = \text{Total Bayar}$$
   - Memastikan buku besar (*ledger*) tidak mengalami selisih atau anomali saldo.

---

### 4. 📱 Role Gate Crew (Petugas Pemeriksa Tiket Venue)
Alur operasional di lapangan saat hari pelaksanaan konser:

1. **Login & Penugasan Pos Gate**:
   - Login akun staf gate crew resmi.
   - Memilih pos gerbang masuk (Gate A, Gate B, Gate VIP, dll.).
2. **Pemindaian QR Tiket Cepat & Offline-Resilient (Fase 4)**:
   - Scanner kamera aktif dengan laser pemandu.
   - Validasi QR via RPC database / Edge Function `validate-ticket`:
     - Verifikasi tanda tangan kriptografi HMAC-SHA256.
     - Verifikasi kesesuaian konser dan tier tiket.
     - Pencegahan tiket ganda (*anti double-scan*): tiket yang sudah check-in langsung ditolak jika di-scan ulang.
     - Penolakan tiket yang sudah dibatalkan atau direfund.
3. **Input Kode Manual & Statistik Lapangan**:
   - Opsi input kode tiket manual jika kamera penonton bermasalah atau layar retak.
   - Indikator real-time: total penonton yang telah masuk (*checked-in*), tiket ditolak, dan kapasitas pos gate.

---

## 💰 Rumus Transaksi & Invarian Keuangan

Setiap transaksi tiket di LiveTix mengikuti rumus baku terpusat di server PostgreSQL:

1. $\text{Harga Tiket} = \text{Harga Satuan} \times \text{Jumlah Tiket}$ (maks. 4 tiket)
2. $\text{Pajak Hiburan} = \text{ROUND}(10\% \times \text{Harga Tiket})$
3. $\text{Biaya Aplikasi} = \text{ROUND}(2\% \times \text{Harga Tiket})$
4. $\text{Subtotal} = \text{Harga Tiket} + \text{Pajak Hiburan} + \text{Biaya Aplikasi}$
5. $\text{Total Bayar} = \text{CEIL}(\text{Subtotal} / 1000) \times 1000$ (pembulatan ratusan ke atas)
6. $\text{Pembulatan} = \text{Total Bayar} - \text{Subtotal}$
7. $\text{Bagian Produser} = \text{Harga Tiket} + \text{Pajak Hiburan}$
8. $\text{Bagian Admin} = \text{Biaya Aplikasi} + \text{Pembulatan}$

> **Invarian Mutlak**: $\text{Bagian Produser} + \text{Bagian Admin} \equiv \text{Total Bayar}$ selalu bernilai benar di semua kondisi transaksi.

---

## 🚀 Panduan Menjalankan Proyek

1. **Prasyarat**:
   - Flutter SDK (versi >= 3.24.0)
   - Dart SDK (versi >= 3.5.0)
2. **Instalasi Dependensi**:
   ```bash
   flutter pub get
   ```
3. **Menjalankan Pengujian Otomatis (E2E Test Suite)**:
   ```bash
   flutter test test/e2e_reconciliation_test.dart
   ```
4. **Analisis Kualitas Kode**:
   ```bash
   flutter analyze
   ```
5. **Menjalankan Aplikasi**:
   ```bash
   flutter run
   ```
