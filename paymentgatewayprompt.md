## 1. Aturan Keamanan (WAJIB)
- **Server Key Midtrans tidak boleh ada di aplikasi Flutter.** Semua pemanggilan Midtrans (charge, status, refund, payout) dilakukan dari **backend**. Flutter hanya memanggil API backend. Client Key boleh di client bila diperlukan.
- Simpan kunci di environment variable (`.env`), bukan di source code.
- **Status pembayaran hanya boleh berubah lewat webhook (HTTP Notification) Midtrans yang sudah diverifikasi**, bukan dari klaim client.
- Verifikasi `signature_key` pada setiap webhook: `SHA512(order_id + status_code + gross_amount + ServerKey)`. Tolak jika tidak cocok. Sebagai pengaman tambahan, panggil Get Transaction Status API sebelum menandai lunas.
- Webhook harus **idempotent**. Notifikasi yang sama diterima dua kali tidak boleh membuat tiket ganda atau saldo ganda.
- Semua perhitungan uang di backend dengan integer (rupiah, tanpa desimal), jangan float. Harga tiket diambil dari database, bukan dari request client.
- Otorisasi per role di backend. Produser hanya bisa mengakses data konser dan saldonya sendiri, admin hanya fee, user hanya tiket dan refund miliknya.

## 2. Pembayaran
Gunakan **Midtrans Core API** (bukan Snap popup/WebView) supaya UI pembayaran sepenuhnya milik LiveTix dan e-wallet bisa langsung membuka aplikasinya. Mulai dari **Sandbox**, dengan konfigurasi mudah dipindah ke Production.

Metode yang disediakan:
1. **QRIS**
   - Backend memanggil charge QRIS, mengambil data QR dari response Midtrans, lalu menampilkannya di Flutter sebagai QR yang bisa discan. **Bukan gambar dummy.**
   - Tampilkan nominal, countdown batas waktu bayar, dan tombol simpan QR.
2. **E-Wallet** (GoPay, ShopeePay, DANA, dan yang didukung akun Midtrans kami; cek yang aktif di dashboard)
   - **Wajib deep link langsung ke aplikasi e-wallet pilihan user.** Gunakan `deeplink_url` / action `deeplink-redirect` dari response charge, lalu buka dengan `url_launcher` (mode external application). Atur `callback_url` agar user kembali ke aplikasi LiveTix setelah bayar.
   - Tangani kasus aplikasi e-wallet belum terpasang atau deep link gagal, dengan fallback ke URL web/QR dari response dan pesan yang jelas.
3. **Transfer Bank (Virtual Account)** untuk bank yang ditentukan: **[ISI: BCA, BNI, BRI, Mandiri (bill), Permata, dll]**
   - Tampilkan nomor VA, bank, nominal, batas waktu, tombol salin, dan petunjuk singkat cara bayar.

Alur transaksi:
1. User pilih tiket, jumlah, dan metode, lalu backend membuat order `PENDING` dengan `order_id` unik, mengunci stok tiket, dan memanggil Midtrans charge.
2. Flutter menampilkan UI sesuai metode (QR / deep link / VA).
3. Flutter memantau status lewat **polling ringan ke backend** (atau realtime kalau sudah ada), dan **backend** yang di-update webhook.
4. Status: `PENDING → PAID`, atau `EXPIRED / CANCELLED / FAILED`. Stok dilepas kembali saat expired atau gagal.
5. Setelah `PAID`, sistem menerbitkan tiket (lihat bagian 3) dan memproses pembagian dana (bagian 4).

Halaman **Detail Pembayaran** menampilkan: nama konser, jumlah tiket, harga, metode, order ID, waktu transaksi, status (pending / berhasil / kedaluwarsa), dan riwayat transaksi user.

## 3. Tiket & QR Code
- QR tiket **dibuat oleh sistem setelah status PAID**, tidak sebelumnya dan tidak dari data statis.
- Setiap tiket punya kode unik yang tidak bisa ditebak (UUID/token acak, atau ditandatangani HMAC). Simpan di database dan hubungkan dengan order, user, dan konser.
- Render QR di Flutter dari kode tersebut (mis. `qr_flutter`). Halaman **Tiket Saya** menampilkan QR, detail konser, dan status tiket: `AKTIF / SUDAH DIPAKAI / DIREFUND`.
- Disediakan endpoint validasi tiket untuk check-in. Tiket yang sudah dipakai atau direfund tidak valid lagi.
- Tiket berstatus `DIREFUND` harus langsung tidak bisa dipakai.

## 4. Pembagian Dana & Biaya Admin 3%
Setiap transaksi `PAID`:
- `fee_admin = 3% × total_transaksi` (bulatkan konsisten, tentukan aturan pembulatan dan dokumentasikan)
- `dana_produser = total_transaksi − fee_admin`
- Catat di tabel **ledger/mutasi saldo** (append-only, tidak boleh di-edit atau dihapus): order_id, konser_id, produser_id, gross, fee, net, status, timestamp.
- Saldo produser dan saldo admin **dihitung dari ledger**, bukan angka yang di-update sembarangan.
- Dana produser berstatus **tertahan (pending balance)** sampai konser dimulai (bagian 5), lalu berpindah ke **saldo tersedia**.
- Fee admin 3% masuk ke **saldo admin** dan ditampilkan di halaman **Penarikan Dana Admin**.

