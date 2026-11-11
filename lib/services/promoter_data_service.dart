import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide LocalStorage;
import '../models/approval_models.dart';
import '../models/promoter_models.dart';
import '../utils/local_storage.dart';
import 'admin_service.dart';
import 'data_service.dart';
import 'payment_gateway_service.dart';
import 'supabase_service.dart';

class PromoterDataService {
  static final PromoterDataService _instance = PromoterDataService._internal();
  factory PromoterDataService() => _instance;

  PromoterDataService._internal() {
    _initData();
  }

  // Notifiers
  final ValueNotifier<List<PromoterConcertItem>> concertsNotifier =
      ValueNotifier<List<PromoterConcertItem>>([]);
  final ValueNotifier<int> quotaRemainingNotifier = ValueNotifier<int>(2);
  final ValueNotifier<bool> isDarkModeNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<int> activeBalanceNotifier =
      ValueNotifier<int>(1845000000);
  final ValueNotifier<int> pendingBalanceNotifier =
      ValueNotifier<int>(450000000);
  final ValueNotifier<List<PromoterTransactionItem>> transactionsNotifier =
      ValueNotifier<List<PromoterTransactionItem>>([]);
  final ValueNotifier<List<PromoterConcertFinanceSummary>>
      concertFinanceSummariesNotifier =
      ValueNotifier<List<PromoterConcertFinanceSummary>>([]);
  final ValueNotifier<List<PromoterWithdrawalRecord>>
      withdrawalRecordsNotifier =
      ValueNotifier<List<PromoterWithdrawalRecord>>([]);

  // Reactive Promoter Identity, Verification, PIN, and Pending Profile Changes
  final ValueNotifier<String> promoterNameNotifier =
      ValueNotifier<String>('Java Promotor');
  final ValueNotifier<String?> pendingPromoterNameNotifier =
      ValueNotifier<String?>(null);
  final ValueNotifier<String> ktpDocumentNotifier =
      ValueNotifier<String>('ktp_rafi_firmansyah.jpg');
  final ValueNotifier<String> responsibilityLetterNotifier =
      ValueNotifier<String>('lembar_penanggung_jawab_rafi.doc');
  final ValueNotifier<String?> pendingKtpDocumentNotifier =
      ValueNotifier<String?>(null);
  final ValueNotifier<String?> pendingResponsibilityLetterNotifier =
      ValueNotifier<String?>(null);
  final ValueNotifier<String?> avatarUrlNotifier =
      ValueNotifier<String?>(null);

  ValueNotifier<String?> get pendingNameChangeNotifier =>
      pendingPromoterNameNotifier;
  ValueNotifier<String?> get pendingKtpFileNameNotifier =>
      pendingKtpDocumentNotifier;
  ValueNotifier<String?> get pendingResponsibilityLetterFileNameNotifier =>
      pendingResponsibilityLetterNotifier;

  String get promoterEmail =>
      DataService().currentUser?.email ?? 'official@javapromotor.com';
  String get promoterPhone =>
      (DataService().currentUser?.phone.isNotEmpty == true)
          ? DataService().currentUser!.phone
          : '+62 812-9908-1120';

  List<PromoterConcertItem> get activeConcerts =>
      concertsNotifier.value.where((c) => !c.isCompleted).toList();

  Future<void> updateProfilePhotoDirectly(String fileName) async {
    avatarUrlNotifier.value = fileName;
    DataService().updateProfile(avatarUrl: fileName);
  }

  void lockPinSession() {
    isPinUnlockedThisSession = false;
  }

  /// Status verifikasi akun produser: 'unverified' | 'pending' | 'approved' | 'rejected'
  final ValueNotifier<String> verificationStatusNotifier =
      ValueNotifier<String>('approved');

  /// Alasan penolakan akun produser dari Admin (diambil langsung dari database)
  final ValueNotifier<String?> rejectionReasonNotifier =
      ValueNotifier<String?>(null);

  /// Waktu penolakan akun produser untuk countdown "Ajukan Ulang" real-time
  final ValueNotifier<DateTime?> rejectedAtNotifier =
      ValueNotifier<DateTime?>(null);

  /// Durasi cooldown sebelum produser dapat mengajukan ulang (default 24 jam dari waktu penolakan)
  static const Duration resubmitCooldownDuration = Duration(hours: 24);

  /// PIN 6-digit keamanan Produser (diatur saat verifikasi dokumen & diminta setiap login)
  final ValueNotifier<String> pinCodeNotifier =
      ValueNotifier<String>('123456');

  /// Status apakah sesi login saat ini sudah membuka kunci PIN
  bool isPinUnlockedThisSession = false;

  String get promoterName => promoterNameNotifier.value;
  String get verificationBadge =>
      verificationStatusNotifier.value == 'approved'
          ? 'TERVERIFIKASI'
          : (verificationStatusNotifier.value == 'pending'
              ? 'MENUNGGU APPROVAL'
              : 'BELUM VERIFIKASI');

  String get promoterInitials {
    final parts = promoterName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts.isNotEmpty ? parts[0][0].toUpperCase() : 'JP';
  }

  final int quotaMax = 3;

  // Dashboard Metrics (Dihitung akurat dari data konser & pesanan yang lunas)
  int get totalConcerts {
    return concertsNotifier.value.length;
  }

  int get totalAvailableTickets {
    return concertsNotifier.value.fold<int>(
      0,
      (sum, c) => sum + c.remainingTickets,
    );
  }

  int get totalReservedTickets {
    return concertsNotifier.value.fold<int>(
      0,
      (sum, c) => sum + c.totalReservedTickets,
    );
  }

  int get totalPaidTickets {
    return concertsNotifier.value.fold<int>(
      0,
      (sum, c) => sum + c.totalSoldTickets,
    );
  }

  int get ticketsSold => totalPaidTickets;

  final String ticketsSoldGrowth = '+15% bulan ini';

  int get totalRevenue {
    return concertsNotifier.value.fold<int>(
      0,
      (sum, c) => sum + c.resolvedGrossRevenue,
    );
  }

  final double revenueGrowth = 8.2;

  // 7 Days Sales Trend (values relative to max height)
  final List<double> weeklySalesRatios = [
    0.35,
    0.50,
    0.28,
    0.60,
    0.82,
    0.52,
    0.95
  ];

