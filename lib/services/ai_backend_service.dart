import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/concert_model.dart';

/// Model filter terstruktur hasil ekstraksi AI (Fitur 2)
class AiFilterModel {
  final String? genre;
  final int? year;
  final String? location;
  final String? keyword;
  final int? minPrice;
  final int? maxPrice;

  const AiFilterModel({
    this.genre,
    this.year,
    this.location,
    this.keyword,
    this.minPrice,
    this.maxPrice,
  });

  factory AiFilterModel.fromJson(Map<String, dynamic> json) {
    return AiFilterModel(
      genre: json['genre'] as String?,
      year: json['year'] is int
          ? json['year'] as int
          : (json['year'] != null ? int.tryParse(json['year'].toString()) : null),
      location: json['location'] as String?,
      keyword: json['keyword'] as String?,
      minPrice: json['min_price'] is int
          ? json['min_price'] as int
          : (json['min_price'] != null ? int.tryParse(json['min_price'].toString()) : null),
      maxPrice: json['max_price'] is int
          ? json['max_price'] as int
          : (json['max_price'] != null ? int.tryParse(json['max_price'].toString()) : null),
    );
  }

  bool get hasActiveFilter =>
      genre != null ||
      year != null ||
      location != null ||
      keyword != null ||
      minPrice != null ||
      maxPrice != null;

  List<String> get filterBadges {
    final list = <String>[];
    if (genre != null && genre!.isNotEmpty) list.add('Tema: ${genre!}');
    if (year != null) list.add('Tahun: $year');
    if (location != null && location!.isNotEmpty) list.add('Lokasi: ${location!}');
    if (keyword != null && keyword!.isNotEmpty) list.add('Artis: "${keyword!}"');
    if (minPrice != null) list.add('Min: Rp${minPrice!.toLocaleString()}');
    if (maxPrice != null) list.add('Maks: Rp${maxPrice!.toLocaleString()}');
    return list;
  }
}

extension on int {
  String toLocaleString() {
    final buffer = StringBuffer();
    final str = toString();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }
}

/// Respons untuk Fitur 1: Asisten Info Konser
class AiConcertInfoResponse {
  final bool success;
  final bool matched;
  final bool ambiguous;
  final String message;
  final ConcertModel? concert;
  final List<ConcertModel> matchedConcerts;

  const AiConcertInfoResponse({
    required this.success,
    required this.matched,
    required this.ambiguous,
    required this.message,
    this.concert,
    this.matchedConcerts = const [],
  });

  factory AiConcertInfoResponse.fromJson(Map<String, dynamic> json) {
    ConcertModel? primary;
    if (json['concert'] is Map<String, dynamic>) {
      primary = ConcertModel.fromJson(json['concert'] as Map<String, dynamic>);
    }

    List<ConcertModel> list = [];
    if (json['matchedConcerts'] is List) {
      list = (json['matchedConcerts'] as List)
          .whereType<Map<String, dynamic>>()
          .map((c) => ConcertModel.fromJson(c))
          .toList();
    }

    return AiConcertInfoResponse(
      success: json['success'] == true,
      matched: json['matched'] == true,
      ambiguous: json['ambiguous'] == true,
      message: (json['message'] as String?) ?? '',
      concert: primary ?? (list.isNotEmpty ? list.first : null),
      matchedConcerts: list,
    );
  }
}

/// Respons untuk Fitur 2: Pencarian Konser dengan AI
class AiSearchResponse {
  final bool success;
  final AiFilterModel? filter;
  final int total;
  final List<ConcertModel> results;
  final String message;

  const AiSearchResponse({
    required this.success,
    this.filter,
    required this.total,
    required this.results,
    required this.message,
  });

  factory AiSearchResponse.fromJson(Map<String, dynamic> json) {
    AiFilterModel? parsedFilter;
    if (json['filter'] is Map<String, dynamic>) {
      parsedFilter = AiFilterModel.fromJson(json['filter'] as Map<String, dynamic>);
    }

    List<ConcertModel> list = [];
    if (json['results'] is List) {
      list = (json['results'] as List)
          .whereType<Map<String, dynamic>>()
          .map((c) => ConcertModel.fromJson(c))
          .toList();
    }

    return AiSearchResponse(
      success: json['success'] == true,
      filter: parsedFilter,
      total: (json['total'] as int?) ?? list.length,
      results: list,
      message: (json['message'] as String?) ?? '',
    );
  }
}

/// Service komunikasi Flutter ke Backend LiveTix AI.
/// Flutter TIDAK memanggil API AI secara langsung.
/// Semua permintaan diproses melalui endpoint Backend ini di mana API Key diamankan.
class AiBackendService {
  static final AiBackendService _instance = AiBackendService._internal();
  factory AiBackendService() => _instance;

  AiBackendService._internal();

  http.Client? _customClient;
  String? _customBaseUrl;

  @visibleForTesting
  set customClient(http.Client? client) => _customClient = client;

  @visibleForTesting
  set customBaseUrl(String? url) => _customBaseUrl = url;

  http.Client get _client => _customClient ?? http.Client();

