# PROJECT OVERVIEW — LiveTix Concert Booking

## Tujuan Proyek
Membangun aplikasi **Concert Booking** berbasis Android menggunakan Flutter & Dart.
Tampilan mengikuti desain Figma secara akurat; backend direncanakan menggunakan Supabase + PostgreSQL.

## Nama Proyek
**LiveTix** (`livetix` — Flutter package name)

## Platform
- **Target utama:** Android
- **Framework:** Flutter / Dart (Null Safety, SDK ≥3.0.0 <4.0.0)

## Status Saat Ini
Proyek sudah diinisiasi. Beberapa screen auth sudah ada (Splash, Login, Register, ForgotPassword, OTP).
Backend belum tersedia — semua TODO API masih stub.

---

## Role & Hak Akses

| Role | Deskripsi |
|------|-----------|
| **User** | Mencari konser & membeli tiket |
| **Admin** | Pengelola operasional platform |
| **Produser** | Pengelola konser miliknya |

> Role Admin tidak boleh bisa didaftarkan dari form publik.
> Role diverifikasi oleh backend, bukan hanya oleh frontend.

---

## Keputusan Teknis Awal

| Aspek | Keputusan |
|-------|-----------|
| Font | Poppins (Google Fonts) untuk body; Playfair Display untuk nama brand di splash |
| Warna utama | `AppColors.primary` `#1B2A8C` (navy) |
| Warna aksen | `AppColors.accent` `#C2185B` (magenta) |
| Splash BG | `#070B14` (dark) |
| Header gradient | `#3B2BB5 → #A020B0` |
| Logo gradient | `#A020F0 → #2D6BFF` |
| State Management | Belum ditentukan — akan disesuaikan setelah lebih banyak desain tersedia |
| Routing | Saat ini menggunakan `Navigator.push` / `MaterialPageRoute` — akan dimigrasi ke named routes atau GoRouter jika skala bertambah |
| Backend | Supabase (direncanakan) — belum diintegrasikan |
| Autentikasi | Supabase Auth (direncanakan) — termasuk Google Sign-In |

---

## Dependensi Aktif

```yaml
dependencies:
  flutter: sdk
  google_fonts: ^6.2.1

dev_dependencies:
  flutter_test: sdk
  flutter_lints: ^4.0.0
```

---

## Catatan Penting
- Jangan tambah dependency tanpa diskusi terlebih dahulu.
- Backend dan schema database belum final — jangan hardcode struktur tabel.
- Harga dan role harus divalidasi di sisi server, bukan client.
- E-ticket dan refund belum diimplementasikan.