  void _initData() {
    // Payment gateway / withdrawal mock records tetap dipertahankan hingga integrasi Midtrans
    transactionsNotifier.value = [
      const PromoterTransactionItem(
        id: 'TX-101',
        title: 'Penjualan Tiket - Soundwave Fest',
        date: '21 Okt 2026, 14:20 WIB',
        amount: '+ Rp 1.050.000',
        isIncome: true,
      ),
      const PromoterTransactionItem(
        id: 'TX-100',
        title: 'Pencairan Dana ke BCA 8820****',
        date: '19 Okt 2026, 10:15 WIB',
        amount: '- Rp 150.000.000',
        isIncome: false,
      ),
      const PromoterTransactionItem(
        id: 'TX-099',
        title: 'Penjualan Tiket - Soundwave Fest',
        date: '18 Okt 2026, 19:40 WIB',
        amount: '+ Rp 2.250.000',
        isIncome: true,
      ),
    ];

    withdrawalRecordsNotifier.value = [
      const PromoterWithdrawalRecord(
        id: 'w-1',
        dateTimeStr: '18 Okt 2026 · 14:05 WIB',
        amount: 250000000,
        bankAccount: 'BCA - ***9901',
        status: WithdrawalStatus.berhasil,
        refId: '#WD-8842109',
      ),
      const PromoterWithdrawalRecord(
        id: 'w-2',
        dateTimeStr: '20 Okt 2026 · 09:12 WIB',
        amount: 150000000,
        bankAccount: 'Mandiri - ***3321',
        status: WithdrawalStatus.menunggu,
        refId: '#WD-9912048',
      ),
      const PromoterWithdrawalRecord(
        id: 'w-3',
        dateTimeStr: '15 Okt 2026 · 11:30 WIB',
        amount: 500000000,
        bankAccount: 'BCA - ***9901',
        status: WithdrawalStatus.ditolak,
        refId: '#WD-8842109',
        rejectionReason:
            'Alasan: Nama pemilik rekening tidak cocok dengan nama KTP terverifikasi.',
      ),
    ];

    // Jika terhubung ke Supabase, jangan isi data konser dummy — muat murni dari database!
    if (SupabaseService.isInitialized) {
      concertsNotifier.value = [];
      concertFinanceSummariesNotifier.value = [];
      fetchPromoterConcertsFromSupabase();
      loadProducerProfileFromSupabase();
      return;
    }

    // Fallback khusus mode pengujian unit/widget test (ketika Supabase tidak diinisialisasi)
    concertsNotifier.value = [
      const PromoterConcertItem(
        id: '1',
        title: 'Soundwave Fest 2026',
        dateAndVenue: '12 Okt · Stadion Gajayana',
        date: 'Minggu, 12 Oktober 2026',
        time: 'Gerbang 17.00 · Mulai 19.00',
        venueName: 'Stadion Gajayana',
        venueAddress:
            'Jl. Tangkuban Perahu, Kauman, Kec. Klojen, Kota Malang, Jawa Timur 65119',
        status: ConcertStatus.disetujui,
        likesCount: '4.2k',
        posterFileName: 'poster_soundwave.png',
        ticketsSold: 0,
        grossRevenue: 0,
        affectedBuyersCount: 0,
        totalRefundAmount: 0,
        refundDoneCount: 0,
        refundProcessingCount: 0,
        refundPendingAccountCount: 0,
        cancellationSubmissionDate: '19 Okt 2026, 14:02',
        cancellationApprovalDate: '20 Okt 2026, 09:15',
        cancellationReason:
            'Izin keramaian dari kepolisian belum terbit sehingga acara tidak dapat dilaksanakan sesuai jadwal. Kami memutuskan membatalkan konser.',
        tiers: [
          PromoterTicketTier(
            id: 't1',
            name: 'VIP Lounge',
            price: 750000,
            quota: 250,
            quotaType: 'Kursi',
            accentColor: Color(0xFFC2185B),
          ),
          PromoterTicketTier(
            id: 't2',
            name: 'Festival',
            price: 350000,
            quota: 2000,
            quotaType: 'Orang',
            accentColor: Color(0xFF1B2A8C),
          ),
        ],
      ),
      const PromoterConcertItem(
        id: '2',
        title: 'Symphony Under the Stars',
        dateAndVenue: '24 Nov · Amphitheater Ijen',
        date: 'Selasa, 24 November 2026',
        time: 'Gerbang 18.00 · Mulai 19.30',
        venueName: 'Amphitheater Ijen',
        venueAddress: 'Kawasan Wisata Ijen Nirwana, Kota Malang',
        status: ConcertStatus.menunggu,
        likesCount: '1.8k',
        posterFileName: 'poster_symphony.png',
        ticketsSold: 0,
        affectedBuyersCount: 0,
        totalRefundAmount: 0,
        refundDoneCount: 0,
        refundProcessingCount: 0,
        refundPendingAccountCount: 0,
        tiers: [
          PromoterTicketTier(
            id: 't3',
            name: 'Amphitheater Seat',
            price: 450000,
            quota: 800,
            quotaType: 'Kursi',
            accentColor: Color(0xFFC2185B),
          ),
        ],
      ),
      const PromoterConcertItem(
        id: '3',
        title: 'Rock Anthem Vol. II',
        dateAndVenue: '05 Des · Dome Universitas',
        date: 'Sabtu, 05 Desember 2026',
        time: 'Gerbang 16.30 · Mulai 18.00',
        venueName: 'Dome Universitas',
        venueAddress: 'Jl. Sumbersari No. 1, Lowokwaru, Kota Malang',
        status: ConcertStatus.draft,
        likesCount: '250',
        posterFileName: 'poster_rock_anthem.png',
        tiers: [
          PromoterTicketTier(
            id: 't4',
            name: 'General Admission',
            price: 250000,
            quota: 1200,
            quotaType: 'Orang',
            accentColor: Color(0xFF1B2A8C),
          ),
        ],
      ),
      const PromoterConcertItem(
        id: '4',
        title: 'Festival Gajayana',
        dateAndVenue: '14 Nov · Stadion Gajayana',
        date: 'Sabtu, 14 November 2026',
        time: 'Gerbang 17.00 · Mulai 19.00',
        venueName: 'Stadion Gajayana',
        venueAddress: 'Jl. Tangkuban Perahu, Kauman, Kec. Klojen, Kota Malang',
        status: ConcertStatus.ditolak,
        likesCount: '0',
        posterFileName: 'poster_harmoni_final.png',
        tiers: [
          PromoterTicketTier(
            id: 't5',
            name: 'VIP Nusantara',
            price: 750000,
            quota: 200,
            quotaType: 'Kursi',
            accentColor: Color(0xFFC2185B),
          ),
          PromoterTicketTier(
            id: 't6',
            name: 'Festival',
            price: 350000,
            quota: 1500,
            quotaType: 'Orang',
            accentColor: Color(0xFF1B2A8C),
          ),
        ],
      ),
    ];

    concertFinanceSummariesNotifier.value = [];
    _rebuildFinanceSummariesFromConcerts();
  }

  void toggleTheme() {
    isDarkModeNotifier.value = !isDarkModeNotifier.value;
    DataService().setDarkMode(isDarkModeNotifier.value);
  }

  /// Sinkronisasi ringkasan keuangan dari daftar konser di database
  void _rebuildFinanceSummariesFromConcerts() {
    final items = concertsNotifier.value;
    if (items.isEmpty) {
      concertFinanceSummariesNotifier.value = [];
      return;
    }
    final List<PromoterConcertFinanceSummary> summaries = [];
    for (final c in items) {
      if (c.status == ConcertStatus.disetujui || c.isCompleted) {
        final cap = c.totalCapacity > 0 ? c.totalCapacity : 5000;
        final sold = c.ticketsSold;
        final gross = c.resolvedGrossRevenue;
        final fee = (gross * 0.05).round();
        final net = gross - fee;
        summaries.add(
          PromoterConcertFinanceSummary(
            id: c.id,
            concertTitle: c.isCompleted ? '${c.title} (Selesai)' : c.title,
            ticketsSold: sold,
            totalCapacity: cap,
            grossAmount: gross,
            systemFeePercent: 5.0,
            systemFeeAmount: fee,
            netAmount: net,
            payoutStatus: c.isCompleted ? 'Payout Selesai' : 'Aktif Berjalan',
          ),
        );
      }
    }
    concertFinanceSummariesNotifier.value = summaries;
  }

