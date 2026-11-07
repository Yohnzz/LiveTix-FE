import 'package:flutter/material.dart';

enum ConcertStatus { semua, draft, menunggu, disetujui, ditolak }

extension ConcertStatusExt on ConcertStatus {
  String get label {
    switch (this) {
      case ConcertStatus.semua:
        return 'Semua';
      case ConcertStatus.draft:
        return 'Draft';
      case ConcertStatus.menunggu:
        return 'Menunggu';
      case ConcertStatus.disetujui:
        return 'Disetujui';
      case ConcertStatus.ditolak:
        return 'Ditolak';
    }
  }

  String get badgeText {
    switch (this) {
      case ConcertStatus.draft:
        return 'DRAFT';
      case ConcertStatus.menunggu:
        return 'MENUNGGU';
      case ConcertStatus.disetujui:
        return 'DISETUJUI';
      case ConcertStatus.ditolak:
        return 'DITOLAK';
      case ConcertStatus.semua:
        return 'SEMUA';
    }
  }

  Color get badgeBgColor {
    switch (this) {
      case ConcertStatus.disetujui:
        return const Color(0xFFE8FDF0); // Mint green
      case ConcertStatus.menunggu:
        return const Color(0xFFFEF3F2); // Soft amber/peach or warm light yellow
      case ConcertStatus.draft:
        return const Color(0xFFF2F4F7); // Soft light grey
      case ConcertStatus.ditolak:
        return const Color(0xFFFEE4E2); // Light red
      case ConcertStatus.semua:
        return const Color(0xFFF2F4F7);
    }
  }

  Color get badgeTextColor {
    switch (this) {
      case ConcertStatus.disetujui:
        return const Color(0xFF039855); // Emerald green
      case ConcertStatus.menunggu:
        return const Color(0xFFD97706); // Amber orange
      case ConcertStatus.draft:
        return const Color(0xFF344054); // Slate grey
      case ConcertStatus.ditolak:
        return const Color(0xFFD92D20); // Red
      case ConcertStatus.semua:
        return const Color(0xFF344054);
    }
  }
}

class PromoterTicketTier {
  final String id;
  final String name;
  final int price;
  final int quota;
  final String quotaType; // 'Kursi' | 'Orang' | 'Tiket'
  final Color accentColor;

  const PromoterTicketTier({
    required this.id,
    required this.name,
    required this.price,
    required this.quota,
    this.quotaType = 'Kursi',
    this.accentColor = const Color(0xFFC2185B),
  });

