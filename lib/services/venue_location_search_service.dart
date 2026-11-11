import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/promoter_models.dart';

class VenueLocationSearchService {
  static final VenueLocationSearchService _instance =
      VenueLocationSearchService._internal();
  factory VenueLocationSearchService() => _instance;
  VenueLocationSearchService._internal();

  /// Comprehensive preset database of prominent concert venues across Indonesia
  static const List<PromoterVenueLocation> popularVenues = [
    // Jakarta & Tangerang
    PromoterVenueLocation(
      name: 'Stadion Utama Gelora Bung Karno (GBK)',
      address:
          'Jl. Pintu Satu Senayan, Gelora, Kec. Tanah Abang, Kota Jakarta Pusat, DKI Jakarta 10270',
      city: 'Jakarta Pusat',
      latitude: -6.2183,
      longitude: 106.8022,
    ),
    PromoterVenueLocation(
      name: 'Istora Mandiri Senayan',
      address:
          'Kompleks Gelora Bung Karno, Jl. Pintu Satu Senayan, RT.1/RW.3, Gelora, Jakarta Pusat 10270',
      city: 'Jakarta Pusat',
      latitude: -6.2165,
      longitude: 106.8005,
    ),
    PromoterVenueLocation(
      name: 'Jakarta International Stadium (JIS)',
      address:
          'Jl. Papanggo, RW.8, Papanggo, Kec. Tanjung Priok, Jakarta Utara, DKI Jakarta 14340',
      city: 'Jakarta Utara',
      latitude: -6.1256,
      longitude: 106.8617,
    ),
    PromoterVenueLocation(
      name: 'JIExpo Kemayoran (Arena PRJ)',
      address:
          'Gedung Pusat Niaga Lt. 1, Arena PRJ Kemayoran, RW.10, Gn. Sahari Utara, Jakarta Pusat 10620',
      city: 'Jakarta Pusat',
      latitude: -6.1488,
      longitude: 106.8524,
    ),
    PromoterVenueLocation(
      name: 'Indonesia Convention Exhibition (ICE) BSD',
      address:
          'Jl. BSD Grand Boulevard No.1, Pagedangan, Kec. Pagedangan, Kabupaten Tangerang, Banten 15339',
      city: 'Tangerang',
      latitude: -6.3015,
      longitude: 106.6385,
    ),
    PromoterVenueLocation(
      name: 'Beach City International Stadium (BCIS) Ancol',
      address:
          'Jl. Pantai Karnaval Ancol, Ancol, Kec. Pademangan, Jakarta Utara, DKI Jakarta 14430',
      city: 'Jakarta Utara',
      latitude: -6.1205,
      longitude: 106.8488,
    ),
    PromoterVenueLocation(
      name: 'Sentul International Convention Center (SICC)',
      address:
          'Jl. Jend. Sudirman No.1, Cipambuan, Kec. Babakan Madang, Kabupaten Bogor, Jawa Barat 16810',
      city: 'Bogor',
      latitude: -6.5369,
      longitude: 106.8596,
    ),

    // East Java (Malang & Surabaya)
    PromoterVenueLocation(
      name: 'Stadion Gajayana',
      address:
          'Jl. Tangkuban Perahu, Kauman, Kec. Klojen, Kota Malang, Jawa Timur 65119',
      city: 'Malang',
      latitude: -7.9786,
      longitude: 112.6225,
    ),
    PromoterVenueLocation(
      name: 'Graha Cakrawala UM',
      address:
          'Jl. Semarang No.5, Sumbersari, Kec. Lowokwaru, Kota Malang, Jawa Timur 65145',
      city: 'Malang',
      latitude: -7.9620,
      longitude: 112.6180,
    ),
    PromoterVenueLocation(
      name: 'Amphitheater Krida Budaya',
      address:
          'Jl. Soekarno Hatta No.7, Jatimulyo, Kec. Lowokwaru, Kota Malang, Jawa Timur 65141',
      city: 'Malang',
      latitude: -7.9472,
      longitude: 112.6163,
    ),
    PromoterVenueLocation(
      name: 'Dome UMM (Universitas Muhammadiyah Malang)',
      address:
          'Jl. Raya Tlogomas No.246, Babatan, Tegalgondo, Kec. Lowokwaru, Kota Malang, Jawa Timur 65144',
      city: 'Malang',
      latitude: -7.9208,
      longitude: 112.5978,
    ),
    PromoterVenueLocation(
      name: 'Stadion Gelora Bung Tomo (GBT)',
      address:
          'Benowo, Kec. Pakal, Kota Surabaya, Jawa Timur 60196',
      city: 'Surabaya',
      latitude: -7.2281,
      longitude: 112.6212,
    ),
    PromoterVenueLocation(
      name: 'Grand City Convention & Exhibition Surabaya',
      address:
          'Jl. Walikota Mustajab No.1, Ketabang, Kec. Genteng, Kota Surabaya, Jawa Timur 60272',
      city: 'Surabaya',
      latitude: -7.2618,
      longitude: 112.7485,
    ),
    PromoterVenueLocation(
      name: 'DBL Arena Surabaya',
      address:
          'Jl. Ahmad Yani No.88, Ketintang, Kec. Gayungan, Surabaya, Jawa Timur 60231',
      city: 'Surabaya',
      latitude: -7.3182,
      longitude: 112.7303,
    ),

    // West Java (Bandung)
    PromoterVenueLocation(
      name: 'Stadion Gelora Bandung Lautan Api (GBLA)',
      address:
          'Rancabolang, Kec. Gedebage, Kota Bandung, Jawa Barat 40294',
      city: 'Bandung',
      latitude: -6.9575,
      longitude: 107.7121,
    ),
    PromoterVenueLocation(
      name: 'Stadion Si Jalak Harupat',
      address:
          'Kopo, Kec. Kutawaringin, Kabupaten Bandung, Jawa Barat 40911',
      city: 'Bandung',
      latitude: -7.0006,
      longitude: 107.5303,
    ),
    PromoterVenueLocation(
      name: 'Trans Convention Centre Bandung',
      address:
          'Jl. Gatot Subroto No.289, Cibangkong, Kec. Batununggal, Kota Bandung, Jawa Barat 40273',
      city: 'Bandung',
      latitude: -6.9265,
      longitude: 107.6362,
    ),

    // Central Java & Yogyakarta
    PromoterVenueLocation(
      name: 'Stadion Manahan Solo',
      address:
          'Jl. Adi Sucipto No.1, Manahan, Kec. Banjarsari, Kota Surakarta, Jawa Tengah 57139',
      city: 'Surakarta / Solo',
      latitude: -7.5539,
      longitude: 110.8061,
    ),
    PromoterVenueLocation(
      name: 'Stadion Jatidiri Semarang',
      address:
          'Karanrejo, Kec. Gajahmungkur, Kota Semarang, Jawa Tengah 50231',
      city: 'Semarang',
      latitude: -7.0258,
      longitude: 110.4172,
    ),
    PromoterVenueLocation(
      name: 'Jogja Expo Center (JEC)',
      address:
          'Jl. Raya Janti Jl. Wonocatur, Wonocatur, Banguntapan, Kec. Banguntapan, Bantul, D.I. Yogyakarta 55198',
      city: 'Yogyakarta',
      latitude: -7.7981,
      longitude: 110.4042,
    ),
    PromoterVenueLocation(
      name: 'Stadion Maguwoharjo Sleman',
      address:
          'Jenengan, Maguwoharjo, Kec. Depok, Kabupaten Sleman, D.I. Yogyakarta 55281',
      city: 'Yogyakarta',
      latitude: -7.7533,
      longitude: 110.4358,
    ),
    PromoterVenueLocation(
      name: 'Candi Prambanan Open Theater',
      address:
          'Jl. Raya Solo - Yogyakarta No.16, Kranggan, Bokoharjo, Kec. Prambanan, Sleman 55571',
      city: 'Yogyakarta',
      latitude: -7.7520,
      longitude: 110.4915,
    ),

    // Bali
    PromoterVenueLocation(
      name: 'Garuda Wisnu Kencana (GWK) Cultural Park',
      address:
          'Jl. Raya Uluwatu, Ungasan, Kec. Kuta Selatan, Kabupaten Badung, Bali 80364',
      city: 'Badung, Bali',
      latitude: -8.8105,
      longitude: 115.1678,
    ),
    PromoterVenueLocation(
      name: 'Bali Nusa Dua Convention Center (BNDCC)',
      address:
          'Kawasan Pariwisata Nusa Dua Lot NW/1, Benoa, Kec. Kuta Sel., Kabupaten Badung, Bali 80363',
      city: 'Nusa Dua, Bali',
      latitude: -8.7997,
      longitude: 115.2285,
    ),

    // Sumatra & Sulawesi
    PromoterVenueLocation(
      name: 'Stadion Gelora Sriwijaya Jakabaring',
      address:
          'Jl. Gubernur H. A. Bastari, 15 Ulu, Jakabaring, Kota Palembang, Sumatera Selatan 30257',
      city: 'Palembang',
      latitude: -3.0189,
      longitude: 104.7904,
    ),
    PromoterVenueLocation(
      name: 'Stadion Teladan Medan',
      address:
          'Jl. Gedung Arca, Teladan Barat, Kec. Medan Kota, Kota Medan, Sumatera Utara 20217',
      city: 'Medan',
      latitude: 3.5658,
      longitude: 98.6947,
    ),
    PromoterVenueLocation(
      name: 'Celebes Convention Center (CCC) Makassar',
      address:
          'Jl. Metro Tanjung Bunga, Maccini Sombala, Kec. Tamalate, Kota Makassar, Sulawesi Selatan 90224',
      city: 'Makassar',
      latitude: -5.1586,
      longitude: 119.4042,
    ),
  ];