  /// Memuat profil, status verifikasi, dokumen, dan PIN Produser dari Supabase
  Future<void> loadProducerProfileFromSupabase([String? userId]) async {
    if (!SupabaseService.isInitialized) return;
    final targetId = userId ?? DataService().currentUser?.id;
    if (targetId == null || targetId.isEmpty) return;

    try {
      final profileRow = await SupabaseService.client
          .from('profiles')
          .select()
          .eq('id', targetId)
          .maybeSingle();

      if (profileRow != null) {
        final name = (profileRow['name'] ?? profileRow['full_name'])?.toString();
        if (name != null && name.trim().isNotEmpty) {
          promoterNameNotifier.value = name.trim();
        }
        final pin = profileRow['pin_code']?.toString();
        if (pin != null && pin.trim().isNotEmpty) {
          pinCodeNotifier.value = pin.trim();
        }
        final verStatus = profileRow['verification_status']?.toString();
        if (verStatus != null && verStatus.trim().isNotEmpty) {
          verificationStatusNotifier.value = verStatus.trim().toLowerCase();
        }
      }

      final promoterRow = await SupabaseService.client
          .from('promoter_profiles')
          .select()
          .eq('user_id', targetId)
          .maybeSingle();

      if (promoterRow != null) {
        final compName = promoterRow['company_name']?.toString();
        if (compName != null && compName.trim().isNotEmpty) {
          promoterNameNotifier.value = compName.trim();
        }
        final appStatus = promoterRow['approval_status']?.toString();
        if (appStatus != null && appStatus.trim().isNotEmpty) {
          verificationStatusNotifier.value = appStatus.trim().toLowerCase();
        }
        final ktpUrl = promoterRow['ktp_url']?.toString();
        if (ktpUrl != null && ktpUrl.isNotEmpty) {
          ktpDocumentNotifier.value = ktpUrl;
        }
        final letterUrl = promoterRow['responsibility_letter_url']?.toString();
        if (letterUrl != null && letterUrl.isNotEmpty) {
          responsibilityLetterNotifier.value = letterUrl;
        }
        final pin = promoterRow['pin_code']?.toString();
        if (pin != null && pin.isNotEmpty) {
          pinCodeNotifier.value = pin;
        }
        pendingPromoterNameNotifier.value =
            promoterRow['pending_name']?.toString();
        pendingKtpDocumentNotifier.value =
            promoterRow['pending_ktp_url']?.toString();
        pendingResponsibilityLetterNotifier.value =
            promoterRow['pending_responsibility_letter_url']?.toString();
        final rejReason = promoterRow['rejection_reason']?.toString();
        if (rejReason != null && rejReason.trim().isNotEmpty) {
          rejectionReasonNotifier.value = rejReason.trim();
          LocalStorage.setString('livetix_producer_rejection_reason', rejReason.trim());
        }
        final rejAtRaw = promoterRow['rejected_at']?.toString();
        if (rejAtRaw != null && rejAtRaw.isNotEmpty) {
          final parsed = DateTime.tryParse(rejAtRaw);
          if (parsed != null) {
            rejectedAtNotifier.value = parsed;
            LocalStorage.setString(
              'livetix_producer_rejected_at',
              parsed.toIso8601String(),
            );
          }
        }
      }

      // Ambil saldo ledger realtime (saldo tertahan dan saldo tersedia)
      PaymentGatewayService().getPromoterBalance(targetId).then((bal) {
        if (bal.availableBalance > 0 || bal.pendingBalance > 0) {
          activeBalanceNotifier.value = bal.availableBalance;
          pendingBalanceNotifier.value = bal.pendingBalance;
        }
      }).catchError((err) {
        debugPrint('Error getPromoterBalance: $err');
      });
    } catch (e) {
      debugPrint('Error loadProducerProfileFromSupabase: $e');
    }

    // Fallback baca dari LocalStorage apabila kolom database belum mengembalikan nilai
    if (rejectionReasonNotifier.value == null) {
      final savedReason =
          LocalStorage.getString('livetix_producer_rejection_reason');
      if (savedReason != null && savedReason.isNotEmpty) {
        rejectionReasonNotifier.value = savedReason;
      }
    }
    if (rejectedAtNotifier.value == null) {
      final savedAt = LocalStorage.getString('livetix_producer_rejected_at');
      if (savedAt != null && savedAt.isNotEmpty) {
        rejectedAtNotifier.value = DateTime.tryParse(savedAt);
      }
    }
  }

  RealtimeChannel? _stockRealtimeChannel;
  bool _isRealtimeSubscribed = false;

  /// Mengaktifkan sinkronisasi realtime stok & pesanan untuk role Produser
  void startRealtimeStockSync() {
    if (!SupabaseService.isInitialized || _isRealtimeSubscribed) return;
    _isRealtimeSubscribed = true;

    try {
      _stockRealtimeChannel = SupabaseService.client
          .channel('promoter_realtime_stock')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'ticket_tiers',
            callback: (_) => fetchPromoterConcertsFromSupabase(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'orders',
            callback: (_) => fetchPromoterConcertsFromSupabase(),
          )
          .subscribe();
    } catch (e) {
      _isRealtimeSubscribed = false;
      debugPrint('Error subscribe promoter realtime stock: $e');
    }
  }

  /// Menghentikan langganan realtime stok untuk role Produser
  void stopRealtimeStockSync() {
    if (_stockRealtimeChannel != null && SupabaseService.isInitialized) {
      SupabaseService.client.removeChannel(_stockRealtimeChannel!);
    }
    _stockRealtimeChannel = null;
    _isRealtimeSubscribed = false;
  }

  /// Memperbarui dan menyimpan daftar Pos Gate konser ke Supabase
  Future<void> updateConcertGates(String concertId, List<String> gates) async {
    final list = List<PromoterConcertItem>.from(concertsNotifier.value);
    final idx = list.indexWhere((c) => c.id == concertId);
    if (idx != -1) {
      list[idx] = list[idx].copyWith(gates: gates);
      concertsNotifier.value = list;
    }

    if (SupabaseService.isInitialized) {
      try {
        await SupabaseService.client
            .from('concerts')
            .update({'gates': gates})
            .eq('id', concertId);
      } catch (e) {
        debugPrint('Error updateConcertGates Supabase: $e');
      }
    }
  }

