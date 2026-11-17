import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/supabase_config.dart';
import 'supabase_service.dart';

/// Pemantau status koneksi ke server LiveTix (Supabase).
///
/// Dipakai untuk memberi umpan balik cepat ke pengguna ketika perangkat
/// sedang offline, sehingga form tidak "diam" lalu gagal tanpa penjelasan.
class NetworkStatusService {
  NetworkStatusService._();
  static final NetworkStatusService _instance = NetworkStatusService._();
  factory NetworkStatusService() => _instance;

  /// `null` = belum diketahui, `true` = terhubung, `false` = tidak terhubung.
  final ValueNotifier<bool?> isOnlineNotifier = ValueNotifier<bool?>(null);

  /// Anggap online bila status belum pernah diketahui, agar tidak memblokir
  /// pengguna pada pemeriksaan pertama.
  bool get isOnline => isOnlineNotifier.value != false;

  static const Duration _probeTimeout = Duration(seconds: 6);

  Timer? _timer;
  bool _checking = false;

  void _set(bool value) {
    if (isOnlineNotifier.value != value) {
      isOnlineNotifier.value = value;
    }
  }

  /// Melakukan pemeriksaan koneksi langsung ke endpoint Supabase.
  /// Respons HTTP apa pun (termasuk 401) berarti jaringan & server terjangkau.
  Future<bool> checkConnection() async {
    if (_checking) return isOnline;

    // Mode lokal/demo (Supabase belum diinisialisasi) dianggap selalu online,
    // karena tidak ada server yang perlu dijangkau.
    if (!SupabaseService.isInitialized) {
      _set(true);
      return true;
    }

    _checking = true;
    try {
      // Probe endpoint normal (bukan root /rest/v1/ yang butuh service_role).
      // Endpoint root selalu menolak anon key dengan "Invalid API key".
      final uri = Uri.parse(
        '${SupabaseConfig.url}/rest/v1/profiles?select=id&limit=1',
      );
      final key = SupabaseConfig.publishableKey;
      final res = await http.get(
        uri,
        headers: {'apikey': key, 'Authorization': 'Bearer $key'},
      ).timeout(_probeTimeout);
      final reachable = res.statusCode < 500;
      _set(reachable);
      return reachable;
    } catch (_) {
      _set(false);
      return false;
    } finally {
      _checking = false;
    }
  }

  /// Memulai pemantauan berkala (aman dipanggil berulang).
  void startMonitoring({Duration interval = const Duration(seconds: 20)}) {
    if (_timer != null) return;
    checkConnection();
    _timer = Timer.periodic(interval, (_) => checkConnection());
  }

  /// Menghentikan pemantauan berkala.
  void stopMonitoring() {
    _timer?.cancel();
    _timer = null;
  }
}
