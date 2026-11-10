import 'dart:math';

/// Utility untuk pembuatan dan validasi UUID v4 (RFC 4122)
class UuidUtils {
  static final Random _random = Random.secure();
  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// Menghasilkan UUID versi 4 yang valid (36 karakter termasuk tanda hubung)
  static String generateV4() {
    final values = List<int>.generate(16, (i) => _random.nextInt(256));

    // Versi 4 (bit 12-15 = 0100)
    values[6] = (values[6] & 0x0f) | 0x40;
    // Varian RFC 4122 (bit 6-7 = 10)
    values[8] = (values[8] & 0x3f) | 0x80;

    final hex = values.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  /// Memeriksa apakah sebuah string merupakan format UUID yang valid
  static bool isValidUuid(String? value) {
    if (value == null) return false;
    return _uuidRegex.hasMatch(value.trim());
  }

  /// Mengonversi nilai non-UUID menjadi format UUID deterministik yang aman
  static String ensureValidUuid(String? input) {
    if (input != null && isValidUuid(input)) {
      return input.trim();
    }
    return generateV4();
  }
}