  /// Memuat daftar konser Produser langsung dari Supabase Cloud (tanpa dummy)
  Future<void> fetchPromoterConcertsFromSupabase() async {
    if (!SupabaseService.isInitialized) return;
    startRealtimeStockSync();
    try {
      final currentUserId = DataService().currentUser?.id;

      // Ambil metrik penjualan aktual langsung dari tabel orders / tickets Supabase
      final Map<String, int> actualSoldMap = {};
      final Map<String, int> actualRevenueMap = {};
      try {
        final paidOrders = await SupabaseService.client
            .from('orders')
            .select('concert_id, quantity, gross_amount, total_amount')
            .eq('payment_status', 'PAID');
        for (final o in paidOrders) {
          final cid = o['concert_id']?.toString() ?? '';
          if (cid.isNotEmpty) {
            final qty = (o['quantity'] as num?)?.toInt() ?? 1;
            final rev = ((o['gross_amount'] ?? o['total_amount']) as num?)?.toInt() ?? 0;
            actualSoldMap[cid] = (actualSoldMap[cid] ?? 0) + qty;
            actualRevenueMap[cid] = (actualRevenueMap[cid] ?? 0) + rev;
          }
        }
      } catch (errMetrics) {
        debugPrint('Catat order penjualan Supabase: $errMetrics');
      }

      try {
        final paidTickets = await SupabaseService.client
            .from('tickets')
            .select('concert_id, qr_scan_quota')
            .eq('status', 'ACTIVE');
        for (final t in paidTickets) {
          final cid = t['concert_id']?.toString() ?? '';
          if (cid.isNotEmpty && !actualSoldMap.containsKey(cid)) {
            final qty = (t['qr_scan_quota'] as num?)?.toInt() ?? 1;
            actualSoldMap[cid] = (actualSoldMap[cid] ?? 0) + qty;
          }
        }
      } catch (_) {}

      final response = await SupabaseService.client
          .from('concerts')
          .select('*, ticket_tiers(*)')
          .order('created_at', ascending: false);

      final List<PromoterConcertItem> supaItems = [];
      for (final row in response) {
        try {
          final rowProducer = row['producer_id']?.toString();
          if (currentUserId == null ||
              rowProducer == null ||
              rowProducer == currentUserId ||
              row['status'] == 'pending') {
            var parsed = PromoterConcertItem.fromJson(row);
            final cid = parsed.id;

            // Hubungkan penjualan aktual dari database (gunakan nilai tertinggi antara orders/tickets & tier soldCount)
            final tierSold = parsed.tiers.fold<int>(0, (s, t) => s + t.soldCount);
            final rawActualSold = actualSoldMap[cid] ?? 0;
            final actualSold = rawActualSold > tierSold ? rawActualSold : tierSold;
            final actualRev = actualRevenueMap[cid] ??
                (actualSold * (parsed.tiers.isNotEmpty ? parsed.tiers.first.price : 0));
            parsed = parsed.copyWith(
              ticketsSold: actualSold,
              grossRevenue: actualRev,
            );

            final cachedReason =
                LocalStorage.getString('livetix_concert_rej_reason_$cid');
            final cachedAtStr =
                LocalStorage.getString('livetix_concert_rej_at_$cid');
            if ((parsed.rejectionReason == null ||
                    parsed.rejectionReason!.isEmpty) &&
                cachedReason != null &&
                cachedReason.isNotEmpty) {
              parsed = parsed.copyWith(rejectionReason: cachedReason);
            }
            if (parsed.rejectedAt == null &&
                cachedAtStr != null &&
                cachedAtStr.isNotEmpty) {
              parsed =
                  parsed.copyWith(rejectedAt: DateTime.tryParse(cachedAtStr));
            }
            final cachedHighlights =
                LocalStorage.getStringList('livetix_concert_highlights_$cid');
            final cachedHighlightNames =
                LocalStorage.getStringList('livetix_concert_highlight_names_$cid');
            if (cachedHighlights.isNotEmpty) {
              parsed = parsed.copyWith(
                highlights: cachedHighlights,
                highlightNames: cachedHighlightNames,
              );
            }
            supaItems.add(parsed);
          }
        } catch (e) {
          debugPrint('Error parse promoter concert row: $e');
        }
      }
      concertsNotifier.value = supaItems;
      _rebuildFinanceSummariesFromConcerts();
    } catch (err) {
      debugPrint('Error fetch promoter concerts: $err');
    }
  }

  /// Mencatat penjualan tiket baru ke memori Produser secara real-time
  void recordTicketSale(String concertId, int quantity, int grossAmount) {
    final list = List<PromoterConcertItem>.from(concertsNotifier.value);
    final idx = list.indexWhere((c) => c.id == concertId);
    if (idx != -1) {
      final old = list[idx];
      list[idx] = old.copyWith(
        ticketsSold: old.ticketsSold + quantity,
        grossRevenue: old.resolvedGrossRevenue + grossAmount,
      );
      concertsNotifier.value = list;
      _rebuildFinanceSummariesFromConcerts();
    }
  }

  /// Verifikasi PIN 6-digit Produser saat login
  bool verifyPin(String inputPin) {
    final cleanInput = inputPin.trim();
    final storedPin = pinCodeNotifier.value.trim();
    if (cleanInput.isNotEmpty && cleanInput == storedPin) {
      isPinUnlockedThisSession = true;
      return true;
    }
    return false;
  }

  /// Simpan atau perbarui PIN 6-digit Produser
  Future<void> updateProducerPin(String newPin) async {
    final trimmed = newPin.trim();
    if (trimmed.length != 6) return;
    pinCodeNotifier.value = trimmed;
    isPinUnlockedThisSession = true;

    if (SupabaseService.isInitialized) {
      final userId = DataService().currentUser?.id;
      if (userId != null) {
        try {
          await SupabaseService.client
              .from('profiles')
              .update({'pin_code': trimmed}).eq('id', userId);
          await SupabaseService.client
              .from('promoter_profiles')
              .update({'pin_code': trimmed}).eq('user_id', userId);
        } catch (e) {
          debugPrint('Error updateProducerPin Supabase: $e');
        }
      }
    }
  }