  String get formattedPrice {
    final buffer = StringBuffer('Rp ');
    final str = price.toString();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  String get formattedQuota => 'Kuota: ${formatNumber(quota)} $quotaType';

  static String formatNumber(int number) {
    final buffer = StringBuffer();
    final str = number.toString();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  PromoterTicketTier copyWith({
    String? id,
    String? name,
    int? price,
    int? quota,
    String? quotaType,
    Color? accentColor,
  }) {
    return PromoterTicketTier(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      quota: quota ?? this.quota,
      quotaType: quotaType ?? this.quotaType,
      accentColor: accentColor ?? this.accentColor,
    );
  }

  factory PromoterTicketTier.fromJson(Map<String, dynamic> json) {
    final parsedPrice = json['price'] is int
        ? json['price'] as int
        : int.tryParse(json['price']?.toString() ?? '0') ?? 0;
    final parsedQuota = json['total_quota'] is int
        ? json['total_quota'] as int
        : (json['quota'] is int
            ? json['quota'] as int
            : int.tryParse(json['quota']?.toString() ?? '0') ?? 0);

    return PromoterTicketTier(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      price: parsedPrice,
      quota: parsedQuota,
      quotaType: json['quota_type']?.toString() ?? 'Kursi',
      accentColor: json['accent_color'] != null
          ? Color(int.tryParse(json['accent_color'].toString()) ?? 0xFFC2185B)
          : const Color(0xFFC2185B),
    );
  }

  Map<String, dynamic> toJson({String? concertId}) {
    return {
      'id': id,
      if (concertId != null) 'concert_id': concertId,
      'name': name,
      'price': price,
      'total_quota': quota,
      'remaining_quota': quota,
      'quota_type': quotaType,
      'accent_color': accentColor.toARGB32(),
    };
  }
}

enum ConcertCancellationStatus {
  none,
  menungguAdmin, // Menunggu Persetujuan Admin (Image 3 & 4)
  disetujui,     // Pembatalan Disetujui (Image 5)
  ditolak,
}

class PromoterConcertItem {
  final String id;
  final String title;
  final String dateAndVenue;
  final String date;
  final String time;
  final String venueName;
  final String venueAddress;
  final String description;
  final String posterFileName;
  final String squareLogoFileName;
  final ConcertStatus status;
  final String likesCount;
  final List<PromoterTicketTier> tiers;

  // Cancellation and Refund fields
  final ConcertCancellationStatus cancellationStatus;
  final String cancellationCategory;
  final String cancellationReason;
  final String? cancellationAttachment;
  final String cancellationSubmissionDate;
  final String? cancellationApprovalDate;
  final int ticketsSold;
  final int affectedBuyersCount;
  final int totalRefundAmount;
  final int refundDoneCount;
  final int refundProcessingCount;
  final int refundPendingAccountCount;
  final bool isCompleted;
  final int grossRevenue;

  const PromoterConcertItem({
    required this.id,
    required this.title,
    required this.dateAndVenue,
    required this.date,
    this.time = '19:00 WIB',
    required this.venueName,
    required this.venueAddress,
    this.description = '',
    this.posterFileName = 'poster_harmoni_final.png',
    this.squareLogoFileName = 'logo_soundwave_square.png',
    this.status = ConcertStatus.disetujui,
    this.likesCount = '4.2k',
    this.tiers = const [],
    this.cancellationStatus = ConcertCancellationStatus.none,
    this.cancellationCategory = 'Perizinan',
    this.cancellationReason = '',
    this.cancellationAttachment,
    this.cancellationSubmissionDate = '19 Okt 2026, 14:02',
    this.cancellationApprovalDate = '20 Okt 2026, 09:15',
    this.ticketsSold = 4200,
    this.affectedBuyersCount = 1860,
    this.totalRefundAmount = 2115000000,
    this.refundDoneCount = 2940,
    this.refundProcessingCount = 1050,
    this.refundPendingAccountCount = 210,
    this.isCompleted = false,
    this.grossRevenue = 0,
  });

  int get numericLikes {
    final cleaned = likesCount.trim().toLowerCase();
    if (cleaned.endsWith('k')) {
      final numPart =
          double.tryParse(cleaned.substring(0, cleaned.length - 1)) ?? 0;
      return (numPart * 1000).round();
    }
    return int.tryParse(cleaned.replaceAll('.', '').replaceAll(',', '')) ?? 0;
  }

  static String formatLikes(int count) {
    if (count < 0) return '0';
    return count.toString();
  }

  int get resolvedGrossRevenue {
    if (grossRevenue > 0) return grossRevenue;
    if (ticketsSold > 0 && tiers.isNotEmpty) {
      return ticketsSold * tiers.first.price;
    }
    return estimatedRevenue;
  }

  String get formattedGrossRevenue {
    return 'Rp${PromoterTicketTier.formatNumber(resolvedGrossRevenue)}';
  }

  bool get isCancellationPending =>
      cancellationStatus == ConcertCancellationStatus.menungguAdmin;

  bool get isCancellationApproved =>
      cancellationStatus == ConcertCancellationStatus.disetujui;

  String get formattedTicketsSold {
    return '${PromoterTicketTier.formatNumber(ticketsSold)} tiket';
  }

  String get formattedTotalRefund {
    final buffer = StringBuffer('Rp');
    final str = totalRefundAmount.toString();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  PromoterConcertItem copyWith({
    String? id,
    String? title,
    String? dateAndVenue,
    String? date,
    String? time,
    String? venueName,
    String? venueAddress,
    String? description,
    String? posterFileName,
    String? squareLogoFileName,
    ConcertStatus? status,
    String? likesCount,
    List<PromoterTicketTier>? tiers,
    ConcertCancellationStatus? cancellationStatus,
    String? cancellationCategory,
    String? cancellationReason,
    String? cancellationAttachment,
    String? cancellationSubmissionDate,
    String? cancellationApprovalDate,
    int? ticketsSold,
    int? affectedBuyersCount,
    int? totalRefundAmount,
    int? refundDoneCount,
    int? refundProcessingCount,
    int? refundPendingAccountCount,
    bool? isCompleted,
    int? grossRevenue,
  }) {
    return PromoterConcertItem(
      id: id ?? this.id,
      title: title ?? this.title,
      dateAndVenue: dateAndVenue ?? this.dateAndVenue,
      date: date ?? this.date,
      time: time ?? this.time,
      venueName: venueName ?? this.venueName,
      venueAddress: venueAddress ?? this.venueAddress,
      description: description ?? this.description,
      posterFileName: posterFileName ?? this.posterFileName,
      squareLogoFileName: squareLogoFileName ?? this.squareLogoFileName,
      status: status ?? this.status,
      likesCount: likesCount ?? this.likesCount,
      tiers: tiers ?? this.tiers,
      cancellationStatus: cancellationStatus ?? this.cancellationStatus,
      cancellationCategory: cancellationCategory ?? this.cancellationCategory,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      cancellationAttachment:
          cancellationAttachment ?? this.cancellationAttachment,
      cancellationSubmissionDate:
          cancellationSubmissionDate ?? this.cancellationSubmissionDate,
      cancellationApprovalDate:
          cancellationApprovalDate ?? this.cancellationApprovalDate,
      ticketsSold: ticketsSold ?? this.ticketsSold,
      affectedBuyersCount: affectedBuyersCount ?? this.affectedBuyersCount,
      totalRefundAmount: totalRefundAmount ?? this.totalRefundAmount,
      refundDoneCount: refundDoneCount ?? this.refundDoneCount,
      refundProcessingCount:
          refundProcessingCount ?? this.refundProcessingCount,
      refundPendingAccountCount:
          refundPendingAccountCount ?? this.refundPendingAccountCount,
      isCompleted: isCompleted ?? this.isCompleted,
      grossRevenue: grossRevenue ?? this.grossRevenue,
    );
  }

  int get totalCapacity {
    return tiers.fold(0, (sum, item) => sum + item.quota);
  }

  int get estimatedRevenue {
    return tiers.fold(0, (sum, item) => sum + (item.price * item.quota));
  }

  String get formattedTotalCapacity {
    return '${PromoterTicketTier.formatNumber(totalCapacity)} Tiket';
  }

  String get formattedEstimatedRevenue {
    final buffer = StringBuffer('Rp ');
    final str = estimatedRevenue.toString();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  factory PromoterConcertItem.fromJson(Map<String, dynamic> json) {
    ConcertStatus parseStatus(String? statusStr) {
      switch (statusStr?.toLowerCase()) {
        case 'published':
        case 'disetujui':
        case 'approved':
          return ConcertStatus.disetujui;
        case 'pending':
        case 'menunggu':
          return ConcertStatus.menunggu;
        case 'cancelled':
        case 'ditolak':
        case 'rejected':
          return ConcertStatus.ditolak;
        case 'draft':
        default:
          return ConcertStatus.draft;
      }
    }

    final rawTiers = json['ticket_tiers'] as List<dynamic>?;
    final tiersList = rawTiers
            ?.map((e) => PromoterTicketTier.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final resolvedDate = json['date']?.toString() ?? json['date_time']?.toString() ?? '';

    return PromoterConcertItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      dateAndVenue: json['subtitle']?.toString() ??
          '$resolvedDate · ${json['venue'] ?? ''}',
      date: resolvedDate,
      time: json['time']?.toString() ?? '19:00 WIB',
      venueName: json['venue']?.toString() ?? '',
      venueAddress: json['venue_address']?.toString() ??
          (json['venue']?.toString() ?? ''),
      description: json['description']?.toString() ?? '',
      posterFileName: json['banner_image_url']?.toString() ??
          json['banner_url']?.toString() ??
          'poster_soundwave.png',
      squareLogoFileName: json['logo_image_url']?.toString() ??
          json['logo_url']?.toString() ??
          'logo_soundwave_square.png',
      status: parseStatus(json['status']?.toString()),
      likesCount: json['likes_count']?.toString() ?? '0',
      tiers: tiersList,
      ticketsSold: (json['tickets_sold'] as num?)?.toInt() ?? 0,
      isCompleted: (json['is_completed'] as bool?) ?? false,
      grossRevenue: (json['gross_revenue'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson({String? promoterId}) {
    String statusString;
    switch (status) {
      case ConcertStatus.disetujui:
        statusString = 'published';
        break;
      case ConcertStatus.menunggu:
        statusString = 'pending';
        break;
      case ConcertStatus.ditolak:
        statusString = 'rejected';
        break;
      case ConcertStatus.draft:
      case ConcertStatus.semua:
        statusString = 'draft';
        break;
    }

    return {
      'id': id,
      if (promoterId != null) 'promoter_id': promoterId,
      if (promoterId != null) 'producer_id': promoterId,
      'title': title,
      'subtitle': dateAndVenue,
      'date': date,
      'date_time': date,
      'time': time,
      'venue': venueName,
      'venue_address': venueAddress,
      'description': description,
      'banner_url': posterFileName,
      'banner_image_url': posterFileName,
      'logo_url': squareLogoFileName,
      'logo_image_url': squareLogoFileName,
      'status': statusString,
      'total_capacity': totalCapacity,
      'price': tiers.isNotEmpty
          ? tiers.map((t) => t.price).reduce((a, b) => a < b ? a : b)
          : 0,
      'likes_count': numericLikes,
      'tickets_sold': ticketsSold,
      'is_completed': isCompleted,
      'gross_revenue': resolvedGrossRevenue,
      'ticket_tiers': tiers.map((t) => t.toJson(concertId: id)).toList(),
    };
  }
}

class PromoterVenueLocation {
  final String name;
  final String address;
  final String city;
  final double latitude;
  final double longitude;

  const PromoterVenueLocation({
    required this.name,
    required this.address,
    required this.city,
    required this.latitude,
    required this.longitude,
  });
}

class PromoterTransactionItem {
  final String id;
  final String title;
  final String date;
  final String amount;
  final bool isIncome;

  const PromoterTransactionItem({
    required this.id,
    required this.title,
    required this.date,
    required this.amount,
    required this.isIncome,
  });
}

enum WithdrawalStatus { berhasil, menunggu, ditolak }

extension WithdrawalStatusExt on WithdrawalStatus {
  String get label {
    switch (this) {
      case WithdrawalStatus.berhasil:
        return 'BERHASIL';
      case WithdrawalStatus.menunggu:
        return 'MENUNGGU';
      case WithdrawalStatus.ditolak:
        return 'DITOLAK';
    }
  }

  Color get bgColor {
    switch (this) {
      case WithdrawalStatus.berhasil:
        return const Color(0xFFE8FDF0); // Soft green
      case WithdrawalStatus.menunggu:
        return const Color(0xFFFFFBEB); // Soft yellow
      case WithdrawalStatus.ditolak:
        return const Color(0xFFFEE4E2); // Soft red
    }
  }

  Color get textColor {
    switch (this) {
      case WithdrawalStatus.berhasil:
        return const Color(0xFF039855); // Green
      case WithdrawalStatus.menunggu:
        return const Color(0xFFD97706); // Amber
      case WithdrawalStatus.ditolak:
        return const Color(0xFFD92D20); // Red
    }
  }
}

class PromoterWithdrawalRecord {
  final String id;
  final String dateTimeStr;
  final int amount;
  final String bankAccount;
  final WithdrawalStatus status;
  final String refId;
  final String? rejectionReason;

  const PromoterWithdrawalRecord({
    required this.id,
    required this.dateTimeStr,
    required this.amount,
    required this.bankAccount,
    required this.status,
    required this.refId,
    this.rejectionReason,
  });

  String get formattedAmount => 'Rp${PromoterTicketTier.formatNumber(amount)}';
}

class PromoterConcertFinanceSummary {
  final String id;
  final String concertTitle;
  final int ticketsSold;
  final int totalCapacity;
  final int grossAmount;
  final double systemFeePercent;
  final int systemFeeAmount;
  final int netAmount;

  // Breakdown details for Detail Pendapatan screen
  final int vipTicketsSold;
  final int vipGross;
  final int festivalTicketsSold;
  final int festivalGross;
  final String payoutStatus;
  final String transferDestination;
  final String transferDate;
  final String payoutTransactionId;

  const PromoterConcertFinanceSummary({
    required this.id,
    required this.concertTitle,
    required this.ticketsSold,
    required this.totalCapacity,
    required this.grossAmount,
    this.systemFeePercent = 5.0,
    required this.systemFeeAmount,
    required this.netAmount,
    this.vipTicketsSold = 800,
    this.vipGross = 400000000,
    this.festivalTicketsSold = 3400,
    this.festivalGross = 650000000,
    this.payoutStatus = 'Payout Sukses',
    this.transferDestination = 'Ditransfer ke Mandiri (***8842)',
    this.transferDate = '15 Oktober 2026',
    this.payoutTransactionId = '#TX-PY9088312',
  });

  String get formattedTicketsRatio =>
      '${PromoterTicketTier.formatNumber(ticketsSold)} / ${PromoterTicketTier.formatNumber(totalCapacity)}';
  String get formattedGross =>
      'Rp${PromoterTicketTier.formatNumber(grossAmount)}';
  String get formattedSystemFee =>
      '-Rp${PromoterTicketTier.formatNumber(systemFeeAmount)}';
  String get formattedNet => 'Rp${PromoterTicketTier.formatNumber(netAmount)}';
}
