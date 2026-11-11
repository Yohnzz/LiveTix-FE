import 'package:supabase_flutter/supabase_flutter.dart' hide LocalStorage;
import 'supabase_service.dart';
import 'promoter_data_service.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../data/db_dummy.dart';
import '../models/concert_model.dart';
import '../models/ticket_order_model.dart';
import '../models/user_model.dart';
import '../utils/local_storage.dart';
import '../utils/uuid_utils.dart';

/// Service akses data pusat aplikasi LiveTix.
/// Bertindak sebagai lapisan abstraksi (Data Access Layer) di atas db_dummy.dart.
/// Di masa depan, implementasi di dalam service ini dapat langsung diganti
/// dengan pemanggilan API backend / Supabase tanpa mengubah kode komponen antarmuka.
class DataService {
  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;
  DataService._internal() {
    _initService();
  }

  // Reactive State Notifiers
  final ValueNotifier<UserModel?> currentUserNotifier = ValueNotifier<UserModel?>(null);
  final ValueNotifier<List<UserTicketModel>> userTicketsNotifier = ValueNotifier<List<UserTicketModel>>([]);
  final ValueNotifier<bool> isDarkModeNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<Set<String>> favoriteConcertIdsNotifier = ValueNotifier<Set<String>>(<String>{});

  // Rekening khusus penerimaan refund dengan masa cooldown 1 minggu (7 hari) demi keamanan akun
  final ValueNotifier<UserRefundAccount?> refundAccountNotifier =
      ValueNotifier<UserRefundAccount?>(null);

  // Konfigurasi perkiraan biaya admin transaksi per kanal (dapat diatur dinamis oleh admin)
  final Map<String, int> _transactionFees = {
    'qris': 1000,
    'gopay': 1500,
    'dana': 1500,
    'shopeepay': 1500,
    'bca': 2500,
    'mandiri': 2500,
    'bri': 2500,
    'seabank': 2500,
  };

  // In-memory data store derived from DbDummy
  late final List<ConcertModel> _concerts;
  late final List<CityModel> _cities;
  late final List<UserModel> _users;
  final Set<String> _paidOrderIds = <String>{};
  bool _agreementAccepted = DbDummy.defaultGuestAgreementAccepted;

  static const String _cachedConcertsStorageKey = 'livetix_cached_concerts_v1';

  List<ConcertModel> _readCachedConcertsFromLocalStorage() {
    try {
      final raw = LocalStorage.getString(_cachedConcertsStorageKey);
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        return decoded
            .whereType<Map<String, dynamic>>()
            .map(ConcertModel.fromJson)
            .where((c) => c.id.isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return <ConcertModel>[];
  }

  void _saveCachedConcertsToLocalStorage(List<ConcertModel> concerts) {
    try {
      final encoded = jsonEncode(
        concerts
            .map((c) => {
                  ...c.toJson(),
                  'ticket_tiers': c.ticketTiers.map((t) => t.toJson()).toList(),
                })
            .toList(),
      );
      LocalStorage.setString(_cachedConcertsStorageKey, encoded);
    } catch (_) {}
  }

  bool _isTransientNetworkError(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('failed to fetch') ||
        msg.contains('clientexception') ||
        msg.contains('socketexception') ||
        msg.contains('timeoutexception') ||
        msg.contains('xmlhttprequest error') ||
        msg.contains('connection reset') ||
        msg.contains('connection closed');
  }

  Future<T> _withTransientRetry<T>(
    Future<T> Function() action, {
    int maxAttempts = 2,
  }) async {
    Object? lastError;
    StackTrace? lastStack;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await action();
      } catch (e, st) {
        lastError = e;
        lastStack = st;
        if (attempt >= maxAttempts || !_isTransientNetworkError(e)) {
          rethrow;
        }
        await Future.delayed(Duration(milliseconds: 450 * attempt));
      }
    }
    Error.throwWithStackTrace(lastError!, lastStack!);
  }

  void _initService() {
    _concerts = SupabaseService.isInitialized
        ? _readCachedConcertsFromLocalStorage()
        : List.from(DbDummy.concerts);
    _cities = List.from(DbDummy.cities);
    _users = List.from(DbDummy.users);
    // Pulihkan tiket tersimpan dari cache lokal jika ada (filter tiket dummy lawas)
    final savedTicketsRaw = LocalStorage.getString('livetix_saved_user_tickets');
    if (savedTicketsRaw != null && savedTicketsRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(savedTicketsRaw) as List<dynamic>;
        final cachedTickets = decoded
            .map((e) => UserTicketModel.fromJson(e as Map<String, dynamic>))
            .where((t) =>
                t.id != 'TKT-001' &&
                t.id != 'TKT-002' &&
                t.concertTitle != 'Soundwave Fest 2026' &&
                t.concertTitle != 'Nadin Amizah Live')
            .toList();
        userTicketsNotifier.value = cachedTickets;
      } catch (_) {
        userTicketsNotifier.value = <UserTicketModel>[];
      }
    } else {
      userTicketsNotifier.value = <UserTicketModel>[];
    }
    _agreementAccepted = DbDummy.defaultGuestAgreementAccepted ||
        LocalStorage.getBool(LocalStorage.agreementAcceptedKey);

    // Pulihkan rekening refund yang telah didaftarkan pengguna jika ada
    final savedRefund = LocalStorage.getString('livetix_saved_refund_account');
    if (savedRefund != null && savedRefund.isNotEmpty) {
      try {
        final map = jsonDecode(savedRefund) as Map<String, dynamic>;
        refundAccountNotifier.value = UserRefundAccount(
          provider: map['provider'] as String? ?? 'Bank BCA',
          accountNumber: map['accountNumber'] as String? ?? '',
          accountHolderName: map['accountHolderName'] as String? ?? '',
          accountType: map['accountType'] as String? ?? 'bank',
          lastUpdated:
              DateTime.tryParse(map['lastUpdated'] as String? ?? '') ??
                  DateTime.now(),
        );
      } catch (_) {}
    }

    // Tema tampilan: default Dark pada data dummy sesuai permintaan pengguna
    if (LocalStorage.containsKey(LocalStorage.darkModeKey)) {
      isDarkModeNotifier.value = LocalStorage.getBool(LocalStorage.darkModeKey);
    } else {
      isDarkModeNotifier.value = true;
    }

    // Data konser disukai (Favorit / Love) - murni dari penyimpanan pengguna
    final savedFavs = LocalStorage.getStringList('livetix_favorite_ids');
    favoriteConcertIdsNotifier.value = savedFavs.isNotEmpty ? savedFavs.toSet() : <String>{};

