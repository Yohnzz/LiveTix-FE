import 'package:flutter/material.dart';
import '../models/promoter_models.dart';

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
  final ValueNotifier<List<PromoterTransactionItem>> transactionsNotifier =
      ValueNotifier<List<PromoterTransactionItem>>([]);
  final ValueNotifier<List<PromoterConcertFinanceSummary>>
      concertFinanceSummariesNotifier =
      ValueNotifier<List<PromoterConcertFinanceSummary>>([]);
  final ValueNotifier<List<PromoterWithdrawalRecord>>
      withdrawalRecordsNotifier =
      ValueNotifier<List<PromoterWithdrawalRecord>>([]);

  // Promoter Profile Info
  final String promoterName = 'Java Promotor';
  final String verificationBadge = 'TERVERIFIKASI';
  final String promoterInitials = 'JP';
  final int quotaMax = 3;

  // Dashboard Metrics
  final int totalConcerts = 12;
  final int ticketsSold = 8450;
  final String ticketsSoldGrowth = '+15% bulan ini';
  final int totalRevenue = 2115000000;
  final double revenueGrowth = 8.2;

  // 7 Days Sales Trend (values relative to max height)
  final List<double> weeklySalesRatios = [0.35, 0.50, 0.28, 0.60, 0.82, 0.52, 0.95];

  void _initData() {
    concertsNotifier.value = [
      const PromoterConcertItem(
        id: '1',
        title: 'Soundwave Fest 2026',
        dateAndVenue: '12 Okt · Stadion Gajayana',
        date: 'Minggu, 12 Oktober 2026',
        time: 'Gerbang 17.00 · Mulai 19.00',
        venueName: 'Stadion Gajayana',
        venueAddress: 'Jl. Tangkuban Perahu, Kauman, Kec. Klojen, Kota Malang, Jawa Timur 65119',
        status: ConcertStatus.disetujui,
        likesCount: '4.2k',
        posterFileName: 'poster_soundwave.png',
        ticketsSold: 4200,
        affectedBuyersCount: 1860,
        totalRefundAmount: 2115000000,
        refundDoneCount: 2940,
        refundProcessingCount: 1050,
        refundPendingAccountCount: 210,
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

    concertFinanceSummariesNotifier.value = [
      const PromoterConcertFinanceSummary(
        id: 'c-1',
        concertTitle: 'Soundwave Fest 2026',
        ticketsSold: 4200,
        totalCapacity: 5000,
        grossAmount: 1050000000,
        systemFeePercent: 5.0,
        systemFeeAmount: 52500000,
        netAmount: 997500000,
        vipTicketsSold: 800,
        vipGross: 400000000,
        festivalTicketsSold: 3400,
        festivalGross: 650000000,
        payoutStatus: 'Payout Sukses',
        transferDestination: 'Ditransfer ke Mandiri (***8842)',
        transferDate: '15 Oktober 2026',
        payoutTransactionId: '#TX-PY9088312',
      ),
      const PromoterConcertFinanceSummary(
        id: 'c-2',
        concertTitle: 'Java Jazz Tribute 2026',
        ticketsSold: 4250,
        totalCapacity: 4250,
        grossAmount: 1065000000,
        systemFeePercent: 5.0,
        systemFeeAmount: 53250000,
        netAmount: 1011750000,
        vipTicketsSold: 1250,
        vipGross: 500000000,
        festivalTicketsSold: 3000,
        festivalGross: 565000000,
        payoutStatus: 'Payout Sukses',
        transferDestination: 'Ditransfer ke BCA (***9901)',
        transferDate: '10 Oktober 2026',
        payoutTransactionId: '#TX-PY9081120',
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
  }

  void toggleTheme() {
    isDarkModeNotifier.value = !isDarkModeNotifier.value;
  }

  bool addConcert(PromoterConcertItem newConcert) {
    if (quotaRemainingNotifier.value <= 0) {
      return false;
    }
    final updatedList = List<PromoterConcertItem>.from(concertsNotifier.value);
    updatedList.insert(0, newConcert);
    concertsNotifier.value = updatedList;

    quotaRemainingNotifier.value = quotaRemainingNotifier.value - 1;
    return true;
  }

  void deleteConcert(String id) {
    final updatedList = List<PromoterConcertItem>.from(concertsNotifier.value);
    updatedList.removeWhere((item) => item.id == id);
    concertsNotifier.value = updatedList;
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
