// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

String? getPlatformStorageItem(String key) {
  try {
    return html.window.localStorage[key];
  } catch (_) {
    return null;
  }
}

void setPlatformStorageItem(String key, String value) {
  try {
    html.window.localStorage[key] = value;
  } catch (_) {
    // Abaikan jika mode penyimpanan browser dibatasi
  }
}

void removePlatformStorageItem(String key) {
  try {
    html.window.localStorage.remove(key);
  } catch (_) {
    // Abaikan jika mode penyimpanan browser dibatasi
  }
}