    if (SupabaseService.isInitialized) {
      fetchConcertsFromSupabase();
      fetchUserTicketsFromSupabase();
      startRealtimeSubscriptions();
    }
  }

  UserModel? get currentUser => currentUserNotifier.value;
  bool get isGuest => currentUserNotifier.value == null;
  List<ConcertModel> get rawConcerts => List.unmodifiable(_concerts);

  /// Mengambil konser dari cache memori lokal tanpa melakukan request jaringan.
  ConcertModel? cachedConcertById(String id) {
    final idx = _concerts.indexWhere((c) => c.id == id);
    if (idx == -1) return null;
    return _concerts[idx];
  }

  // --- API Mode Tampilan Gelap (Dark Mode Global) ---

  /// Mengatur preferensi tema gelap aplikasi dan menyimpannya di penyimpanan lokal
  void setDarkMode(bool isDark) {
    isDarkModeNotifier.value = isDark;
    LocalStorage.setBool('livetix_dark_mode', isDark);
  }

  /// Toggle tema tampilan antara mode terang dan gelap
  void toggleDarkMode() {
    setDarkMode(!isDarkModeNotifier.value);
  }

  // --- API Konser Favorit (Disukai / Love) ---

  /// Mengecek apakah suatu konser ditandai sebagai favorit oleh pengguna
  bool isFavorite(String concertId) =>
      favoriteConcertIdsNotifier.value.contains(concertId);

  final Map<String, Timer> _likeDebounceTimers = {};
  final Set<String> _serverLikedConcertIds = {};
  final ValueNotifier<int> stockVersionNotifier = ValueNotifier<int>(0);
  RealtimeChannel? _tiersRealtimeChannel;
  RealtimeChannel? _concertsRealtimeChannel;
  DateTime? _lastExpiredCleanup;
  Future<void>? _ongoingLikesFetch;
  Future<void>? _ongoingTicketFetch;
  Future<void>? _ongoingRestoreSession;
  DateTime? _lastSessionRestoreAt;
  bool _pendingConcertForceRefresh = false;
  final Map<String, Future<ConcertModel?>> _ongoingConcertByIdFetches = {};

  /// Mengambil daftar konser yang disukai user langsung dari tabel concert_likes Supabase
  Future<void> fetchUserLikesFromSupabase() async {
    if (!SupabaseService.isInitialized) return;
    if (_ongoingLikesFetch != null) return _ongoingLikesFetch!;

    final future = _doFetchUserLikesFromSupabase();
    _ongoingLikesFetch = future;
    try {
      await future;
    } finally {
      if (_ongoingLikesFetch == future) {
        _ongoingLikesFetch = null;
      }
    }
  }

  Future<void> _doFetchUserLikesFromSupabase() async {
    final userId = currentUserNotifier.value?.id;
    if (userId == null || userId.isEmpty) return;
    final uuidRegex = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    if (!uuidRegex.hasMatch(userId)) return;

    try {
      final rows = await _withTransientRetry(
        () => SupabaseService.client
            .from('concert_likes')
            .select('concert_id')
            .eq('user_id', userId),
      );
      final serverIds = rows
          .map((e) => (e['concert_id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet();
      _serverLikedConcertIds
        ..clear()
        ..addAll(serverIds);
      favoriteConcertIdsNotifier.value = Set<String>.from(serverIds);
      LocalStorage.setStringList('livetix_favorite_ids', serverIds.toList());
    } catch (e) {
      debugPrint('Error fetchUserLikesFromSupabase: $e');
    }
  }

  /// Mendengarkan perubahan realtime pada ticket_tiers & concerts via Supabase Realtime
  void startRealtimeSubscriptions() {
    if (!SupabaseService.isInitialized) return;
    try {
      _tiersRealtimeChannel ??= SupabaseService.client
          .channel('public:ticket_tiers')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'ticket_tiers',
            callback: (payload) async {
              await fetchConcertsFromSupabase(forceRefresh: true);
              await PromoterDataService().fetchPromoterConcertsFromSupabase();
            },
          )
          .subscribe();
      _concertsRealtimeChannel ??= SupabaseService.client
          .channel('public:concerts')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'concerts',
            callback: (payload) async {
              await fetchConcertsFromSupabase(forceRefresh: true);
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Error starting realtime subscriptions: $e');
    }
  }

  /// Mengambil jumlah suka (love) terkini dari suatu konser
  int getConcertLikesCount(String concertId) {
    final idx = _concerts.indexWhere((c) => c.id == concertId);
    if (idx != -1) return _concerts[idx].likesCount;
    return 0;
  }

  void _syncConcertLikeWithDebounce(
      String concertId, int delta, bool targetIsLiked) {
    if (delta == 0) return;
    final idx = _concerts.indexWhere((c) => c.id == concertId);
    if (idx != -1) {
      final currentLikes = _concerts[idx].likesCount;
      final nextLikes = (currentLikes + delta) < 0 ? 0 : (currentLikes + delta);
      _concerts[idx] = _concerts[idx].copyWith(likesCount: nextLikes);
    }
    // Sinkronkan jumlah love ke dashboard & daftar konser Produser secara optimistic
    PromoterDataService().adjustConcertLikes(concertId, delta);

    if (!SupabaseService.isInitialized) return;
    final userId = currentUserNotifier.value?.id;
    if (userId == null || userId.isEmpty) return;

    // Batalkan timer debounce yang tertunda jika user mengubah pilihan dalam 5 detik
    _likeDebounceTimers[concertId]?.cancel();
    _likeDebounceTimers.remove(concertId);

    // Jika kembali ke status yang sama dengan yang tersimpan di server, tidak perlu request
    final bool wasServerLiked = _serverLikedConcertIds.contains(concertId);
    if (targetIsLiked == wasServerLiked) {
      return;
    }

    // Tunggu 5 detik sebelum mengirim request Like/Unlike ke Supabase
    _likeDebounceTimers[concertId] =
        Timer(const Duration(seconds: 5), () async {
      _likeDebounceTimers.remove(concertId);
      if (!SupabaseService.isInitialized) return;
      final activeUid = currentUserNotifier.value?.id;
      if (activeUid == null || activeUid.isEmpty) return;

      final uuidRegex = RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
      if (!uuidRegex.hasMatch(activeUid)) return;

      try {
        if (targetIsLiked) {
          await SupabaseService.client.from('concert_likes').upsert(
            {'concert_id': concertId, 'user_id': activeUid},
            onConflict: 'user_id,concert_id',
          );
          _serverLikedConcertIds.add(concertId);
        } else {
          await SupabaseService.client
              .from('concert_likes')
              .delete()
              .match({'concert_id': concertId, 'user_id': activeUid});
          _serverLikedConcertIds.remove(concertId);
        }

        // Hitung ulang total like secara akurat dari database & simpan ke concerts
        final countRes = await SupabaseService.client
            .from('concert_likes')
            .select('id')
            .eq('concert_id', concertId);
        final exactCount = countRes.length;
        await SupabaseService.client
            .from('concerts')
            .update({'likes_count': exactCount}).eq('id', concertId);
      } catch (e) {
        debugPrint('Error sync concert_likes ke Supabase: $e');
      }
    });
  }

  /// Toggle status favorit konser dan menyimpan perubahan ke memori, penyimpanan lokal, serta Produser (debounce 5 detik)
  void toggleFavorite(String concertId) {
    final updated = Set<String>.from(favoriteConcertIdsNotifier.value);
    final bool wasFav = updated.contains(concertId);
    if (wasFav) {
      updated.remove(concertId);
    } else {
      updated.add(concertId);
    }
    favoriteConcertIdsNotifier.value = updated;
    LocalStorage.setStringList('livetix_favorite_ids', updated.toList());
    _syncConcertLikeWithDebounce(concertId, wasFav ? -1 : 1, !wasFav);
  }

  /// Menetapkan status favorit suatu konser secara eksplisit (debounce 5 detik)
  void setFavorite(String concertId, bool isFav) {
    final updated = Set<String>.from(favoriteConcertIdsNotifier.value);
    final bool wasFav = updated.contains(concertId);
    if (wasFav == isFav) return;
    if (isFav) {
      updated.add(concertId);
    } else {
      updated.remove(concertId);
    }
    favoriteConcertIdsNotifier.value = updated;
    LocalStorage.setStringList('livetix_favorite_ids', updated.toList());
    _syncConcertLikeWithDebounce(concertId, isFav ? 1 : -1, isFav);
  }

  /// Mengecek apakah pengguna sudah pernah menyetujui modal persetujuan (tersimpan di lokal atau akun)
  bool get hasAcceptedAgreement =>
      _agreementAccepted ||
      LocalStorage.getBool(LocalStorage.agreementAcceptedKey) ||
      (currentUserNotifier.value?.hasAcceptedAgreement ?? false);

  /// Menyimpan status persetujuan ke penyimpanan lokal dan data sesi agar tidak ditampilkan berulang
  void acceptAgreement() {
    _agreementAccepted = true;
    LocalStorage.setBool(LocalStorage.agreementAcceptedKey, true);
    final active = currentUserNotifier.value;
    if (active != null && !active.hasAcceptedAgreement) {
      final updated = active.copyWith(hasAcceptedAgreement: true);
      final idx = _users.indexWhere(
        (u) => u.email.toLowerCase() == active.email.toLowerCase(),
      );
      if (idx != -1) {
        _users[idx] = updated;
      }
      currentUserNotifier.value = updated;
    }
  }

  /// Mengatur ulang status persetujuan (untuk pengujian atau penarikan persetujuan)
  void setAgreementStatus(bool accepted) {
    _agreementAccepted = accepted;
    if (accepted) {
      LocalStorage.setBool(LocalStorage.agreementAcceptedKey, true);
    } else {
      LocalStorage.remove(LocalStorage.agreementAcceptedKey);
    }
  }

  // --- API Konser & Event ---
  bool _hasFetchedConcertsFromSupabase = false;
  Future<List<ConcertModel>>? _ongoingConcertFetch;

  /// Memuat daftar konser dan kategori tiket secara langsung dari Supabase Cloud
  Future<List<ConcertModel>> fetchConcertsFromSupabase({bool forceRefresh = false}) async {
    if (!SupabaseService.isInitialized) return _concerts;
    if (_hasFetchedConcertsFromSupabase && !forceRefresh) return _concerts;
    if (_ongoingConcertFetch != null) {
      if (forceRefresh) {
        _pendingConcertForceRefresh = true;
      }
      return _ongoingConcertFetch!;
    }

    final future = _doFetchConcertsFromSupabase();
    _ongoingConcertFetch = future;
    try {
      return await future;
    } finally {
      if (_ongoingConcertFetch == future) {
        _ongoingConcertFetch = null;
      }
      if (_pendingConcertForceRefresh) {
        _pendingConcertForceRefresh = false;
        unawaited(fetchConcertsFromSupabase(forceRefresh: true));
      }
    }
  }

  void _triggerExpiredOrdersCleanupNonBlocking() {
    final now = DateTime.now();
    if (_lastExpiredCleanup != null &&
        now.difference(_lastExpiredCleanup!).inSeconds < 60) {
      return;
    }
    _lastExpiredCleanup = now;
    unawaited(() async {
      try {
        await SupabaseService.client
            .rpc('release_expired_orders')
            .timeout(const Duration(seconds: 4));
      } catch (_) {}
    }());
  }

  Future<List<ConcertModel>> _doFetchConcertsFromSupabase() async {
    try {
      _triggerExpiredOrdersCleanupNonBlocking();

      final response = await _withTransientRetry(
        () => SupabaseService.client
            .from('concerts')
            .select('*, ticket_tiers(*)')
            .order('created_at', ascending: false),
      );

      final List<ConcertModel> liveItems = [];
      for (final item in response) {
        try {
          final statusStr =
              (item['approval_status'] ?? item['status'] ?? 'published')
                  .toString()
                  .toLowerCase();
          final isApproved = statusStr == 'published' ||
              statusStr == 'approved' ||
              statusStr == 'disetujui';
          if (!isApproved) continue;

          final parsed = ConcertModel.fromJson(item);
          if (parsed.isPublished) {
            liveItems.add(parsed);
          }
        } catch (err) {
          debugPrint('Error parse concert item: $err');
        }
      }
      _concerts
        ..clear()
        ..addAll(liveItems);
      _hasFetchedConcertsFromSupabase = true;
      _saveCachedConcertsToLocalStorage(_concerts);
      stockVersionNotifier.value++;
      return _concerts;
    } catch (e) {
      debugPrint('Gagal fetch konser dari Supabase: $e');
    }
    return _concerts;
  }

  /// Mengambil detail satu konser secara lengkap berdasarkan ID (termasuk tiket tiers dari Supabase).
  /// Tidak memicu stockVersionNotifier agar listener detail/checkout tidak memicu loop fetch berulang.
  Future<ConcertModel?> getConcertById(String id) async {
    if (SupabaseService.isInitialized) {
      final ongoing = _ongoingConcertByIdFetches[id];
      if (ongoing != null) return ongoing;

      final future = _doGetConcertById(id);
      _ongoingConcertByIdFetches[id] = future;
      try {
        return await future;
      } finally {
        if (identical(_ongoingConcertByIdFetches[id], future)) {
          _ongoingConcertByIdFetches.remove(id);
        }
      }
    }

    return cachedConcertById(id);
  }

  Future<ConcertModel?> _doGetConcertById(String id) async {
    try {
      final res = await _withTransientRetry(
        () => SupabaseService.client
            .from('concerts')
            .select('*, ticket_tiers(*)')
            .eq('id', id)
            .maybeSingle(),
      );

      if (res != null) {
        final liveConcert = ConcertModel.fromJson(res);
        final idx = _concerts.indexWhere((c) => c.id == id);
        if (idx != -1) {
          _concerts[idx] = liveConcert;
        } else {
          _concerts.add(liveConcert);
        }
        return liveConcert;
      }
    } catch (e) {
      debugPrint('Gagal fetch konser by id dari Supabase: $e');
    }

    return cachedConcertById(id);
  }

  /// Mengambil daftar event dengan dukungan filter kota, genre, tanggal spesifik, rentang harga, keyword pencarian, dan favorit (maksimal limit bila ditentukan).
  Future<List<ConcertModel>> getEvents({
    String city = 'Semua',
    String genre = 'Semua',
    String date = 'Semua',
    DateTime? selectedDate,
    int? minPrice,
    int? maxPrice,
    String query = '',
    bool onlyFavorites = false,
    int? limit,
  }) async {
    if (SupabaseService.isInitialized && !_hasFetchedConcertsFromSupabase) {
      await fetchConcertsFromSupabase();
    } else {
      await Future.delayed(const Duration(milliseconds: 50));
    }

    final results = _concerts.where((concert) {
      // 0. Filter Favorit (Disukai) jika diminta
      if (onlyFavorites && !isFavorite(concert.id)) {
        return false;
      }

      // 1. Filter Kota
      final matchCity = city == 'Semua' ||
          city.isEmpty ||
          concert.venue.toLowerCase().contains(city.toLowerCase());

      // 2. Filter Genre
      final matchGenre = genre == 'Semua' ||
          genre.isEmpty ||
          concert.category.toLowerCase() == genre.toLowerCase();

      // 3. Filter Tanggal (mendukung DateTime spesifik maupun string)
      bool matchDate = true;
      if (selectedDate != null) {
        final concertDt = concert.parsedDate;
        matchDate = concertDt != null &&
            concertDt.year == selectedDate.year &&
            concertDt.month == selectedDate.month &&
            concertDt.day == selectedDate.day;
      } else if (date != 'Semua' && date.isNotEmpty) {
        matchDate = concert.date.toLowerCase().contains(date.toLowerCase().split(' ').first);
      }

      // 4. Filter Rentang Harga
      final matchMinPrice = minPrice == null || concert.price >= minPrice;
      final matchMaxPrice = maxPrice == null || concert.price <= maxPrice;

      // 5. Filter Keyword Pencarian (case-insensitive & substring)
      final q = query.trim().toLowerCase();
      final matchQuery = q.isEmpty ||
          concert.title.toLowerCase().contains(q) ||
          concert.subtitle.toLowerCase().contains(q) ||
          concert.venue.toLowerCase().contains(q) ||
          concert.category.toLowerCase().contains(q);

      return matchCity && matchGenre && matchDate && matchMinPrice && matchMaxPrice && matchQuery;
    }).toList();

    if (limit != null && limit > 0 && results.length > limit) {
      return results.take(limit).toList();
    }
    return results;
  }

  /// Mengambil satu konser unggulan (Featured Concert) untuk kompatibilitas
  Future<ConcertModel> getFeaturedEvent() async {
    if (SupabaseService.isInitialized && !_hasFetchedConcertsFromSupabase) {
      await fetchConcertsFromSupabase();
    } else {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    if (_concerts.isEmpty) {
      return const ConcertModel(
        id: 'no-concert',
        title: 'Belum Ada Konser',
        subtitle: 'Segera Hadir di LiveTix',
        date: 'Segera',
        time: '',
        venue: 'LiveTix Arena',
        price: 0,
        category: 'Live',
        tag: 'Segera Hadir',
      );
    }
    return _concerts.firstWhere(
      (c) => c.status == 'published' || c.bannerImageUrl != null || c.bannerImageBytes != null,
      orElse: () => _concerts.first,
    );
  }

  /// Mengambil daftar konser highlight di Beranda untuk carousel geser & otomatis
  Future<List<ConcertModel>> getFeaturedEvents() async {
    if (SupabaseService.isInitialized && !_hasFetchedConcertsFromSupabase) {
      await fetchConcertsFromSupabase();
    } else {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    final featured = _concerts
        .where((c) =>
            c.bannerImageUrl != null ||
            c.bannerImageBytes != null ||
            c.status == 'published')
        .toList();
    if (featured.isNotEmpty) return featured;
    return _concerts.take(5).toList();
  }

  /// Memperbarui aset gambar konser oleh Produser (banner persegi panjang & logo persegi)
  ConcertModel? updateConcertMedia({
    required String concertId,
    String? bannerImageUrl,
    Uint8List? bannerImageBytes,
    bool clearBannerImage = false,
    String? logoImageUrl,
    Uint8List? logoImageBytes,
    bool clearLogoImage = false,
  }) {
    final index = _concerts.indexWhere((c) => c.id == concertId);
    if (index == -1) return null;

    final updated = _concerts[index].copyWith(
      bannerImageUrl: bannerImageUrl,
      bannerImageBytes: bannerImageBytes,
      clearBannerImage: clearBannerImage,
      logoImageUrl: logoImageUrl,
      logoImageBytes: logoImageBytes,
      clearLogoImage: clearLogoImage,
    );
    _concerts[index] = updated;
    return updated;
  }

  /// Mengambil daftar kota populer
  Future<List<CityModel>> getCities() async {
    await Future.delayed(const Duration(milliseconds: 50));
    return List.unmodifiable(_cities);
  }

  /// Mengambil daftar genre
  Future<List<String>> getGenres() async {
    return List.unmodifiable(DbDummy.genres);
  }

  /// Mengambil daftar opsi tanggal
  Future<List<String>> getDates() async {
    return List.unmodifiable(DbDummy.dates);
  }

  // --- API Autentikasi & Profil ---

  /// Login sinkron untuk validasi instan dan pembaruan state langsung
  UserModel? loginSync(String email, String password) {
    final trimmedEmail = email.trim();
    final normalizedEmail = trimmedEmail.toLowerCase();
    final existingIndex = _users.indexWhere(
      (u) => u.email.toLowerCase() == normalizedEmail,
    );

    if (existingIndex != -1) {
      final existingUser = _users[existingIndex];
      final pwMatches = existingUser.password == password ||
          (existingUser.role == 'Admin' &&
              (password == 'admin123' || password == 'password123')) ||
          (existingUser.role == 'Gatecrew' &&
              (password == 'crewgate123' ||
                  password == 'gatecrew123' ||
                  password == 'password123')) ||
          (password == 'password123');
      if (!pwMatches) {
        return null;
      }
      currentUserNotifier.value = existingUser;
      if (existingUser.role == 'Produser') {
        PromoterDataService().isPinUnlockedThisSession = false;
      }
      if (SupabaseService.isInitialized) {
        fetchUserTicketsFromSupabase();
      }
      return existingUser;
    }

    // Buat akun dinamis jika email belum terdaftar untuk pengujian cepat
    final rawPrefix = trimmedEmail.split('@').first;
    final displayName = rawPrefix.isNotEmpty
        ? '${rawPrefix[0].toUpperCase()}${rawPrefix.substring(1)}'
        : 'User';
    String resolvedRole = 'User';
    if (normalizedEmail.contains('admin')) {
      resolvedRole = 'Admin';
    } else if (normalizedEmail.contains('produser') ||
        normalizedEmail.contains('producer') ||
        normalizedEmail.contains('promoter')) {
      resolvedRole = 'Produser';
    } else if (normalizedEmail.contains('gatecrew') ||
        normalizedEmail.contains('crew')) {
      resolvedRole = 'Gatecrew';
    }

    final fallback = UserModel(
      id: UserModel.generateSixCharId(normalizedEmail),
      name: displayName,
      email: trimmedEmail,
      phone: '08123456789',
      password: password,
      role: resolvedRole,
    );
    _users.add(fallback);
    currentUserNotifier.value = fallback;
    if (SupabaseService.isInitialized) {
      fetchUserTicketsFromSupabase();
    }
    return fallback;
  }

  /// Helper normalisasi role dari Supabase
  static String normalizeRole(String? rawRole) {
    if (rawRole == null) return 'User';
    final lower = rawRole.trim().toLowerCase();
    if (lower == 'admin') return 'Admin';
    if (lower == 'produser' || lower == 'producer' || lower == 'developer' || lower == 'promoter') {
      return 'Produser';
    }
    if (lower == 'gatecrew' || lower == 'gate_crew' || lower == 'crew' || lower == 'gate crew') {
      return 'Gatecrew';
    }
    return 'User';
  }

  /// Pulihkan sesi Supabase saat aplikasi dibuka
  Future<void> restoreSupabaseSession({bool force = false}) async {
    if (!force && _ongoingRestoreSession != null) {
      return _ongoingRestoreSession!;
    }
    if (!force &&
        _lastSessionRestoreAt != null &&
        DateTime.now().difference(_lastSessionRestoreAt!) <
            const Duration(seconds: 3)) {
      return;
    }
    final future = _doRestoreSupabaseSession();
    _ongoingRestoreSession = future;
    try {
      await future;
    } finally {
      if (identical(_ongoingRestoreSession, future)) {
        _ongoingRestoreSession = null;
      }
    }
  }

  Future<void> _doRestoreSupabaseSession() async {
    // 1. Cek penyimpanan lokal disk terlebih dahulu agar instan saat cold/hot start
    final cached = LocalStorage.getString(LocalStorage.savedUserKey);
    if (cached != null && cached.isNotEmpty) {
      try {
        final cachedUser = UserModel.fromJson(jsonDecode(cached));
        currentUserNotifier.value = cachedUser;
      } catch (_) {}
    }

    if (!SupabaseService.isInitialized) return;
    _lastSessionRestoreAt = DateTime.now();
    await fetchConcertsFromSupabase();
    await fetchUserTicketsFromSupabase();
    try {
      final authUser = SupabaseService.client.auth.currentUser;
      if (authUser == null) {
        // Jika Supabase tidak mendeteksi sesi pengguna aktif, bersihkan cache lokal
        currentUserNotifier.value = null;
        LocalStorage.remove(LocalStorage.savedUserKey);
        return;
      }

      final meta = authUser.userMetadata ?? {};
      String resolvedRole = normalizeRole(meta['role'] as String?);
      String resolvedName = (meta['name'] as String?) ??
          (meta['full_name'] as String?) ??
          (authUser.email ?? 'User').split('@').first;
      String resolvedPhone = (meta['phone'] as String?) ?? '';
      String? resolvedAvatarUrl =
          (meta['url_foto'] as String?) ?? (meta['avatar_url'] as String?);

      try {
        final profileRes = await _withTransientRetry(
          () => SupabaseService.client
              .from('profiles')
              .select()
              .eq('id', authUser.id)
              .maybeSingle(),
        );

        if (profileRes != null) {
          resolvedRole = normalizeRole(profileRes['role'] as String?);
          resolvedName = (profileRes['name'] as String?) ??
              (profileRes['full_name'] as String?) ??
              resolvedName;
          resolvedPhone = (profileRes['phone'] as String?) ?? resolvedPhone;

          final dbFoto = (profileRes['url_foto'] as String?) ??
              (profileRes['avatar_url'] as String?);
          if (dbFoto != null) {
            resolvedAvatarUrl = dbFoto;
          }

          final rBank = profileRes['refund_bank_name'] as String?;
          final rNum = profileRes['refund_account_number'] as String?;
          final rHolder = profileRes['refund_account_name'] as String?;
          final rType = (profileRes['refund_account_type'] as String?) ?? 'bank';
          final rUpdated = profileRes['refund_last_updated'] as String?;
          if (rBank != null && rNum != null && rBank.isNotEmpty && rNum.isNotEmpty) {
            refundAccountNotifier.value = UserRefundAccount(
              provider: rBank,
              accountNumber: rNum,
              accountHolderName: rHolder ?? resolvedName,
              accountType: rType,
              lastUpdated: DateTime.tryParse(rUpdated ?? '') ?? DateTime.now(),
            );
          }
        }
      } catch (_) {}

      final user = UserModel(
        id: authUser.id,
        name: resolvedName,
        email: authUser.email ?? '',
        phone: resolvedPhone,
        password: currentUserNotifier.value?.password ?? '',
        role: resolvedRole,
        avatarUrl: resolvedAvatarUrl,
      );

      currentUserNotifier.value = user;
      LocalStorage.setString(
        LocalStorage.savedUserKey,
        jsonEncode(user.toJson()),
      );
      await fetchUserLikesFromSupabase();
      startRealtimeSubscriptions();
      if (user.role == 'Produser') {
        await PromoterDataService().loadProducerProfileFromSupabase();
      }
    } catch (_) {}
  }

  /// Login akun pengguna via Supabase Auth
  Future<UserModel?> login(String email, String password) async {
    _lastSessionRestoreAt = null;
    if (SupabaseService.isInitialized) {
      final response = await SupabaseService.client.auth.signInWithPassword(
        email: email.trim(),
        password: password.trim(),
      );
      final authUser = response.user;
      if (authUser == null) return null;

      final meta = authUser.userMetadata ?? {};
      String resolvedRole = normalizeRole(meta['role'] as String?);
      String resolvedName = (meta['name'] as String?) ??
          (meta['full_name'] as String?) ??
          email.trim().split('@').first;
      String resolvedPhone = (meta['phone'] as String?) ?? '';
      String? resolvedAvatarUrl =
          (meta['url_foto'] as String?) ?? (meta['avatar_url'] as String?);

      try {
        final profileRes = await _withTransientRetry(
          () => SupabaseService.client
              .from('profiles')
              .select()
              .eq('id', authUser.id)
              .maybeSingle(),
        );

        if (profileRes != null) {
          resolvedRole = normalizeRole(profileRes['role'] as String?);
          resolvedName = (profileRes['name'] as String?) ??
              (profileRes['full_name'] as String?) ??
              resolvedName;
          resolvedPhone = (profileRes['phone'] as String?) ?? resolvedPhone;

          final dbFoto = (profileRes['url_foto'] as String?) ??
              (profileRes['avatar_url'] as String?);
          if (dbFoto != null) {
            resolvedAvatarUrl = dbFoto;
          }

          final rBank = profileRes['refund_bank_name'] as String?;
          final rNum = profileRes['refund_account_number'] as String?;
          final rHolder = profileRes['refund_account_name'] as String?;
          final rType = (profileRes['refund_account_type'] as String?) ?? 'bank';
          final rUpdated = profileRes['refund_last_updated'] as String?;
          if (rBank != null && rNum != null && rBank.isNotEmpty && rNum.isNotEmpty) {
            refundAccountNotifier.value = UserRefundAccount(
              provider: rBank,
              accountNumber: rNum,
              accountHolderName: rHolder ?? resolvedName,
              accountType: rType,
              lastUpdated: DateTime.tryParse(rUpdated ?? '') ?? DateTime.now(),
            );
          }
        }
      } catch (_) {}

      final user = UserModel(
        id: authUser.id,
        name: resolvedName,
        email: authUser.email ?? email.trim(),
        phone: resolvedPhone,
        password: password.trim(),
        role: resolvedRole,
        avatarUrl: resolvedAvatarUrl,
      );

      currentUserNotifier.value = user;
      LocalStorage.setString(
        LocalStorage.savedUserKey,
        jsonEncode(user.toJson()),
      );
      if (user.role == 'Produser') {
        PromoterDataService().isPinUnlockedThisSession = false;
        await PromoterDataService().loadProducerProfileFromSupabase();
      }
      if (SupabaseService.isInitialized) {
        await fetchUserTicketsFromSupabase();
        await fetchUserLikesFromSupabase();
        startRealtimeSubscriptions();
      }
      return user;
    }

    final user = loginSync(email, password);
    if (user != null) {
      LocalStorage.setString(
        LocalStorage.savedUserKey,
        jsonEncode(user.toJson()),
      );
      if (user.role == 'Produser') {
        PromoterDataService().isPinUnlockedThisSession = false;
      }
    }
    await Future.delayed(const Duration(milliseconds: 100));
    return user;
  }

  /// Mendaftarkan akun Gate Crew yang sudah disetujui Admin ke dalam memori autentikasi
  void registerGateCrewAccountInMemory({
    required String id,
    required String name,
    required String email,
    required String phone,
    String password = 'crewgate123',
  }) {
    final normalizedEmail = email.trim().toLowerCase();
    final existingIdx = _users.indexWhere(
      (u) => u.email.toLowerCase() == normalizedEmail,
    );
    final crewUser = UserModel(
      id: id,
      name: name.trim(),
      email: email.trim(),
      phone: phone.trim(),
      password: password,
      role: 'Gatecrew',
    );
    if (existingIdx != -1) {
      _users[existingIdx] = crewUser;
    } else {
      _users.add(crewUser);
    }
  }

  /// Menghapus akun Gate Crew dari memori autentikasi lokal setelah dihapus Admin
  void removeGateCrewAccountInMemory({String? id, String? email}) {
    final normalizedEmail = email?.trim().toLowerCase() ?? '';
    _users.removeWhere((u) {
      if (u.role.toLowerCase() != 'gatecrew') return false;
      final matchId = id != null && id.isNotEmpty && u.id == id;
      final matchEmail = normalizedEmail.isNotEmpty &&
          u.email.trim().toLowerCase() == normalizedEmail;
      return matchId || matchEmail;
    });
  }

  /// Registrasi sinkron untuk pembaruan state langsung
  UserModel registerSync({
    required String name,
    required String email,
    required String phone,
    required String password,
    String role = 'User',
  }) {
    final normalizedEmail = email.trim().toLowerCase();
    final existingIndex = _users.indexWhere(
      (u) => u.email.toLowerCase() == normalizedEmail,
    );
    final resolvedId = existingIndex != -1
        ? _users[existingIndex].displayId
        : UserModel.generateSixCharId(normalizedEmail);
    final normalizedRole = normalizeRole(role);
    final newUser = UserModel(
      id: resolvedId,
      name: name.trim(),
      email: email.trim(),
      phone: phone.trim(),
      password: password,
      role: normalizedRole,
    );
    if (existingIndex != -1) {
      _users[existingIndex] = newUser;
    } else {
      _users.add(newUser);
    }
    if (normalizedRole == 'Produser') {
      PromoterDataService().promoterNameNotifier.value = name.trim();
      PromoterDataService().verificationStatusNotifier.value = 'unverified';
      PromoterDataService().isPinUnlockedThisSession = false;
    }
    currentUserNotifier.value = newUser;
    return newUser;
  }

  /// Registrasi akun baru via Supabase Auth
  Future<UserModel> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    String role = 'User',
  }) async {
    final normalizedRole = normalizeRole(role);
    if (SupabaseService.isInitialized) {
      final response = await SupabaseService.client.auth.signUp(
        email: email.trim(),
        password: password.trim(),
        data: {
          'name': name.trim(),
          'full_name': name.trim(),
          'phone': phone.trim(),
          'role': normalizedRole,
        },
      );

      final authUser = response.user;
      final userId = authUser?.id ?? UserModel.generateSixCharId(email);

      try {
        final generatedUsername =
            '${name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_')}_${userId.length >= 6 ? userId.substring(0, 6) : userId}';
        await SupabaseService.client.from('profiles').upsert({
          'id': userId,
          'username': generatedUsername,
          'name': name.trim(),
          'full_name': name.trim(),
          'email': email.trim(),
          'phone': phone.trim(),
          'role': normalizedRole,
          'verification_status':
              normalizedRole == 'Produser' ? 'unverified' : 'approved',
          'approval_status':
              normalizedRole == 'Produser' ? 'unverified' : 'approved',
        });

        if (normalizedRole == 'Produser') {
          await SupabaseService.client.from('promoter_profiles').upsert({
            'id': 'promoter-$userId',
            'user_id': userId,
            'company_name': name.trim(),
            'is_verified': false,
            'approval_status': 'unverified',
            'submitted_at': DateTime.now().toIso8601String(),
          });
          PromoterDataService().promoterNameNotifier.value = name.trim();
          PromoterDataService().verificationStatusNotifier.value = 'unverified';
          PromoterDataService().isPinUnlockedThisSession = false;
        }
      } catch (_) {}

      final user = UserModel(
        id: userId,
        name: name.trim(),
        email: email.trim(),
        phone: phone.trim(),
        password: password.trim(),
        role: normalizedRole,
      );

      currentUserNotifier.value = user;
      LocalStorage.setString(
        LocalStorage.savedUserKey,
        jsonEncode(user.toJson()),
      );
      return user;
    }

    final newUser = registerSync(
      name: name,
      email: email,
      phone: phone,
      password: password,
      role: normalizedRole,
    );
    LocalStorage.setString(
      LocalStorage.savedUserKey,
      jsonEncode(newUser.toJson()),
    );
    await Future.delayed(const Duration(milliseconds: 100));
    return newUser;
  }

  /// Memperbarui data profil pengguna yang sedang login (nama, foto profil, tema warna avatar)
  Future<UserModel?> updateProfile({
    String? name,
    String? avatarUrl,
    Uint8List? profileImageBytes,
    bool clearProfileImage = false,
    int? avatarColorIndex,
  }) async {
    final active = currentUserNotifier.value;
    if (active == null) return null;

    final resolvedName =
        name != null && name.trim().isNotEmpty ? name.trim() : active.name;

    String? resolvedAvatarUrl = avatarUrl;
    if (clearProfileImage) {
      resolvedAvatarUrl = '';
    } else if (resolvedAvatarUrl == null &&
        profileImageBytes != null &&
        profileImageBytes.isNotEmpty) {
      resolvedAvatarUrl = 'data:image/jpeg;base64,${base64Encode(profileImageBytes)}';
    }

    // 1. Optimistic update agar UI langsung responsif
    var updated = active.copyWith(
      name: resolvedName,
      avatarUrl: resolvedAvatarUrl ?? active.avatarUrl,
      profileImageBytes: profileImageBytes,
      clearProfileImage: clearProfileImage,
      avatarColorIndex: avatarColorIndex,
    );

    final index = _users.indexWhere(
      (u) => u.email.toLowerCase() == active.email.toLowerCase(),
    );
    if (index != -1) {
      _users[index] = updated;
    } else {
      _users.add(updated);
    }
    currentUserNotifier.value = updated;

    try {
      LocalStorage.setString(
        LocalStorage.savedUserKey,
        jsonEncode(updated.toJson()),
      );
    } catch (_) {}

    // 2. Upload foto ke Supabase Storage & simpan url_foto ke tabel profiles
    if (SupabaseService.isInitialized) {
      if (!clearProfileImage &&
          profileImageBytes != null &&
          profileImageBytes.isNotEmpty) {
        try {
          final filePath =
              'user_${active.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          await SupabaseService.client.storage.from('avatars').uploadBinary(
                filePath,
                profileImageBytes,
                fileOptions: const FileOptions(
                  contentType: 'image/jpeg',
                  upsert: true,
                ),
              );
          final publicUrl = SupabaseService.client.storage
              .from('avatars')
              .getPublicUrl(filePath);
          if (publicUrl.isNotEmpty) {
            resolvedAvatarUrl = publicUrl;
            updated = updated.copyWith(avatarUrl: publicUrl);
            currentUserNotifier.value = updated;
            try {
              LocalStorage.setString(
                LocalStorage.savedUserKey,
                jsonEncode(updated.toJson()),
              );
            } catch (_) {}
          }
        } catch (e) {
          debugPrint('Error upload foto ke Supabase Storage: $e');
        }
      }

      final updateData = <String, dynamic>{
        'name': resolvedName,
        'full_name': resolvedName,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (resolvedAvatarUrl != null) {
        updateData['url_foto'] = resolvedAvatarUrl;
        updateData['avatar_url'] = resolvedAvatarUrl;
      }

      try {
        await SupabaseService.client
            .from('profiles')
            .update(updateData)
            .eq('id', active.id);
      } catch (err) {
        debugPrint('DataService.updateProfile Supabase error: $err');
        // Fallback jika kolom url_foto belum termigrasi di DB lama
        if (updateData.containsKey('url_foto')) {
          try {
            final fallbackData = Map<String, dynamic>.from(updateData)
              ..remove('url_foto');
            await SupabaseService.client
                .from('profiles')
                .update(fallbackData)
                .eq('id', active.id);
          } catch (_) {}
        }
      }

      try {
        await SupabaseService.client.auth.updateUser(
          UserAttributes(data: {
            'name': resolvedName,
            'full_name': resolvedName,
            if (resolvedAvatarUrl != null) 'url_foto': resolvedAvatarUrl,
            if (resolvedAvatarUrl != null) 'avatar_url': resolvedAvatarUrl,
          }),
        );
      } catch (err) {
        debugPrint('DataService.updateProfile auth metadata error: $err');
      }
    }

    return updated;
  }

  /// Mengganti kata sandi menggunakan verifikasi kata sandi lama secara asynchronous via Supabase Auth
  Future<({bool success, String? message})> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final active = currentUserNotifier.value;
    if (active == null) {
      return (success: false, message: 'Tidak ada sesi pengguna aktif');
    }

    if (SupabaseService.isInitialized && active.email.isNotEmpty) {
      try {
        // Cek keabsahan kata sandi lama dengan verifikasi signIn ke Supabase Auth
        final authRes = await SupabaseService.client.auth.signInWithPassword(
          email: active.email.trim(),
          password: oldPassword,
        );
        if (authRes.user == null) {
          return (success: false, message: 'Password lama tidak sesuai');
        }
      } on AuthException catch (e) {
        final msg = e.message.toLowerCase();
        if (msg.contains('invalid login credentials') ||
            msg.contains('invalid') ||
            msg.contains('credentials')) {
          return (success: false, message: 'Password lama tidak sesuai');
        }
        return (success: false, message: e.message);
      } catch (_) {
        if (active.password.isNotEmpty && active.password != oldPassword) {
          return (success: false, message: 'Password lama tidak sesuai');
        }
      }

      // Password lama valid -> perbarui kata sandi akun di Supabase Auth
      try {
        await SupabaseService.client.auth.updateUser(
          UserAttributes(password: newPassword),
        );
      } on AuthException catch (e) {
        return (success: false, message: e.message);
      } catch (e) {
        return (success: false, message: 'Gagal memperbarui kata sandi: $e');
      }
    } else {
      if (active.password.isNotEmpty && active.password != oldPassword) {
        return (success: false, message: 'Password lama tidak sesuai');
      }
    }

    final updated = active.copyWith(password: newPassword);
    final index = _users.indexWhere(
      (u) => u.email.toLowerCase() == active.email.toLowerCase(),
    );
    if (index != -1) {
      _users[index] = updated;
    } else {
      _users.add(updated);
    }
    currentUserNotifier.value = updated;
    try {
      LocalStorage.setString(
        LocalStorage.savedUserKey,
        jsonEncode(updated.toJson()),
      );
    } catch (_) {}

    return (success: true, message: null);
  }

  /// Mereset kata sandi berdasarkan email yang telah diverifikasi lewat OTP
  bool resetPasswordByEmail({
    required String email,
    required String newPassword,
  }) {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) return false;

    final index = _users.indexWhere(
      (u) => u.email.toLowerCase() == normalizedEmail,
    );
    if (index != -1) {
      final updated = _users[index].copyWith(password: newPassword);
      _users[index] = updated;
      if (currentUserNotifier.value?.email.toLowerCase() == normalizedEmail) {
        currentUserNotifier.value = updated;
      }
      return true;
    }

    // Jika user sedang login dengan sesi dinamis pada email tersebut
    final active = currentUserNotifier.value;
    if (active != null && active.email.toLowerCase() == normalizedEmail) {
      final updated = active.copyWith(password: newPassword);
      _users.add(updated);
      currentUserNotifier.value = updated;
      return true;
    }

    // Untuk alur lupa kata sandi dari halaman login pada email baru simulasi
    final rawPrefix = email.trim().split('@').first;
    final created = UserModel(
      id: UserModel.generateSixCharId(normalizedEmail),
      name: rawPrefix.isNotEmpty
          ? '${rawPrefix[0].toUpperCase()}${rawPrefix.substring(1)}'
          : 'User',
      email: email.trim(),
      phone: '08123456789',
      password: newPassword,
    );
    _users.add(created);
    return true;
  }

  /// Memastikan sesi pengguna tersedia ketika tampilan non-guest dibuka langsung
  UserModel ensureSessionForLoggedInView({
    required String name,
    required String email,
  }) {
    if (currentUserNotifier.value != null) {
      return currentUserNotifier.value!;
    }
    final normalizedEmail = email.trim().toLowerCase();
    final existingIndex = _users.indexWhere(
      (u) => u.email.toLowerCase() == normalizedEmail,
    );
    if (existingIndex != -1) {
      var user = _users[existingIndex];
      if (name.trim().isNotEmpty &&
          name.trim() != 'Guest' &&
          user.name != name.trim() &&
          !user.name.toLowerCase().startsWith(name.trim().toLowerCase())) {
        user = user.copyWith(name: name.trim());
        _users[existingIndex] = user;
      }
      currentUserNotifier.value = user;
      return user;
    }

    final resolvedEmail =
        normalizedEmail.contains('@') ? email.trim() : 'user@livetix.id';
    final created = UserModel(
      id: UserModel.generateSixCharId(resolvedEmail),
      name: name.trim().isNotEmpty ? name.trim() : 'Pengguna LiveTix',
      email: resolvedEmail,
      phone: '081234567890',
      password: 'password123',
    );
    _users.add(created);
    currentUserNotifier.value = created;
    return created;
  }

  /// Logout akun pengguna dan reset state ke mode Guest
  void logout() {
    _lastSessionRestoreAt = null;
    for (final t in _likeDebounceTimers.values) {
      t.cancel();
    }
    _likeDebounceTimers.clear();
    _serverLikedConcertIds.clear();
    favoriteConcertIdsNotifier.value = <String>{};
    currentUserNotifier.value = null;
    userTicketsNotifier.value = <UserTicketModel>[];
    refundAccountNotifier.value = null;
    PromoterDataService().isPinUnlockedThisSession = false;
    LocalStorage.remove(LocalStorage.savedUserKey);
    LocalStorage.remove('livetix_saved_user_tickets');
    LocalStorage.remove('livetix_saved_refund_account');
    LocalStorage.remove('livetix_favorite_ids');
    if (SupabaseService.isInitialized) {
      try {
        unawaited(
          SupabaseService.client.auth
              .signOut(scope: SignOutScope.local)
              .catchError((_) {}),
        );
      } catch (_) {}
    }
  }

  void resetUsersForTesting() {
    _users
      ..clear()
      ..addAll(DbDummy.users);
  }

  // --- API Tiket & Pemesanan ---

  /// Menandai order pembayaran e-wallet/QRIS/bank telah terbayar pada sesi berjalan
  void markOrderPaid(String orderId) {
    _paidOrderIds.add(orderId);
  }

  /// Mengecek apakah order dengan ID tertentu sudah berhasil dibayar
  bool isOrderPaid(String orderId) => _paidOrderIds.contains(orderId);

  /// Menyesuaikan stok tier di cache lokal agar perubahan stok langsung terlihat sebelum/bersama Realtime
  void adjustLocalTierStock(
    String concertId,
    String tierId, {
    int reservedDelta = 0,
    int soldDelta = 0,
  }) {
    final cIdx = _concerts.indexWhere((c) => c.id == concertId);
    if (cIdx == -1) return;
    final concert = _concerts[cIdx];
    final updatedTiers = concert.ticketTiers.map((t) {
      if (t.id == tierId) {
        final newReserved = (t.reservedCount + reservedDelta).clamp(0, t.totalQuota);
        final newSold = (t.soldCount + soldDelta).clamp(0, t.totalQuota);
        return t.copyWith(
          reservedCount: newReserved,
          soldCount: newSold,
          isSoldOut: (newSold + newReserved) >= t.totalQuota,
        );
      }
      return t;
    }).toList();
    _concerts[cIdx] = concert.copyWith(ticketTiers: updatedTiers);
    stockVersionNotifier.value++;
  }

  /// Membatalkan atau menandai kadaluarsa pesanan PENDING dan melepaskan reservasi stok lokal
  void cancelOrderTicket(String orderId, {String reason = 'CANCELLED'}) {
    final list = List<UserTicketModel>.from(userTicketsNotifier.value);
    final idx = list.indexWhere((t) => t.id == orderId);
    if (idx != -1) {
      final existing = list[idx];
      if (existing.isPendingPayment && existing.pendingOrder != null) {
        adjustLocalTierStock(
          existing.pendingOrder!.concert.id,
          existing.pendingOrder!.tier.id,
          reservedDelta: -existing.pendingOrder!.quantity,
        );
      }
      list[idx] = existing.copyWith(
        status: 'Expired/Cancelled',
        isCompleted: true,
        isCancelled: false,
        pendingOrder: null,
      );
      userTicketsNotifier.value = list;
      _saveUserTicketsToLocalStorage();
    }
  }

  /// Menyimpan pesanan tiket dalam status PENDING (Menunggu Pembayaran)
  /// agar user dapat melihatnya di tab Tiket Saya dan dapat melanjutkan pembayaran.
  UserTicketModel addPendingOrderTicket(OrderModel order) {
    final cleanCode = order.orderId.replaceAll('ORD-', '');
    final bookingCode = 'LTX-$cleanCode-2A';
    final existingIndex =
        userTicketsNotifier.value.indexWhere((t) => t.id == order.orderId);

    final sDate = order.concert.shortDate.replaceAll('null', '').trim();
    final sVenue = order.concert.venue.replaceAll('null', '').trim();
    final safeSub = (sDate.isNotEmpty && sVenue.isNotEmpty)
        ? '$sDate · $sVenue'
        : (sVenue.isNotEmpty ? sVenue : (sDate.isNotEmpty ? sDate : 'Jadwal Segera Diumumkan'));

    final pendingTicket = UserTicketModel(
      id: order.orderId,
      bookingCode: bookingCode,
      concertTitle: order.concert.title,
      concertSubtitle: safeSub,
      category: order.tier.name,
      date: order.concert.date,
      time: order.concert.time.isNotEmpty ? order.concert.time : '19.00 WIB',
      gate: 'Gate B',
      block: 'FEST-04',
      venue: order.concert.venue,
      quantity: order.quantity,
      totalPrice: order.totalAmount,
      status: 'Menunggu Pembayaran',
      isCompleted: false,
      daysLeft: 14,
      hasStar: false,
      stripeColor: const Color(0xFFF59E0B),
      iconBgColor: const Color(0xFFFEF3C7),
      iconColor: const Color(0xFFD97706),
      qrCodeUrl: order.qrCodeUrl,
      qrCodeBytes: order.qrCodeBytes,
      qrData: order.qrString,
      qrScanQuota: order.quantity,
      paymentMethod: order.paymentMethod,
      pendingOrder: order,
    );

    final list = List<UserTicketModel>.from(userTicketsNotifier.value);
    if (existingIndex != -1) {
      list[existingIndex] = pendingTicket;
    } else {
      list.insert(0, pendingTicket);
    }
    userTicketsNotifier.value = list;
    return pendingTicket;
  }

  /// Menerbitkan tiket konser resmi dari pesanan yang lunas (idempoten berdasarkan orderId).
  /// Satu QR Code diterbitkan per pesanan dengan kuota scan sesuai jumlah tiket (maks 4x scan).
  UserTicketModel completeOrderPayment(OrderModel order) {
    _paidOrderIds.add(order.orderId);
    final cleanCode = order.orderId.replaceAll('ORD-', '');
    final bookingCode = 'LTX-$cleanCode-2A';

    final existingIndex =
        userTicketsNotifier.value.indexWhere((t) => t.id == order.orderId);
    if (existingIndex != -1) {
      final existing = userTicketsNotifier.value[existingIndex];
      if (existing.status == 'Aktif' && !existing.isPendingPayment) {
        return existing;
      }
      final updatedTicket = existing.copyWith(
        status: 'Aktif',
        isCompleted: false,
        paymentMethod: order.paymentMethod,
        qrCodeUrl: order.qrCodeUrl,
        qrCodeBytes: order.qrCodeBytes,
        qrData: bookingCode,
        pendingOrder: null,
      );
      final list = List<UserTicketModel>.from(userTicketsNotifier.value);
      list[existingIndex] = updatedTicket;
      userTicketsNotifier.value = list;
      _saveUserTicketsToLocalStorage();

      adjustLocalTierStock(
        order.concert.id,
        order.tier.id,
        reservedDelta: existing.isPendingPayment ? -order.quantity : 0,
        soldDelta: order.quantity,
      );
      PromoterDataService().recordTicketSale(order.concert.id, order.quantity, order.totalAmount);
      _syncTicketToSupabase(order, bookingCode, validUserId: currentUser?.id);
      return updatedTicket;
    }

    final sDate = order.concert.shortDate.replaceAll('null', '').trim();
    final sVenue = order.concert.venue.replaceAll('null', '').trim();
    final safeSub = (sDate.isNotEmpty && sVenue.isNotEmpty)
        ? '$sDate · $sVenue'
        : (sVenue.isNotEmpty ? sVenue : (sDate.isNotEmpty ? sDate : 'Jadwal Segera Diumumkan'));

    final newTicket = UserTicketModel(
      id: order.orderId,
      bookingCode: bookingCode,
      concertTitle: order.concert.title,
      concertSubtitle: safeSub,
      category: order.tier.name,
      date: order.concert.date,
      time: order.concert.time.isNotEmpty ? order.concert.time : '19.00 WIB',
      gate: 'Gate B',
      block: 'FEST-04',
      venue: order.concert.venue,
      quantity: order.quantity,
      totalPrice: order.totalAmount,
      status: 'Aktif',
      isCompleted: false,
      daysLeft: 14,
      hasStar: true,
      stripeColor: const Color(0xFF1B2A8C),
      iconBgColor: const Color(0xFFE0EAFF),
      iconColor: const Color(0xFF1B2A8C),
      qrCodeUrl: order.qrCodeUrl,
      qrCodeBytes: order.qrCodeBytes,
      qrData: bookingCode,
      qrScanQuota: order.quantity,
      paymentMethod: order.paymentMethod,
    );

    addPurchasedTicket(newTicket);
    adjustLocalTierStock(
      order.concert.id,
      order.tier.id,
      soldDelta: order.quantity,
    );
    PromoterDataService().recordTicketSale(order.concert.id, order.quantity, order.totalAmount);
    _syncTicketToSupabase(order, bookingCode, validUserId: currentUser?.id);
    return newTicket;
  }

  void _syncTicketToSupabase(OrderModel order, String bookingCode, {String? validUserId}) {
    if (!SupabaseService.isInitialized) return;
    final rawUserId = validUserId ?? currentUser?.id;
    final uuidRegex = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    final sanitizedUserId = (rawUserId != null && uuidRegex.hasMatch(rawUserId))
        ? rawUserId
        : (SupabaseService.client.auth.currentUser?.id);

    final rawConcertId = order.concert.id;
    final validConcertUuid = (uuidRegex.hasMatch(rawConcertId)) ? rawConcertId : null;
    final validTierUuid = UuidUtils.ensureValidUuid(order.tier.id);

    final orderPayload = {
      'id': order.orderId,
      if (sanitizedUserId != null) 'user_id': sanitizedUserId,
      'concert_id': order.concert.id,
      'tier_id': validTierUuid,
      'quantity': order.quantity,
      'subtotal_amount': order.totalAmount,
      'total_amount': order.totalAmount,
      'gross_amount': order.totalAmount,
      'payment_method': order.paymentMethod,
      'payment_status': 'PAID',
      'customer_name': order.customerName,
      'customer_email': order.customerEmail,
      'paid_at': DateTime.now().toIso8601String(),
    };

    SupabaseService.client.from('orders').upsert(orderPayload).catchError((err) {
      debugPrint('Error sync order ke Supabase: $err');
      final errStr = err.toString();
      if (errStr.contains('22P02') || errStr.contains('uuid')) {
        final fallback = Map<String, dynamic>.from(orderPayload)
          ..remove('user_id')
          ..remove('concert_id')
          ..remove('tier_id');
        SupabaseService.client.from('orders').upsert(fallback).catchError((_) {});
      }
    });

    final ticketPayload = {
      'id': UuidUtils.generateV4(),
      'order_id': order.orderId,
      if (sanitizedUserId != null) 'user_id': sanitizedUserId,
      if (validConcertUuid != null) 'concert_id': validConcertUuid,
      'tier_id': validTierUuid,
      'booking_code': bookingCode,
      'ticket_code': bookingCode,
      'qr_token': 'LTX-${order.orderId}',
      'tier_name': order.tier.name,
      'gate_name': 'Gate A',
      'venue': order.concert.venue,
      'concert_title': order.concert.title,
      'concert_date': order.concert.date,
      'concert_time':
          order.concert.time.isNotEmpty ? order.concert.time : '19.00 WIB',
      'status': 'ACTIVE',
      'is_active': true,
      'qr_scan_quota': order.quantity,
      'qr_scans_used': 0,
      'scans_used': 0,
    };

    SupabaseService.client.from('tickets').upsert(ticketPayload).then((_) {
      fetchUserTicketsFromSupabase();
    }).catchError((err) {
      debugPrint('Error sync ticket ke Supabase: $err');
      final errStr = err.toString();
      if (errStr.contains('22P02') || errStr.contains('uuid')) {
        final fallback = Map<String, dynamic>.from(ticketPayload)
          ..remove('user_id')
          ..remove('concert_id');
        SupabaseService.client
            .from('tickets')
            .upsert(fallback)
            .then((_) => fetchUserTicketsFromSupabase())
            .catchError((e) => debugPrint('Retry fallback ticket error: $e'));
      }
    });
  }

  /// Sinkronisasi tiket resmi pengguna langsung dari tabel tickets Supabase Cloud
  Future<void> fetchUserTicketsFromSupabase() async {
    if (!SupabaseService.isInitialized) return;
    if (_ongoingTicketFetch != null) return _ongoingTicketFetch!;
    final future = _doFetchUserTicketsFromSupabase();
    _ongoingTicketFetch = future;
    try {
      await future;
    } finally {
      if (identical(_ongoingTicketFetch, future)) {
        _ongoingTicketFetch = null;
      }
    }
  }

  Future<void> _doFetchUserTicketsFromSupabase() async {
    try {
      final user = currentUser;
      final rawUserId = user?.id;
      final uuidRegex = RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
      final validUserId = (rawUserId != null && uuidRegex.hasMatch(rawUserId))
          ? rawUserId
          : (SupabaseService.client.auth.currentUser?.id);

      final List<dynamic> rows = await _withTransientRetry(() async {
        var query = SupabaseService.client.from('tickets').select();
        if (validUserId != null) {
          query = query.or('user_id.eq.$validUserId,user_id.is.null');
        }
        return await query.order('issued_at', ascending: false);
      });
      if (rows.isNotEmpty) {
        // Ambil data detail pesanan terkait dari tabel orders
        final Map<String, Map<String, dynamic>> ordersMap = {};
        try {
          final orderIds = rows
              .map((r) => r['order_id']?.toString())
              .where((id) => id != null && id.isNotEmpty)
              .toSet()
              .toList();
          if (orderIds.isNotEmpty) {
            final List<dynamic> orderRows = await SupabaseService.client
                .from('orders')
                .select('id, total_amount, gross_amount, payment_method, tier_name, created_at')
                .filter('id', 'in', orderIds);
            for (final o in orderRows) {
              final oid = o['id']?.toString();
              if (oid != null) ordersMap[oid] = Map<String, dynamic>.from(o);
            }
          }
        } catch (_) {}

        final List<UserTicketModel> fetched = [];
        for (final r in rows) {
          final quota = (r['qr_scan_quota'] as num?)?.toInt() ?? 1;
          final statusStr = r['status']?.toString().toUpperCase() ?? 'ACTIVE';
          final isCompleted = statusStr == 'SUDAH DIPAKAI' || statusStr == 'USED';
          final displayStatus = isCompleted
              ? 'Selesai'
              : ((statusStr == 'DIREFUND' || statusStr == 'REFUNDED')
                  ? 'Refund Selesai'
                  : 'Aktif');

          final tCode = r['booking_code']?.toString() ??
              r['ticket_code']?.toString() ??
              'LTX-001';

          final rawDate = r['concert_date']?.toString();
          final cDate = (rawDate != null && rawDate != 'null' && rawDate.trim().isNotEmpty)
              ? rawDate.trim()
              : '';
          final rawVenue = r['venue']?.toString();
          final vVenue = (rawVenue != null && rawVenue != 'null' && rawVenue.trim().isNotEmpty)
              ? rawVenue.trim()
              : '';

          final safeSubtitle = (cDate.isNotEmpty && vVenue.isNotEmpty)
              ? '$cDate · $vVenue'
              : (vVenue.isNotEmpty ? vVenue : (cDate.isNotEmpty ? cDate : 'Jadwal Segera Diumumkan'));

          final orderIdStr = r['order_id']?.toString();
          final orderData = orderIdStr != null ? ordersMap[orderIdStr] : null;

          final realPrice = (orderData?['gross_amount'] as num?)?.toInt() ??
              (orderData?['total_amount'] as num?)?.toInt() ??
              (r['price'] as num?)?.toInt() ??
              0;

          final realPaymentMethod =
              orderData?['payment_method']?.toString() ?? 'QRIS Universal';

          int daysRemaining = 14;
          final issuedAt = DateTime.tryParse(r['issued_at']?.toString() ?? '');
          if (issuedAt != null) {
            final diff = 30 - DateTime.now().difference(issuedAt).inDays;
            daysRemaining = diff < 0 ? 0 : diff;
          }

          fetched.add(UserTicketModel(
            id: r['order_id']?.toString() ?? r['id'].toString(),
            bookingCode: tCode,
            concertTitle: r['concert_title']?.toString() ?? 'Konser LiveTix',
            concertSubtitle: safeSubtitle,
            category: r['tier_name']?.toString() ?? orderData?['tier_name']?.toString() ?? 'Reguler',
            date: cDate.isNotEmpty ? cDate : 'Jadwal Segera Diumumkan',
            time: r['concert_time']?.toString() ?? '19.00 WIB',
            gate: r['gate_name']?.toString() ?? 'Gate A',
            block: 'FEST-01',
            venue: vVenue.isNotEmpty ? vVenue : 'LiveTix Arena',
            quantity: quota,
            totalPrice: realPrice > 0 ? realPrice : 350000,
            status: displayStatus,
            isCompleted: isCompleted,
            daysLeft: daysRemaining,
            hasStar: true,
            stripeColor: const Color(0xFF1B2A8C),
            iconBgColor: const Color(0xFFE0EAFF),
            iconColor: const Color(0xFF1B2A8C),
            qrCodeUrl: null,
            qrData: tCode,
            qrScanQuota: quota,
            paymentMethod: realPaymentMethod,
          ));
        }

        // Pertahankan SEMUA tiket lokal (baik pending maupun aktif yang baru dibeli) yang belum tersinkron
        final localRetained = userTicketsNotifier.value
            .where((t) => !fetched.any((f) => f.id == t.id || (t.bookingCode.isNotEmpty && f.bookingCode == t.bookingCode)))
            .toList();

        final combined = [...localRetained, ...fetched];
        userTicketsNotifier.value = combined;
        _saveUserTicketsToLocalStorage();
      } else {
        // Jika belum ada tiket dari Supabase, jangan hapus tiket lokal yang ada!
        _saveUserTicketsToLocalStorage();
      }
    } catch (e) {
      debugPrint('Error fetchUserTicketsFromSupabase: $e');
    }
  }

  void _saveUserTicketsToLocalStorage() {
    try {
      final list = userTicketsNotifier.value.map((t) => t.toJson()).toList();
      LocalStorage.setString('livetix_saved_user_tickets', jsonEncode(list));
    } catch (_) {}
  }

  /// Mengambil tiket pengguna yang aktif dan riwayat
  Future<List<UserTicketModel>> getUserTickets() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return List.unmodifiable(userTicketsNotifier.value);
  }

  /// Submit pesanan tiket baru
  Future<void> submitOrder(OrderModel order) async {
    await Future.delayed(const Duration(milliseconds: 100));
    completeOrderPayment(order);
  }

  /// Menambahkan tiket yang baru dibeli ke daftar tiket pengguna tanpa duplikasi ID
  void addPurchasedTicket(UserTicketModel ticket) {
    final updated = List<UserTicketModel>.from(userTicketsNotifier.value);
    final existingIdx = updated.indexWhere((t) => t.id == ticket.id);
    if (existingIdx != -1) {
      updated[existingIdx] = ticket;
    } else {
      updated.insert(0, ticket);
    }
    userTicketsNotifier.value = updated;
    _saveUserTicketsToLocalStorage();
  }

  /// Pengajuan refund tiket yang dibatalkan
  Future<void> submitRefund(RefundModel refund) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final updated = userTicketsNotifier.value.map((t) {
      if (t.id == refund.ticketId) {
        return t.copyWith(
          status: 'Refund Diproses',
          refundData: refund,
        );
      }
      return t;
    }).toList();

    userTicketsNotifier.value = updated;
  }

  // --- API Biaya Admin Transaksi (Dapat Dikonfigurasi Admin) ---

  /// Mengambil perkiraan biaya admin transaksi untuk kanal pembayaran tertentu
  int getTransactionFee(PaymentCategory category, [String? provider]) {
    if (category == PaymentCategory.qris) {
      return _transactionFees['qris'] ?? 1000;
    }
    final key = (provider ?? '').toLowerCase().replaceAll(' ', '');
    return _transactionFees[key] ??
        (category == PaymentCategory.ewallet ? 1500 : 2500);
  }

  /// Mengatur besaran biaya admin transaksi kanal pembayaran (aman diatur oleh admin)
  void setTransactionFee(String providerOrCategory, int fee) {
    _transactionFees[providerOrCategory.toLowerCase().replaceAll(' ', '')] = fee;
  }

  // --- API Metode Pembayaran Refund Akun Pengguna (Cooldown 1 Minggu) ---

  UserRefundAccount? get refundAccount => refundAccountNotifier.value;

  /// Memperbarui atau menambahkan rekening khusus penerimaan refund tiket.
  /// Menolak pembaruan jika masa cooldown 1 minggu (7 hari) masih aktif demi perlindungan akun.
  bool updateRefundAccount({
    required String provider,
    required String accountNumber,
    required String accountHolderName,
    required String accountType,
    bool ignoreCooldown = false,
  }) {
    final current = refundAccountNotifier.value;
    if (!ignoreCooldown && current != null && current.isCooldownActive) {
      return false;
    }

    final newAccount = UserRefundAccount(
      provider: provider,
      accountNumber: accountNumber,
      accountHolderName: accountHolderName,
      accountType: accountType,
      lastUpdated: DateTime.now(),
    );
    refundAccountNotifier.value = newAccount;

    try {
      LocalStorage.setString(
        'livetix_saved_refund_account',
        jsonEncode({
          'provider': provider,
          'accountNumber': accountNumber,
          'accountHolderName': accountHolderName,
          'accountType': accountType,
          'lastUpdated': newAccount.lastUpdated.toIso8601String(),
        }),
      );
    } catch (_) {}

    if (SupabaseService.isInitialized) {
      final active = currentUserNotifier.value;
      if (active != null) {
        SupabaseService.client.from('profiles').update({
          'refund_bank_name': provider,
          'refund_account_number': accountNumber,
          'refund_account_name': accountHolderName,
          'refund_account_type': accountType,
          'refund_last_updated': newAccount.lastUpdated.toIso8601String(),
        }).eq('id', active.id).catchError((_) {});
      }
    }

    return true;
  }

  /// Mengatur simulasi usia pembaruan rekening refund (hari lalu) untuk keperluan testing cooldown
  void setRefundAccountCooldownDaysAgo(int daysAgo) {
    final current = refundAccountNotifier.value;
    if (current != null) {
      refundAccountNotifier.value = UserRefundAccount(
        provider: current.provider,
        accountNumber: current.accountNumber,
        accountHolderName: current.accountHolderName,
        accountType: current.accountType,
        lastUpdated: DateTime.now().subtract(Duration(days: daysAgo)),
      );
    }
  }
}

