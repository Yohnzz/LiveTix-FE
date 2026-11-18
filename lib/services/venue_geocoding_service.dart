import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/promoter_models.dart';

/// Satu hasil pencarian atau reverse geocoding dari Nominatim (OpenStreetMap).
class VenueSearchResult {
  /// Identitas objek OSM, misalnya `N123` (node), `W456` (way), atau
  /// `R789` (relation). Bisa kosong bila titik tidak punya objek OSM.
  final String placeId;
  final String title;
  final String subtitle;
  final String address;
  final String city;
  final double latitude;
  final double longitude;

  const VenueSearchResult({
    required this.placeId,
    required this.title,
    required this.subtitle,
    required this.address,
    required this.city,
    required this.latitude,
    required this.longitude,
  });

  PromoterVenueLocation toVenueLocation() => PromoterVenueLocation(
        name: title,
        address: address,
        city: city,
        latitude: latitude,
        longitude: longitude,
      );
}

class VenueGeocodingException implements Exception {
  final String message;
  const VenueGeocodingException(this.message);

  @override
  String toString() => message;
}

/// Pencarian lokasi dan reverse geocoding gratis memakai Nominatim.
///
/// Tidak perlu API key maupun akun billing. Yang wajib dipatuhi adalah
/// [usage policy Nominatim](https://operations.osmfoundation.org/policies/nominatim/):
/// - User-Agent yang jelas (dikirim lewat header),
/// - maksimal 1 request per detik (diatur otomatis di service ini),
/// - atribusi OpenStreetMap ditampilkan di UI.
///
/// Untuk penggunaan produksi dengan trafik tinggi, jalankan instance Nominatim
/// sendiri atau gunakan penyedia geocoding berbayar.
class VenueGeocodingService {
  static const String _host = 'nominatim.openstreetmap.org';
  static const String _userAgent =
      'LiveTix/1.0 (com.example.livetix; support@livetix.id)';
  static const Duration _timeout = Duration(seconds: 12);
  static const Duration _minInterval = Duration(seconds: 1);

  final http.Client _client;

  /// Semua request dijalankan berurutan supaya batas 1 request/detik aman
  /// meskipun pengguna menekan cari berulang kali.
  Future<void> _requestChain = Future<void>.value();
  DateTime _lastRequestAt = DateTime.fromMillisecondsSinceEpoch(0);

  VenueGeocodingService({http.Client? client}) : _client = client ?? http.Client();

  void dispose() {
    _client.close();
  }

