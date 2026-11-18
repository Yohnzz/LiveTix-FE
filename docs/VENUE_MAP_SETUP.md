# Venue Map Setup: OpenStreetMap (Nominatim)

## Overview
This project uses **OpenStreetMap** with **Nominatim** for venue location search and geocoding, replacing Google Maps. This approach requires **no API key** and has **no billing costs**.

## Features
- 🔍 Pencarian venue/alamat (autocomplete)
- 📍 Reverse geocoding (alamat ↔ koordinat)
- 📲 GPS localization
- 🎯 Pin dapat digeser di peta
- 🗺️ Tile OpenStreetMap gratis

## Konfigurasi

### 1. Dependencies
Tambahkan ke `pubspec.yaml` (sudah ada di proyek):

```yaml
flutter_map: ^8.3.2
latlong2: ^0.8.0
```

### 2. User-Agent (Kebijakan Nominatim)
Setiap request harus menyertakan header `User-Agent` yang jelas:

```
User-Agent: LiveTix/1.0 (com.example.livetix; support@livetix.id)
```

Digunakan di `venue_geocoding_service.dart`.

### 3. Rate Limiting
- Maksimal **1 request per detik** ke endpoint Nominatim
- Implementasi debounce 700ms di `_onSearchQueryChanged`
- Dedupe internal untuk mencegah request ganda

### 4. Endpoint yang Digunakan
- **Search**: `GET https://nominatim.openstreetmap.org/search`
  - Parameters: `q`, `format=jsonv2`, `countrycodes=id`, `accept-language=id`, `limit=5`
- **Reverse**: `GET https://nominatim.openstreetmap.org/reverse`
  - Parameters: `lat`, `lon`, `format=jsonv2`, `accept-language=id`, `zoom=18`, `addressdetails=1`

### 5. Format placeId
- OSM format: `N<osm_id>` (node), `W<osm_id>` (way), `R<osm_id>` (relation)
- Saat reverse/tap/GPS menghasilkan `placeId` kosong dan Step 2 mengirim `null` untuk titik manual

### 6. Validasi Koordinat
- Tidak boleh lanjut tanpa koordinat valid atau `0,0`
- `VenueGeocodingException` dilempar jika gagal mencari/reverse

### 7. Alur Penggunaan
1. User ketik di autocomplete (debounce 700ms, min 3 karakter)
2. Pilihan ditemukan → `_selectSuggestion` → `suggestion.toVenueLocation()`
3. Atau ketuk titik di peta → `_onMapPicked`
4. Atau GPS → pencarian lokasi saat ini
5. Pin digeser → `_handlePinDragUpdate` → update koordinat

### 8. Warna & UI
- Warna utama: `#1B2A8C` (navy), `#C2185B` (magenta)
- Dark mode tetap dippertahankan
- Attribution: `© OpenStreetMap contributors`

### 9. Contoh Request (curl)
```bash
curl -s "https://nominatim.openstreetmap.org/search?q=Jakarta&format=jsonv2&countrycodes=id&accept-language=id&limit=5" \
  -H "User-Agent: LiveTix/1.0 (com.example.livetix; support@livetix.id)"
```

### 10. Batasan
- 1 request/detik (patuhi kebijakan Nominatim)
- Tidak ada fallback jika service mati (tanpa cache lokal)
- Hasil akurasi bergantung pada data OpenStreetMap