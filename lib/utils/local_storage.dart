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

  static String? getString(String key) =>
      _prefs?.getString(key) ?? _memoryFallback[key] as String?;

  static void setString(String key, String value) {
    _prefs?.setString(key, value);
    _memoryFallback[key] = value;
  }

  static void remove(String key) {
    _prefs?.remove(key);
    _memoryFallback.remove(key);
  }

  static bool getBool(String key) =>
      _prefs?.getBool(key) ?? (_memoryFallback[key] == true);

  static void setBool(String key, bool value) {
    _prefs?.setBool(key, value);
    _memoryFallback[key] = value;
  }

  static List<String> getStringList(String key) {
    if (_prefs != null) {
      return _prefs!.getStringList(key) ?? [];
    }
    final val = _memoryFallback[key];
    if (val is List<String>) return val;
    if (val is String && val.isNotEmpty) {
      return val.split(',').where((s) => s.isNotEmpty).toList();
    }
    return [];
  }

  static void setStringList(String key, List<String> list) {
    _prefs?.setStringList(key, list);
    _memoryFallback[key] = list;
  }
}