  /// Cari venue/alamat. Dibatasi ke Indonesia karena aplikasi ini digunakan
  /// untuk konser di Indonesia.
  /// [userLat] & [userLon] opsional untuk memprioritaskan hasil di sekitar lokasi pengguna/peta.
  Future<List<VenueSearchResult>> search(
    String query, {
    double? userLat,
    double? userLon,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return const [];

    final queryParams = <String, String>{
      'q': cleanQuery,
      'format': 'jsonv2',
      'addressdetails': '1',
      'limit': '8',
      'countrycodes': 'id',
      'accept-language': 'id',
      'dedupe': '1',
    };

    if (userLat != null &&
        userLon != null &&
        _isValidCoordinate(userLat, userLon)) {
      // Prioritaskan area di sekitar user (+/- 0.6 derajat)
      queryParams['viewbox'] =
          '${userLon - 0.6},${userLat + 0.6},${userLon + 0.6},${userLat - 0.6}';
      queryParams['bounded'] = '0';
    }

    final uri = Uri.https(_host, '/search', queryParams);

    final json = await _getJson(uri);
    if (json is! List) {
      throw const VenueGeocodingException(
        'Respons pencarian lokasi tidak valid. Coba lagi.',
      );
    }

    final results = <VenueSearchResult>[];
    final seen = <String>{};
    for (final item in json) {
      if (item is! Map) continue;
      final result = _toSearchResult(Map<String, dynamic>.from(item));
      if (result == null) continue;
      final key = result.placeId.isNotEmpty
          ? result.placeId
          : '${result.latitude},${result.longitude}';
      if (seen.add(key)) results.add(result);
    }
    return results;
  }

  /// Ubah koordinat menjadi alamat. Bila Nominatim tidak menemukan alamat,
  /// hasil fallback tetap memakai koordinat supaya pin tidak hilang.
  Future<VenueSearchResult> reverse(
    double latitude,
    double longitude, {
    String? nameOverride,
  }) async {
    final uri = Uri.https(_host, '/reverse', {
      'lat': latitude.toString(),
      'lon': longitude.toString(),
      'format': 'jsonv2',
      'addressdetails': '1',
      'zoom': '18',
      'accept-language': 'id',
    });

    final json = await _getJson(uri);
    if (json is! Map) {
      throw const VenueGeocodingException(
        'Respons alamat lokasi tidak valid. Coba lagi.',
      );
    }

    final map = Map<String, dynamic>.from(json);
    if (map['error'] != null) {
      return _fallbackResult(latitude, longitude, nameOverride);
    }

    final result = _toSearchResult(map);
    if (result == null) {
      return _fallbackResult(latitude, longitude, nameOverride);
    }

    return VenueSearchResult(
      placeId: result.placeId,
      title: nameOverride?.trim().isNotEmpty == true
          ? nameOverride!.trim()
          : result.title,
      subtitle: result.subtitle,
      address: result.address,
      city: result.city,
      latitude: latitude,
      longitude: longitude,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  VenueSearchResult? _toSearchResult(Map<String, dynamic> json) {
    final latitude = double.tryParse(json['lat']?.toString() ?? '');
    final longitude = double.tryParse(json['lon']?.toString() ?? '');
    if (!_isValidCoordinate(latitude, longitude)) return null;

    final displayName = json['display_name']?.toString().trim() ?? '';
    final explicitName = json['name']?.toString().trim() ?? '';

    // display_name Nominatim biasanya diawali nama tempat. Jika tidak ada
    // field name, bagian pertama display_name dipakai sebagai judul.
    final firstPart = displayName.split(',').first.trim();
    final title = explicitName.isNotEmpty
        ? explicitName
        : (firstPart.isNotEmpty ? firstPart : 'Titik di Peta');

    var subtitle = displayName;
    if (subtitle.startsWith('$title,')) {
      subtitle = subtitle.substring(title.length + 1).trim();
    } else if (subtitle == title) {
      subtitle = '';
    }

    final address = displayName.isNotEmpty
        ? displayName
        : '${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}';

    return VenueSearchResult(
      placeId: _placeIdFrom(json),
      title: title,
      subtitle: subtitle,
      address: address,
      city: _cityFrom(json['address']),
      latitude: latitude!,
      longitude: longitude!,
    );
  }

  VenueSearchResult _fallbackResult(
    double latitude,
    double longitude,
    String? nameOverride,
  ) {
    final coordinateLabel =
        '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
    return VenueSearchResult(
      placeId: '',
      title: nameOverride?.trim().isNotEmpty == true
          ? nameOverride!.trim()
          : 'Titik di Peta',
      subtitle: '',
      address: coordinateLabel,
      city: '',
      latitude: latitude,
      longitude: longitude,
    );
  }

  String _placeIdFrom(Map<String, dynamic> json) {
    final id = json['osm_id']?.toString().trim() ?? '';
    if (id.isEmpty) return '';
    final type = json['osm_type']?.toString().toLowerCase() ?? '';
    final prefix = switch (type) {
      'node' => 'N',
      'way' => 'W',
      'relation' => 'R',
      _ => '',
    };
    return '$prefix$id';
  }

  String _cityFrom(dynamic address) {
    if (address is! Map) return '';
    const cityKeys = [
      'city',
      'town',
      'village',
      'municipality',
      'county',
      'state_district',
      'state',
    ];
    for (final key in cityKeys) {
      final value = address[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  bool _isValidCoordinate(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    if (lat.isNaN || lng.isNaN) return false;
    if (lat == 0 && lng == 0) return false;
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }

  Future<dynamic> _getJson(Uri uri) {
    final completer = Completer<dynamic>();

    _requestChain = _requestChain.then((_) async {
      try {
        final elapsed = DateTime.now().difference(_lastRequestAt);
        if (elapsed < _minInterval) {
          await Future<void>.delayed(_minInterval - elapsed);
        }
        _lastRequestAt = DateTime.now();

        final response = await _client
            .get(uri, headers: const {
              'Accept': 'application/json',
              'Accept-Language': 'id',
              'User-Agent': _userAgent,
            })
            .timeout(_timeout);

        if (response.statusCode == 429) {
          throw const VenueGeocodingException(
            'Pencarian lokasi sedang dibatasi. Tunggu beberapa saat lalu coba lagi.',
          );
        }
        if (response.statusCode != 200) {
          throw VenueGeocodingException(
            'Layanan peta gagal merespons (HTTP ${response.statusCode}). Coba lagi.',
          );
        }

        try {
          completer.complete(jsonDecode(response.body));
        } on FormatException {
          throw const VenueGeocodingException(
            'Respons layanan peta tidak valid. Coba lagi.',
          );
        }
      } on VenueGeocodingException catch (e, st) {
        completer.completeError(e, st);
      } on TimeoutException catch (e, st) {
        completer.completeError(
          const VenueGeocodingException(
            'Layanan peta tidak merespons dalam 12 detik. Periksa koneksi internet Anda lalu coba lagi.',
          ),
          st,
        );
      } catch (e, st) {
        completer.completeError(
          const VenueGeocodingException(
            'Tidak dapat terhubung ke layanan peta. Periksa koneksi internet Anda.',
          ),
          st,
        );
      }
    });

    return completer.future;
  }
}
