import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Salt statis aplikasi untuk hashing PIN Produser (6 digit).
/// PIN hanya dimiliki role Produser; role lain menyimpan `null` di database.
const String _pinSalt = 'livetix::pin::v1';

/// Prefix penanda bahwa nilai `pin_code` di database sudah berbentuk hash,
/// bukan plaintext lama.
const String pinHashPrefix = 'sha256:';

/// Menghasilkan hash SHA-256 dari PIN 6 digit dengan salt aplikasi.
/// Mengembalikan string kosong bila PIN kosong.
String hashPin(String pin) {
  final clean = pin.trim();
  if (clean.isEmpty) return '';
  final digest = sha256.convert(utf8.encode('$_pinSalt::$clean'));
  return '$pinHashPrefix$digest';
}

/// Apakah nilai PIN tersimpan sudah berupa hash (bukan plaintext lama).
bool isHashedPin(String stored) => stored.trim().startsWith(pinHashPrefix);

/// Mencocokkan PIN input dengan nilai tersimpan.
/// Mendukung data lama yang masih plaintext agar pengguna tidak terkunci,
/// dan nilai tersebut dapat di-hash ulang secara otomatis setelah login.
bool pinMatchesHash(String inputPin, String stored) {
  final cleanInput = inputPin.trim();
  final storedClean = stored.trim();
  if (cleanInput.isEmpty || storedClean.isEmpty) return false;
  if (!isHashedPin(storedClean)) {
    return cleanInput == storedClean; // kompatibilitas data lama (plaintext)
  }
  return hashPin(cleanInput) == storedClean;
}
