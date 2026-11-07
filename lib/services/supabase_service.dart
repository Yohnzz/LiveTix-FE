import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';

/// Service wrapper untuk koneksi klien Supabase.
class SupabaseService {
  SupabaseService._();

  static bool _initialized = false;

  /// Mengecek apakah klien Supabase telah siap digunakan
  static bool get isInitialized {
    if (_initialized) return true;
    try {
      final _ = Supabase.instance.client;
      _initialized = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Mengakses klien Supabase aktif
  static SupabaseClient get client => Supabase.instance.client;

  /// Inisialisasi koneksi ke Supabase Cloud
  static Future<void> init() async {
    if (isInitialized) return;
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.publishableKey,
      );
      _initialized = true;
      debugPrint('Supabase berhasil diinisialisasi: ${SupabaseConfig.url}');
    } catch (e) {
      debugPrint('Supabase inisialisasi gagal / offline: $e');
    }
  }
}
