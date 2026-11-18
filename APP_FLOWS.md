# Dokumentasi Alur Aplikasi LiveTix (Berdasarkan Role)

Dokumen ini menjelaskan alur operasional, layar (screen), dan interaksi antar-fitur untuk setiap role di aplikasi LiveTix.

---

## 1. Role: User / Penonton

```
[Buka Aplikasi] 
       │
       ▼
[Login / Register / Google Auth]
       │
       ▼
[Beranda / HomeScreen]
       │ ── Cari Konser / Peta Venue
       ▼
[Detail Konser]
       │ ── Pilih Tier Tiket (Maks. 4)
       ▼
[Checkout & Rincian Biaya Transparan]
       │ ── Rincian 5 Baris: Tiket + Pajak 10% + Biaya App 2% + Pembulatan = Total
       ▼
[Pembayaran Snap Midtrans (Sandbox)]
       │ ── QRIS / Virtual Account / E-Wallet
       ▼
[Pembayaran Berhasil / Callback Settlement]
       │
       ▼
[E-Tiket Terbit (QR Bertanda Tangan HMAC-SHA256)]
       │
       ├─── Alur Normal ──────────────────────────► [Check-in di Venue oleh Gate Crew]
       │
       └─── Alur Konser Batal (Force Majeure) ────► [Tiket Dinonaktifkan]
                                                          │
                                                          ▼
                                                   [Form Rekening Refund 100%]
                                                          │
                                                          ▼
                                                   [Status Timeline Refund Masal]
```

### Fitur Utama User:
- **Pencarian Konser & Peta Interaktif**: Menemukan konser berdasarkan genre, tanggal, dan koordinat lokasi venue.
- **Transparansi Biaya 100%**: Tidak ada biaya tersembunyi; rincian pajak hiburan dan biaya aplikasi terpampang jelas sebelum pembayaran.
- **E-Tiket Terenkripsi**: QR Code membawa payload terverifikasi tanpa menyimpan NIK dalam bentuk teks terbaca.
- **Jaminan Refund 100%**: Jika promotor membatalkan konser, dana kembali utuh tanpa potongan.

---

## 2. Role: Produser / Promotor Konser

```
[Login Produser]
       │
       ▼
[Verifikasi Legalitas Penyelenggara (KTP, NPWP, NIB)]
       │
       ▼
[Portal Dasbor Produser]
       │
       ├─── [Kelola Konser] ──► Buat Konser Baru / Atur Tier Tiket / Submit Approval
       │
       ├─── [Keuangan & Payout]
       │          │
       │          ├── Saldo Tertahan (Konser Belum Dimulai): Tidak bisa ditarik
       │          │
       │          └── Saldo Tersedia (Konser Sudah Mulai & Tidak Batal):
       │                    │
       │                    ▼
       │             [Form Penarikan Dana (Min. Rp 50.000)]
       │                    │
       │                    ▼
       │             [Payout Midtrans Iris] ──► Berhasil: Sukses / Gagal: Kredit Balik
       │
       └─── [Pembatalan Konser]
                  │
                  ▼
             [Unggah Alasan & Dokumen Perizinan] ──► Dana Konser Dikunci untuk Refund
```

### Fitur Utama Produser:
- **Proteksi Saldo Tertahan**: Mencegah penarikan dana sebelum konser berlangsung untuk menjamin kepastian acara bagi pembeli.
- **Penarikan Dana Otomatis**: Integrasi payout Iris dengan fitur pembalikan otomatis jika rekening tujuan salah.
- **Manajemen Kuota Real-time**: Memantau kapasitas tiket yang terjual secara live.

---

## 3. Role: Super Admin LiveTix

```
[Login Super Admin]
       │
       ▼
[Admin Shell / Dasbor Utama]
       │
       ├─── [Approval Konser] ──► Tinjau Kelayakan & Setujui / Tolak Konser
       │
       ├─── [Approval Pembatalan] ──► Evaluasi Surat Izin Pembatalan Konser
       │
       ├─── [Monitoring Refund Masal] ──► Pantau Progres Pengembalian Dana Pembeli
       │
       ├─── [Penarikan Dana Admin / Fee Platform]
       │          │
       │          ├── Saldo Biaya Aplikasi (2%)
       │          ├── Saldo Pembulatan Ribuan
       │          │
       │          ▼
       │     [Form Tarik Fee Kapan Saja (Min. Rp 50.000)]
       │
       └─── [Audit Rekonsiliasi Keuangan E2E]
                  │
                  ▼
             [Verifikasi Invarian: Produser + Admin == Total Bayar (Selisih Rp 0)]
```

### Fitur Utama Admin:
- **Kendali Penuh Penjualan**: Hak persetujuan publikasi dan pengawasan pembatalan konser.
- **Pemisahan Dana Fee & Pembulatan**: Rekening kas fee aplikasi terpisah secara transparan dari hak promotor.
- **Audit Otomatis**: Fungsi rekonsiliasi yang memeriksa kesesuaian antara order, transaksi, dan mutasi buku besar.

---

## 4. Role: Gate Crew (Petugas Pintu Masuk)

```
[Login Gate Crew]
       │
       ▼
[Pilih Pos Gerbang (Gate A / B / VIP)]
       │
       ▼
[Kamera Pemindai QR Aktif (Laser Scanner)]
       │
       ▼
[Validasi Tiket ke Server (RPC / Edge Function)]
       │
       ├── Tiket Valid & Sesuai Gate ──► Akses Hijau & Kuota Scan Berkurang
       │
       ├── Tiket Salah Gate ──────────► Akses Merah: "Salah Pos Masuk"
       │
       ├── Tiket Sudah Dipakai ───────► Akses Merah: "Tiket Sudah Pernah Di-scan"
       │
       └── Tiket Dibatalkan/Refund ───► Akses Merah: "Tiket Dibatalkan / Direfund"
```

### Fitur Utama Gate Crew:
- **Pencegahan Tiket Palsu**: Signature cryptographic HMAC-SHA256 diverifikasi dalam hitungan milidetik.
- **Anti Double-Scan**: Tiket yang sudah diverifikasi tidak dapat dipakai ulang oleh orang lain.
- **Mode Input Cadangan**: Tersedia tombol input manual untuk tiket dengan layar ponsel buram atau pecah.