/// Model data rekening atau e-wallet khusus penerimaan pencairan dana refund tiket.
/// Menerapkan perlindungan masa cooldown selama 1 minggu (7 hari) sejak pembaruan terakhir.
class UserRefundAccount {
  final String provider; // Contoh: 'Bank BCA', 'Mandiri', 'GoPay', 'DANA'
  final String accountNumber;
  final String accountHolderName;
  final String accountType; // 'bank' atau 'ewallet'
  final DateTime lastUpdated;

  const UserRefundAccount({
    required this.provider,
    required this.accountNumber,
    required this.accountHolderName,
    required this.accountType,
    required this.lastUpdated,
  });

  /// Durasi lengkap sisa cooldown
  Duration get remainingCooldown {
    final cooldownEnd = lastUpdated.add(const Duration(days: 7));
    final diff = cooldownEnd.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  /// Status apakah masa perlindungan cooldown 1 minggu (7 hari) sedang aktif
  bool get isCooldownActive {
    return remainingCooldown > Duration.zero;
  }

  /// Sisa hari masa cooldown
  int get remainingDays => remainingCooldown.inDays;

  /// String representasi sisa cooldown: misal "6 hari 23:59:12" atau "00:00:00"
  String get cooldownTimerFormatted {
    final rem = remainingCooldown;
    if (rem == Duration.zero) return '00:00:00';
    final days = rem.inDays;
    final hours = rem.inHours % 24;
    final minutes = rem.inMinutes % 60;
    final seconds = rem.inSeconds % 60;
    final timeStr =
        '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    if (days > 0) {
      return '$days hari $timeStr';
    }
    return timeStr;
  }

  /// Masking nomor rekening atau nomor e-wallet demi keamanan tampilan
  String get maskedAccountNumber {
    final clean = accountNumber.replaceAll(' ', '');
    if (clean.length <= 4) return accountNumber;
    final start = clean.substring(0, 4);
    final end = clean.substring(clean.length - 4);
    return '$start •••• •••• $end';
  }
}
