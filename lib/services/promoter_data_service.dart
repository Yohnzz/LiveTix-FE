import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide LocalStorage;
import '../models/approval_models.dart';
import '../screens/promoter/widgets/concert_image_widget.dart';
import '../screens/promoter/widgets/sales_trend_bar_chart.dart';
import '../models/promoter_models.dart';
import '../utils/local_storage.dart';
import '../utils/pin_hash.dart';
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
  final ValueNotifier<String?> avatarUrlNotifier = ValueNotifier<String?>(null);

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
  /// Default aman 'unverified' agar produser yang belum/tidak termuat statusnya
  /// dari database tidak bisa menembus ke fitur produser.
  final ValueNotifier<String> verificationStatusNotifier =
      ValueNotifier<String>('unverified');

  /// Alasan penolakan akun produser dari Admin (diambil langsung dari database)
  final ValueNotifier<String?> rejectionReasonNotifier =
      ValueNotifier<String?>(null);

  /// Alasan penonaktifan akun produser (kolom `deactivation_reason`)
  final ValueNotifier<String?> deactivationReasonNotifier =
      ValueNotifier<String?>(null);

  /// Waktu penolakan akun produser untuk countdown "Ajukan Ulang" real-time
  final ValueNotifier<DateTime?> rejectedAtNotifier =
      ValueNotifier<DateTime?>(null);

  /// Tren penjualan 7 hari terakhir (data nyata dari tabel orders Supabase).
  /// Digunakan oleh grafik dashboard dan kartu statistik dari sumber yang sama.
  final ValueNotifier<List<DailySalesData>> weeklySalesNotifier =
      ValueNotifier<List<DailySalesData>>([]);

  /// Getter tren penjualan 7 hari terakhir untuk dashboard.
  List<DailySalesData> get weeklySales => weeklySalesNotifier.value;

  /// Durasi cooldown sebelum produser dapat mengajukan ulang (default 24 jam dari waktu penolakan)
  static const Duration resubmitCooldownDuration = Duration(hours: 24);

  /// PIN 6-digit keamanan Produser (diatur saat verifikasi dokumen & diminta setiap login).
  /// Disimpan sebagai hash SHA-256, bukan plaintext. Hanya role Produser yang memiliki PIN.
  final ValueNotifier<String> pinCodeNotifier =
      ValueNotifier<String>(hashPin('123456'));

  /// Status apakah sesi login saat ini sudah membuka kunci PIN
  bool isPinUnlockedThisSession = false;

  /// Jumlah percobaan input PIN yang salah berturut-turut (maksimal 5 kali)
  final ValueNotifier<int> pinFailedAttemptsNotifier = ValueNotifier<int>(0);

  /// Batas waktu penguncian PIN Produser jika salah 5 kali (cooldown 10 menit realtime)
  final ValueNotifier<DateTime?> pinLockedUntilNotifier =
      ValueNotifier<DateTime?>(null);

  bool get isPinLockedOut {
    final lockedUntil = pinLockedUntilNotifier.value;
    if (lockedUntil == null) return false;
    return lockedUntil.isAfter(DateTime.now());
  }

  Duration get remainingPinLockoutDuration {
    final lockedUntil = pinLockedUntilNotifier.value;
    if (lockedUntil == null) return Duration.zero;
    final rem = lockedUntil.difference(DateTime.now());
    return rem.isNegative ? Duration.zero : rem;
  }

  /// Rekening bank penerima dana Produser (diisi saat verifikasi, dimuat dari `promoter_profiles`)
  final ValueNotifier<String> bankNameNotifier = ValueNotifier<String>('');
  final ValueNotifier<String> bankAccountNumberNotifier =
      ValueNotifier<String>('');
  final ValueNotifier<String> bankAccountHolderNotifier =
      ValueNotifier<String>('');

  bool get hasBankAccount =>
      bankNameNotifier.value.trim().isNotEmpty &&
      bankAccountNumberNotifier.value.trim().isNotEmpty;

  /// Ringkasan rekening, contoh: "BCA - 1234567890 a/n Nama"
  String get bankAccountSummary {
    if (!hasBankAccount) return 'Belum ada rekening. Lengkapi saat verifikasi.';
    final holder = bankAccountHolderNotifier.value.trim();
    final base =
        '${bankNameNotifier.value.trim()} - ${bankAccountNumberNotifier.value.trim()}';
    return holder.isEmpty ? base : '$base a/n $holder';
  }

  /// Reset state verifikasi saat akun Produser baru dibuat / berganti akun
  void resetProducerVerificationStateForNewAccount(String name) {
    stopRealtimeStatusSync();
    promoterNameNotifier.value = name.trim();
    verificationStatusNotifier.value = 'unverified';
    bankNameNotifier.value = '';
    bankAccountNumberNotifier.value = '';
    bankAccountHolderNotifier.value = '';
    pinCodeNotifier.value = '';
    rejectionReasonNotifier.value = null;
    deactivationReasonNotifier.value = null;
    rejectedAtNotifier.value = null;
    LocalStorage.remove('livetix_producer_rejection_reason');
    LocalStorage.remove('livetix_producer_deactivation_reason');
    LocalStorage.remove('livetix_producer_rejected_at');
    isPinUnlockedThisSession = false;
    pinFailedAttemptsNotifier.value = 0;
    pinLockedUntilNotifier.value = null;
  }

  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// ID baris `promoter_profiles`: sama dengan user UUID bila valid, agar kompatibel dengan kolom UUID.
  static String promoterRowIdFor(String userId) =>
      _uuidPattern.hasMatch(userId) ? userId : 'promoter-$userId';

  String get promoterName => promoterNameNotifier.value;
  String get verificationBadge {
    // Label mengikuti pemetaan status terpusat (AccountStatus), bukan teks
    // yang ditulis ulang di tiap layar.
    final status = AccountStatus.fromValue(verificationStatusNotifier.value);
    switch (status) {
      case AccountStatus.approved:
        return 'TERVERIFIKASI';
      case AccountStatus.pending:
        return verificationStatusNotifier.value.trim().toLowerCase() ==
                'pending'
            ? 'MENUNGGU APPROVAL'
            : 'BELUM VERIFIKASI';
      case AccountStatus.nonaktif:
        return 'NONAKTIF';
      case AccountStatus.rejected:
        return 'DITOLAK';
    }
  }

  /// Menormalkan nilai status lama agar selalu memakai salah satu dari
  /// `pending | approved | rejected | nonaktif`. Nilai `unverified` tetap
  /// dipertahankan karena berarti data diri belum dilengkapi.
  static String normalizeStatusValue(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'deactivated':
      case 'inactive':
        return AccountStatus.nonaktif.value;
      case 'ditolak':
        return AccountStatus.rejected.value;
      case 'disetujui':
        return AccountStatus.approved.value;
      default:
        return raw.trim().toLowerCase();
    }
  }

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
    // Jika Supabase sudah terhubung, semua data dimuat dari database — tidak ada dummy
    if (SupabaseService.isInitialized) {
      transactionsNotifier.value = [];
      withdrawalRecordsNotifier.value = [];
      concertsNotifier.value = [];
      concertFinanceSummariesNotifier.value = [];
      return;
    }

    // Fallback mode pengujian unit/widget test (Supabase tidak diinisialisasi) ↓
    transactionsNotifier.value = [];
    withdrawalRecordsNotifier.value = [];

    // Jika terhubung ke Supabase, inisialisasi kosong — data akan dimuat saat pengguna login sebagai Produser
    if (SupabaseService.isInitialized) {
      concertsNotifier.value = [];
      concertFinanceSummariesNotifier.value = [];
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
        squareLogoFileName: 'logo_soundwave_square.png',
        posterDataUrl: ConcertImageWidget.sampleSoundwavePng,
        squareLogoDataUrl: ConcertImageWidget.sampleSoundwavePng,
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
        squareLogoFileName: 'logo_symphony_square.png',
        posterDataUrl: ConcertImageWidget.sampleSymphonyPng,
        squareLogoDataUrl: ConcertImageWidget.sampleSymphonyPng,
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
        squareLogoFileName: 'logo_rock_anthem_square.png',
        posterDataUrl: ConcertImageWidget.sampleRockAnthemPng,
        squareLogoDataUrl: ConcertImageWidget.sampleRockAnthemPng,
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
        squareLogoFileName: 'logo_harmoni_square.png',
        posterDataUrl: ConcertImageWidget.sampleFestivalGajayanaPng,
        squareLogoDataUrl: ConcertImageWidget.sampleFestivalGajayanaPng,
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
    final currentUser = DataService().currentUser;
    final role = currentUser?.role.toLowerCase();
    if (role != null && role != 'produser' && role != 'promoter') {
      return;
    }
    final targetId = userId ?? currentUser?.id;
    if (targetId == null || targetId.isEmpty) return;
    _statusTargetUserId = targetId;

    bankNameNotifier.value = '';
    bankAccountNumberNotifier.value = '';
    bankAccountHolderNotifier.value = '';

    try {
      final profileRow = await SupabaseService.client
          .from('profiles')
          .select()
          .eq('id', targetId)
          .maybeSingle();

      if (profileRow != null) {
        final name =
            (profileRow['name'] ?? profileRow['full_name'])?.toString();
        if (name != null && name.trim().isNotEmpty) {
          promoterNameNotifier.value = name.trim();
        }
        final pin = profileRow['pin_code']?.toString();
        if (pin != null && pin.trim().isNotEmpty) {
          pinCodeNotifier.value = pin.trim();
        }
        final pAttempts = profileRow['pin_failed_attempts'];
        if (pAttempts != null) {
          pinFailedAttemptsNotifier.value = (pAttempts as num).toInt();
        }
        final pLockedUntil = profileRow['pin_locked_until']?.toString();
        if (pLockedUntil != null && pLockedUntil.isNotEmpty) {
          final dt = DateTime.tryParse(pLockedUntil);
          if (dt != null) pinLockedUntilNotifier.value = dt.toLocal();
        }
        final verStatus = profileRow['verification_status']?.toString();
        if (verStatus != null && verStatus.trim().isNotEmpty) {
          verificationStatusNotifier.value = normalizeStatusValue(verStatus);
        }
        final pBank = profileRow['bank_name']?.toString().trim() ?? '';
        final pNum = profileRow['bank_account_number']?.toString().trim() ?? '';
        final pHolder = (profileRow['bank_account_holder'] ??
                    profileRow['bank_account_name'])
                ?.toString()
                .trim() ??
            '';
        if (pBank.isNotEmpty && pNum.isNotEmpty) {
          bankNameNotifier.value = pBank;
          bankAccountNumberNotifier.value = pNum;
          bankAccountHolderNotifier.value = pHolder;
        }
      }

      Map<String, dynamic>? promoterRow = await SupabaseService.client
          .from('promoter_profiles')
          .select()
          .eq('user_id', targetId)
          .maybeSingle();
      promoterRow ??= await SupabaseService.client
          .from('promoter_profiles')
          .select()
          .eq('id', promoterRowIdFor(targetId))
          .maybeSingle();

      if (promoterRow != null) {
        final compName = promoterRow['company_name']?.toString();
        if (compName != null && compName.trim().isNotEmpty) {
          promoterNameNotifier.value = compName.trim();
        }
        final appStatus = promoterRow['approval_status']?.toString();
        if (appStatus != null && appStatus.trim().isNotEmpty) {
          verificationStatusNotifier.value = normalizeStatusValue(appStatus);
        }
        final rBank = promoterRow['bank_name']?.toString().trim() ?? '';
        final rNum =
            promoterRow['bank_account_number']?.toString().trim() ?? '';
        final rHolder = (promoterRow['bank_account_holder'] ??
                    promoterRow['bank_account_name'])
                ?.toString()
                .trim() ??
            '';
        if (rBank.isNotEmpty && rNum.isNotEmpty) {
          bankNameNotifier.value = rBank;
          bankAccountNumberNotifier.value = rNum;
          bankAccountHolderNotifier.value = rHolder;
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
        final rAttempts = promoterRow['pin_failed_attempts'];
        if (rAttempts != null) {
          pinFailedAttemptsNotifier.value = (rAttempts as num).toInt();
        }
        final rLockedUntil = promoterRow['pin_locked_until']?.toString();
        if (rLockedUntil != null && rLockedUntil.isNotEmpty) {
          final dt = DateTime.tryParse(rLockedUntil);
          if (dt != null) pinLockedUntilNotifier.value = dt.toLocal();
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
          LocalStorage.setString(
              'livetix_producer_rejection_reason', rejReason.trim());
        }
        final deactReason = promoterRow['deactivation_reason']?.toString();
        if (deactReason != null && deactReason.trim().isNotEmpty) {
          deactivationReasonNotifier.value = deactReason.trim();
          LocalStorage.setString(
            'livetix_producer_deactivation_reason',
            deactReason.trim(),
          );
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
    if (deactivationReasonNotifier.value == null) {
      final savedReason =
          LocalStorage.getString('livetix_producer_deactivation_reason');
      if (savedReason != null && savedReason.isNotEmpty) {
        deactivationReasonNotifier.value = savedReason;
      }
    }
    if (rejectedAtNotifier.value == null) {
      final savedAt = LocalStorage.getString('livetix_producer_rejected_at');
      if (savedAt != null && savedAt.isNotEmpty) {
        rejectedAtNotifier.value = DateTime.tryParse(savedAt);
      }
    }

    // Alasan hanya berlaku untuk status yang sesuai. Saat akun diaktifkan lagi,
    // alasan lama tidak boleh tetap tampil.
    final status = verificationStatusNotifier.value;
    if (status != 'rejected') {
      rejectionReasonNotifier.value = null;
      LocalStorage.remove('livetix_producer_rejection_reason');
      rejectedAtNotifier.value = null;
      LocalStorage.remove('livetix_producer_rejected_at');
    }
    if (AccountStatus.fromValue(status) != AccountStatus.nonaktif) {
      deactivationReasonNotifier.value = null;
      LocalStorage.remove('livetix_producer_deactivation_reason');
    }

    _ensureStatusRealtime();
  }

  String? _statusTargetUserId;
  RealtimeChannel? _statusRealtimeChannel;
  bool _isStatusRealtimeSubscribed = false;

  /// Langganan realtime status akun Produser. Perubahan `approval_status` atau
  /// alasan oleh Admin langsung diterapkan tanpa menunggu pembukaan halaman.
  void _ensureStatusRealtime() {
    if (!SupabaseService.isInitialized ||
        _isStatusRealtimeSubscribed ||
        _statusTargetUserId == null) {
      return;
    }
    _isStatusRealtimeSubscribed = true;
    final target = _statusTargetUserId!;

    void reloadIfMine(Map<String, dynamic> record) {
      final rowId = record['id']?.toString() ?? '';
      final rowUser = record['user_id']?.toString() ?? '';
      if (rowId != target && rowUser != target) return;
      unawaited(loadProducerProfileFromSupabase(target));
    }

    try {
      _statusRealtimeChannel = SupabaseService.client
          .channel('promoter_realtime_status')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'promoter_profiles',
            callback: (payload) => reloadIfMine(payload.newRecord),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'profiles',
            callback: (payload) => reloadIfMine(payload.newRecord),
          )
          .subscribe();
    } catch (e) {
      _isStatusRealtimeSubscribed = false;
      debugPrint('Error subscribe promoter status realtime: $e');
    }
  }

  /// Menghentikan langganan realtime status (dipanggil saat logout/reset).
  void stopRealtimeStatusSync() {
    if (_statusRealtimeChannel != null && SupabaseService.isInitialized) {
      SupabaseService.client.removeChannel(_statusRealtimeChannel!);
    }
    _statusRealtimeChannel = null;
    _isStatusRealtimeSubscribed = false;
    _statusTargetUserId = null;
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
            .update({'gates': gates}).eq('id', concertId);
      } catch (e) {
        debugPrint('Error updateConcertGates Supabase: $e');
      }
    }
  }

  /// Memuat daftar konser Produser langsung dari Supabase Cloud (tanpa dummy)
  Future<void> fetchPromoterConcertsFromSupabase() async {
    if (!SupabaseService.isInitialized) return;
    final currentUser = DataService().currentUser;
    final role = currentUser?.role.toLowerCase();
    if (role != null && role != 'produser' && role != 'promoter') {
      return;
    }
    startRealtimeStockSync();
    try {
      final currentUserId = currentUser?.id;

      // Ambil metrik penjualan aktual langsung dari tabel orders / tickets Supabase
      final Map<String, int> actualSoldMap = {};
      final Map<String, int> actualRevenueMap = {};
      final Map<int, int> dailySoldMap = {};
      final Map<int, int> dailyRevenueMap = {};
      try {
        final paidOrders = await SupabaseService.client
            .from('orders')
            .select(
                'concert_id, quantity, gross_amount, total_amount, created_at')
            .eq('payment_status', 'PAID');
        for (final o in paidOrders) {
          final cid = o['concert_id']?.toString() ?? '';
          final qty = (o['quantity'] as num?)?.toInt() ?? 1;
          final rev =
              ((o['gross_amount'] ?? o['total_amount']) as num?)?.toInt() ?? 0;
          if (cid.isNotEmpty) {
            actualSoldMap[cid] = (actualSoldMap[cid] ?? 0) + qty;
            actualRevenueMap[cid] = (actualRevenueMap[cid] ?? 0) + rev;
          }

          // Akumulasi penjualan harian untuk grafik tren 7 hari (sumber sama dengan totalRevenue/ticketsSold)
          final createdAt = o['created_at']?.toString();
          if (createdAt != null && createdAt.isNotEmpty) {
            try {
              final orderDate = DateTime.tryParse(createdAt);
              if (orderDate != null) {
                final now = DateTime.now();
                final startOfToday = DateTime(now.year, now.month, now.day);
                final daysAgo = startOfToday.difference(orderDate).inDays;
                if (daysAgo >= 0 && daysAgo <= 6) {
                  final dayKey = daysAgo;
                  final dailyQty = dailySoldMap[dayKey] ?? 0;
                  final dailyRev = dailyRevenueMap[dayKey] ?? 0;
                  dailySoldMap[dayKey] = dailyQty + qty;
                  dailyRevenueMap[dayKey] = dailyRev + rev;
                }
              }
            } catch (_) {}
          }
        }

        // Bangun data grafik 7 hari terakhir dari order yang sama dengan totalRevenue/ticketsSold
        final shortNames = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
        final fullNames = [
          'Senin',
          'Selasa',
          'Rabu',
          'Kamis',
          'Jumat',
          'Sabtu',
          'Minggu',
        ];
        final now = DateTime.now();
        final weekly = List<DailySalesData>.generate(7, (i) {
          final daysAgo = 6 - i;
          final d = now.subtract(Duration(days: daysAgo));
          final wd = d.weekday - 1;
          final sold = dailySoldMap[daysAgo] ?? 0;
          final rev = dailyRevenueMap[daysAgo] ?? 0;
          return DailySalesData(
            dayLabel: shortNames[wd],
            fullDayName: fullNames[wd],
            valueK: rev / 1000,
            ticketsSold: sold,
            revenueAmount: rev,
          );
        });
        double maxK = 0;
        int peak = -1;
        for (var i = 0; i < weekly.length; i++) {
          if (weekly[i].valueK > maxK) {
            maxK = weekly[i].valueK;
            peak = i;
          }
        }
        for (var i = 0; i < weekly.length; i++) {
          weekly[i] = DailySalesData(
            dayLabel: weekly[i].dayLabel,
            fullDayName: weekly[i].fullDayName,
            valueK: weekly[i].valueK,
            ticketsSold: weekly[i].ticketsSold,
            revenueAmount: weekly[i].revenueAmount,
            isPeak: maxK > 0 && i == peak,
          );
        }
        weeklySalesNotifier.value = weekly;
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
            final tierSold =
                parsed.tiers.fold<int>(0, (s, t) => s + t.soldCount);
            final rawActualSold = actualSoldMap[cid] ?? 0;
            final actualSold =
                rawActualSold > tierSold ? rawActualSold : tierSold;
            final actualRev = actualRevenueMap[cid] ??
                (actualSold *
                    (parsed.tiers.isNotEmpty ? parsed.tiers.first.price : 0));
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
            final cachedHighlightNames = LocalStorage.getStringList(
                'livetix_concert_highlight_names_$cid');
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

  /// Verifikasi PIN 6-digit Produser saat login (PIN tersimpan sebagai hash SHA-256)
  bool verifyPin(String inputPin) {
    if (isPinLockedOut) return false;
    final cleanInput = inputPin.trim();
    final storedPin = pinCodeNotifier.value.trim();
    if (cleanInput.isEmpty || storedPin.isEmpty) return false;
    if (!pinMatchesHash(cleanInput, storedPin)) return false;

    isPinUnlockedThisSession = true;
    // Migrasikan PIN plaintext lama menjadi hash secara diam-diam.
    if (!isHashedPin(storedPin)) {
      _rehashLegacyPin(cleanInput);
    }
    return true;
  }

  /// Catat kegagalan input PIN, tingkatkan hitungan, dan jika mencapai 5 kali salah,
  /// kunci akun selama 10 menit serta simpan ke database secara realtime.
  Future<int> recordFailedPinAttempt() async {
    final currentAttempts = pinFailedAttemptsNotifier.value;
    final newAttempts = currentAttempts + 1;
    pinFailedAttemptsNotifier.value = newAttempts;
    DateTime? lockedUntil;

    if (newAttempts >= 5) {
      lockedUntil = DateTime.now().add(const Duration(minutes: 10));
      pinLockedUntilNotifier.value = lockedUntil;
    }

    if (SupabaseService.isInitialized) {
      final userId = DataService().currentUser?.id;
      if (userId != null && userId.isNotEmpty) {
        final updatePayload = <String, dynamic>{
          'pin_failed_attempts': newAttempts,
          'pin_locked_until': lockedUntil?.toUtc().toIso8601String(),
        };
        try {
          await SupabaseService.client
              .from('profiles')
              .update(updatePayload)
              .eq('id', userId);
        } catch (e) {
          debugPrint('Error updating profiles pin lockout: $e');
        }
        try {
          await SupabaseService.client
              .from('promoter_profiles')
              .update(updatePayload)
              .eq('user_id', userId);
        } catch (e) {
          debugPrint('Error updating promoter_profiles pin lockout: $e');
        }
      }
    }
    return newAttempts;
  }

  /// Reset kegagalan PIN dan status penguncian (dipanggil saat PIN benar atau waktu tunggu selesai).
  Future<void> resetPinLockout() async {
    pinFailedAttemptsNotifier.value = 0;
    pinLockedUntilNotifier.value = null;

    if (SupabaseService.isInitialized) {
      final userId = DataService().currentUser?.id;
      if (userId != null && userId.isNotEmpty) {
        final updatePayload = <String, dynamic>{
          'pin_failed_attempts': 0,
          'pin_locked_until': null,
        };
        try {
          await SupabaseService.client
              .from('profiles')
              .update(updatePayload)
              .eq('id', userId);
        } catch (e) {
          debugPrint('Error resetting profiles pin lockout: $e');
        }
        try {
          await SupabaseService.client
              .from('promoter_profiles')
              .update(updatePayload)
              .eq('user_id', userId);
        } catch (e) {
          debugPrint('Error resetting promoter_profiles pin lockout: $e');
        }
      }
    }
  }

  /// Menyimpan ulang PIN sebagai hash bila sebelumnya masih tersimpan plaintext.
  Future<void> _rehashLegacyPin(String plainPin) async {
    final hashed = hashPin(plainPin);
    pinCodeNotifier.value = hashed;
    if (!SupabaseService.isInitialized) return;
    final userId = DataService().currentUser?.id;
    if (userId == null || userId.isEmpty) return;
    try {
      await SupabaseService.client
          .from('profiles')
          .update({'pin_code': hashed}).eq('id', userId);
      await SupabaseService.client
          .from('promoter_profiles')
          .update({'pin_code': hashed}).eq('user_id', userId);
    } catch (e) {
      debugPrint('Error rehash legacy PIN: $e');
    }
  }

  /// Simpan atau perbarui PIN 6-digit Produser (disimpan sebagai hash SHA-256)
  Future<void> updateProducerPin(String newPin) async {
    final trimmed = newPin.trim();
    if (trimmed.length != 6) return;
    final hashed = hashPin(trimmed);
    pinCodeNotifier.value = hashed;
    isPinUnlockedThisSession = true;

    if (SupabaseService.isInitialized) {
      final userId = DataService().currentUser?.id;
      if (userId != null) {
        try {
          await SupabaseService.client
              .from('profiles')
              .update({'pin_code': hashed}).eq('id', userId);
          await SupabaseService.client
              .from('promoter_profiles')
              .update({'pin_code': hashed}).eq('user_id', userId);
        } catch (e) {
          debugPrint('Error updateProducerPin Supabase: $e');
        }
      }
    }
  }

  /// Pengajuan verifikasi data diri Produser + rekening bank + dokumen + PIN.
  /// Setelah tersimpan, akun berstatus `approved` sehingga alur berlanjut ke halaman PIN lalu Beranda.
  Future<({bool success, String? errorMessage})> submitInitialVerification({
    required String fullName,
    required String birthDate,
    required String phone,
    required String address,
    required String ktpFileName,
    required String responsibilityLetterFileName,
    required String pinCode,
    String bankName = '',
    String bankAccountNumber = '',
    String bankAccountHolder = '',
  }) async {
    final cleanName = fullName.trim().isNotEmpty
        ? fullName.trim()
        : promoterNameNotifier.value;
    final cleanBank = bankName.trim();
    final cleanAccNo = bankAccountNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final cleanHolder = bankAccountHolder.trim().isNotEmpty
        ? bankAccountHolder.trim()
        : cleanName;

    // PIN Produser selalu disimpan sebagai hash SHA-256, bukan plaintext.
    final storedPinHash = hashPin(pinCode.trim());

    final currentUser = DataService().currentUser;
    final authUid = SupabaseService.isInitialized
        ? SupabaseService.client.auth.currentUser?.id
        : null;
    final userId = (authUid != null && authUid.isNotEmpty)
        ? authUid
        : (currentUser?.id ?? 'prd-${DateTime.now().millisecondsSinceEpoch}');
    final userEmail = currentUser?.email ?? 'official@javapromotor.com';
    final rowId = promoterRowIdFor(userId);

    if (SupabaseService.isInitialized) {
      final nowIso = DateTime.now().toIso8601String();
      String? dbError;
      try {
        await SupabaseService.client.from('profiles').upsert({
          'id': userId,
          'name': cleanName,
          'full_name': cleanName,
          'email': userEmail,
          'phone': phone.trim(),
          'role': 'Produser',
          'pin_code': storedPinHash,
          'bank_name': cleanBank,
          'bank_account_number': cleanAccNo,
          'bank_account_holder': cleanHolder,
          'is_verified': false,
          'verification_status': 'pending',
          'approval_status': 'pending',
          'role_verification_status': 'pending',
          'updated_at': nowIso,
        }).select();
      } catch (e) {
        debugPrint('Error submitInitialVerification profiles: $e');
        dbError = e.toString();
        // Fallback tanpa kolom opsional bila migrasi belum dijalankan
        try {
          await SupabaseService.client.from('profiles').upsert({
            'id': userId,
            'name': cleanName,
            'full_name': cleanName,
            'email': userEmail,
            'phone': phone.trim(),
            'role': 'Produser',
            'pin_code': storedPinHash,
            'is_verified': false,
            'verification_status': 'pending',
          }).select();
          dbError = null;
        } catch (e2) {
          dbError = e2.toString();
        }
      }

      String? promoterError;
      try {
        await SupabaseService.client.from('promoter_profiles').upsert({
          'id': rowId,
          'user_id': userId,
          'full_name': cleanName,
          'company_name': cleanName,
          'responsible_name': cleanName,
          'phone': phone.trim(),
          'address': address.trim(),
          'office_address': address.trim(),
          'birth_date': birthDate.trim(),
          'ktp_url': ktpFileName.trim(),
          'responsibility_letter_url': responsibilityLetterFileName.trim(),
          'pin_code': storedPinHash,
          'bank_name': cleanBank,
          'bank_account_number': cleanAccNo,
          'bank_account_name': cleanHolder,
          'bank_account_holder': cleanHolder,
          'is_verified': false,
          'verification_status': 'pending',
          'approval_status': 'pending',
          'submitted_at': nowIso,
          'updated_at': nowIso,
        }).select();
      } catch (e) {
        debugPrint('Error submitInitialVerification promoter_profiles: $e');
        promoterError = e.toString();
        final working = <String, dynamic>{
          'id': rowId,
          'user_id': userId,
          'company_name': cleanName,
          'phone': phone.trim(),
          'ktp_url': ktpFileName.trim(),
          'responsibility_letter_url': responsibilityLetterFileName.trim(),
          'pin_code': storedPinHash,
          'bank_name': cleanBank,
          'bank_account_number': cleanAccNo,
          'bank_account_holder': cleanHolder,
          'is_verified': false,
          'approval_status': 'pending',
        };
        for (int i = 0; i < 12; i++) {
          try {
            await SupabaseService.client
                .from('promoter_profiles')
                .upsert(working)
                .select();
            promoterError = null;
            break;
          } catch (retryErr) {
            final m = RegExp(r"Could not find the '([^']+)' column")
                .firstMatch(retryErr.toString());
            final col = m?.group(1);
            if (col != null &&
                working.containsKey(col) &&
                col != 'id' &&
                col != 'user_id') {
              working.remove(col);
              continue;
            }
            promoterError = retryErr.toString();
            break;
          }
        }
      }

      if (dbError != null && promoterError != null) {
        final low = dbError.toLowerCase();
        return (
          success: false,
          errorMessage: low.contains('failed to fetch') ||
                  low.contains('socket')
              ? 'Koneksi ke server Supabase gagal. Periksa jaringan Anda lalu coba lagi.'
              : 'Gagal menyimpan verifikasi ke database: $dbError',
        );
      }
    }

    promoterNameNotifier.value = cleanName;
    ktpDocumentNotifier.value = ktpFileName.trim();
    responsibilityLetterNotifier.value = responsibilityLetterFileName.trim();
    pinCodeNotifier.value = storedPinHash;
    bankNameNotifier.value = cleanBank;
    bankAccountNumberNotifier.value = cleanAccNo;
    bankAccountHolderNotifier.value = cleanHolder;
    verificationStatusNotifier.value = 'pending';
    isPinUnlockedThisSession = false;

    // Sinkronkan ke daftar Produser di AdminService (tercatat menunggu approval)
    final adminService = AdminService();
    final newApp = ProducerApplicationModel(
      id: rowId,
      userId: userId,
      companyName: cleanName,
      email: userEmail,
      phone: phone.trim().isNotEmpty ? phone.trim() : '081234567890',
      address: address.trim().isNotEmpty
          ? address.trim()
          : 'Jl. Kayutangan No. 45, Malang',
      approvalStatus: AccountStatus.pending,
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
          name:
              'Lembar Penanggung Jawab (${responsibilityLetterFileName.trim()})',
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

    return (success: true, errorMessage: null);
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
      approvalStatus: AccountStatus.pending,
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

  /// Dipanggil saat Admin menonaktifkan akun Produser
  void onAdminDeactivatedProducer(String reason) {
    verificationStatusNotifier.value = 'nonaktif';
    deactivationReasonNotifier.value = reason.trim();
    isPinUnlockedThisSession = false;
    LocalStorage.setString(
      'livetix_producer_deactivation_reason',
      reason.trim(),
    );
  }

  /// Dipanggil saat Admin mengaktifkan kembali akun Produser.
  void onAdminActivatedProducer() {
    verificationStatusNotifier.value = 'approved';
    deactivationReasonNotifier.value = null;
    rejectionReasonNotifier.value = null;
    rejectedAtNotifier.value = null;
    isPinUnlockedThisSession = false;
    LocalStorage.remove('livetix_producer_deactivation_reason');
    LocalStorage.remove('livetix_producer_rejection_reason');
    LocalStorage.remove('livetix_producer_rejected_at');
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
      SupabaseService.client
          .from('concerts')
          .update({
            'status': 'pending',
            'approval_status': 'pending_create',
            'rejection_reason': null,
            'rejected_at': null,
          })
          .eq('id', concertId)
          .catchError((_) {});
    }

    _syncConcertToAdmin(updated, requestType: 'create');
  }

  /// Tambah/kurangi jumlah Love (Disukai) konser secara real-time saat User menekan tombol Love
  void adjustConcertLikes(String concertId, int delta) {
    final list = List<PromoterConcertItem>.from(concertsNotifier.value);
    final idx = list.indexWhere((c) =>
        c.id == concertId ||
        (concertId == 'featured-1' &&
            (c.id == '1' || c.title.toLowerCase().contains('soundwave fest'))));

    if (idx != -1) {
      final currentLikes = list[idx].numericLikes;
      final nextLikes = (currentLikes + delta) < 0 ? 0 : (currentLikes + delta);
      list[idx] = list[idx].copyWith(
        likesCount: PromoterConcertItem.formatLikes(nextLikes),
      );
      concertsNotifier.value = list;
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
      for (final bucket in const ['concert-media', 'concerts', 'avatars']) {
        try {
          await SupabaseService.client.storage
              .from(bucket)
              .uploadBinary(
                filePath,
                bytes,
                fileOptions: FileOptions(
                  contentType: contentType,
                  upsert: true,
                ),
              )
              .timeout(const Duration(seconds: 12));
          final publicUrl = SupabaseService.client.storage
              .from(bucket)
              .getPublicUrl(filePath);
          if (publicUrl.isNotEmpty) {
            return publicUrl;
          }
        } catch (bucketErr) {
          debugPrint(
              'Upload media konser ke bucket "$bucket" gagal: $bucketErr');
        }
      }
      return raw;
    } catch (e) {
      debugPrint('Error upload media konser ($kind): $e');
      return raw;
    }
  }

  String _formatSupabaseError(Object err) {
    final raw = err.toString();
    final lower = raw.toLowerCase();
    if (lower.contains('row-level security') || raw.contains('42501')) {
      return 'Izin akses database ditolak (RLS). Pastikan akun Anda login sebagai Produser dan telah terhubung ke sesi Supabase.';
    }
    if (lower.contains('failed to fetch') ||
        lower.contains('socketexception') ||
        lower.contains('timed out')) {
      return 'Koneksi ke database Supabase gagal. Periksa jaringan internet Anda lalu coba lagi.';
    }
    return 'Gagal menyimpan konser ke database: $raw';
  }

  Future<({bool success, String? errorMessage})> _upsertRowAdaptive({
    required String table,
    required Map<String, dynamic> rawPayload,
    Set<String> requiredKeys = const {'id'},
  }) async {
    final working = Map<String, dynamic>.from(rawPayload);
    for (int attempt = 0; attempt < 24; attempt++) {
      try {
        await SupabaseService.client.from(table).upsert(working).select();
        return (success: true, errorMessage: null);
      } catch (err) {
        final msg = err.toString();
        String? badColumn;
        final pgrstMatch =
            RegExp(r"Could not find the '([^']+)' column").firstMatch(msg);
        if (pgrstMatch != null) {
          badColumn = pgrstMatch.group(1);
        } else {
          final pgColMatch = RegExp(r'column "([^"]+)"').firstMatch(msg);
          if (pgColMatch != null) {
            badColumn = pgColMatch.group(1);
          } else if (msg.contains('42804') || msg.contains('22P02')) {
            if (msg.contains('gates') && working.containsKey('gates')) {
              badColumn = 'gates';
            } else if (msg.contains('highlights') &&
                working.containsKey('highlights')) {
              badColumn = 'highlights';
            } else if (msg.contains('highlight_names') &&
                working.containsKey('highlight_names')) {
              badColumn = 'highlight_names';
            } else if (msg.contains('accent_color') &&
                working.containsKey('accent_color')) {
              badColumn = 'accent_color';
            }
          }
        }

        if (badColumn != null &&
            badColumn.isNotEmpty &&
            !requiredKeys.contains(badColumn) &&
            working.containsKey(badColumn)) {
          debugPrint(
            'Adaptive upsert ($table): melewatkan kolom "$badColumn" ($msg)',
          );
          working.remove(badColumn);
          continue;
        }

        if (msg.contains('22P02') &&
            working.containsKey('accent_color') &&
            working['accent_color'] is int) {
          working['accent_color'] = working['accent_color'].toString();
          continue;
        }

        debugPrint('Error upsert $table to Supabase: $err');
        return (success: false, errorMessage: _formatSupabaseError(err));
      }
    }
    return (
      success: false,
      errorMessage: 'Gagal menyimpan data $table ke database Supabase.',
    );
  }

  Future<({bool success, String? errorMessage})>
      _persistConcertAndTiersToSupabase(
    PromoterConcertItem concert, {
    required String status,
    required String approvalStatus,
    Map<String, dynamic>? pendingEditPayload,
    bool clearPendingEditPayload = false,
  }) async {
    if (!SupabaseService.isInitialized) {
      return (success: true, errorMessage: null);
    }

    var resolvedConcert = concert;
    final authUid = SupabaseService.client.auth.currentUser?.id.trim();
    final currentUserId = (authUid != null && authUid.isNotEmpty)
        ? authUid
        : DataService().currentUser?.id;

    // 1. Unggah gambar data:image/* ke bucket Storage agar baris DB ringkas
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

    if (hasUploadedPoster || hasUploadedLogo || uploadedHighlights.isNotEmpty) {
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

    final concertJson = resolvedConcert.toSupabaseMap(
      promoterId: currentUserId,
      producerName: promoterName,
    );
    concertJson['status'] = status;
    concertJson['approval_status'] = approvalStatus;
    if (pendingEditPayload != null) {
      concertJson['pending_edit_payload'] = pendingEditPayload;
    } else if (clearPendingEditPayload) {
      concertJson['pending_edit_payload'] = null;
    }

    final concertResult = await _upsertRowAdaptive(
      table: 'concerts',
      rawPayload: concertJson,
      requiredKeys: const {'id', 'title'},
    );
    if (!concertResult.success) {
      return concertResult;
    }

    for (int i = 0; i < resolvedConcert.tiers.length; i++) {
      final tier = resolvedConcert.tiers[i];
      final tierResult = await _upsertRowAdaptive(
        table: 'ticket_tiers',
        rawPayload: {
          'id': tier.id,
          'concert_id': resolvedConcert.id,
          'name': tier.name,
          'price': tier.price,
          'quota': tier.quota,
          'total_quota': tier.quota,
          'quota_type': tier.quotaType,
          'accent_color': tier.accentColor.toARGB32(),
          'sort_order': i,
        },
        requiredKeys: const {'id', 'concert_id', 'name'},
      );
      if (!tierResult.success) {
        return tierResult;
      }
    }
    return (success: true, errorMessage: null);
  }

  Future<({bool success, String? errorMessage})> addConcert(
      PromoterConcertItem newConcert) async {
    if (quotaRemainingNotifier.value <= 0) {
      return (
        success: false,
        errorMessage: 'Kuota pengajuan konser Anda sudah habis.',
      );
    }

    final previousList = List<PromoterConcertItem>.from(concertsNotifier.value);
    final previousQuota = quotaRemainingNotifier.value;

    final updatedList = List<PromoterConcertItem>.from(previousList);
    updatedList.insert(0, newConcert);
    concertsNotifier.value = updatedList;
    quotaRemainingNotifier.value = previousQuota - 1;

    if (newConcert.highlights.isNotEmpty) {
      LocalStorage.setStringList(
          'livetix_concert_highlights_${newConcert.id}', newConcert.highlights);
      LocalStorage.setStringList(
          'livetix_concert_highlight_names_${newConcert.id}',
          newConcert.highlightNames);
    }

    // 1. Simpan ke Supabase Cloud (tunggu hasil asli agar error terlihat & FK gate crew valid)
    if (SupabaseService.isInitialized) {
      final result = await _persistConcertAndTiersToSupabase(
        newConcert,
        status: 'pending',
        approvalStatus: 'pending_create',
      );
      if (!result.success) {
        concertsNotifier.value = previousList;
        quotaRemainingNotifier.value = previousQuota;
        return result;
      }
    }

    // 2. Hubungkan ke antrean persetujuan Super Admin
    _syncConcertToAdmin(newConcert, requestType: 'create');

    return (success: true, errorMessage: null);
  }

  /// Memperbarui informasi konser dan mengirim ulang ke antrean approval Admin
  Future<({bool success, String? errorMessage})> updateConcert(
    PromoterConcertItem updatedConcert, {
    bool requiresAdminApproval = true,
  }) async {
    final previousList = List<PromoterConcertItem>.from(concertsNotifier.value);
    final list = List<PromoterConcertItem>.from(previousList);
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
      if (finalConcert.venueLatitude != null)
        'venue_latitude': finalConcert.venueLatitude,
      if (finalConcert.venueLongitude != null)
        'venue_longitude': finalConcert.venueLongitude,
      if (finalConcert.venuePlaceId != null &&
          finalConcert.venuePlaceId!.isNotEmpty)
        'venue_place_id': finalConcert.venuePlaceId,
      'description': finalConcert.description,
      'banner_image_url': (finalConcert.posterDataUrl?.isNotEmpty == true)
          ? finalConcert.posterDataUrl
          : finalConcert.posterFileName,
      'logo_image_url': (finalConcert.squareLogoDataUrl?.isNotEmpty == true)
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
      final result = await _persistConcertAndTiersToSupabase(
        finalConcert,
        status: requiresAdminApproval ? 'pending' : 'published',
        approvalStatus: requiresAdminApproval ? 'pending_edit' : 'approved',
        pendingEditPayload: requiresAdminApproval ? editPayload : null,
        clearPendingEditPayload: !requiresAdminApproval,
      );
      if (!result.success) {
        concertsNotifier.value = previousList;
        return result;
      }
    }

    if (requiresAdminApproval) {
      _syncConcertToAdmin(
        finalConcert,
        requestType: 'edit',
        pendingEditPayload: editPayload,
      );
    }
    return (success: true, errorMessage: null);
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
      SupabaseService.client
          .from('concerts')
          .update({
            'status': 'cancellation_pending',
            'approval_status': 'pending_cancel',
            'cancellation_status': 'pending',
            'cancellation_category': category,
            'cancellation_reason': reason,
            'cancellation_attachment': attachmentName,
            'cancellation_date': '19 Okt 2026, 14:02',
          })
          .eq('id', concertId)
          .catchError((err) {
            debugPrint('Error submit cancellation in Supabase: $err');
          });
    }

    final adminService = AdminService();
    final current = adminService.concertById(concertId);
    if (current != null) {
      final updated = current.copyWith(
        approvalStatus: AccountStatus.pending,
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
      approvalStatus: AccountStatus.pending,
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
