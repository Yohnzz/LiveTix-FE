import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/promoter_models.dart';

class VenueLocationSearchService {
  static final VenueLocationSearchService _instance =
      VenueLocationSearchService._internal();
  factory VenueLocationSearchService() => _instance;
  VenueLocationSearchService._internal();

  /// Headers yang aman digunakan baik di platform Web (tanpa User-Agent terlarang)
  /// maupun di Android, iOS, Windows, macOS, dan Linux.
  static Map<String, String> _getHeaders() {
    if (kIsWeb) {
      return {'Accept': 'application/json'};
    }
    return {
      'User-Agent': 'LiveTixApp/1.0 (contact@livetix.id)',
      'Accept': 'application/json',
    };
  }

  /// Database tempat konser dan landmark populer di Indonesia
  static const List<PromoterVenueLocation> popularVenues = [
    // --- MALANG & JAWA TIMUR ---
    PromoterVenueLocation(
      name: 'Stadion Gajayana Malang',
      address:
          'Jl. Tangkuban Perahu, Kauman, Kec. Klojen, Kota Malang, Jawa Timur 65119',
      city: 'Kota Malang',
      latitude: -7.9786,
      longitude: 112.6225,
    ),
    PromoterVenueLocation(
      name: 'Graha Cakrawala UM (Universitas Negeri Malang)',
      address:
          'Jl. Semarang No.5, Sumbersari, Kec. Lowokwaru, Kota Malang, Jawa Timur 65145',
      city: 'Kota Malang',
      latitude: -7.9620,
      longitude: 112.6180,
    ),
    PromoterVenueLocation(
      name: 'Amphitheater Krida Budaya Malang',
      address:
          'Jl. Soekarno Hatta No.7, Jatimulyo, Kec. Lowokwaru, Kota Malang, Jawa Timur 65141',
      city: 'Kota Malang',
      latitude: -7.9472,
      longitude: 112.6163,
    ),
    PromoterVenueLocation(
      name: 'Dome UMM (Universitas Muhammadiyah Malang)',
      address:
          'Jl. Raya Tlogomas No.246, Babatan, Tegalgondo, Kec. Lowokwaru, Kota Malang, Jawa Timur 65144',
      city: 'Kota Malang',
      latitude: -7.9208,
      longitude: 112.5978,
    ),
    PromoterVenueLocation(
      name: 'Jl. Ijen (Ijen Boulevard)',
      address:
          'Jl. Besar Ijen, Gading Kasri, Kec. Klojen, Kota Malang, Jawa Timur 65115',
      city: 'Kota Malang',
      latitude: -7.9702,
      longitude: 112.6228,
    ),
    PromoterVenueLocation(
      name: 'Jl. Soekarno Hatta (Suhat)',
      address:
          'Jl. Soekarno Hatta, Jatimulyo, Kec. Lowokwaru, Kota Malang, Jawa Timur 65141',
      city: 'Kota Malang',
      latitude: -7.9461,
      longitude: 112.6171,
    ),
    PromoterVenueLocation(
      name: 'Jl. Veteran Malang',
      address:
          'Jl. Veteran, Ketawanggede, Kec. Lowokwaru, Kota Malang, Jawa Timur 65145',
      city: 'Kota Malang',
      latitude: -7.9575,
      longitude: 112.6148,
    ),
    PromoterVenueLocation(
      name: 'Alun-Alun Tugu & Balai Kota Malang',
      address:
          'Jl. Tugu No.1, Kiduldalem, Kec. Klojen, Kota Malang, Jawa Timur 65111',
      city: 'Kota Malang',
      latitude: -7.9772,
      longitude: 112.6341,
    ),
    PromoterVenueLocation(
      name: 'Lapangan Rampal Malang',
      address:
          'Ksatrian, Kec. Blimbing, Kota Malang, Jawa Timur 65111',
      city: 'Kota Malang',
      latitude: -7.9760,
      longitude: 112.6415,
    ),
    PromoterVenueLocation(
      name: 'Malang Creative Center (MCC)',
      address:
          'Jl. Jend. A. Yani No.53, Blimbing, Kec. Blimbing, Kota Malang, Jawa Timur 65118',
      city: 'Kota Malang',
      latitude: -7.9492,
      longitude: 112.6418,
    ),
    PromoterVenueLocation(
      name: 'Stadion Kanjuruhan',
      address:
          'Jl. Trunojoyo, Kedungpedaringan, Kec. Kepanjen, Kabupaten Malang, Jawa Timur 65163',
      city: 'Kabupaten Malang',
      latitude: -8.1561,
      longitude: 112.5714,
    ),
    PromoterVenueLocation(
      name: 'Gedung Samanta Krida UB (Universitas Brawijaya)',
      address:
          'Jl. Veteran, Ketawanggede, Kec. Lowokwaru, Kota Malang, Jawa Timur 65145',
      city: 'Kota Malang',
      latitude: -7.9525,
      longitude: 112.6144,
    ),
    PromoterVenueLocation(
      name: 'Stadion Gelora Bung Tomo (GBT)',
      address:
          'Benowo, Kec. Pakal, Kota Surabaya, Jawa Timur 60196',
      city: 'Kota Surabaya',
      latitude: -7.2281,
      longitude: 112.6212,
    ),
    PromoterVenueLocation(
      name: 'Grand City Convention & Exhibition Surabaya',
      address:
          'Jl. Walikota Mustajab No.1, Ketabang, Kec. Genteng, Kota Surabaya, Jawa Timur 60272',
      city: 'Kota Surabaya',
      latitude: -7.2618,
      longitude: 112.7485,
    ),
    PromoterVenueLocation(
      name: 'DBL Arena Surabaya',
      address:
          'Jl. Ahmad Yani No.88, Ketintang, Kec. Gayungan, Surabaya, Jawa Timur 60231',
      city: 'Kota Surabaya',
      latitude: -7.3182,
      longitude: 112.7303,
    ),

    // --- JAKARTA & BANTEN ---
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
          'Kompleks Gelora Bung Karno, Jl. Pintu Satu Senayan, Gelora, Jakarta Pusat 10270',
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
          'Gedung Pusat Niaga Lt. 1, Arena PRJ Kemayoran, Gn. Sahari Utara, Jakarta Pusat 10620',
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

    // --- JAWA BARAT ---
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

    // --- JAWA TENGAH & YOGYAKARTA ---
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
          'Jl. Raya Janti Jl. Wonocatur, Banguntapan, Bantul, D.I. Yogyakarta 55198',
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
          'Jl. Raya Solo - Yogyakarta No.16, Kranggan, Bokoharjo, Prambanan, Sleman 55571',
      city: 'Yogyakarta',
      latitude: -7.7520,
      longitude: 110.4915,
    ),