  /// Search locations dynamically: queries OSM/Nominatim geocoder online,
  /// merges with local venue database, and always provides an instant fallback.
  Future<List<PromoterVenueLocation>> search(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty) {
      return popularVenues;
    }

    final lowerQuery = query.toLowerCase();

    // 1. Filter local premier database
    final localMatches = popularVenues.where((v) {
      return v.name.toLowerCase().contains(lowerQuery) ||
          v.address.toLowerCase().contains(lowerQuery) ||
          v.city.toLowerCase().contains(lowerQuery);
    }).toList();

    // 2. Try online geocoding API for worldwide / anywhere search
    List<PromoterVenueLocation> onlineResults = [];
    try {
      final encoded = Uri.encodeComponent(query);
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$encoded&format=json&addressdetails=1&limit=6',
      );

      final response = await http
          .get(
            url,
            headers: {
              'User-Agent': 'LiveTixApp/1.0 (contact@livetix.id)',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        for (final item in data) {
          final displayName = item['display_name']?.toString() ?? '';
          final lat = double.tryParse(item['lat']?.toString() ?? '0') ?? 0.0;
          final lon = double.tryParse(item['lon']?.toString() ?? '0') ?? 0.0;

          final addressObj = item['address'] as Map<String, dynamic>?;
          final city = addressObj?['city'] ??
              addressObj?['town'] ??
              addressObj?['municipality'] ??
              addressObj?['state'] ??
              'Indonesia';

          final parts = displayName.split(',');
          final cleanName = parts.isNotEmpty ? parts.first.trim() : query;

          final isAlreadyLocal = localMatches.any(
            (m) => m.name.toLowerCase() == cleanName.toLowerCase(),
          );

          if (!isAlreadyLocal && lat != 0.0) {
            onlineResults.add(
              PromoterVenueLocation(
                name: cleanName,
                address: displayName,
                city: city.toString(),
                latitude: lat,
                longitude: lon,
              ),
            );
          }
        }
      }
    } catch (_) {
      // Offline or network timeout: gracefully continue with local & fallback
    }

