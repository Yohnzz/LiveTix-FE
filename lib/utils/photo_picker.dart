import 'dart:typed_data';

import 'photo_picker_stub.dart'
    if (dart.library.html) 'photo_picker_web.dart';

/// Utilitas pemilih foto profil tanpa ketergantungan paket eksternal.
/// Pada Flutter Web membuka dialog file gambar perangkat secara langsung,
/// dan mendukung override untuk pengujian widget terotomasi.
class PhotoPicker {
  PhotoPicker._();

  static Future<Uint8List?> Function()? testOverride;

  static bool get canPickFromDevice =>
      testOverride != null || isPlatformFilePickerSupported;

  static Future<Uint8List?> pickImageBytes() {
    if (testOverride != null) {
      return testOverride!();
    }
    return pickPlatformImageBytes();
  }
}
