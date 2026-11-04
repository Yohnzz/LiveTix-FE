/// Model sisi Super Admin untuk antrean approval produser dan konser.
///
/// Kolom `approval_status`, `rejection_reason`, dan `submitted_at` belum ada di
/// ERD awal. Ketiganya perlu ditambahkan ke `promoter_profiles` dan `concerts`
/// sebelum integrasi Supabase. Kolom lain mengikuti nama kolom ERD.
library;

enum ApprovalKind { producer, concert }

enum ApprovalStatus {
  pending('pending', 'Menunggu'),
  approved('approved', 'Disetujui'),
  rejected('rejected', 'Ditolak'),
  deactivated('deactivated', 'Nonaktif');

  const ApprovalStatus(this.value, this.label);

  final String value;
  final String label;

  static ApprovalStatus fromValue(String? raw) {
    for (final status in ApprovalStatus.values) {
      if (status.value == raw) return status;
    }
    return ApprovalStatus.pending;
  }
}

class ApprovalFormat {
  ApprovalFormat._();

  static const List<String> _shortMonths = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  static const List<String> monthNames = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  static String dayMonth(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')} ${_shortMonths[date.month - 1]}';

  static String dayMonthYear(DateTime date) => '${dayMonth(date)} ${date.year}';

  static String dayFullMonthYear(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')} ${monthNames[date.month - 1]} ${date.year}';

  static String time(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}.${date.minute.toString().padLeft(2, '0')} WIB';

  static String dateTimeWib(DateTime date) =>
      '${dayMonthYear(date)} · ${time(date)}';

  static String rupiah(int amount) {
    final digits = amount.toString();
    final buffer = StringBuffer('Rp');
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  static String thousands(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  static String initialsOf(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    if (parts.isNotEmpty) {
      final word = parts[0];
      return word.length >= 2
          ? word.substring(0, 2).toUpperCase()
          : word.toUpperCase();
    }
    return '?';
  }
}

/// Dokumen legalitas dan pengajuan produser (KTP, NIB, SIUP/TDUP, Akta).
class ProducerDocumentModel {
  final String id;
  final String name;
  final String type; // 'PDF' | 'JPG'
  final String fileSize; // '2.4 MB' | '1,2 MB' | '640 KB'
  final String fileUrl;

  const ProducerDocumentModel({
    required this.id,
    required this.name,
    this.type = 'PDF',
    this.fileSize = '2.4 MB',
    this.fileUrl = '',
  });

  factory ProducerDocumentModel.fromJson(Map<String, dynamic> json) {
    return ProducerDocumentModel(
      id: (json['id'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      type: (json['type'] ?? 'PDF') as String,
      fileSize: (json['file_size'] ?? '2.4 MB') as String,
      fileUrl: (json['file_url'] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'file_size': fileSize,
        'file_url': fileUrl,
      };

  static List<ProducerDocumentModel> defaultLegalDocuments() => const [
        ProducerDocumentModel(
          id: 'doc-ktp',
          name: 'KTP Penanggung Jawab',
          type: 'PDF',
          fileSize: '2.4 MB',
        ),
        ProducerDocumentModel(
          id: 'doc-siup',
          name: 'SIUP / TDUP',
          type: 'PDF',
          fileSize: '2.4 MB',
        ),
        ProducerDocumentModel(
          id: 'doc-akta',
          name: 'Akta Pendirian Perusahaan',
          type: 'PDF',
          fileSize: '2.4 MB',
        ),
      ];

  static List<ProducerDocumentModel> defaultSubmissionDocuments() => const [
        ProducerDocumentModel(
          id: 'doc-nib',
          name: 'NIB Perusahaan',
          type: 'PDF',
          fileSize: '1,2 MB',
        ),
        ProducerDocumentModel(
          id: 'doc-ktp',
          name: 'KTP Penanggung Jawab',
          type: 'JPG',
          fileSize: '640 KB',
        ),
      ];
}

/// Baris `promoter_profiles` yang digabung dengan `users.email` dan `users.phone`.
class ProducerApplicationModel {
  final String id;
  final String userId;
  final String companyName;
  final String email;
  final String phone;
  final String address;
  final String bankName;
  final String bankAccountNumber;
  final String bankAccountName;
  final bool isVerified;
  final ApprovalStatus approvalStatus;
  final String? rejectionReason;
  final DateTime submittedAt;
  final List<ProducerDocumentModel> legalDocuments;
  final List<ProducerDocumentModel> submissionDocuments;
  final int proposedConcertsCount;
  final int activeConcertsCount;
  final int ticketsSold;
  final int ticketPurchases;

  const ProducerApplicationModel({
    required this.id,
    required this.userId,
    required this.companyName,
    required this.email,
    this.phone = '',
    this.address = 'Jl. Sudirman No. 45, Jakarta',
    this.bankName = '',
    this.bankAccountNumber = '',
    this.bankAccountName = '',
    this.isVerified = false,
    this.approvalStatus = ApprovalStatus.pending,
    this.rejectionReason,
    required this.submittedAt,
    this.legalDocuments = const [],
    this.submissionDocuments = const [],
    this.proposedConcertsCount = 8,
    this.activeConcertsCount = 5,
    this.ticketsSold = 12450,
    this.ticketPurchases = 8,
  });

  String get initials => ApprovalFormat.initialsOf(companyName);

  factory ProducerApplicationModel.fromJson(Map<String, dynamic> json) {
    final rawUser = json['users'];
    final user =
        rawUser is Map<String, dynamic> ? rawUser : const <String, dynamic>{};
    final rawLegal = json['legal_documents'];
    final rawSubm = json['submission_documents'];
    return ProducerApplicationModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      companyName: json['company_name'] as String,
      email: (json['email'] ?? user['email'] ?? '') as String,
      phone: (json['phone'] ?? user['phone'] ?? '') as String,
      address: (json['address'] ?? 'Jl. Sudirman No. 45, Jakarta') as String,
      bankName: (json['bank_name'] ?? '') as String,
      bankAccountNumber: (json['bank_account_number'] ?? '') as String,
      bankAccountName: (json['bank_account_name'] ?? '') as String,
      isVerified: (json['is_verified'] ?? false) as bool,
      approvalStatus:
          ApprovalStatus.fromValue(json['approval_status'] as String?),
      rejectionReason: json['rejection_reason'] as String?,
      submittedAt: DateTime.parse(json['submitted_at'] as String),
      legalDocuments: rawLegal is List
          ? rawLegal
              .whereType<Map<String, dynamic>>()
              .map(ProducerDocumentModel.fromJson)
              .toList()
          : ProducerDocumentModel.defaultLegalDocuments(),
      submissionDocuments: rawSubm is List
          ? rawSubm
              .whereType<Map<String, dynamic>>()
              .map(ProducerDocumentModel.fromJson)
              .toList()
          : ProducerDocumentModel.defaultSubmissionDocuments(),
      proposedConcertsCount:
          (json['proposed_concerts_count'] as num?)?.toInt() ?? 8,
      activeConcertsCount:
          (json['active_concerts_count'] as num?)?.toInt() ?? 5,
      ticketsSold: (json['tickets_sold'] as num?)?.toInt() ?? 12450,
      ticketPurchases: (json['ticket_purchases'] as num?)?.toInt() ?? 8,
    );
  }

  /// Hanya kolom milik `promoter_profiles`. `email` dan `phone` milik `users`.
  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'company_name': companyName,
        'bank_name': bankName,
        'bank_account_number': bankAccountNumber,
        'bank_account_name': bankAccountName,
        'is_verified': isVerified,
        'approval_status': approvalStatus.value,
        'rejection_reason': rejectionReason,
        'submitted_at': submittedAt.toIso8601String(),
      };

  ProducerApplicationModel copyWith({
    String? address,
    bool? isVerified,
    ApprovalStatus? approvalStatus,
    String? rejectionReason,
    List<ProducerDocumentModel>? legalDocuments,
    List<ProducerDocumentModel>? submissionDocuments,
    int? proposedConcertsCount,
    int? activeConcertsCount,
    int? ticketsSold,
    int? ticketPurchases,
  }) {
    return ProducerApplicationModel(
      id: id,
      userId: userId,
      companyName: companyName,
      email: email,
      phone: phone,
      address: address ?? this.address,
      bankName: bankName,
      bankAccountNumber: bankAccountNumber,
      bankAccountName: bankAccountName,
      isVerified: isVerified ?? this.isVerified,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      submittedAt: submittedAt,
      legalDocuments: legalDocuments ?? this.legalDocuments,
      submissionDocuments: submissionDocuments ?? this.submissionDocuments,
      proposedConcertsCount:
          proposedConcertsCount ?? this.proposedConcertsCount,
      activeConcertsCount: activeConcertsCount ?? this.activeConcertsCount,
      ticketsSold: ticketsSold ?? this.ticketsSold,
      ticketPurchases: ticketPurchases ?? this.ticketPurchases,
    );
  }
}

/// Baris `ticket_tiers`.
class SubmissionTierModel {
  final String id;
  final String concertId;
  final String name;
  final String description;
  final int price;
  final int totalQuota;
  final int remainingQuota;

  const SubmissionTierModel({
    required this.id,
    required this.concertId,
    required this.name,
    this.description = '',
    required this.price,
    required this.totalQuota,
    int? remainingQuota,
  }) : remainingQuota = remainingQuota ?? totalQuota;

  factory SubmissionTierModel.fromJson(Map<String, dynamic> json) {
    final total = (json['total_quota'] as num).toInt();
    return SubmissionTierModel(
      id: json['id'] as String,
      concertId: json['concert_id'] as String,
      name: json['name'] as String,
      description: (json['description'] ?? '') as String,
      price: (json['price'] as num).toInt(),
      totalQuota: total,
      remainingQuota: (json['remaining_quota'] as num?)?.toInt() ?? total,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'concert_id': concertId,
        'name': name,
        'description': description,
        'price': price,
        'total_quota': totalQuota,
        'remaining_quota': remainingQuota,
      };
}

/// Baris `concerts` yang digabung dengan `promoter_profiles.company_name` dan `ticket_tiers`.
class ConcertSubmissionModel {
  final String id;
  final String promoterId;
  final String promoterName;
  final String title;
  final String subtitle;
  final String genre;
  final DateTime dateTime;
  final String venue;
  final int totalCapacity;

  /// Nilai kolom ERD `concerts.status`: draft, published, completed, cancelled.
  final String status;
  final String? bannerUrl;
  final ApprovalStatus approvalStatus;
  final String? rejectionReason;
  final DateTime submittedAt;
  final List<SubmissionTierModel> tiers;
  final String? requestType;
  final String? requestInfo;
  final String? cancellationReason;
  final String? cancellationDate;
  final String? attachmentName;
  final int soldTickets;
  final int affectedBuyers;
  final int refundAmount;
  final int escrowWithheldAmount;
  final String? cancellationReviewReason;

  const ConcertSubmissionModel({
    required this.id,
    required this.promoterId,
    required this.promoterName,
    required this.title,
    this.subtitle = '',
    this.genre = 'Jazz',
    required this.dateTime,
    required this.venue,
    this.totalCapacity = 5000,
    this.status = 'draft',
    this.bannerUrl,
    this.approvalStatus = ApprovalStatus.pending,
    this.rejectionReason,
    required this.submittedAt,
    this.tiers = const [],
    this.requestType,
    this.requestInfo,
    this.cancellationReason,
    this.cancellationDate,
    this.attachmentName,
    this.soldTickets = 4200,
    this.affectedBuyers = 1860,
    this.refundAmount = 2115000000,
    this.escrowWithheldAmount = 2115000000,
    this.cancellationReviewReason,
  });

  factory ConcertSubmissionModel.fromJson(Map<String, dynamic> json) {
    final rawPromoter = json['promoter_profiles'];
    final promoter = rawPromoter is Map<String, dynamic>
        ? rawPromoter
        : const <String, dynamic>{};
    final rawTiers = json['ticket_tiers'];
    final tiersList = rawTiers is List
        ? rawTiers
            .whereType<Map<String, dynamic>>()
            .map(SubmissionTierModel.fromJson)
            .toList()
        : const <SubmissionTierModel>[];
    final defaultCapacity = tiersList.isNotEmpty
        ? tiersList.fold<int>(0, (sum, t) => sum + t.totalQuota)
        : 5000;

    return ConcertSubmissionModel(
      id: json['id'] as String,
      promoterId: json['promoter_id'] as String,
      promoterName:
          (json['promoter_name'] ?? promoter['company_name'] ?? '') as String,
      title: json['title'] as String,
      subtitle: (json['subtitle'] ?? '') as String,
      genre: (json['genre'] ?? 'Jazz') as String,
      dateTime: DateTime.parse(json['date_time'] as String),
      venue: json['venue'] as String,
      totalCapacity: (json['total_capacity'] ??
              json['capacity'] ??
              defaultCapacity) as int? ??
          5000,
      status: (json['status'] ?? 'draft') as String,
      bannerUrl: json['banner_url'] as String?,
      approvalStatus:
          ApprovalStatus.fromValue(json['approval_status'] as String?),
      rejectionReason: json['rejection_reason'] as String?,
      submittedAt: DateTime.parse(json['submitted_at'] as String),
      tiers: tiersList,
      requestType: json['request_type'] as String?,
      requestInfo: json['request_info'] as String?,
      cancellationReason: json['cancellation_reason'] as String?,
      cancellationDate: json['cancellation_date'] as String?,
      attachmentName: json['attachment_name'] as String?,
      soldTickets: (json['sold_tickets'] as int?) ?? 4200,
      affectedBuyers: (json['affected_buyers'] as int?) ?? 1860,
      refundAmount: (json['refund_amount'] as int?) ?? 2115000000,
      escrowWithheldAmount: (json['escrow_withheld_amount'] as int?) ?? 2115000000,
      cancellationReviewReason: json['cancellation_review_reason'] as String?,
    );
  }

  /// Hanya kolom milik `concerts`. `ticket_tiers` ditulis lewat tabelnya sendiri.
  Map<String, dynamic> toJson() => {
        'id': id,
        'promoter_id': promoterId,
        'title': title,
        'subtitle': subtitle,
        'date_time': dateTime.toIso8601String(),
        'venue': venue,
        'status': status,
        'banner_url': bannerUrl,
        'approval_status': approvalStatus.value,
        'rejection_reason': rejectionReason,
        'submitted_at': submittedAt.toIso8601String(),
        if (requestType != null) 'request_type': requestType,
        if (requestInfo != null) 'request_info': requestInfo,
        if (cancellationReason != null) 'cancellation_reason': cancellationReason,
        if (cancellationDate != null) 'cancellation_date': cancellationDate,
        if (attachmentName != null) 'attachment_name': attachmentName,
        'sold_tickets': soldTickets,
        'affected_buyers': affectedBuyers,
        'refund_amount': refundAmount,
        'escrow_withheld_amount': escrowWithheldAmount,
        if (cancellationReviewReason != null)
          'cancellation_review_reason': cancellationReviewReason,
      };

  ConcertSubmissionModel copyWith({
    String? status,
    ApprovalStatus? approvalStatus,
    String? rejectionReason,
    String? requestType,
    String? requestInfo,
    String? cancellationReason,
    String? cancellationDate,
    String? attachmentName,
    int? soldTickets,
    int? affectedBuyers,
    int? refundAmount,
    int? escrowWithheldAmount,
    String? cancellationReviewReason,
  }) {
    return ConcertSubmissionModel(
      id: id,
      promoterId: promoterId,
      promoterName: promoterName,
      title: title,
      subtitle: subtitle,
      genre: genre,
      dateTime: dateTime,
      venue: venue,
      totalCapacity: totalCapacity,
      status: status ?? this.status,
      bannerUrl: bannerUrl,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      submittedAt: submittedAt,
      tiers: tiers,
      requestType: requestType ?? this.requestType,
      requestInfo: requestInfo ?? this.requestInfo,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      cancellationDate: cancellationDate ?? this.cancellationDate,
      attachmentName: attachmentName ?? this.attachmentName,
      soldTickets: soldTickets ?? this.soldTickets,
      affectedBuyers: affectedBuyers ?? this.affectedBuyers,
      refundAmount: refundAmount ?? this.refundAmount,
      escrowWithheldAmount: escrowWithheldAmount ?? this.escrowWithheldAmount,
      cancellationReviewReason:
          cancellationReviewReason ?? this.cancellationReviewReason,
    );
  }
}

/// Angka agregat dashboard. Di Supabase berasal dari satu RPC atau view.
class AdminOverviewStats {
  final int totalUsers;
  final int activeProducers;
  final int activeConcerts;

  const AdminOverviewStats({
    required this.totalUsers,
    required this.activeProducers,
    required this.activeConcerts,
  });

  factory AdminOverviewStats.fromJson(Map<String, dynamic> json) {
    return AdminOverviewStats(
      totalUsers: (json['total_users'] as num).toInt(),
      activeProducers: (json['active_producers'] as num).toInt(),
      activeConcerts: (json['active_concerts'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'total_users': totalUsers,
        'active_producers': activeProducers,
        'active_concerts': activeConcerts,
      };

  AdminOverviewStats copyWith({int? activeProducers, int? activeConcerts}) {
    return AdminOverviewStats(
      totalUsers: totalUsers,
      activeProducers: activeProducers ?? this.activeProducers,
      activeConcerts: activeConcerts ?? this.activeConcerts,
    );
  }
}

/// Satu baris antrean "Approval Terbaru" di dashboard.
class ApprovalQueueItem {
  final ApprovalKind kind;
  final String id;
  final String title;
  final DateTime submittedAt;

  const ApprovalQueueItem({
    required this.kind,
    required this.id,
    required this.title,
    required this.submittedAt,
  });

  String get subtitle => kind == ApprovalKind.producer
      ? 'Pengajuan: Produser Baru · ${ApprovalFormat.dayMonth(submittedAt)}'
      : 'Pengajuan: Konser Baru · ${ApprovalFormat.dayMonth(submittedAt)}';
}

/// Transaksi pengguna untuk tab Kelola User (Image 5).
class UserTransactionModel {
  final String title;
  final String invoice;
  final int amount;
  final String status;

  const UserTransactionModel({
    required this.title,
    required this.invoice,
    required this.amount,
    required this.status,
  });

  factory UserTransactionModel.fromJson(Map<String, dynamic> json) {
    return UserTransactionModel(
      title: (json['title'] ?? '') as String,
      invoice: (json['invoice'] ?? '') as String,
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      status: (json['status'] ?? 'Berhasil') as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'invoice': invoice,
        'amount': amount,
        'status': status,
      };
}

/// Model pengguna untuk fitur Kelola Pengguna (Image 4 & 5).
class ManagedUserModel {
  final String id;
  final String name;
  final String email;
  final String role; // 'User', 'Produser', 'Admin'
  final String phone;
  final String joinedAt;
  final bool isActive;
  final int ticketsBought;
  final int concertsAttended;
  final bool hasFavorite;
  final List<UserTransactionModel> transactions;

  const ManagedUserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone = '',
    this.joinedAt = '',
    this.isActive = true,
    this.ticketsBought = 0,
    this.concertsAttended = 0,
    this.hasFavorite = false,
    this.transactions = const [],
  });

  String get initials => ApprovalFormat.initialsOf(name);

  factory ManagedUserModel.fromJson(Map<String, dynamic> json) {
    final rawTx = json['transactions'];
    return ManagedUserModel(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      role: (json['role'] ?? 'User') as String,
      phone: (json['phone'] ?? '') as String,
      joinedAt: (json['joined_at'] ?? '') as String,
      isActive: (json['is_active'] ?? true) as bool,
      ticketsBought: (json['tickets_bought'] as num?)?.toInt() ?? 0,
      concertsAttended: (json['concerts_attended'] as num?)?.toInt() ?? 0,
      hasFavorite: (json['has_favorite'] ?? false) as bool,
      transactions: rawTx is List
          ? rawTx
              .whereType<Map<String, dynamic>>()
              .map(UserTransactionModel.fromJson)
              .toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
        'phone': phone,
        'joined_at': joinedAt,
        'is_active': isActive,
        'tickets_bought': ticketsBought,
        'concerts_attended': concertsAttended,
        'has_favorite': hasFavorite,
        'transactions': transactions.map((t) => t.toJson()).toList(),
      };

  ManagedUserModel copyWith({
    String? name,
    String? email,
    String? role,
    String? phone,
    String? joinedAt,
    bool? isActive,
    int? ticketsBought,
    int? concertsAttended,
    bool? hasFavorite,
    List<UserTransactionModel>? transactions,
  }) {
    return ManagedUserModel(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      joinedAt: joinedAt ?? this.joinedAt,
      isActive: isActive ?? this.isActive,
      ticketsBought: ticketsBought ?? this.ticketsBought,
      concertsAttended: concertsAttended ?? this.concertsAttended,
      hasFavorite: hasFavorite ?? this.hasFavorite,
      transactions: transactions ?? this.transactions,
    );
  }
}

/// Model notifikasi Super Admin (Image 3): log aktivitas pendaftaran, approval, dan sistem.
class AdminNotificationModel {
  final String id;
  final String title;
  final String body;
  final String timeAgo;
  final String category; // 'approval' atau 'system'
  final bool isUnread;
  final String? targetId;
  final ApprovalKind? targetKind;

  const AdminNotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.timeAgo,
    required this.category,
    this.isUnread = false,
    this.targetId,
    this.targetKind,
  });

  factory AdminNotificationModel.fromJson(Map<String, dynamic> json) {
    ApprovalKind? kind;
    if (json['target_kind'] == 'producer') {
      kind = ApprovalKind.producer;
    } else if (json['target_kind'] == 'concert') {
      kind = ApprovalKind.concert;
    }

    return AdminNotificationModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      timeAgo: json['time_ago'] as String? ?? '',
      category: json['category'] as String? ?? 'approval',
      isUnread: json['is_unread'] as bool? ?? false,
      targetId: json['target_id'] as String?,
      targetKind: kind,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'time_ago': timeAgo,
        'category': category,
        'is_unread': isUnread,
        if (targetId != null) 'target_id': targetId,
        if (targetKind != null) 'target_kind': targetKind?.name,
      };

  AdminNotificationModel copyWith({
    String? title,
    String? body,
    String? timeAgo,
    String? category,
    bool? isUnread,
    String? targetId,
    ApprovalKind? targetKind,
  }) {
    return AdminNotificationModel(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
      timeAgo: timeAgo ?? this.timeAgo,
      category: category ?? this.category,
      isUnread: isUnread ?? this.isUnread,
      targetId: targetId ?? this.targetId,
      targetKind: targetKind ?? this.targetKind,
    );
  }
}

class RefundBuyerModel {
  final String name;
  final int tickets;
  final String paymentInfo;
  final String status;

  const RefundBuyerModel({
    required this.name,
    required this.tickets,
    required this.paymentInfo,
    required this.status,
  });

  factory RefundBuyerModel.fromJson(Map<String, dynamic> json) {
    return RefundBuyerModel(
      name: json['name'] as String? ?? '',
      tickets: json['tickets'] as int? ?? 0,
      paymentInfo: json['payment_info'] as String? ?? '',
      status: json['status'] as String? ?? 'Perlu data',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'tickets': tickets,
        'payment_info': paymentInfo,
        'status': status,
      };
}

class RefundMonitoringModel {
  final String concertId;
  final String title;
  final String status;
  final int refundedTickets;
  final int totalTickets;
  final int percent;
  final int refundedAmount;
  final int totalAmount;
  final int processingTickets;
  final int needDataTickets;
  final String deadlineDate;
  final int remainingDays;
  final List<RefundBuyerModel> buyers;

  const RefundMonitoringModel({
    required this.concertId,
    required this.title,
    required this.status,
    required this.refundedTickets,
    required this.totalTickets,
    required this.percent,
    required this.refundedAmount,
    required this.totalAmount,
    required this.processingTickets,
    required this.needDataTickets,
    required this.deadlineDate,
    required this.remainingDays,
    this.buyers = const [],
  });

  factory RefundMonitoringModel.fromJson(Map<String, dynamic> json) {
    final rawBuyers = json['buyers'] as List<dynamic>? ?? [];
    return RefundMonitoringModel(
      concertId: json['concert_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      status: json['status'] as String? ?? 'Berjalan',
      refundedTickets: json['refunded_tickets'] as int? ?? 0,
      totalTickets: json['total_tickets'] as int? ?? 0,
      percent: json['percent'] as int? ?? 0,
      refundedAmount: json['refunded_amount'] as int? ?? 0,
      totalAmount: json['total_amount'] as int? ?? 0,
      processingTickets: json['processing_tickets'] as int? ?? 0,
      needDataTickets: json['need_data_tickets'] as int? ?? 0,
      deadlineDate: json['deadline_date'] as String? ?? '',
      remainingDays: json['remaining_days'] as int? ?? 0,
      buyers: rawBuyers
          .map((b) => RefundBuyerModel.fromJson(b as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'concert_id': concertId,
        'title': title,
        'status': status,
        'refunded_tickets': refundedTickets,
        'total_tickets': totalTickets,
        'percent': percent,
        'refunded_amount': refundedAmount,
        'total_amount': totalAmount,
        'processing_tickets': processingTickets,
        'need_data_tickets': needDataTickets,
        'deadline_date': deadlineDate,
        'remaining_days': remainingDays,
        'buyers': buyers.map((b) => b.toJson()).toList(),
      };
}

class RefundOverviewModel {
  final String totalRefundedLabel;
  final int totalRefundedAmount;
  final int actionNeededCount;

  const RefundOverviewModel({
    required this.totalRefundedLabel,
    required this.totalRefundedAmount,
    required this.actionNeededCount,
  });

  factory RefundOverviewModel.fromJson(Map<String, dynamic> json) {
    return RefundOverviewModel(
      totalRefundedLabel: json['total_refunded_label'] as String? ?? 'Rp0',
      totalRefundedAmount: json['total_refunded_amount'] as int? ?? 0,
      actionNeededCount: json['action_needed_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'total_refunded_label': totalRefundedLabel,
        'total_refunded_amount': totalRefundedAmount,
        'action_needed_count': actionNeededCount,
      };
}