## 5. Penarikan Dana Produser
- Produser mengajukan penarikan dari halaman **Penarikan Dana** (saldo tertahan, saldo tersedia, riwayat penarikan, rekening/e-wallet tujuan).
- **Aturan kunci: dana dari sebuah konser hanya bisa ditarik setelah waktu mulai konser (tanggal + jam yang diatur produser) terlewati.** Validasi dilakukan di **backend** dengan waktu server (zona waktu Asia/Jakarta), bukan di client.
- Dana konser yang **dibatalkan** tidak bisa ditarik. Dananya dialihkan untuk refund (bagian 6).
- Validasi: nominal ≤ saldo tersedia, nominal minimum **[ISI, mis. Rp 50.000]**, rekening tujuan valid.
- Eksekusi payout lewat **Midtrans Iris** (disbursement) ke bank/e-wallet produser, atau jika akun Iris belum tersedia, buat **mode simulasi sandbox** dengan antarmuka service yang sama agar mudah diganti. Status: `PENDING → PROCESSING → SUCCESS / FAILED`. Jika FAILED, saldo dikembalikan otomatis lewat entri ledger.
- Cegah **race condition dan double withdraw** (database transaction + row locking atau idempotency key).
- **Admin** punya halaman Penarikan Dana sendiri: total fee terkumpul, riwayat fee per transaksi/konser, dan form tarik dana dengan alur payout yang sama. Admin juga bisa melihat daftar penarikan produser.

## 6. Refund (Konser Dibatalkan)
- Produser dapat membatalkan konser dengan alasan apa pun (alasan wajib diisi). Saat dibatalkan:
  1. Status konser menjadi `DIBATALKAN`, penjualan tiket dihentikan, semua tiket aktif menjadi berhak refund.
  2. User yang terdampak menerima notifikasi.
  3. Penarikan dana untuk konser tersebut terkunci.
- User membuka **Tiket Saya → Ajukan Refund**, lalu memasukkan tujuan refund (**e-wallet atau rekening bank**: jenis, nomor, nama pemilik).
- Nominal refund: **[KONFIRMASI: 100% harga tiket. Fee 3% dikembalikan dari saldo admin untuk transaksi itu, bukan dibebankan ke user.]**
- Eksekusi: karena Refund API Midtrans tidak mendukung semua metode (mis. VA bank dan sebagian QRIS tidak bisa direfund lewat API), gunakan strategi berikut:
  - Metode yang didukung refund API Midtrans → pakai Refund API.
  - Selain itu → kirim **payout via Midtrans Iris** ke rekening/e-wallet yang dimasukkan user.
- Dana refund diambil dari dana tertahan konser tersebut dan fee admin transaksi itu, lengkap dengan entri ledger. Status refund: `DIAJUKAN → DIPROSES → BERHASIL / GAGAL` (gagal bisa diajukan ulang dengan data tujuan baru).
- Satu tiket hanya bisa direfund sekali. Tiket yang sudah dipakai tidak bisa direfund.
- Tampilkan riwayat dan status refund ke user, serta ringkasan refund di dashboard produser dan admin.

## 7. Deliverables
1. Skema database/migration baru: orders, payments, tickets, ledger, withdrawals, refunds (sesuaikan dengan DB yang sudah ada).
2. Endpoint backend: create payment, webhook Midtrans, status pembayaran, daftar tiket, validasi tiket, pengajuan & riwayat withdraw, pembatalan konser, pengajuan refund.
3. Service Flutter + screen: pilih metode bayar, QRIS, e-wallet (deep link), VA, detail pembayaran, tiket saya (QR), withdraw produser, withdraw admin, refund user.
4. Panduan testing sandbox: cara mengatur URL webhook (mis. ngrok) di dashboard Midtrans, akun/nomor tes tiap metode, dan skenario uji.
5. Daftar environment variable yang dibutuhkan.

## 8. Checklist Uji (harus lulus)
- [ ] Bayar QRIS sukses → status PAID → tiket + QR terbit.
- [ ] E-wallet membuka aplikasi e-wallet langsung; kembali ke app setelah bayar.
- [ ] VA: bayar → PAID; tidak dibayar → EXPIRED, stok kembali.
- [ ] Webhook ganda tidak menggandakan tiket/saldo; signature palsu ditolak.
- [ ] Fee 3% tercatat benar dan muncul di saldo admin; sisa 97% ke produser (tertahan).
- [ ] Produser gagal tarik sebelum konser mulai, berhasil setelah mulai.
- [ ] Produser tidak bisa menarik dana konser yang dibatalkan.
- [ ] Konser dibatalkan → user refund ke e-wallet/bank → ledger konsisten, tiket tidak valid.
- [ ] Withdraw bersamaan tidak membuat saldo minus.

## 9. Cara Kerja
Kerjakan bertahap dan pastikan tiap tahap jalan sebelum lanjut: (1) database + backend pembayaran + webhook, (2) UI pembayaran Flutter + tiket QR, (3) ledger + fee, (4) withdraw produser & admin, (5) pembatalan + refund. Di akhir, ringkas apa yang dikerjakan, file yang diubah, dan hal yang masih perlu input saya (kunci API, daftar bank, nominal minimum).