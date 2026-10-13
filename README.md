# LiveTix

Aplikasi mobile pengelolaan konser & penjualan tiket (role: admin, produser, user).

## Cara menjalankan
1. Ekstrak zip, buka terminal di folder `livetix`.
2. Generate folder platform (android/ios) satu kali saja:
   `flutter create . --project-name livetix --org com.livetix`
   (file `lib/` dan `pubspec.yaml` milikmu tidak akan ditimpa)
3. `flutter pub get`
4. `flutter run`

## Struktur
- lib/core: warna & konstanta
- lib/widgets: komponen reusable
- lib/screens: splash, login, register, lupa sandi, OTP