    // --- BALI ---
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
          'Kawasan Pariwisata Nusa Dua Lot NW/1, Benoa, Kec. Kuta Selatan, Badung, Bali 80363',
      city: 'Nusa Dua, Bali',
      latitude: -8.7997,
      longitude: 115.2285,
    ),

    // --- SUMATERA & SULAWESI ---
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
          'Jl. Metro Tanjung Bunga, Maccini Sombala, Tamalate, Kota Makassar, Sulawesi Selatan 90224',
      city: 'Makassar',
      latitude: -5.1586,
      longitude: 119.4042,
    ),
  ];

  /// Kamus koordinat kota dan landmark Indonesia untuk resolusi pencarian akurat
  static final Map<String, _CityInfo> _cityDirectory = {
    'malang': const _CityInfo(lat: -7.9786, lon: 112.6225, city: 'Kota Malang', province: 'Jawa Timur'),
    'ijen': const _CityInfo(lat: -7.9702, lon: 112.6228, city: 'Klojen, Malang', province: 'Jawa Timur'),
    'klojen': const _CityInfo(lat: -7.9768, lon: 112.6288, city: 'Klojen, Malang', province: 'Jawa Timur'),
    'lowokwaru': const _CityInfo(lat: -7.9450, lon: 112.6150, city: 'Lowokwaru, Malang', province: 'Jawa Timur'),
    'suhat': const _CityInfo(lat: -7.9461, lon: 112.6171, city: 'Lowokwaru, Malang', province: 'Jawa Timur'),
    'blimbing': const _CityInfo(lat: -7.9400, lon: 112.6400, city: 'Blimbing, Malang', province: 'Jawa Timur'),
    'sukun': const _CityInfo(lat: -7.9950, lon: 112.6100, city: 'Sukun, Malang', province: 'Jawa Timur'),
    'kedungkandang': const _CityInfo(lat: -7.9980, lon: 112.6500, city: 'Kedungkandang, Malang', province: 'Jawa Timur'),
    'batu': const _CityInfo(lat: -7.8712, lon: 112.5270, city: 'Kota Batu', province: 'Jawa Timur'),
    'surabaya': const _CityInfo(lat: -7.2575, lon: 112.7521, city: 'Kota Surabaya', province: 'Jawa Timur'),
    'sidoarjo': const _CityInfo(lat: -7.4530, lon: 112.7183, city: 'Sidoarjo', province: 'Jawa Timur'),
    'gresik': const _CityInfo(lat: -7.1594, lon: 112.6517, city: 'Gresik', province: 'Jawa Timur'),
    'pasuruan': const _CityInfo(lat: -7.6453, lon: 112.9075, city: 'Pasuruan', province: 'Jawa Timur'),
    'probolinggo': const _CityInfo(lat: -7.7543, lon: 113.2159, city: 'Probolinggo', province: 'Jawa Timur'),
    'kediri': const _CityInfo(lat: -7.8480, lon: 112.0178, city: 'Kediri', province: 'Jawa Timur'),
    'blitar': const _CityInfo(lat: -8.0983, lon: 112.1681, city: 'Blitar', province: 'Jawa Timur'),
    'madiun': const _CityInfo(lat: -7.6298, lon: 111.5239, city: 'Madiun', province: 'Jawa Timur'),
    'jember': const _CityInfo(lat: -8.1724, lon: 113.7007, city: 'Jember', province: 'Jawa Timur'),
    'banyuwangi': const _CityInfo(lat: -8.2192, lon: 114.3691, city: 'Banyuwangi', province: 'Jawa Timur'),
    'jakarta': const _CityInfo(lat: -6.2088, lon: 106.8456, city: 'DKI Jakarta', province: 'DKI Jakarta'),
    'jaksel': const _CityInfo(lat: -6.2615, lon: 106.8106, city: 'Jakarta Selatan', province: 'DKI Jakarta'),
    'jakpus': const _CityInfo(lat: -6.1805, lon: 106.8284, city: 'Jakarta Pusat', province: 'DKI Jakarta'),
    'jakbar': const _CityInfo(lat: -6.1683, lon: 106.7588, city: 'Jakarta Barat', province: 'DKI Jakarta'),
    'jaktim': const _CityInfo(lat: -6.2250, lon: 106.9004, city: 'Jakarta Timur', province: 'DKI Jakarta'),
    'jakut': const _CityInfo(lat: -6.1384, lon: 106.8640, city: 'Jakarta Utara', province: 'DKI Jakarta'),
    'senayan': const _CityInfo(lat: -6.2183, lon: 106.8022, city: 'Tanah Abang, Jakarta Pusat', province: 'DKI Jakarta'),
    'monas': const _CityInfo(lat: -6.1754, lon: 106.8272, city: 'Gambir, Jakarta Pusat', province: 'DKI Jakarta'),
    'tangerang': const _CityInfo(lat: -6.1783, lon: 106.6319, city: 'Kota Tangerang', province: 'Banten'),
    'bsd': const _CityInfo(lat: -6.3015, lon: 106.6385, city: 'Tangerang Selatan', province: 'Banten'),
    'tangsel': const _CityInfo(lat: -6.2885, lon: 106.7179, city: 'Tangerang Selatan', province: 'Banten'),
    'bekasi': const _CityInfo(lat: -6.2383, lon: 106.9756, city: 'Kota Bekasi', province: 'Jawa Barat'),
    'depok': const _CityInfo(lat: -6.4025, lon: 106.7942, city: 'Kota Depok', province: 'Jawa Barat'),
    'bogor': const _CityInfo(lat: -6.5971, lon: 106.8060, city: 'Kota Bogor', province: 'Jawa Barat'),
    'bandung': const _CityInfo(lat: -6.9175, lon: 107.6191, city: 'Kota Bandung', province: 'Jawa Barat'),
    'dago': const _CityInfo(lat: -6.8797, lon: 107.6153, city: 'Coblong, Bandung', province: 'Jawa Barat'),
    'cimahi': const _CityInfo(lat: -6.8723, lon: 107.5422, city: 'Cimahi', province: 'Jawa Barat'),
    'cirebon': const _CityInfo(lat: -6.7320, lon: 108.5523, city: 'Cirebon', province: 'Jawa Barat'),
    'semarang': const _CityInfo(lat: -6.9667, lon: 110.4167, city: 'Kota Semarang', province: 'Jawa Tengah'),
    'solo': const _CityInfo(lat: -7.5539, lon: 110.8061, city: 'Kota Surakarta / Solo', province: 'Jawa Tengah'),
    'surakarta': const _CityInfo(lat: -7.5539, lon: 110.8061, city: 'Kota Surakarta / Solo', province: 'Jawa Tengah'),
    'jogja': const _CityInfo(lat: -7.7956, lon: 110.3695, city: 'Kota Yogyakarta', province: 'D.I. Yogyakarta'),
    'yogyakarta': const _CityInfo(lat: -7.7956, lon: 110.3695, city: 'Kota Yogyakarta', province: 'D.I. Yogyakarta'),
    'sleman': const _CityInfo(lat: -7.7167, lon: 110.3556, city: 'Sleman', province: 'D.I. Yogyakarta'),
    'bantul': const _CityInfo(lat: -7.8897, lon: 110.3297, city: 'Bantul', province: 'D.I. Yogyakarta'),
    'magelang': const _CityInfo(lat: -7.4705, lon: 110.2178, city: 'Magelang', province: 'Jawa Tengah'),
    'bali': const _CityInfo(lat: -8.6705, lon: 115.2126, city: 'Denpasar', province: 'Bali'),
    'denpasar': const _CityInfo(lat: -8.6705, lon: 115.2126, city: 'Denpasar', province: 'Bali'),
    'badung': const _CityInfo(lat: -8.5833, lon: 115.1833, city: 'Badung', province: 'Bali'),
    'kuta': const _CityInfo(lat: -8.7233, lon: 115.1725, city: 'Kuta', province: 'Bali'),
    'ubud': const _CityInfo(lat: -8.5069, lon: 115.2625, city: 'Ubud, Gianyar', province: 'Bali'),
    'mataram': const _CityInfo(lat: -8.5833, lon: 116.1167, city: 'Kota Mataram', province: 'Nusa Tenggara Barat'),
    'lombok': const _CityInfo(lat: -8.5833, lon: 116.1167, city: 'Lombok', province: 'Nusa Tenggara Barat'),
    'kupang': const _CityInfo(lat: -10.1772, lon: 123.6070, city: 'Kota Kupang', province: 'Nusa Tenggara Timur'),
    'medan': const _CityInfo(lat: 3.5952, lon: 98.6722, city: 'Kota Medan', province: 'Sumatera Utara'),
    'palembang': const _CityInfo(lat: -2.9909, lon: 104.7565, city: 'Kota Palembang', province: 'Sumatera Selatan'),
    'padang': const _CityInfo(lat: -0.9471, lon: 100.4172, city: 'Kota Padang', province: 'Sumatera Barat'),
    'pekanbaru': const _CityInfo(lat: 0.5071, lon: 101.4478, city: 'Kota Pekanbaru', province: 'Riau'),
    'lampung': const _CityInfo(lat: -5.4292, lon: 105.2611, city: 'Bandar Lampung', province: 'Lampung'),
    'batam': const _CityInfo(lat: 1.0456, lon: 104.0305, city: 'Kota Batam', province: 'Kepulauan Riau'),
    'jambi': const _CityInfo(lat: -1.6101, lon: 103.6131, city: 'Kota Jambi', province: 'Jambi'),
    'bengkulu': const _CityInfo(lat: -3.8004, lon: 102.2655, city: 'Kota Bengkulu', province: 'Bengkulu'),
    'pontianak': const _CityInfo(lat: -0.0263, lon: 109.3425, city: 'Kota Pontianak', province: 'Kalimantan Barat'),
    'banjarmasin': const _CityInfo(lat: -3.3194, lon: 114.5908, city: 'Kota Banjarmasin', province: 'Kalimantan Selatan'),
    'balikpapan': const _CityInfo(lat: -1.2379, lon: 116.8289, city: 'Kota Balikpapan', province: 'Kalimantan Timur'),
    'samarinda': const _CityInfo(lat: -0.5021, lon: 117.1537, city: 'Kota Samarinda', province: 'Kalimantan Timur'),
    'makassar': const _CityInfo(lat: -5.1477, lon: 119.4327, city: 'Kota Makassar', province: 'Sulawesi Selatan'),
    'manado': const _CityInfo(lat: 1.4748, lon: 124.8421, city: 'Kota Manado', province: 'Sulawesi Utara'),
    'palu': const _CityInfo(lat: -0.8917, lon: 119.8707, city: 'Kota Palu', province: 'Sulawesi Tengah'),
    'kendari': const _CityInfo(lat: -3.9985, lon: 122.5126, city: 'Kota Kendari', province: 'Sulawesi Tenggara'),
    'ambon': const _CityInfo(lat: -3.6954, lon: 128.1814, city: 'Kota Ambon', province: 'Maluku'),
    'jayapura': const _CityInfo(lat: -2.5916, lon: 140.6690, city: 'Kota Jayapura', province: 'Papua'),
  };

  /// Mencari lokasi berdasarkan teks alamat / gedung / nama jalan
  /// [userLat] & [userLon] opsional untuk menjaga konteks posisi peta terkini
  Future<List<PromoterVenueLocation>> search(
    String rawQuery, {
    double? userLat,
    double? userLon,
  }) async {
    final query = rawQuery.trim();
    if (query.isEmpty) {
      return popularVenues;
    }

    final lowerQuery = query.toLowerCase();

    // 1. Cek kecocokan di database venue lokal
    final localMatches = popularVenues.where((v) {
      final nameLower = v.name.toLowerCase();
      final addrLower = v.address.toLowerCase();
      final cityLower = v.city.toLowerCase();
      return nameLower.contains(lowerQuery) ||
          addrLower.contains(lowerQuery) ||
          cityLower.contains(lowerQuery);
    }).toList();

    // 2. Deteksi kota dari kamus referensi wilayah Indonesia
    _CityInfo? matchedCity;
    for (final entry in _cityDirectory.entries) {
      if (lowerQuery.contains(entry.key)) {
        matchedCity = entry.value;
        break;
      }
    }

    // 3. Pencarian online geocoder (Nominatim & Photon) dengan prioritas Indonesia
    List<PromoterVenueLocation> onlineResults = [];
    final googleApiKey = dotenv.env['GOOGLE_MAPS_API_KEY']?.trim();

    // A. Google Geocoding jika ada API key di .env
    if (googleApiKey != null && googleApiKey.isNotEmpty) {
      try {
        final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent('$query, Indonesia')}&key=$googleApiKey&language=id',
        );
        final response = await http.get(url).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final results = data['results'] as List<dynamic>?;
          if (results != null && results.isNotEmpty) {
            for (final item in results.take(4)) {
              final formatted = item['formatted_address']?.toString() ?? '';
              final geom = item['geometry']?['location'];
              final lat = (geom?['lat'] as num?)?.toDouble() ?? 0.0;
              final lng = (geom?['lng'] as num?)?.toDouble() ?? 0.0;
              final cleanName = formatted.split(',').first.trim();

              if (lat != 0.0 && lng != 0.0) {
                onlineResults.add(
                  PromoterVenueLocation(
                    name: cleanName.isNotEmpty ? cleanName : query,
                    address: formatted,
                    city: matchedCity?.city ?? 'Indonesia',
                    latitude: lat,
                    longitude: lng,
                  ),
                );
              }
            }
          }
        }
      } catch (_) {}
    }

    // B. OpenStreetMap Nominatim Geocoder dengan countrycodes=id
    if (onlineResults.isEmpty) {
      try {
        final encoded = Uri.encodeComponent(query);
        final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=$encoded&countrycodes=id&format=json&addressdetails=1&limit=6',
        );

        final response = await http
            .get(url, headers: _getHeaders())
            .timeout(const Duration(seconds: 5));

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
                addressObj?['county'] ??
                matchedCity?.city ??
                'Indonesia';

            final road = addressObj?['road'] ?? addressObj?['pedestrian'];
            final parts = displayName.split(',');
            final cleanName = road != null && road.toString().isNotEmpty
                ? road.toString()
                : (parts.isNotEmpty ? parts.first.trim() : query);

            if (lat != 0.0 && lon != 0.0) {
              final isDup = localMatches.any(
                (m) =>
                    (m.latitude - lat).abs() < 0.0001 &&
                    (m.longitude - lon).abs() < 0.0001,
              );
              if (!isDup) {
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
        }
      } catch (_) {}
    }

    // C. Photon Komoot Geocoder sebagai pelengkap pencarian jalan & tempat
    if (onlineResults.isEmpty) {
      try {
        final encoded = Uri.encodeComponent(query);
        final url = Uri.parse('https://photon.komoot.io/api/?q=$encoded&limit=6');
        final response = await http
            .get(url, headers: {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final features = data['features'] as List<dynamic>?;
          if (features != null) {
            for (final f in features) {
              final props = f['properties'] as Map<String, dynamic>?;
              final country = props?['country']?.toString().toLowerCase() ?? '';
              final countryCode = props?['countrycode']?.toString().toUpperCase() ?? '';

              // Prioritaskan hasil wilayah Indonesia
              if (country.contains('indonesia') || countryCode == 'ID' || country.isEmpty) {
                final geom = f['geometry']?['coordinates'] as List<dynamic>?;
                if (geom != null && geom.length >= 2) {
                  final lon = (geom[0] as num).toDouble();
                  final lat = (geom[1] as num).toDouble();

                  // Pastikan koordinat berada di dalam area batas kepulauan Indonesia
                  if (lat >= -11.5 && lat <= 6.5 && lon >= 95.0 && lon <= 141.5) {
                    final name = props?['name']?.toString() ?? query;
                    final street = props?['street']?.toString() ?? '';
                    final city = props?['city']?.toString() ?? matchedCity?.city ?? 'Indonesia';
                    final state = props?['state']?.toString() ?? '';

                    final fullAddr = [
                      if (street.isNotEmpty && street != name) street,
                      name,
                      city,
                      if (state.isNotEmpty) state,
                      'Indonesia'
                    ].join(', ');

                    onlineResults.add(
                      PromoterVenueLocation(
                        name: street.isNotEmpty ? '$name ($street)' : name,
                        address: fullAddr,
                        city: city,
                        latitude: lat,
                        longitude: lon,
                      ),
                    );
                  }
                }
              }
            }
          }
        }
      } catch (_) {}
    }

    // Gabungkan hasil lokal dan online
    final combined = <PromoterVenueLocation>[
      ...localMatches,
      ...onlineResults,
    ];

    // 4. Fallback Cerdas: Jika tidak ada kecocokan persis, buat entri lokasi
    // yang SESUAI DENGAN KOTA / JALAN yang diketik pengguna, BUKAN malah ke Jakarta!
    final hasExact = combined.any(
      (v) => v.name.toLowerCase() == lowerQuery,
    );

    if (!hasExact) {
      double resolvedLat;
      double resolvedLon;
      String resolvedCity;
      String resolvedAddress;

      if (matchedCity != null) {
        // Kota terdeteksi di kamus (contoh: Malang, Surabaya, Bandung, dll.)
        resolvedLat = matchedCity.lat;
        resolvedLon = matchedCity.lon;
        resolvedCity = '${matchedCity.city}, ${matchedCity.province}';
        resolvedAddress = '$query, ${matchedCity.city}, ${matchedCity.province}, Indonesia';
      } else if (userLat != null && userLon != null && userLat != 0.0 && userLon != 0.0) {
        // Gunakan posisi peta terkini agar tidak tiba-tiba loncat ke kota lain
        resolvedLat = userLat;
        resolvedLon = userLon;
        resolvedCity = 'Lokasi Terpilih';
        resolvedAddress = '$query, Indonesia';
      } else {
        // Default ke Malang Raya (venue default LiveTix)
        resolvedLat = -7.9786;
        resolvedLon = 112.6225;
        resolvedCity = 'Kota Malang, Jawa Timur';
        resolvedAddress = '$query, Kota Malang, Jawa Timur, Indonesia';
      }

      final customChoice = PromoterVenueLocation(
        name: query,
        address: resolvedAddress,
        city: resolvedCity,
        latitude: resolvedLat,
        longitude: resolvedLon,
      );

      if (combined.isEmpty) {
        combined.add(customChoice);
      } else {
        combined.insert(0, customChoice);
      }
    }

    return combined;
  }

  /// Reverse geocode: Menerjemahkan koordinat latitude & longitude menjadi
  /// nama jalan, venue, kelurahan/kecamatan, kota, dan provinsi secara akurat.
  Future<PromoterVenueLocation?> reverseGeocode(double lat, double lon) async {
    // 1. Google Maps Geocoding API jika memiliki API key di .env
    final googleApiKey = dotenv.env['GOOGLE_MAPS_API_KEY']?.trim();
    if (googleApiKey != null && googleApiKey.isNotEmpty) {
      try {
        final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lon&key=$googleApiKey&language=id',
        );
        final response = await http.get(url).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final results = data['results'] as List<dynamic>?;
          if (results != null && results.isNotEmpty) {
            final first = results.first;
            final formatted = first['formatted_address']?.toString() ?? '';
            final components = first['address_components'] as List<dynamic>? ?? [];

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

            final resolvedCity = province.isNotEmpty ? '$city, $province' : city;
            final resolvedName = street.isNotEmpty
                ? street
                : (formatted.split(',').first.trim());

            return PromoterVenueLocation(
              name: resolvedName.isNotEmpty ? resolvedName : formatted.split(',').first.trim(),
              address: formatted,
              city: resolvedCity.isNotEmpty ? resolvedCity : 'Indonesia',
              latitude: lat,
              longitude: lon,
            );
          }
        }
      } catch (_) {}
    }

    // 2. OpenStreetMap Nominatim reverse geocoding (web-safe, no forbidden User-Agent on Web)
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json&addressdetails=1',
      );
      final response = await http
          .get(url, headers: _getHeaders())
          .timeout(const Duration(seconds: 5));

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
          name: resolvedName.isNotEmpty ? resolvedName : displayName.split(',').first.trim(),
          address: displayName,
          city: cityWithProvince,
          latitude: lat,
          longitude: lon,
        );
      }
    } catch (_) {}

    // 3. Fallback: Estimasi geografis lokal berdasarkan bounding box wilayah pulau di Indonesia
    return _estimateIndonesianLocation(lat, lon);
  }

  /// Estimasi nama kota & pulau berdasarkan koordinat bounding box di Indonesia
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

  /// Mendapatkan URL embed Google Maps interaktif untuk iframe atau browser
  static String getGoogleMapsEmbedUrl(
    double lat,
    double lon, {
    String mapType = 'm',
    int zoom = 16,
  }) {
    return 'https://maps.google.com/maps?q=$lat,$lon&t=$mapType&z=$zoom&output=embed';
  }

  /// Mendapatkan tautan langsung ke aplikasi Google Maps
  static String getGoogleMapsUrl(String venueName, String address) {
    final query = '$venueName $address';
    return 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}';
  }
}

class _CityInfo {
  final double lat;
  final double lon;
  final String city;
  final String province;

  const _CityInfo({
    required this.lat,
    required this.lon,
    required this.city,
    required this.province,
  });
}
