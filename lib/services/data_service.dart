import 'dart:async';
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

  /// Toggle status favorit konser dan menyimpan perubahan ke memori dan penyimpanan lokal
  void toggleFavorite(String concertId) {
    final updated = Set<String>.from(favoriteConcertIdsNotifier.value);
    if (updated.contains(concertId)) {
      updated.remove(concertId);
    } else {
      updated.add(concertId);
    }
    favoriteConcertIdsNotifier.value = updated;
    LocalStorage.setStringList('livetix_favorite_ids', updated.toList());
  }

  /// Menetapkan status favorit suatu konser secara eksplisit
  void setFavorite(String concertId, bool isFav) {
    final updated = Set<String>.from(favoriteConcertIdsNotifier.value);
    if (isFav) {
      updated.add(concertId);
    } else {
      updated.remove(concertId);
    }
    favoriteConcertIdsNotifier.value = updated;
    LocalStorage.setStringList('livetix_favorite_ids', updated.toList());
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
    // Simulasi delay fetch asynchronous dari database
    await Future.delayed(const Duration(milliseconds: 100));

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
    await Future.delayed(const Duration(milliseconds: 50));
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
      if (existingUser.password != password) {
        return null;
      }
      currentUserNotifier.value = existingUser;
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

  /// Login akun pengguna
  Future<UserModel?> login(String email, String password) async {
    final user = loginSync(email, password);
    await Future.delayed(const Duration(milliseconds: 100));
    return user;
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
    final newUser = UserModel(
      id: resolvedId,
      name: name.trim(),
      email: email.trim(),
      phone: phone.trim(),
      password: password,
      role: role,
    );
    if (existingIndex != -1) {
      _users[existingIndex] = newUser;
    } else {
      _users.add(newUser);
    }
    currentUserNotifier.value = newUser;
    return newUser;
  }

  /// Registrasi akun baru
  Future<UserModel> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    String role = 'User',
  }) async {
    final newUser = registerSync(
      name: name,
      email: email,
      phone: phone,
      password: password,
      role: role,
    );
    await Future.delayed(const Duration(milliseconds: 100));
    return newUser;
  }

  /// Memperbarui data profil pengguna yang sedang login (nama, foto profil, tema warna avatar)
  UserModel? updateProfile({
    String? name,
    Uint8List? profileImageBytes,
    bool clearProfileImage = false,
    int? avatarColorIndex,
  }) {
    final active = currentUserNotifier.value;
    if (active == null) return null;

    final updated = active.copyWith(
      name: name != null && name.trim().isNotEmpty ? name.trim() : active.name,
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
    return updated;
  }

  /// Mengganti kata sandi menggunakan verifikasi kata sandi lama
  bool changePassword({
    required String oldPassword,
    required String newPassword,
  }) {
    final active = currentUserNotifier.value;
    if (active == null) return false;
    if (active.password != oldPassword) return false;

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