    final combined = <PromoterVenueLocation>[
      ...localMatches,
      ...onlineResults,
    ];

    // 3. Fallback: If no exact match, inject custom location choice
    final hasExact = combined.any(
      (v) => v.name.toLowerCase() == lowerQuery,
    );

    if (!hasExact) {
      combined.add(
        PromoterVenueLocation(
          name: query,
          address: 'Lokasi di $query (Ditemukan via Google Maps Search)',
          city: 'Lokasi Pencarian',
          latitude: -6.2088,
          longitude: 106.8456,
        ),
      );
    }

    return combined;
  }

  /// Reverse geocode given coordinates to retrieve real address, city, province, and venue name.
  Future<PromoterVenueLocation?> reverseGeocode(double lat, double lon) async {
    // 1. Google Maps Geocoding API if key is provided in .env
    final googleApiKey = dotenv.env['GOOGLE_MAPS_API_KEY']?.trim();
    if (googleApiKey != null && googleApiKey.isNotEmpty) {
      try {
        final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lon&key=$googleApiKey&language=id',
        );
        final response =
            await http.get(url).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final results = data['results'] as List<dynamic>?;
          if (results != null && results.isNotEmpty) {
            final first = results.first;
            final formatted = first['formatted_address']?.toString() ?? '';
            final components =
                first['address_components'] as List<dynamic>? ?? [];

            String street = '';
            String city = '';
            String province = '';

            for (final comp in components) {
              final types = (comp['types'] as List<dynamic>?) ?? [];
              if (types.contains('route') ||
                  types.contains('point_of_interest') ||
                  types.contains('establishment')) {
                street = comp['long_name']?.toString() ?? street;
              } else if (types.contains('administrative_area_level_2')) {
                city = comp['long_name']?.toString() ?? city;
              } else if (types.contains('administrative_area_level_1')) {
                province = comp['long_name']?.toString() ?? province;
              }
            }

            final resolvedCity =
                province.isNotEmpty ? '$city, $province' : city;
            final resolvedName = street.isNotEmpty
                ? street
                : (formatted.split(',').first.trim());

            return PromoterVenueLocation(
              name: resolvedName,
              address: formatted,
              city: resolvedCity.isNotEmpty ? resolvedCity : 'Indonesia',
              latitude: lat,
              longitude: lon,
            );
          }
        }
      } catch (_) {}
    }

    // 2. OpenStreetMap Nominatim reverse geocoding
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$lat,$lon&format=json&addressdetails=1',
      );
      final response = await http
          .get(
            url,
            headers: {
              'User-Agent': 'LiveTixApp/1.0 (contact@livetix.id)',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final displayName = data['display_name']?.toString() ?? '';
        final addressObj = data['address'] as Map<String, dynamic>?;

        final road = addressObj?['road'] ??
            addressObj?['pedestrian'] ??
            addressObj?['suburb'];
        final amenity = addressObj?['amenity'] ??
            addressObj?['building'] ??
            addressObj?['stadium'] ??
            addressObj?['leisure'];
        final city = addressObj?['city'] ??
            addressObj?['town'] ??
            addressObj?['municipality'] ??
            addressObj?['county'] ??
            'Indonesia';
        final state = addressObj?['state'] ?? addressObj?['province'] ?? '';

        final resolvedName =
            (amenity ?? road ?? displayName.split(',').first).toString().trim();
        final cityWithProvince =
            state.isNotEmpty ? '$city, $state' : city.toString();

        return PromoterVenueLocation(
          name: resolvedName,
          address: displayName,
          city: cityWithProvince,
          latitude: lat,
          longitude: lon,
        );
      }
    } catch (_) {}

    // 3. Fallback: Local geographical estimate based on Indonesian island bounding boxes
    return _estimateIndonesianLocation(lat, lon);
  }

  /// Estimates island and city name based on Indonesian geographical bounding boxes
  static PromoterVenueLocation _estimateIndonesianLocation(
      double lat, double lon) {
    String city = 'Indonesia';
    String name = 'Titik Koordinat Terpilih';

    if (lat >= -8.5 && lat <= -5.5 && lon >= 105.0 && lon <= 115.0) {
      if (lat >= -8.2 && lat <= -7.8 && lon >= 112.4 && lon <= 112.9) {
        city = 'Kota Malang, Jawa Timur';
        name = 'Kawasan Malang Raya';
      } else if (lat >= -7.4 && lat <= -7.1 && lon >= 112.5 && lon <= 113.0) {
        city = 'Surabaya, Jawa Timur';
        name = 'Kawasan Surabaya';
      } else if (lat >= -6.4 && lat <= -6.0 && lon >= 106.6 && lon <= 107.0) {
        city = 'Jakarta Pusat, DKI Jakarta';
        name = 'Kawasan Jakarta';
      } else if (lat >= -7.1 && lat <= -6.8 && lon >= 107.4 && lon <= 107.8) {
        city = 'Bandung, Jawa Barat';
        name = 'Kawasan Bandung';
      } else if (lat >= -7.6 && lat <= -7.4 && lon >= 110.7 && lon <= 110.9) {
        city = 'Surakarta, Jawa Tengah';
        name = 'Kawasan Solo';
      } else if (lat >= -7.9 && lat <= -7.6 && lon >= 110.2 && lon <= 110.6) {
        city = 'Yogyakarta, D.I. Yogyakarta';
        name = 'Kawasan Yogyakarta';
      } else {
        city = 'Pulau Jawa, Indonesia';
      }
    } else if (lat >= -9.0 && lat <= -8.0 && lon >= 114.4 && lon <= 115.8) {
      city = 'Denpasar / Badung, Bali';
      name = 'Kawasan Pulau Bali';
    } else if (lat >= -6.0 && lat <= 6.0 && lon >= 95.0 && lon <= 106.0) {
      city = 'Sumatera, Indonesia';
    } else if (lat >= -4.5 && lat <= 4.5 && lon >= 108.0 && lon <= 119.0) {
      city = 'Kalimantan, Indonesia';
    } else if (lat >= -6.0 && lat <= 2.5 && lon >= 118.0 && lon <= 125.5) {
      city = 'Sulawesi, Indonesia';
    } else if (lat >= -9.0 && lat <= 0.0 && lon >= 130.0 && lon <= 141.0) {
      city = 'Papua, Indonesia';
    }

    return PromoterVenueLocation(
      name: name,
      address:
          'Koordinat (${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}), $city',
      city: city,
      latitude: lat,
      longitude: lon,
    );
  }


  /// Get direct Google Maps Embed URL for iframe or web view.
  /// [mapType]: 'm' (roadmap / peta), 'k' (satelit), 'p' (terrain)
  static String getGoogleMapsEmbedUrl(
    double lat,
    double lon, {
    String mapType = 'm',
    int zoom = 16,
  }) {
    return 'https://maps.google.com/maps?q=$lat,$lon&t=$mapType&z=$zoom&output=embed';
  }

  /// Get Google Maps direct search URL for opening in browser or map app.
  static String getGoogleMapsUrl(String venueName, String address) {
    final query = '$venueName $address';
    return 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}';
  }
}
