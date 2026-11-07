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
      ValueNotifier<UserRefundAccount?>(
    UserRefundAccount(
      provider: 'Bank BCA',
      accountNumber: '8808 1234 5678 9012',
      accountHolderName: 'Rafi Firmansyah',
      accountType: 'bank',
      lastUpdated: DateTime.now().subtract(const Duration(days: 2)),
    ),
  );

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

  void _initService() {
    _concerts = List.from(DbDummy.concerts);
    _cities = List.from(DbDummy.cities);
    _users = List.from(DbDummy.users);
    userTicketsNotifier.value = List.from(DbDummy.initialUserTickets);
    _agreementAccepted = DbDummy.defaultGuestAgreementAccepted ||
        LocalStorage.getBool(LocalStorage.agreementAcceptedKey);

    // Tema tampilan: default Dark pada data dummy sesuai permintaan pengguna
    final savedTheme = LocalStorage.getString('livetix_dark_mode');
    isDarkModeNotifier.value = savedTheme == null ? true : LocalStorage.getBool('livetix_dark_mode');

    // Data konser disukai (Favorit / Love)
    final savedFavs = LocalStorage.getStringList('livetix_favorite_ids');
    if (savedFavs.isNotEmpty) {
      favoriteConcertIdsNotifier.value = savedFavs.toSet();
    } else {
      favoriteConcertIdsNotifier.value = {'featured-1', 'c2'};
    }
  }

  UserModel? get currentUser => currentUserNotifier.value;
  bool get isGuest => currentUserNotifier.value == null;
  List<ConcertModel> get rawConcerts => List.unmodifiable(_concerts);

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

  /// Mengambil jumlah suka (love) terkini dari suatu konser
  int getConcertLikesCount(String concertId) {
    final idx = _concerts.indexWhere((c) => c.id == concertId);
    if (idx != -1) return _concerts[idx].likesCount;
    return 0;
  }

  void _syncConcertLikeDelta(String concertId, int delta) {
    if (delta == 0) return;
    final idx = _concerts.indexWhere((c) => c.id == concertId);
    if (idx != -1) {
      final currentLikes = _concerts[idx].likesCount;
      final nextLikes = (currentLikes + delta) < 0 ? 0 : (currentLikes + delta);
      _concerts[idx] = _concerts[idx].copyWith(likesCount: nextLikes);
    }
    // Sinkronkan jumlah love ke dashboard & daftar konser Produser
    PromoterDataService().adjustConcertLikes(concertId, delta);

    if (SupabaseService.isInitialized) {
      final userId = currentUserNotifier.value?.id;
      if (userId != null && userId.isNotEmpty) {
        if (delta > 0) {
          SupabaseService.client.from('concert_likes').upsert({
            'concert_id': concertId,
            'user_id': userId,
          }).catchError((_) {});
        } else {
          SupabaseService.client
              .from('concert_likes')
              .delete()
              .match({'concert_id': concertId, 'user_id': userId}).catchError(
                  (_) {});
        }
      }
    }
  }

  /// Toggle status favorit konser dan menyimpan perubahan ke memori, penyimpanan lokal, serta Produser
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
    _syncConcertLikeDelta(concertId, wasFav ? -1 : 1);
  }

  /// Menetapkan status favorit suatu konser secara eksplisit
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
    _syncConcertLikeDelta(concertId, isFav ? 1 : -1);
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

  /// Memuat daftar konser dan kategori tiket secara langsung dari Supabase Cloud
  Future<List<ConcertModel>> fetchConcertsFromSupabase({bool forceRefresh = false}) async {
    if (!SupabaseService.isInitialized) return _concerts;
    if (_hasFetchedConcertsFromSupabase && !forceRefresh) return _concerts;

    try {
      final response = await SupabaseService.client
          .from('concerts')
          .select('*, ticket_tiers(*)')
          .or('status.eq.published,status.is.null')
          .order('created_at', ascending: false);

      if (response.isNotEmpty) {
        final List<ConcertModel> liveItems = [];
        for (final item in response) {
          try {
            final parsed = ConcertModel.fromJson(item);
            if (parsed.isPublished) {
              liveItems.add(parsed);
            }
          } catch (err) {
            debugPrint('Error parse concert item: $err');
          }
        }
        if (liveItems.isNotEmpty) {
          _concerts.clear();
          _concerts.addAll(liveItems);
          _hasFetchedConcertsFromSupabase = true;
          return _concerts;
        }
      }
    } catch (e) {
      debugPrint('Gagal fetch konser dari Supabase, menggunakan data lokal: $e');
    }
    return _concerts;
  }

  /// Mengambil detail satu konser secara lengkap berdasarkan ID (termasuk tiket tiers dari Supabase)
  Future<ConcertModel?> getConcertById(String id) async {
    if (SupabaseService.isInitialized) {
      try {
        final res = await SupabaseService.client
            .from('concerts')
            .select('*, ticket_tiers(*)')
            .eq('id', id)
            .maybeSingle();

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
    }

    final index = _concerts.indexWhere((c) => c.id == id);
    if (index != -1) return _concerts[index];
    return null;
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
    await Future.delayed(const Duration(milliseconds: 50));
    return _concerts.firstWhere(
      (c) => c.id == 'featured-1',
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
    const highlightIds = {'featured-1', 'c4', 'c6', 'c9', 'c2'};
    final items = _concerts.where((c) => highlightIds.contains(c.id)).toList();
    return items.isNotEmpty ? items : _concerts.take(5).toList();
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
  Future<void> restoreSupabaseSession() async {
    // 1. Cek penyimpanan lokal disk terlebih dahulu agar instan saat cold/hot start
    final cached = LocalStorage.getString(LocalStorage.savedUserKey);
    if (cached != null && cached.isNotEmpty) {
      try {
        final cachedUser = UserModel.fromJson(jsonDecode(cached));
        currentUserNotifier.value = cachedUser;
      } catch (_) {}
    }

    if (!SupabaseService.isInitialized) return;
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

      try {
        final profileRes = await SupabaseService.client
            .from('profiles')
            .select()
            .eq('id', authUser.id)
            .maybeSingle();

        if (profileRes != null) {
          resolvedRole = normalizeRole(profileRes['role'] as String?);
          resolvedName = (profileRes['name'] as String?) ??
              (profileRes['full_name'] as String?) ??
              resolvedName;
          resolvedPhone = (profileRes['phone'] as String?) ?? resolvedPhone;
        }
      } catch (_) {}

      final user = UserModel(
        id: authUser.id,
        name: resolvedName,
        email: authUser.email ?? '',
        phone: resolvedPhone,
        password: '',
        role: resolvedRole,
      );

      currentUserNotifier.value = user;
      LocalStorage.setString(
        LocalStorage.savedUserKey,
        jsonEncode(user.toJson()),
      );
      if (user.role == 'Produser') {
        await PromoterDataService().loadProducerProfileFromSupabase();
      }
    } catch (_) {}
  }

  /// Login akun pengguna via Supabase Auth
  Future<UserModel?> login(String email, String password) async {
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

      try {
        final profileRes = await SupabaseService.client
            .from('profiles')
            .select()
            .eq('id', authUser.id)
            .maybeSingle();

        if (profileRes != null) {
          resolvedRole = normalizeRole(profileRes['role'] as String?);
          resolvedName = (profileRes['name'] as String?) ??
              (profileRes['full_name'] as String?) ??
              resolvedName;
          resolvedPhone = (profileRes['phone'] as String?) ?? resolvedPhone;
        }
      } catch (_) {}

      final user = UserModel(
        id: authUser.id,
        name: resolvedName,
        email: authUser.email ?? email.trim(),
        phone: resolvedPhone,
        password: '',
        role: resolvedRole,
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
        password: '',
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
  UserModel? updateProfile({
    String? name,
    String? avatarUrl,
    Uint8List? profileImageBytes,
    bool clearProfileImage = false,
    int? avatarColorIndex,
  }) {
    final active = currentUserNotifier.value;
    if (active == null) return null;

    final resolvedName =
        name != null && name.trim().isNotEmpty ? name.trim() : active.name;
    final updated = active.copyWith(
      name: resolvedName,
      avatarUrl: avatarUrl,
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

    if (SupabaseService.isInitialized) {
      SupabaseService.client
          .from('profiles')
          .update({
            'name': resolvedName,
            'full_name': resolvedName,
          })
          .eq('id', active.id)
          .catchError((_) {});
    }

    return updated;
  }

  /// Mengganti kata sandi menggunakan verifikasi kata sandi lama
  bool changePassword({
    required String oldPassword,
    required String newPassword,
  }) {
    final active = currentUserNotifier.value;
    if (active == null) return false;
    // Jika login dari Supabase Auth, active.password di lokal bisa kosong ('')
    if (active.password.isNotEmpty && active.password != oldPassword) {
      return false;
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
    return true;
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
    currentUserNotifier.value = null;
    PromoterDataService().isPinUnlockedThisSession = false;
    LocalStorage.remove(LocalStorage.savedUserKey);
    if (SupabaseService.isInitialized) {
      try {
        SupabaseService.client.auth.signOut();
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

  /// Menerbitkan tiket konser resmi dari pesanan yang lunas (idempoten berdasarkan orderId).
  /// Satu QR Code diterbitkan per pesanan dengan kuota scan sesuai jumlah tiket (maks 4x scan).
  UserTicketModel completeOrderPayment(OrderModel order) {
    _paidOrderIds.add(order.orderId);
    final existingIndex =
        userTicketsNotifier.value.indexWhere((t) => t.id == order.orderId);
    if (existingIndex != -1) {
      return userTicketsNotifier.value[existingIndex];
    }

    final cleanCode = order.orderId.replaceAll('ORD-', '');
    final bookingCode = 'LTX-$cleanCode-2A';
    final newTicket = UserTicketModel(
      id: order.orderId,
      bookingCode: bookingCode,
      concertTitle: order.concert.title,
      concertSubtitle: '${order.concert.shortDate} · ${order.concert.venue}',
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
      qrScanQuota: order.quantity,
      paymentMethod: order.paymentMethod,
    );

    addPurchasedTicket(newTicket);
    return newTicket;
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

    refundAccountNotifier.value = UserRefundAccount(
      provider: provider,
      accountNumber: accountNumber,
      accountHolderName: accountHolderName,
      accountType: accountType,
      lastUpdated: DateTime.now(),
    );
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

  /// Status apakah masa perlindungan cooldown 1 minggu (7 hari) sedang aktif
  bool get isCooldownActive {
    return DateTime.now().difference(lastUpdated).inDays < 7;
  }

  /// Sisa hari masa cooldown
  int get remainingDays {
    final daysPassed = DateTime.now().difference(lastUpdated).inDays;
    final diff = 7 - daysPassed;
    return diff < 0 ? 0 : diff;
  }

  /// Durasi lengkap sisa cooldown
  Duration get remainingCooldown {
    final cooldownEnd = lastUpdated.add(const Duration(days: 7));
    final diff = cooldownEnd.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
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
