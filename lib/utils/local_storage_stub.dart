final Map<String, String> _memoryStore = <String, String>{};

String? getPlatformStorageItem(String key) => _memoryStore[key];

void setPlatformStorageItem(String key, String value) {
  _memoryStore[key] = value;
}

void removePlatformStorageItem(String key) {
  _memoryStore.remove(key);
}