  /// Pengajuan verifikasi awal data diri Produser + KTP + Lembar Penanggung Jawab + PIN
  Future<void> submitInitialVerification({
    required String fullName,
    required String birthDate,
    required String phone,
    required String address,
    required String ktpFileName,
    required String responsibilityLetterFileName,
    required String pinCode,
  }) async {
    final cleanName = fullName.trim().isNotEmpty
        ? fullName.trim()
        : promoterNameNotifier.value;
    promoterNameNotifier.value = cleanName;
    ktpDocumentNotifier.value = ktpFileName.trim();
    responsibilityLetterNotifier.value = responsibilityLetterFileName.trim();
    pinCodeNotifier.value = pinCode.trim();
    verificationStatusNotifier.value = 'pending';
    isPinUnlockedThisSession = false;

    final currentUser = DataService().currentUser;
    final userId = currentUser?.id ?? 'prd-${DateTime.now().millisecondsSinceEpoch}';
    final userEmail = currentUser?.email ?? 'official@javapromotor.com';

    // Sinkronkan ke antrean approval Produser di AdminService
    final adminService = AdminService();
    final newApp = ProducerApplicationModel(
      id: 'promoter-$userId',
      userId: userId,
      companyName: cleanName,
      email: userEmail,
      phone: phone.trim().isNotEmpty ? phone.trim() : '081234567890',
      address: address.trim().isNotEmpty
          ? address.trim()
          : 'Jl. Kayutangan No. 45, Malang',
      approvalStatus: ApprovalStatus.pending,
      isVerified: false,
      submittedAt: DateTime.now(),
      submissionDocuments: [
        ProducerDocumentModel(
          id: 'doc-ktp-$userId',
          name: 'KTP Penanggung Jawab (${ktpFileName.trim()})',
          type: 'JPG',
          fileSize: '850 KB',
          fileUrl: ktpFileName.trim(),
        ),
        ProducerDocumentModel(
          id: 'doc-letter-$userId',
          name: 'Lembar Penanggung Jawab (${responsibilityLetterFileName.trim()})',
          type: 'PDF',
          fileSize: '540 KB',
          fileUrl: responsibilityLetterFileName.trim(),
        ),
      ],
    );
    final list = List<ProducerApplicationModel>.from(
        adminService.producersNotifier.value);
    list.removeWhere((p) => p.id == newApp.id || p.userId == userId);
    list.insert(0, newApp);
    adminService.producersNotifier.value = list;

    if (SupabaseService.isInitialized) {
      try {
        await SupabaseService.client.from('profiles').upsert({
          'id': userId,
          'name': cleanName,
          'full_name': cleanName,
          'email': userEmail,
          'phone': phone.trim(),
          'role': 'Produser',
          'pin_code': pinCode.trim(),
          'is_verified': false,
          'verification_status': 'pending',
        });

        await SupabaseService.client.from('promoter_profiles').upsert({
          'id': 'promoter-$userId',
          'user_id': userId,
          'company_name': cleanName,
          'responsible_name': cleanName,
          'phone': phone.trim(),
          'office_address': address.trim(),
          'birth_date': birthDate.trim(),
          'ktp_url': ktpFileName.trim(),
          'responsibility_letter_url': responsibilityLetterFileName.trim(),
          'pin_code': pinCode.trim(),
          'is_verified': false,
          'approval_status': 'pending',
          'submitted_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        debugPrint('Error submitInitialVerification Supabase: $e');
      }
    }
  }

  /// Ajukan perubahan Nama Produser atau Dokumen Legalitas (Memerlukan Approval Admin)
  Future<void> requestProfileOrLegalityChange({
    String? newName,
    String? newKtpFileName,
    String? newResponsibilityLetterFileName,
  }) async {
    if (newName != null &&
        newName.trim().isNotEmpty &&
        newName.trim() != promoterNameNotifier.value) {
      pendingPromoterNameNotifier.value = newName.trim();
    }
    if (newKtpFileName != null && newKtpFileName.trim().isNotEmpty) {
      pendingKtpDocumentNotifier.value = newKtpFileName.trim();
    }
    if (newResponsibilityLetterFileName != null &&
        newResponsibilityLetterFileName.trim().isNotEmpty) {
      pendingResponsibilityLetterNotifier.value =
          newResponsibilityLetterFileName.trim();
    }

    final currentUser = DataService().currentUser;
    final userId = currentUser?.id ?? 'prd-006';
    final userEmail = currentUser?.email ?? 'official@javapromotor.com';

    // Tambahkan ke antrean approval Admin
    final adminService = AdminService();
    final targetName =
        pendingPromoterNameNotifier.value ?? promoterNameNotifier.value;
    final targetKtp =
        pendingKtpDocumentNotifier.value ?? ktpDocumentNotifier.value;
    final targetLetter = pendingResponsibilityLetterNotifier.value ??
        responsibilityLetterNotifier.value;

    final changeApp = ProducerApplicationModel(
      id: 'promoter-$userId',
      userId: userId,
      companyName: targetName,
      email: userEmail,
      phone: currentUser?.phone ?? '081234567890',
      address: 'Perubahan Data/Dokumen Produser',
      approvalStatus: ApprovalStatus.pending,
      isVerified: false,
      submittedAt: DateTime.now(),
      pendingName: pendingPromoterNameNotifier.value,
      pendingKtpUrl: pendingKtpDocumentNotifier.value,
      pendingResponsibilityLetterUrl: pendingResponsibilityLetterNotifier.value,
      requestType: 'profile_edit',
      legalDocuments: [
        ProducerDocumentModel(
          id: 'doc-ktp-$userId',
          name: 'KTP Penanggung Jawab ($targetKtp)',
          type: 'JPG',
          fileSize: '850 KB',
          fileUrl: targetKtp,
        ),
        ProducerDocumentModel(
          id: 'doc-letter-$userId',
          name: 'Lembar Penanggung Jawab ($targetLetter)',
          type: 'PDF',
          fileSize: '540 KB',
          fileUrl: targetLetter,
        ),
      ],
      submissionDocuments: [
        ProducerDocumentModel(
          id: 'doc-ktp-$userId',
          name: 'KTP Penanggung Jawab ($targetKtp)',
          type: 'JPG',
          fileSize: '850 KB',
          fileUrl: targetKtp,
        ),
        ProducerDocumentModel(
          id: 'doc-letter-$userId',
          name: 'Lembar Penanggung Jawab ($targetLetter)',
          type: 'PDF',
          fileSize: '540 KB',
          fileUrl: targetLetter,
        ),
      ],
    );

    final list = List<ProducerApplicationModel>.from(
        adminService.producersNotifier.value);
    list.removeWhere((p) => p.id == changeApp.id || p.userId == userId);
    list.insert(0, changeApp);
    adminService.producersNotifier.value = list;

    if (SupabaseService.isInitialized) {
      try {
        await SupabaseService.client.from('promoter_profiles').upsert({
          'id': 'promoter-$userId',
          'user_id': userId,
          'company_name': promoterNameNotifier.value,
          if (pendingPromoterNameNotifier.value != null)
            'pending_name': pendingPromoterNameNotifier.value,
          if (pendingKtpDocumentNotifier.value != null)
            'pending_ktp_url': pendingKtpDocumentNotifier.value,
          if (pendingResponsibilityLetterNotifier.value != null)
            'pending_responsibility_letter_url':
                pendingResponsibilityLetterNotifier.value,
          'profile_change_status': 'pending',
          'approval_status': 'pending',
          'submitted_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        debugPrint('Error requestProfileOrLegalityChange Supabase: $e');
      }
    }
  }

  /// Dipanggil saat Admin menyetujui akun produser atau perubahan nama/dokumen produser
  void onAdminApprovedProducer(ProducerApplicationModel approvedModel) {
    verificationStatusNotifier.value = 'approved';
    rejectionReasonNotifier.value = null;
    rejectedAtNotifier.value = null;
    LocalStorage.remove('livetix_producer_rejection_reason');
    LocalStorage.remove('livetix_producer_rejected_at');
    if (pendingPromoterNameNotifier.value != null &&
        pendingPromoterNameNotifier.value!.isNotEmpty) {
      promoterNameNotifier.value = pendingPromoterNameNotifier.value!;
      DataService().updateProfile(name: pendingPromoterNameNotifier.value!);
      pendingPromoterNameNotifier.value = null;
    } else if (approvedModel.companyName.isNotEmpty) {
      promoterNameNotifier.value = approvedModel.companyName;
    }
    if (pendingKtpDocumentNotifier.value != null &&
        pendingKtpDocumentNotifier.value!.isNotEmpty) {
      ktpDocumentNotifier.value = pendingKtpDocumentNotifier.value!;
      pendingKtpDocumentNotifier.value = null;
    }
    if (pendingResponsibilityLetterNotifier.value != null &&
        pendingResponsibilityLetterNotifier.value!.isNotEmpty) {
      responsibilityLetterNotifier.value =
          pendingResponsibilityLetterNotifier.value!;
      pendingResponsibilityLetterNotifier.value = null;
    }
  }

  /// Dipanggil saat Admin menolak pengajuan Produser agar alasan & waktu penolakan sinkron
  void onAdminRejectedProducer(String reason, DateTime rejectedAt) {
    verificationStatusNotifier.value = 'rejected';
    rejectionReasonNotifier.value = reason.trim();
    rejectedAtNotifier.value = rejectedAt;
    LocalStorage.setString('livetix_producer_rejection_reason', reason.trim());
    LocalStorage.setString(
      'livetix_producer_rejected_at',
      rejectedAt.toIso8601String(),
    );
  }

  /// Mengambil alasan penolakan konser secara real dari model / AdminService / LocalStorage
  String getConcertRejectionReason(PromoterConcertItem concert) {
    if (concert.rejectionReason != null &&
        concert.rejectionReason!.trim().isNotEmpty) {
      return concert.rejectionReason!.trim();
    }
    final adminConcert = AdminService().concertById(concert.id);
    if (adminConcert?.rejectionReason != null &&
        adminConcert!.rejectionReason!.trim().isNotEmpty) {
      return adminConcert.rejectionReason!.trim();
    }
    final saved =
        LocalStorage.getString('livetix_concert_rej_reason_${concert.id}');
    if (saved != null && saved.trim().isNotEmpty) {
      return saved.trim();
    }
    return 'Pengajuan konser ditolak oleh Admin. Silakan periksa kembali kelengkapan informasi konser Anda.';
  }

  /// Mengambil timestamp waktu penolakan konser (persisten saat aplikasi dibuka kembali)
  DateTime getConcertRejectedAt(PromoterConcertItem concert) {
    if (concert.rejectedAt != null) return concert.rejectedAt!;
    final adminConcert = AdminService().concertById(concert.id);
    if (adminConcert?.rejectedAt != null) return adminConcert!.rejectedAt!;
    final key = 'livetix_concert_rej_at_${concert.id}';
    final saved = LocalStorage.getString(key);
    if (saved != null && saved.isNotEmpty) {
      final parsed = DateTime.tryParse(saved);
      if (parsed != null) return parsed;
    }
    final now = DateTime.now();
    LocalStorage.setString(key, now.toIso8601String());
    return now;
  }

  /// Mengambil timestamp waktu penolakan verifikasi produser (persisten saat aplikasi dibuka kembali)
  DateTime getProducerRejectedAt() {
    if (rejectedAtNotifier.value != null) return rejectedAtNotifier.value!;
    const key = 'livetix_producer_rejected_at';
    final saved = LocalStorage.getString(key);
    if (saved != null && saved.isNotEmpty) {
      final parsed = DateTime.tryParse(saved);
      if (parsed != null) {
        rejectedAtNotifier.value = parsed;
        return parsed;
      }
    }
    final now = DateTime.now();
    rejectedAtNotifier.value = now;
    LocalStorage.setString(key, now.toIso8601String());
    return now;
  }

  /// Ajukan ulang konser yang sebelumnya ditolak setelah waktu tunggu selesai
  void resubmitRejectedConcert(String concertId) {
    final list = List<PromoterConcertItem>.from(concertsNotifier.value);
    final idx = list.indexWhere((c) => c.id == concertId);
    if (idx == -1) return;

    final updated = list[idx].copyWith(
      status: ConcertStatus.menunggu,
      rejectionReason: '',
    );
    list[idx] = updated;
    concertsNotifier.value = list;
    LocalStorage.remove('livetix_concert_rej_reason_$concertId');
    LocalStorage.remove('livetix_concert_rej_at_$concertId');

    if (SupabaseService.isInitialized) {
      SupabaseService.client.from('concerts').update({
        'status': 'pending',
        'approval_status': 'pending_create',
        'rejection_reason': null,
        'rejected_at': null,
      }).eq('id', concertId).catchError((_) {});
    }

    _syncConcertToAdmin(updated, requestType: 'create');
  }

  /// Tambah/kurangi jumlah Love (Disukai) konser secara real-time saat User menekan tombol Love
  void adjustConcertLikes(String concertId, int delta) {
    final list = List<PromoterConcertItem>.from(concertsNotifier.value);
    final idx = list.indexWhere((c) =>
        c.id == concertId ||
        (concertId == 'featured-1' &&
            (c.id == '1' ||
                c.title.toLowerCase().contains('soundwave fest'))));

    if (idx != -1) {
      final currentLikes = list[idx].numericLikes;
      final nextLikes = (currentLikes + delta) < 0 ? 0 : (currentLikes + delta);
      list[idx] = list[idx].copyWith(
        likesCount: PromoterConcertItem.formatLikes(nextLikes),
      );
      concertsNotifier.value = list;

      if (SupabaseService.isInitialized) {
        SupabaseService.client
            .from('concerts')
            .update({'likes_count': nextLikes})
            .eq('id', list[idx].id)
            .catchError((err) {
              debugPrint('Error sync likes_count to Supabase: $err');
            });
      }
    } else if (SupabaseService.isInitialized) {
      // Update langsung berdasarkan concertId di Supabase
      SupabaseService.client
          .from('concerts')
          .select('likes_count')
          .eq('id', concertId)
          .maybeSingle()
          .then((row) {
        if (row != null) {
          final curr = (row['likes_count'] as num?)?.toInt() ?? 0;
          final next = (curr + delta) < 0 ? 0 : (curr + delta);
          return SupabaseService.client
              .from('concerts')
              .update({'likes_count': next})
              .eq('id', concertId)
              .catchError((_) {});
        }
        return Future<void>.value();
      }).catchError((_) {});
    }
  }

  /// Tandai konser telah selesai (masuk ke Riwayat Selesai beserta data pendapatan)
  void markConcertCompleted(String concertId, {bool completed = true}) {
    final list = List<PromoterConcertItem>.from(concertsNotifier.value);
    final idx = list.indexWhere((c) => c.id == concertId);
    if (idx != -1) {
      list[idx] = list[idx].copyWith(isCompleted: completed);
      concertsNotifier.value = list;
      _rebuildFinanceSummariesFromConcerts();

      if (SupabaseService.isInitialized) {
        SupabaseService.client
            .from('concerts')
            .update({'is_completed': completed})
            .eq('id', concertId)
            .catchError((err) {
              debugPrint('Error markConcertCompleted Supabase: $err');
            });
      }
    }
  }

  Future<String?> _uploadConcertMediaIfDataUrl({
    required String concertId,
    required String kind,
    required String? source,
  }) async {
    final raw = source?.trim() ?? '';
    if (raw.isEmpty || !raw.startsWith('data:image/')) {
      return raw.isEmpty ? null : raw;
    }
    if (!SupabaseService.isInitialized) return raw;

    final commaIdx = raw.indexOf(',');
    if (commaIdx == -1) return raw;
    final header = raw.substring(0, commaIdx).toLowerCase();
    final base64Part = raw.substring(commaIdx + 1);

    String ext = 'jpg';
    String contentType = 'image/jpeg';
    if (header.contains('image/png')) {
      ext = 'png';
      contentType = 'image/png';
    } else if (header.contains('image/webp')) {
      ext = 'webp';
      contentType = 'image/webp';
    } else if (header.contains('image/gif')) {
      ext = 'gif';
      contentType = 'image/gif';
    }

    try {
      final bytes = base64Decode(base64Part);
      final safeConcertId =
          concertId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final filePath =
          'concerts/$safeConcertId/${kind}_${DateTime.now().microsecondsSinceEpoch}.$ext';
      await SupabaseService.client.storage
          .from('concert-media')
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(
              contentType: contentType,
              upsert: false,
            ),
          )
          .timeout(const Duration(seconds: 12));
      final publicUrl = SupabaseService.client.storage
          .from('concert-media')
          .getPublicUrl(filePath);
      return publicUrl.isNotEmpty ? publicUrl : raw;
    } catch (e) {
      debugPrint('Error upload media konser ke concert-media ($kind): $e');
      return raw;
    }
  }

  Future<void> _persistConcertAndTiersToSupabase(
    PromoterConcertItem concert, {
    required String status,
    required String approvalStatus,
    Map<String, dynamic>? pendingEditPayload,
    bool clearPendingEditPayload = false,
  }) async {
    if (!SupabaseService.isInitialized) return;

    var resolvedConcert = concert;
    final currentUserId = DataService().currentUser?.id;

    // 1. Unggah gambar data:image/* ke bucket Storage `concert-media` agar baris DB ringkas
    final uploadedPoster = await _uploadConcertMediaIfDataUrl(
      concertId: concert.id,
      kind: 'poster',
      source: concert.posterDataUrl,
    );
    final uploadedLogo = await _uploadConcertMediaIfDataUrl(
      concertId: concert.id,
      kind: 'logo',
      source: concert.squareLogoDataUrl,
    );
    final uploadedHighlights = <String>[];
    for (int i = 0; i < concert.highlights.length; i++) {
      final h = concert.highlights[i];
      final res = await _uploadConcertMediaIfDataUrl(
        concertId: concert.id,
        kind: 'highlight_$i',
        source: h,
      );
      if (res != null && res.isNotEmpty) {
        uploadedHighlights.add(res);
      }
    }

    final hasUploadedPoster =
        uploadedPoster != null && uploadedPoster.startsWith('http');
    final hasUploadedLogo =
        uploadedLogo != null && uploadedLogo.startsWith('http');

    if (hasUploadedPoster ||
        hasUploadedLogo ||
        uploadedHighlights.isNotEmpty) {
      resolvedConcert = concert.copyWith(
        posterFileName:
            hasUploadedPoster ? uploadedPoster : concert.posterFileName,
        posterDataUrl: hasUploadedPoster ? '' : concert.posterDataUrl,
        squareLogoFileName:
            hasUploadedLogo ? uploadedLogo : concert.squareLogoFileName,
        squareLogoDataUrl: hasUploadedLogo ? '' : concert.squareLogoDataUrl,
        highlights: uploadedHighlights.isNotEmpty
            ? uploadedHighlights
            : concert.highlights,
      );

      final list = List<PromoterConcertItem>.from(concertsNotifier.value);
      final idx = list.indexWhere((c) => c.id == concert.id);
      if (idx != -1) {
        list[idx] = resolvedConcert;
        concertsNotifier.value = list;
      }

      if (pendingEditPayload != null) {
        if (hasUploadedPoster) {
          pendingEditPayload['banner_image_url'] = uploadedPoster;
        }
        if (hasUploadedLogo) {
          pendingEditPayload['logo_image_url'] = uploadedLogo;
        }
      }

      final adminService = AdminService();
      final adminList = List<ConcertSubmissionModel>.from(
          adminService.concertsNotifier.value);
      final adminIdx = adminList.indexWhere((c) => c.id == concert.id);
      if (adminIdx != -1) {
        adminList[adminIdx] = adminList[adminIdx].copyWith(
          bannerUrl: resolvedConcert.posterFileName,
          pendingEditPayload: pendingEditPayload,
        );
        adminService.concertsNotifier.value = adminList;
      }
    }

    final concertJson = resolvedConcert.toJson(promoterId: currentUserId);
    concertJson.remove('ticket_tiers');
    concertJson['producer_name'] = promoterName;
    concertJson['status'] = status;
    concertJson['approval_status'] = approvalStatus;
    if (pendingEditPayload != null) {
      concertJson['pending_edit_payload'] = pendingEditPayload;
    } else if (clearPendingEditPayload) {
      concertJson['pending_edit_payload'] = null;
    }

    try {
      await SupabaseService.client.from('concerts').upsert(concertJson);
    } catch (err) {
      debugPrint('Error upsert concert to Supabase: $err');
      final errStr = err.toString();
      if (errStr.contains('PGRST204') || errStr.contains('column')) {
        final fallbackJson = Map<String, dynamic>.from(concertJson)
          ..remove('highlights')
          ..remove('highlight_names')
          ..remove('poster_data_url')
          ..remove('square_logo_data_url')
          ..remove('square_logo_url');
        try {
          await SupabaseService.client.from('concerts').upsert(fallbackJson);
        } catch (fallbackErr) {
          debugPrint('Error upsert fallback concert to Supabase: $fallbackErr');
          return;
        }
      } else {
        return;
      }
    }

    for (final tier in resolvedConcert.tiers) {
      try {
        await SupabaseService.client.from('ticket_tiers').upsert({
          'id': tier.id,
          'concert_id': resolvedConcert.id,
          'name': tier.name,
          'price': tier.price,
          'quota': tier.quota,
          'total_quota': tier.quota,
          'quota_type': tier.quotaType,
          'accent_color': tier.accentColor.toARGB32(),
        });
      } catch (err) {
        debugPrint('Error upsert ticket_tier: $err');
      }
    }
  }

  bool addConcert(PromoterConcertItem newConcert) {
    if (quotaRemainingNotifier.value <= 0) {
      return false;
    }
    final updatedList = List<PromoterConcertItem>.from(concertsNotifier.value);
    updatedList.insert(0, newConcert);
    concertsNotifier.value = updatedList;

    quotaRemainingNotifier.value = quotaRemainingNotifier.value - 1;

    if (newConcert.highlights.isNotEmpty) {
      LocalStorage.setStringList(
          'livetix_concert_highlights_${newConcert.id}', newConcert.highlights);
      LocalStorage.setStringList(
          'livetix_concert_highlight_names_${newConcert.id}',
          newConcert.highlightNames);
    }

    // 1. Simpan ke Supabase Cloud (unggah media ke Storage lalu upsert konser & tiers)
    if (SupabaseService.isInitialized) {
      unawaited(
        _persistConcertAndTiersToSupabase(
          newConcert,
          status: 'pending',
          approvalStatus: 'pending_create',
        ).catchError((_) {}),
      );
    }

    // 2. Hubungkan ke antrean persetujuan Super Admin
    _syncConcertToAdmin(newConcert, requestType: 'create');

    return true;
  }

  /// Memperbarui informasi konser dan mengirim ulang ke antrean approval Admin
  void updateConcert(
    PromoterConcertItem updatedConcert, {
    bool requiresAdminApproval = true,
  }) {
    final list = List<PromoterConcertItem>.from(concertsNotifier.value);
    final idx = list.indexWhere((c) => c.id == updatedConcert.id);
    final finalConcert = requiresAdminApproval
        ? updatedConcert.copyWith(status: ConcertStatus.menunggu)
        : updatedConcert;

    if (idx != -1) {
      list[idx] = finalConcert;
    } else {
      list.insert(0, finalConcert);
    }
    concertsNotifier.value = list;

    if (finalConcert.highlights.isNotEmpty) {
      LocalStorage.setStringList(
          'livetix_concert_highlights_${finalConcert.id}',
          finalConcert.highlights);
      LocalStorage.setStringList(
          'livetix_concert_highlight_names_${finalConcert.id}',
          finalConcert.highlightNames);
    }

    final editPayload = <String, dynamic>{
      'title': finalConcert.title,
      'subtitle': finalConcert.dateAndVenue,
      'date': finalConcert.date,
      'time': finalConcert.time,
      'venue': finalConcert.venueName,
      'venue_address': finalConcert.venueAddress,
      'description': finalConcert.description,
      'banner_image_url':
          (finalConcert.posterDataUrl?.isNotEmpty == true)
              ? finalConcert.posterDataUrl
              : finalConcert.posterFileName,
      'logo_image_url':
          (finalConcert.squareLogoDataUrl?.isNotEmpty == true)
              ? finalConcert.squareLogoDataUrl
              : finalConcert.squareLogoFileName,
      'total_capacity': finalConcert.totalCapacity,
      'price': finalConcert.tiers.isNotEmpty
          ? finalConcert.tiers
              .map((t) => t.price)
              .reduce((a, b) => a < b ? a : b)
          : 0,
      'gates': finalConcert.gates,
      'ticket_tiers': finalConcert.tiers
          .map((t) => t.toJson(concertId: finalConcert.id))
          .toList(),
    };

    if (SupabaseService.isInitialized) {
      unawaited(
        _persistConcertAndTiersToSupabase(
          finalConcert,
          status: requiresAdminApproval ? 'pending' : 'published',
          approvalStatus:
              requiresAdminApproval ? 'pending_edit' : 'approved',
          pendingEditPayload: requiresAdminApproval ? editPayload : null,
          clearPendingEditPayload: !requiresAdminApproval,
        ).catchError((_) {}),
      );
    }

    if (requiresAdminApproval) {
      _syncConcertToAdmin(
        finalConcert,
        requestType: 'edit',
        pendingEditPayload: editPayload,
      );
    }
  }

  void deleteConcert(String id) {
    final updatedList = List<PromoterConcertItem>.from(concertsNotifier.value);
    updatedList.removeWhere((item) => item.id == id);
    concertsNotifier.value = updatedList;

    if (SupabaseService.isInitialized) {
      SupabaseService.client
          .from('concerts')
          .delete()
          .eq('id', id)
          .catchError((err) {
        debugPrint('Error delete concert from Supabase: $err');
      });
    }

    final adminService = AdminService();
    final adminConcerts =
        List<ConcertSubmissionModel>.from(adminService.concertsNotifier.value);
    adminConcerts.removeWhere((c) => c.id == id);
    adminService.concertsNotifier.value = adminConcerts;
  }

  void submitConcertCancellation({
    required String concertId,
    required String category,
    required String reason,
    String? attachmentName,
  }) {
    final list = List<PromoterConcertItem>.from(concertsNotifier.value);
    final idx = list.indexWhere((c) => c.id == concertId);
    if (idx != -1) {
      final old = list[idx];
      list[idx] = old.copyWith(
        cancellationStatus: ConcertCancellationStatus.menungguAdmin,
        cancellationCategory: category,
        cancellationReason: reason,
        cancellationAttachment: attachmentName,
        cancellationSubmissionDate: '19 Okt 2026, 14:02',
      );
      concertsNotifier.value = list;
    }

    if (SupabaseService.isInitialized) {
      SupabaseService.client.from('concerts').update({
        'status': 'cancellation_pending',
        'approval_status': 'pending_cancel',
        'cancellation_status': 'pending',
        'cancellation_category': category,
        'cancellation_reason': reason,
        'cancellation_attachment': attachmentName,
        'cancellation_date': '19 Okt 2026, 14:02',
      }).eq('id', concertId).catchError((err) {
        debugPrint('Error submit cancellation in Supabase: $err');
      });
    }

    final adminService = AdminService();
    final current = adminService.concertById(concertId);
    if (current != null) {
      final updated = current.copyWith(
        approvalStatus: ApprovalStatus.pending,
        requestType: 'cancellation',
        cancellationReason: reason,
        attachmentName: attachmentName,
      );
      adminService.concertsNotifier.value = [
        for (final c in adminService.concertsNotifier.value)
          c.id == concertId ? updated : c,
      ];
    }
  }

  void _syncConcertToAdmin(
    PromoterConcertItem item, {
    String? requestType,
    Map<String, dynamic>? pendingEditPayload,
  }) {
    final adminService = AdminService();
    final submission = ConcertSubmissionModel(
      id: item.id,
      promoterId: DataService().currentUser?.id ?? 'prd-006',
      promoterName: promoterName,
      title: item.title,
      subtitle: item.dateAndVenue,
      dateTime: DateTime.tryParse(item.date) ??
          DateTime.now().add(const Duration(days: 7)),
      venue: item.venueName,
      totalCapacity: item.totalCapacity,
      status: 'pending',
      bannerUrl: item.posterFileName,
      approvalStatus: ApprovalStatus.pending,
      submittedAt: DateTime.now(),
      requestType: requestType,
      requestInfo: requestType == 'edit' ? 'Perubahan Data Konser' : null,
      soldTickets: item.ticketsSold,
      refundAmount: item.totalRefundAmount,
      pendingEditPayload: pendingEditPayload,
      tiers: item.tiers
          .map((t) => SubmissionTierModel(
                id: t.id,
                concertId: item.id,
                name: t.name,
                price: t.price,
                totalQuota: t.quota,
              ))
          .toList(),
    );

    final adminConcerts =
        List<ConcertSubmissionModel>.from(adminService.concertsNotifier.value);
    adminConcerts.removeWhere((c) => c.id == submission.id);
    adminConcerts.insert(0, submission);
    adminService.concertsNotifier.value = adminConcerts;
  }

  void approveConcertCancellation({required String concertId}) {
    final list = List<PromoterConcertItem>.from(concertsNotifier.value);
    final idx = list.indexWhere((c) => c.id == concertId);
    if (idx != -1) {
      final old = list[idx];
      list[idx] = old.copyWith(
        cancellationStatus: ConcertCancellationStatus.disetujui,
        cancellationApprovalDate: '20 Okt 2026, 09:15',
      );
      concertsNotifier.value = list;
    }
  }

  void resetConcertCancellation({required String concertId}) {
    final list = List<PromoterConcertItem>.from(concertsNotifier.value);
    final idx = list.indexWhere((c) => c.id == concertId);
    if (idx != -1) {
      final old = list[idx];
      list[idx] = old.copyWith(
        cancellationStatus: ConcertCancellationStatus.none,
      );
      concertsNotifier.value = list;
    }
  }

  bool withdrawBalance({
    required int amount,
    required String targetBank,
    required String targetAccount,
  }) {
    if (amount <= 0 || amount > activeBalanceNotifier.value) {
      return false;
    }

    activeBalanceNotifier.value = activeBalanceNotifier.value - amount;

    final formattedAmount = formatCurrency(amount);
    final ref =
        '#WD-${(DateTime.now().millisecondsSinceEpoch % 10000000).toString().padLeft(7, '0')}';

    final newRecord = PromoterWithdrawalRecord(
      id: 'WD-${DateTime.now().millisecondsSinceEpoch}',
      dateTimeStr: 'Hari ini · 11:30 WIB',
      amount: amount,
      bankAccount: '$targetBank - $targetAccount',
      status: WithdrawalStatus.menunggu,
      refId: ref,
    );

    final updatedRecords =
        List<PromoterWithdrawalRecord>.from(withdrawalRecordsNotifier.value);
    updatedRecords.insert(0, newRecord);
    withdrawalRecordsNotifier.value = updatedRecords;

    final newTx = PromoterTransactionItem(
      id: ref,
      title:
          'Pencairan Dana ke $targetBank ${targetAccount.length > 4 ? targetAccount.substring(targetAccount.length - 4) : targetAccount}',
      date: 'Baru saja',
      amount: '- Rp $formattedAmount',
      isIncome: false,
    );

    final updatedTx =
        List<PromoterTransactionItem>.from(transactionsNotifier.value);
    updatedTx.insert(0, newTx);
    transactionsNotifier.value = updatedTx;

    return true;
  }

  static String formatCurrency(int amount) {
    final buffer = StringBuffer();
    final str = amount.toString();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  String get formattedActiveBalance {
    return 'Rp ${formatCurrency(activeBalanceNotifier.value)}';
  }

  String get formattedTotalRevenue {
    final buffer = StringBuffer('Rp ');
    final str = totalRevenue.toString();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  String get formattedTicketsSold {
    final buffer = StringBuffer();
    final str = ticketsSold.toString();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }
}
