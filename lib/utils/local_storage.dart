import 'local_storage_stub.dart'
    if (dart.library.html) 'local_storage_web.dart';

/// Penyimpanan key-value lokal lintas platform tanpa paket tambahan.
/// Menggunakan window.localStorage pada Flutter Web dan memori lokal pada VM/pengujian.
class LocalStorage {
  LocalStorage._();

  static const String agreementAcceptedKey = 'livetix_agreement_accepted';

  static String? getString(String key) => getPlatformStorageItem(key);

  static void setString(String key, String value) =>
      setPlatformStorageItem(key, value);

  static void remove(String key) => removePlatformStorageItem(key);

  static bool getBool(String key) => getPlatformStorageItem(key) == 'true';

  static void setBool(String key, bool value) =>
      setPlatformStorageItem(key, value ? 'true' : 'false');

  static List<String> getStringList(String key) {
    final val = getString(key);
    if (val == null || val.isEmpty) return [];
    return val.split(',').where((s) => s.isNotEmpty).toList();
  }

  static void setStringList(String key, List<String> list) {
    setString(key, list.join(','));
  }
}
