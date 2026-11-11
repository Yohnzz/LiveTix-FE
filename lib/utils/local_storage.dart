import 'package:shared_preferences/shared_preferences.dart';

/// Penyimpanan key-value lokal permanen lintas platform menggunakan SharedPreferences.
/// Menyimpan data sesi, preferensi tema, status persetujuan, dan tiket pengguna ke disk.
class LocalStorage {
  LocalStorage._();

  static const String agreementAcceptedKey = 'livetix_agreement_accepted';
  static const String savedUserKey = 'livetix_saved_user';
  static const String darkModeKey = 'livetix_dark_mode';
  static const String favoriteIdsKey = 'livetix_favorite_ids';

  static SharedPreferences? _prefs;
  static final Map<String, dynamic> _memoryFallback = {};

  /// Inisialisasi SharedPreferences saat aplikasi dibuka
  static Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (_) {}
  }

  static bool containsKey(String key) {
    try {
      return _prefs?.containsKey(key) ?? _memoryFallback.containsKey(key);
    } catch (_) {
      return _memoryFallback.containsKey(key);
    }
  }

  static String? getString(String key) {
    try {
      final val = _prefs?.getString(key);
      if (val != null) return val;
      return _memoryFallback[key]?.toString();
    } catch (_) {
      try {
        final raw = _prefs?.get(key);
        return raw?.toString() ?? _memoryFallback[key]?.toString();
      } catch (_) {
        return _memoryFallback[key]?.toString();
      }
    }
  }

  static void setString(String key, String value) {
    try {
      _prefs?.setString(key, value);
    } catch (_) {}
    _memoryFallback[key] = value;
  }

  static String? getItem(String key) => getString(key);
  static void setItem(String key, String value) => setString(key, value);

  static void remove(String key) {
    try {
      _prefs?.remove(key);
    } catch (_) {}
    _memoryFallback.remove(key);
  }

  static bool getBool(String key, {bool defaultValue = false}) {
    try {
      final val = _prefs?.getBool(key);
      if (val != null) return val;
      final mem = _memoryFallback[key];
      if (mem is bool) return mem;
      if (mem is String) return mem.toLowerCase() == 'true';
      return defaultValue;
    } catch (_) {
      try {
        final raw = _prefs?.get(key);
        if (raw is bool) return raw;
        if (raw is String) return raw.toLowerCase() == 'true';
        return defaultValue;
      } catch (_) {
        return defaultValue;
      }
    }
  }

  static void setBool(String key, bool value) {
    try {
      _prefs?.setBool(key, value);
    } catch (_) {}
    _memoryFallback[key] = value;
  }

  static List<String> getStringList(String key) {
    try {
      if (_prefs != null) {
        return _prefs!.getStringList(key) ?? [];
      }
    } catch (_) {}
    final val = _memoryFallback[key];
    if (val is List<String>) return val;
    if (val is String && val.isNotEmpty) {
      return val.split(',').where((s) => s.isNotEmpty).toList();
    }
    return [];
  }

  static void setStringList(String key, List<String> list) {
    try {
      _prefs?.setStringList(key, list);
    } catch (_) {}
    _memoryFallback[key] = list;
  }
}