  /// Mendapatkan Base URL backend dari .env atau default localhost
  String get baseUrl {
    if (_customBaseUrl != null && _customBaseUrl!.isNotEmpty) {
      return _customBaseUrl!;
    }
    try {
      if (dotenv.isInitialized) {
        final fromEnv = dotenv.env['AI_BACKEND_URL'];
        if (fromEnv != null && fromEnv.trim().isNotEmpty) {
          return fromEnv.trim();
        }
      }
    } catch (_) {}

    // Deteksi platform default
    if (!kIsWeb) {
      try {
        if (Platform.isAndroid) {
          // Emulator Android menggunakan 10.0.2.2 untuk akses host
          return 'http://10.0.2.2:3000';
        }
      } catch (_) {}
    }
    // Desktop Windows/Linux/macOS dan Web browser → localhost
    return 'http://localhost:3000';
  }

  // ==========================================================================
  // FITUR 1: ASISTEN INFO KONSER (SISI USER)
  // ==========================================================================
  /// Mengirim pertanyaan pengguna ke backend untuk dicocokkan dengan database
  /// dan dijelaskan oleh AI berdasarkan data konser yang tersimpan.
  Future<AiConcertInfoResponse> askConcertInfo(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) {
      return const AiConcertInfoResponse(
        success: false,
        matched: false,
        ambiguous: false,
        message: 'Silakan ketik pertanyaan tentang konser yang ingin Anda tanyakan.',
      );
    }

    final uri = Uri.parse('$baseUrl/api/ai/concert-info');
    try {
      debugPrint('[AiBackendService] askConcertInfo → POST $uri | query: "$clean"');
      final res = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'query': clean}),
      ).timeout(const Duration(seconds: 25));

      debugPrint('[AiBackendService] askConcertInfo ← HTTP ${res.statusCode}');
      if (res.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(res.body);
        return AiConcertInfoResponse.fromJson(data);
      } else {
        final Map<String, dynamic>? data =
            tryDecodeJson(res.body);
        return AiConcertInfoResponse(
          success: false,
          matched: false,
          ambiguous: false,
          message: data?['message'] ??
              'Gagal memuat info konser dari server (HTTP ${res.statusCode}).',
        );
      }
    } catch (e) {
      debugPrint('[AiBackendService] askConcertInfo error ($uri): $e');
      return AiConcertInfoResponse(
        success: false,
        matched: false,
        ambiguous: false,
        message:
            'Tidak dapat terhubung ke server AI backend ($baseUrl). Pastikan backend server telah dijalankan.',
      );
    }
  }

  // ==========================================================================
  // FITUR 2: PENCARIAN KONSER DENGAN AI (SISI USER)
  // ==========================================================================
  /// Mengirim query bahasa alami ke backend untuk diekstrak menjadi filter JSON
  /// dan mengambil daftar konser yang cocok dari database.
  Future<AiSearchResponse> searchConcerts(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) {
      return const AiSearchResponse(
        success: false,
        total: 0,
        results: [],
        message: 'Masukkan kata kunci atau kriteria pencarian konser.',
      );
    }

    final uri = Uri.parse('$baseUrl/api/ai/search-concerts');
    try {
      final res = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'query': clean}),
      ).timeout(const Duration(seconds: 25));

      if (res.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(res.body);
        return AiSearchResponse.fromJson(data);
      } else {
        final Map<String, dynamic>? data = tryDecodeJson(res.body);
        return AiSearchResponse(
          success: false,
          total: 0,
          results: [],
          message: data?['message'] ??
              'Gagal melakukan pencarian konser di server (HTTP ${res.statusCode}).',
        );
      }
    } catch (e) {
      debugPrint('[AiBackendService] searchConcerts error: $e');
      return AiSearchResponse(
        success: false,
        total: 0,
        results: [],
        message:
            'Gagal menghubungi server AI backend ($baseUrl). Pastikan server backend sedang berjalan.',
      );
    }
  }

  // ==========================================================================
  // FITUR 3: AI ASSISTANT DESKRIPSI (SISI PRODUSER)
  // ==========================================================================
  /// Membantu produser menulis deskripsi konser 2-3 paragraf berdasarkan instruksi
  /// dan data form konser yang ada.
  Future<String> generateDescription({
    required String draft,
    String? title,
    String? genre,
    String? date,
    String? venue,
    String? artists,
  }) async {
    final cleanDraft = draft.trim();
    if (cleanDraft.length < 10) {
      throw 'Tuliskan poin-poin atau instruksi deskripsi minimal 10 karakter terlebih dahulu.';
    }

    final uri = Uri.parse('$baseUrl/api/ai/generate-description');
    try {
      final res = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'prompt': cleanDraft,
          'title': title,
          'genre': genre,
          'date': date,
          'venue': venue,
          'artists': artists,
        }),
      ).timeout(const Duration(seconds: 30));

      if (res.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(res.body);
        final desc = data['description'] as String?;
        if (desc != null && desc.isNotEmpty) {
          return desc;
        }
        throw 'Respons deskripsi dari AI kosong.';
      } else {
        final Map<String, dynamic>? data = tryDecodeJson(res.body);
        throw data?['message'] ??
            'Gagal membuat deskripsi dari server (HTTP ${res.statusCode}).';
      }
    } catch (e) {
      debugPrint('[AiBackendService] generateDescription error: $e');
      if (e is String) rethrow;
      throw 'Gagal terhubung ke backend AI ($baseUrl). Pastikan server backend telah aktif.';
    }
  }

  @visibleForTesting
  static Map<String, dynamic>? tryDecodeJson(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }
}
