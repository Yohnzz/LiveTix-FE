import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../data/admin_dummy.dart';
import '../models/approval_models.dart';
import '../models/promoter_models.dart';
import '../utils/local_storage.dart';
import 'data_service.dart';
import 'gate_crew_service.dart';
import 'payment_gateway_service.dart';
import 'promoter_data_service.dart';
import 'supabase_service.dart';

enum AdminLoadState { loading, ready, error }

/// Akses data Super Admin yang terhubung langsung ke Supabase.
/// Saat `SupabaseService.isInitialized == true`, seluruh data (Produser, Konser,
/// Pengguna, Gate Crew, Statistik, Notifikasi, dan Refund) diambil dari database
/// tanpa data dummy.
class AdminService {
  static final AdminService _instance = AdminService._internal();
  factory AdminService() => _instance;
  AdminService._internal();

  final ValueNotifier<AdminLoadState> loadState =
      ValueNotifier<AdminLoadState>(AdminLoadState.loading);
  final ValueNotifier<List<ProducerApplicationModel>> producersNotifier =
      ValueNotifier<List<ProducerApplicationModel>>(const []);
  final ValueNotifier<List<ConcertSubmissionModel>> concertsNotifier =
      ValueNotifier<List<ConcertSubmissionModel>>(const []);
  final ValueNotifier<List<ManagedUserModel>> usersNotifier =
      ValueNotifier<List<ManagedUserModel>>(const []);
  final ValueNotifier<List<AdminNotificationModel>> notificationsNotifier =
      ValueNotifier<List<AdminNotificationModel>>(const []);
  final ValueNotifier<RefundOverviewModel> refundOverviewNotifier =
      ValueNotifier<RefundOverviewModel>(
    const RefundOverviewModel(
      totalRefundedLabel: 'Rp0',
      totalRefundedAmount: 0,
      actionNeededCount: 0,
    ),
  );
  final ValueNotifier<List<RefundMonitoringModel>> refundMonitoringNotifier =
      ValueNotifier<List<RefundMonitoringModel>>(const []);
  final ValueNotifier<AdminOverviewStats> statsNotifier =
      ValueNotifier<AdminOverviewStats>(
    const AdminOverviewStats(
        totalUsers: 0, activeProducers: 0, activeConcerts: 0),
  );

  /// Jeda simulasi jaringan. Diset nol pada pengujian.
  Duration latency = const Duration(milliseconds: 350);

  /// Memaksa `load` gagal untuk memeriksa tampilan error.
  bool simulateFailure = false;

  bool _hasData = false;

  Future<void> load({bool force = false}) async {
    if (!force && loadState.value == AdminLoadState.ready) return;
    loadState.value = AdminLoadState.loading;
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    if (simulateFailure) {
      loadState.value = AdminLoadState.error;
      return;
    }

    if (!SupabaseService.isInitialized) {
      if (!_hasData) _seed();
      loadState.value = AdminLoadState.ready;
      return;
    }

    // Ketika terhubung ke Supabase: pastikan tidak ada data dummy yang dimuat.
    if (!_hasData) {
      producersNotifier.value = const [];
      concertsNotifier.value = const [];
      usersNotifier.value = const [];
      notificationsNotifier.value = const [];
      refundMonitoringNotifier.value = const [];
      refundOverviewNotifier.value = const RefundOverviewModel(
        totalRefundedLabel: 'Rp0',
        totalRefundedAmount: 0,
        actionNeededCount: 0,
      );
      statsNotifier.value = const AdminOverviewStats(
        totalUsers: 0,
        activeProducers: 0,
        activeConcerts: 0,
      );
      _hasData = true;
    }

    try {
      // 1. Sinkronkan Gate Crew dari database
      await GateCrewService().loadTeam();

      // 2. Ambil seluruh data profiles dari database
      List<dynamic> profilesRaw = const [];
      try {
        profilesRaw = await SupabaseService.client
            .from('profiles')
            .select('*')
            .order('created_at', ascending: false);
      } catch (e) {
        debugPrint('AdminService fetch profiles error: $e');
      }

      final Map<String, Map<String, dynamic>> profileById = {};
      final List<ManagedUserModel> dbUsers = [];
      for (final raw in profilesRaw) {
        if (raw is! Map<String, dynamic>) continue;
        final id = (raw['id'] ?? '').toString();
        if (id.isEmpty) continue;
        profileById[id] = raw;

        final rawRole = (raw['role'] ?? 'User').toString();
        final normalizedRole = _normalizeRoleLabel(rawRole);
        final email = (raw['email'] ?? '').toString();
        final name =
            (raw['name'] ?? raw['full_name'] ?? email.split('@').first)
                .toString();
        final approvalSt =
            (raw['approval_status'] ?? raw['verification_status'] ?? 'approved')
                .toString()
                .toLowerCase();
        final isActive =
            approvalSt != 'deactivated' && approvalSt != 'rejected';
        final createdAt =
            DateTime.tryParse((raw['created_at'] ?? '').toString()) ??
                DateTime.now();

        dbUsers.add(ManagedUserModel(
          id: id,
          name: name,
          email: email,
          role: normalizedRole,
          isActive: isActive,
          joinedAt: ApprovalFormat.dayMonthYear(createdAt),
          phone: (raw['phone'] ?? '-').toString(),
          password: '••••••••',
        ));
      }
      usersNotifier.value = dbUsers;

      // 3. Ambil seluruh data promoter_profiles dari database
      List<dynamic> promoterProfilesRaw = const [];
      try {
        promoterProfilesRaw = await SupabaseService.client
            .from('promoter_profiles')
            .select('*')
            .order('created_at', ascending: false);
      } catch (e) {
        debugPrint('AdminService fetch promoter_profiles error: $e');
      }

      final Map<String, Map<String, dynamic>> promoterRowById = {};
      for (final raw in promoterProfilesRaw) {
        if (raw is! Map<String, dynamic>) continue;
        final id = (raw['id'] ?? '').toString();
        if (id.isNotEmpty) {
          promoterRowById[id] = raw;
        }
      }

      // 4. Ambil seluruh data concerts beserta ticket_tiers dari database
      List<dynamic> concertsRaw = const [];
      try {
        concertsRaw = await SupabaseService.client
            .from('concerts')
            .select('*, ticket_tiers(*)')
            .order('created_at', ascending: false);
      } catch (e) {
        debugPrint('AdminService fetch concerts error: $e');
      }

      final List<ConcertSubmissionModel> dbConcerts = [];
      for (final row in concertsRaw) {
        if (row is! Map<String, dynamic>) continue;
        try {
          dbConcerts.add(_mapConcertRow(row, promoterRowById, profileById));
        } catch (e) {
          debugPrint('Error parse supa concert for admin: $e');
        }
      }
      concertsNotifier.value = dbConcerts;

      // 5. Bangun daftar ProducerApplicationModel dari promoter_profiles + profiles ber-role Produser
      final Set<String> allProducerIds = {
        ...promoterRowById.keys,
        for (final entry in profileById.entries)
          if (_normalizeRoleLabel((entry.value['role'] ?? '').toString()) ==
              'Produser')
            entry.key,
      };

      final List<ProducerApplicationModel> dbProducers = [];
      for (final prodId in allProducerIds) {
        final promRow = promoterRowById[prodId];
        final profRow = profileById[prodId];
        dbProducers.add(
          _mapProducerRow(
            prodId,
            promRow: promRow,
            profRow: profRow,
            allConcerts: dbConcerts,
          ),
        );
      }
      dbProducers.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
      producersNotifier.value = dbProducers;

      // 6. Hitung Refund Monitoring & Overview dari konser yang dibatalkan di database
      _recomputeRefundsFromConcerts(dbConcerts);

      // 7. Hitung Statistik Dashboard secara dinamis dari database
      _recomputeStats();

      // 8. Bangun Notifikasi Admin secara dinamis dari database
      _rebuildNotificationsFromDatabase();
    } catch (err) {
      debugPrint('AdminService fetch Supabase error: $err');
    }

    loadState.value = AdminLoadState.ready;
  }

  String _normalizeRoleLabel(String rawRole) {
    final lower = rawRole.trim().toLowerCase();
    if (lower == 'admin') return 'Admin';
    if (lower == 'produser' || lower == 'producer' || lower == 'promoter') {
      return 'Produser';
    }
    if (lower == 'gatecrew' || lower == 'gate_crew' || lower == 'crew') {
      return 'Gatecrew';
    }
    return 'User';
  }

  ConcertSubmissionModel _mapConcertRow(
    Map<String, dynamic> row,
    Map<String, Map<String, dynamic>> promoterRowById,
    Map<String, Map<String, dynamic>> profileById,
  ) {
    final rawTiers = row['ticket_tiers'] as List<dynamic>?;
    final tiersList = rawTiers is List
        ? rawTiers
            .whereType<Map<String, dynamic>>()
            .map(SubmissionTierModel.fromJson)
            .toList()
        : const <SubmissionTierModel>[];

    final st = (row['status'] as String? ?? 'pending').toLowerCase();
    final appSt = (row['approval_status'] as String? ?? '').toLowerCase();
    final cancelSt =
        (row['cancellation_status'] as String? ?? 'none').toLowerCase();

    Map<String, dynamic>? pendingEditPayload;
    final rawPayload = row['pending_edit_payload'];
    if (rawPayload is Map<String, dynamic>) {
      pendingEditPayload = Map<String, dynamic>.from(rawPayload);
    } else if (rawPayload is String && rawPayload.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawPayload);
        if (decoded is Map<String, dynamic>) {
          pendingEditPayload = decoded;
        }
      } catch (_) {}
    }

    ApprovalStatus approvalStatus = ApprovalStatus.pending;
    String requestType = 'create';

    if (cancelSt == 'pending' || appSt == 'pending_cancel') {
      requestType = 'cancellation';
      approvalStatus = ApprovalStatus.pending;
    } else if (cancelSt == 'approved' || st == 'cancelled') {
      requestType = 'cancellation';
      approvalStatus = ApprovalStatus.approved;
    } else if (cancelSt == 'rejected') {
      requestType = 'cancellation';
      approvalStatus = ApprovalStatus.rejected;
    } else if (appSt == 'pending_edit' || pendingEditPayload != null) {
      requestType = 'edit';
      approvalStatus = ApprovalStatus.pending;
    } else if (appSt == 'pending' ||
        appSt == 'pending_create' ||
        st == 'pending') {
      requestType = 'create';
      approvalStatus = ApprovalStatus.pending;
    } else if (appSt == 'rejected' || st == 'rejected' || st == 'ditolak') {
      approvalStatus = ApprovalStatus.rejected;
    } else if (appSt == 'approved' ||
        st == 'published' ||
        st == 'disetujui' ||
        st == 'approved' ||
        st == 'completed') {
      approvalStatus = ApprovalStatus.approved;
    }

    final producerId = (row['producer_id'] ?? '').toString();
    String promoterName = (row['producer_name'] ?? '').toString().trim();
    if (promoterName.isEmpty && producerId.isNotEmpty) {
      final promRow = promoterRowById[producerId];
      final profRow = profileById[producerId];
      promoterName = (promRow?['company_name'] ??
              promRow?['responsible_name'] ??
              profRow?['name'] ??
              profRow?['full_name'] ??
              'Produser LiveTix')
          .toString();
    }
    if (promoterName.isEmpty) {
      promoterName = 'Produser LiveTix';
    }

    final parsedDate = _parseIndonesianOrIsoDate(
      (row['date'] ?? '').toString(),
      (row['time'] ?? '').toString(),
      fallbackIso: (row['created_at'] ?? '').toString(),
    );

    final int ticketsSold = (row['tickets_sold'] as num?)?.toInt() ??
        tiersList.fold<int>(
          0,
          (sum, t) =>
              sum +
              ((t.totalQuota - t.remainingQuota) > 0
                  ? (t.totalQuota - t.remainingQuota)
                  : 0),
        );

    int grossRevenue = (row['gross_revenue'] as num?)?.toInt() ?? 0;
    if (grossRevenue == 0 && tiersList.isNotEmpty) {
      grossRevenue = tiersList.fold<int>(
        0,
        (sum, t) =>
            sum +
            (((t.totalQuota - t.remainingQuota) > 0
                    ? (t.totalQuota - t.remainingQuota)
                    : 0) *
                t.price),
      );
    }

    return ConcertSubmissionModel(
      id: (row['id'] ?? '').toString(),
      promoterId: producerId,
      promoterName: promoterName,
      title: (row['title'] ?? '').toString(),
      subtitle: (row['subtitle'] ?? row['description'] ?? '').toString(),
      genre: (row['category'] ?? 'Musik').toString(),
      dateTime: parsedDate,
      venue: (row['venue'] ?? '').toString(),
      totalCapacity: (row['total_capacity'] as num?)?.toInt() ??
          tiersList.fold<int>(0, (sum, t) => sum + t.totalQuota),
      status: (row['status'] ?? 'pending').toString(),
      bannerUrl: row['banner_image_url'] as String?,
      approvalStatus: approvalStatus,
      rejectionReason: row['rejection_reason'] as String?,
      submittedAt: DateTime.tryParse((row['created_at'] ?? '').toString()) ??
          DateTime.now(),
      tiers: tiersList,
      requestType: requestType,
      cancellationReason: row['cancellation_reason'] as String?,
      cancellationDate: row['cancellation_date'] as String?,
      attachmentName: row['cancellation_attachment'] as String?,
      soldTickets: ticketsSold,
      affectedBuyers: ticketsSold > 0 ? ticketsSold : 0,
      refundAmount: grossRevenue,
      escrowWithheldAmount: grossRevenue,
      pendingEditPayload: pendingEditPayload,
    );
  }

  DateTime _parseIndonesianOrIsoDate(
    String rawDate,
    String rawTime, {
    String? fallbackIso,
  }) {
    final direct = DateTime.tryParse(rawDate);
    if (direct != null) return direct;

    final months = <String, int>{
      'januari': 1,
      'jan': 1,
      'februari': 2,
      'feb': 2,
      'maret': 3,
      'mar': 3,
      'april': 4,
      'apr': 4,
      'mei': 5,
      'juni': 6,
      'jun': 6,
      'juli': 7,
      'jul': 7,
      'agustus': 8,
      'agu': 8,
      'agt': 8,
      'september': 9,
      'sep': 9,
      'oktober': 10,
      'okt': 10,
      'november': 11,
      'nov': 11,
      'desember': 12,
      'des': 12,
    };

    final match =
        RegExp(r'(\d{1,2})\s+([A-Za-z]+)\s+(\d{4})').firstMatch(rawDate);
    if (match != null) {
      final day = int.tryParse(match.group(1)!) ?? 1;
      final monthName = match.group(2)!.toLowerCase();
      final year = int.tryParse(match.group(3)!) ?? DateTime.now().year;
      final month = months[monthName] ?? 1;
      int hour = 19;
      int minute = 0;
      final timeMatch = RegExp(r'(\d{1,2})[:.](\d{2})').firstMatch(rawTime);
      if (timeMatch != null) {
        hour = int.tryParse(timeMatch.group(1)!) ?? 19;
        minute = int.tryParse(timeMatch.group(2)!) ?? 0;
      }
      return DateTime(year, month, day, hour, minute);
    }

    if (fallbackIso != null) {
      final fb = DateTime.tryParse(fallbackIso);
      if (fb != null) return fb;
    }
    return DateTime.now();
  }

  ProducerApplicationModel _mapProducerRow(
    String producerId, {
    required Map<String, dynamic>? promRow,
    required Map<String, dynamic>? profRow,
    required List<ConcertSubmissionModel> allConcerts,
  }) {
    final email = (promRow?['email'] ?? profRow?['email'] ?? '').toString();
    final companyName = (promRow?['company_name'] ??
            profRow?['name'] ??
            profRow?['full_name'] ??
            email.split('@').first)
        .toString();
    final phone = (promRow?['phone'] ?? profRow?['phone'] ?? '-').toString();
    final location = (promRow?['location'] ?? 'Indonesia').toString();

    final ktpUrl =
        (promRow?['ktp_image_url'] ?? profRow?['ktp_url'] ?? '').toString();
    final letterUrl = (promRow?['responsibility_letter_url'] ??
            profRow?['responsibility_letter_url'] ??
            '')
        .toString();

    final pendingName =
        (promRow?['pending_name'] ?? profRow?['pending_name'])?.toString();
    final pendingKtpUrl =
        (promRow?['pending_ktp_url'] ?? profRow?['pending_ktp_url'])
            ?.toString();
    final pendingLetterUrl = (promRow?['pending_responsibility_letter_url'] ??
            profRow?['pending_responsibility_letter_url'])
        ?.toString();
    final profileChangeStatus = (promRow?['profile_change_status'] ??
            profRow?['profile_change_status'] ??
            'none')
        .toString()
        .toLowerCase();

    final hasPendingProfileEdit = profileChangeStatus == 'pending' ||
        (pendingName != null && pendingName.trim().isNotEmpty) ||
        (pendingKtpUrl != null && pendingKtpUrl.trim().isNotEmpty) ||
        (pendingLetterUrl != null && pendingLetterUrl.trim().isNotEmpty);

    final rawApproval = (promRow?['approval_status'] ??
            profRow?['approval_status'] ??
            profRow?['verification_status'] ??
            'pending')
        .toString()
        .toLowerCase();

    final isVerified = (promRow?['is_verified'] as bool?) ??
        (profRow?['is_verified'] as bool?) ??
        (rawApproval == 'approved');

    ApprovalStatus approvalStatus;
    if (rawApproval == 'deactivated') {
      approvalStatus = ApprovalStatus.deactivated;
    } else if (hasPendingProfileEdit) {
      approvalStatus = ApprovalStatus.pending;
    } else if (rawApproval == 'rejected') {
      approvalStatus = ApprovalStatus.rejected;
    } else if (rawApproval == 'approved' || isVerified) {
      approvalStatus = ApprovalStatus.approved;
    } else {
      approvalStatus = ApprovalStatus.pending;
    }

    final producerConcerts = allConcerts
        .where((c) =>
            c.promoterId == producerId ||
            c.promoterName.toLowerCase() == companyName.toLowerCase())
        .toList();

    final activeConcertsList = producerConcerts
        .where((c) =>
            c.approvalStatus == ApprovalStatus.approved &&
            c.status.toLowerCase() != 'cancelled')
        .toList();

    final totalTicketsSold =
        producerConcerts.fold<int>(0, (sum, c) => sum + c.soldTickets);

    final List<ProducerDocumentModel> submissionDocs = [];
    final List<ProducerDocumentModel> legalDocs = [];

    final effectiveKtp =
        (pendingKtpUrl != null && pendingKtpUrl.trim().isNotEmpty)
            ? pendingKtpUrl
            : ktpUrl;
    final effectiveLetter =
        (pendingLetterUrl != null && pendingLetterUrl.trim().isNotEmpty)
            ? pendingLetterUrl
            : letterUrl;

    if (effectiveKtp.isNotEmpty) {
      final ktpDoc = ProducerDocumentModel(
        id: 'doc-ktp-$producerId',
        name: pendingKtpUrl != null && pendingKtpUrl.trim().isNotEmpty
            ? 'KTP Penanggung Jawab (Pembaruan: ${effectiveKtp.split('/').last})'
            : 'KTP Penanggung Jawab (${effectiveKtp.split('/').last})',
        type: 'JPG',
        fileSize: '640 KB',
        fileUrl: effectiveKtp,
      );
      submissionDocs.add(ktpDoc);
      legalDocs.add(ktpDoc);
    }

    if (effectiveLetter.isNotEmpty) {
      final letterDoc = ProducerDocumentModel(
        id: 'doc-letter-$producerId',
        name: pendingLetterUrl != null && pendingLetterUrl.trim().isNotEmpty
            ? 'Lembar Penanggung Jawab (Pembaruan: ${effectiveLetter.split('/').last})'
            : 'Lembar Penanggung Jawab (${effectiveLetter.split('/').last})',
        type: 'DOC',
        fileSize: '1,2 MB',
        fileUrl: effectiveLetter,
      );
      submissionDocs.add(letterDoc);
      legalDocs.add(letterDoc);
    }

    if (legalDocs.isEmpty) {
      legalDocs.addAll(ProducerDocumentModel.defaultLegalDocuments());
    }
    if (submissionDocs.isEmpty) {
      submissionDocs.addAll(ProducerDocumentModel.defaultSubmissionDocuments());
    }

    final createdAtStr =
        (promRow?['created_at'] ?? profRow?['created_at'] ?? '').toString();
    final submittedAt = DateTime.tryParse(createdAtStr) ?? DateTime.now();

    return ProducerApplicationModel(
      id: producerId,
      userId: producerId,
      companyName: companyName,
      email: email,
      phone: phone,
      address: location,
      isVerified: isVerified,
      approvalStatus: approvalStatus,
      rejectionReason: (promRow?['rejection_reason'] ??
          profRow?['rejection_reason']) as String?,
      submittedAt: submittedAt,
      legalDocuments: legalDocs,
      submissionDocuments: submissionDocs,
      proposedConcertsCount: producerConcerts.length,
      activeConcertsCount: activeConcertsList.length,
      ticketsSold: totalTicketsSold,
      ticketPurchases: 0,
      pendingName:
          (pendingName != null && pendingName.trim().isNotEmpty)
              ? pendingName.trim()
              : null,
      pendingKtpUrl:
          (pendingKtpUrl != null && pendingKtpUrl.trim().isNotEmpty)
              ? pendingKtpUrl.trim()
              : null,
      pendingResponsibilityLetterUrl:
          (pendingLetterUrl != null && pendingLetterUrl.trim().isNotEmpty)
              ? pendingLetterUrl.trim()
              : null,
      requestType: hasPendingProfileEdit ? 'profile_edit' : 'registration',
      activeConcertSummaries: [
        for (final c in activeConcertsList)
          <String, String>{
            'title': c.title,
            'subtitle': '${ApprovalFormat.dayMonthYear(c.dateTime)} · ${c.venue}',
            if (c.bannerUrl != null) 'posterUrl': c.bannerUrl!,
          },
      ],
    );
  }

  void _recomputeRefundsFromConcerts(List<ConcertSubmissionModel> concerts) {
    final cancelled = concerts
        .where((c) =>
            c.status.toLowerCase() == 'cancelled' ||
            c.requestType == 'cancellation')
        .toList();

    final List<RefundMonitoringModel> list = [];
    int totalRefundedAmount = 0;
    int actionNeeded = 0;

    for (final c in cancelled) {
      final totalTickets = c.soldTickets;
      final isCancelledApproved = c.status.toLowerCase() == 'cancelled';
      final refundedTickets = isCancelledApproved ? totalTickets : 0;
      final processingTickets = totalTickets - refundedTickets;
      if (processingTickets > 0) actionNeeded += processingTickets;
      totalRefundedAmount += c.refundAmount;

      list.add(RefundMonitoringModel(
        concertId: c.id,
        title: c.title,
        status: isCancelledApproved ? 'Selesai' : 'Berjalan',
        refundedTickets: refundedTickets,
        totalTickets: totalTickets,
        percent: isCancelledApproved ? 100 : 50,
        refundedAmount: isCancelledApproved ? c.refundAmount : 0,
        totalAmount: c.refundAmount,
        processingTickets: processingTickets,
        needDataTickets: 0,
        deadlineDate: c.cancellationDate ?? ApprovalFormat.dayMonthYear(DateTime.now()),
        remainingDays: isCancelledApproved ? 0 : 3,
        buyers: const [],
      ));
    }

    refundMonitoringNotifier.value = list;
    refundOverviewNotifier.value = RefundOverviewModel(
      totalRefundedLabel: _formatRupiahShort(totalRefundedAmount),
      totalRefundedAmount: totalRefundedAmount,
      actionNeededCount: actionNeeded,
    );
  }

  String _formatRupiahShort(int amount) {
    if (amount <= 0) return 'Rp0';
    if (amount >= 1000000000) {
      final m = (amount / 1000000000).toStringAsFixed(2).replaceAll('.', ',');
      return 'Rp$m M';
    }
    if (amount >= 1000000) {
      final jt = (amount / 1000000).toStringAsFixed(1).replaceAll('.', ',');
      return 'Rp$jt Jt';
    }
    final str = amount.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
    return 'Rp$str';
  }

  void _recomputeStats() {
    final totalUsers = usersNotifier.value.length;
    final activeProducers = producersNotifier.value
        .where((p) =>
            p.approvalStatus == ApprovalStatus.approved && p.isVerified)
        .length;
    final activeConcerts = concertsNotifier.value
        .where((c) =>
            c.approvalStatus == ApprovalStatus.approved &&
            c.status.toLowerCase() != 'cancelled')
        .length;

    statsNotifier.value = AdminOverviewStats(
      totalUsers: totalUsers,
      activeProducers: activeProducers,
      activeConcerts: activeConcerts,
    );
  }

  void _rebuildNotificationsFromDatabase() {
    final List<AdminNotificationModel> items = [];

    for (final p in producersNotifier.value) {
      if (p.approvalStatus == ApprovalStatus.pending) {
        final isEdit = p.requestType == 'profile_edit' ||
            p.pendingName != null ||
            p.pendingKtpUrl != null ||
            p.pendingResponsibilityLetterUrl != null;
        items.add(AdminNotificationModel(
          id: 'notif-prod-${p.id}',
          category: 'approval',
          title: isEdit
              ? 'Pengajuan Ubah Profil/Legalitas Produser'
              : 'Pengajuan Produser Baru',
          body: isEdit
              ? '${p.companyName}${p.pendingName != null ? " → ${p.pendingName}" : ""} mengajukan perubahan data untuk ditinjau.'
              : '${p.companyName} mengajukan verifikasi akun produser.',
          timeAgo: 'Menunggu Review',
          isUnread: true,
          targetId: p.id,
          targetKind: ApprovalKind.producer,
        ));
      }
    }

    for (final c in concertsNotifier.value) {
      if (c.approvalStatus == ApprovalStatus.pending) {
        final isEdit = c.requestType == 'edit' || c.pendingEditPayload != null;
        final isCancel = c.requestType == 'cancellation';
        items.add(AdminNotificationModel(
          id: 'notif-con-${c.id}',
          category: 'approval',
          title: isCancel
              ? 'Pengajuan Pembatalan Konser'
              : isEdit
                  ? 'Pengajuan Edit Konser'
                  : 'Pengajuan Konser Baru',
          body:
              '${c.title} oleh ${c.promoterName} menunggu persetujuan Admin.',
          timeAgo: 'Menunggu Review',
          isUnread: true,
          targetId: c.id,
          targetKind: ApprovalKind.concert,
        ));
      }
    }

    for (final crew in GateCrewService().teamCrewNotifier.value) {
      if (crew.approvalStatus == 'pending') {
        items.add(AdminNotificationModel(
          id: 'notif-crew-${crew.id}',
          category: 'approval',
          title: 'Approval Akun Gate Crew',
          body:
              '${crew.name} (${crew.email}) menunggu persetujuan akun Gate Crew.',
          timeAgo: 'Menunggu Review',
          isUnread: true,
          targetId: crew.id,
        ));
      }
    }

    notificationsNotifier.value = items;
  }

  void _seed() {
    producersNotifier.value =
        AdminDummy.producers.map(ProducerApplicationModel.fromJson).toList();
    concertsNotifier.value =
        AdminDummy.concerts.map(ConcertSubmissionModel.fromJson).toList();
    usersNotifier.value =
        AdminDummy.users.map(ManagedUserModel.fromJson).toList();
    notificationsNotifier.value =
        AdminDummy.notifications.map(AdminNotificationModel.fromJson).toList();
    refundOverviewNotifier.value =
        RefundOverviewModel.fromJson(AdminDummy.refundOverview);
    refundMonitoringNotifier.value = AdminDummy.refundMonitoring
        .map(RefundMonitoringModel.fromJson)
        .toList();
    statsNotifier.value = AdminOverviewStats.fromJson(AdminDummy.stats);
    _hasData = true;
  }

  /// Mengembalikan service ke kondisi awal. Dipakai pengujian dan saat logout.
  void reset() {
    _hasData = false;
    simulateFailure = false;
    producersNotifier.value = const [];
    concertsNotifier.value = const [];
    usersNotifier.value = const [];
    notificationsNotifier.value = const [];
    refundMonitoringNotifier.value = const [];
    loadState.value = AdminLoadState.loading;
  }

  int get unreadNotificationCount =>
      notificationsNotifier.value.where((n) => n.isUnread).length;

  void markNotificationAsRead(String id) {
    final list = notificationsNotifier.value;
    final index = list.indexWhere((n) => n.id == id);
    if (index == -1 || !list[index].isUnread) return;
    final updated = List<AdminNotificationModel>.from(list);
    updated[index] = updated[index].copyWith(isUnread: false);
    notificationsNotifier.value = updated;
  }

  int get pendingProducerCount => producersNotifier.value
      .where((p) => p.approvalStatus == ApprovalStatus.pending)
      .length;

  int get pendingConcertCount => concertsNotifier.value
      .where((c) => c.approvalStatus == ApprovalStatus.pending)
      .length;

  int get pendingGateCrewCount => GateCrewService()
      .teamCrewNotifier
      .value
      .where((m) => m.approvalStatus == 'pending')
      .length;

  int get pendingTotal =>
      pendingProducerCount + pendingConcertCount + pendingGateCrewCount;

  /// Pengajuan menunggu, yang terbaru di atas.
  List<ApprovalQueueItem> recentPending({int limit = 2}) {
    final items = <ApprovalQueueItem>[
      for (final p in producersNotifier.value)
        if (p.approvalStatus == ApprovalStatus.pending)
          ApprovalQueueItem(
            kind: ApprovalKind.producer,
            id: p.id,
            title: p.pendingName != null && p.pendingName!.isNotEmpty
                ? '${p.companyName} → ${p.pendingName}'
                : p.companyName,
            submittedAt: p.submittedAt,
          ),
      for (final c in concertsNotifier.value)
        if (c.approvalStatus == ApprovalStatus.pending)
          ApprovalQueueItem(
            kind: ApprovalKind.concert,
            id: c.id,
            title: c.title,
            submittedAt: c.submittedAt,
          ),
    ]..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return items.take(limit).toList();
  }

  ProducerApplicationModel? producerById(String id) {
    for (final p in producersNotifier.value) {
      if (p.id == id) return p;
    }
    return null;
  }

  ConcertSubmissionModel? concertById(String id) {
    for (final c in concertsNotifier.value) {
      if (c.id == id) return c;
    }
    return null;
  }

  ManagedUserModel? userById(String id) {
    for (final u in usersNotifier.value) {
      if (u.id == id) return u;
    }
    return null;
  }

  void toggleUserActive(String userId) {
    final list = List<ManagedUserModel>.from(usersNotifier.value);
    final index = list.indexWhere((u) => u.id == userId);
    if (index != -1) {
      final newActive = !list[index].isActive;
      list[index] = list[index].copyWith(isActive: newActive);
      usersNotifier.value = list;

      if (SupabaseService.isInitialized) {
        final newStatus = newActive ? 'approved' : 'deactivated';
        SupabaseService.client
            .from('profiles')
            .update({
              'approval_status': newStatus,
              'verification_status': newStatus,
            })
            .eq('id', userId)
            .catchError((_) {});
        SupabaseService.client
            .from('promoter_profiles')
            .update({
              'approval_status': newStatus,
              'is_verified': newActive,
            })
            .eq('id', userId)
            .catchError((_) {});
      }
    }
  }

  ManagedUserModel? updateUserName(String userId, String newName) {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return null;
    final list = List<ManagedUserModel>.from(usersNotifier.value);
    final index = list.indexWhere((u) => u.id == userId);
    if (index == -1) return null;
    final updated = list[index].copyWith(name: trimmed);
    list[index] = updated;
    usersNotifier.value = list;

    // Jika user ini juga seorang Produser, sinkronkan namanya di daftar Produser & Konser
    final prod = producerById(userId);
    if (prod != null) {
      _replaceProducer(
        prod.copyWith(
          companyName: trimmed,
          clearPendingName: true,
        ),
      );
      concertsNotifier.value = [
        for (final c in concertsNotifier.value)
          if (c.promoterId == userId) c.copyWith(promoterName: trimmed) else c,
      ];
    }

    if (SupabaseService.isInitialized) {
      SupabaseService.client
          .from('profiles')
          .update({
            'name': trimmed,
            'full_name': trimmed,
          })
          .eq('id', userId)
          .catchError((_) {});
      if (updated.role.toLowerCase() == 'produser' || prod != null) {
        SupabaseService.client
            .from('promoter_profiles')
            .update({
              'company_name': trimmed,
              'responsible_name': trimmed,
            })
            .eq('id', userId)
            .catchError((_) {});
        SupabaseService.client
            .from('concerts')
            .update({'producer_name': trimmed})
            .eq('producer_id', userId)
            .catchError((_) {});
      }
    }

    final dataService = DataService();
    final active = dataService.currentUser;
    if (active != null &&
        (active.email.toLowerCase() == updated.email.toLowerCase() ||
            active.id == updated.id)) {
      dataService.updateProfile(name: trimmed);
    }
    return updated;
  }

  /// Admin mengubah nama profil Produser secara langsung dari halaman Detail Produser
  /// maupun Kelola Pengguna, dan menyimpannya ke database Supabase.
  ProducerApplicationModel? updateProducerNameByAdmin(
    String producerId,
    String newName,
  ) {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return null;

    final current = producerById(producerId);
    ProducerApplicationModel? updatedProducer;
    if (current != null) {
      updatedProducer = current.copyWith(
        companyName: trimmed,
        clearPendingName: true,
      );
      _replaceProducer(updatedProducer);
    }

    // Sinkronkan juga ke daftar usersNotifier
    final userList = List<ManagedUserModel>.from(usersNotifier.value);
    final uIdx = userList.indexWhere((u) =>
        u.id == producerId ||
        (current != null &&
            u.email.toLowerCase() == current.email.toLowerCase()));
    if (uIdx != -1) {
      userList[uIdx] = userList[uIdx].copyWith(name: trimmed);
      usersNotifier.value = userList;
    }

    // Sinkronkan nama produser pada konser terkait
    concertsNotifier.value = [
      for (final c in concertsNotifier.value)
        if (c.promoterId == producerId ||
            (current != null &&
                c.promoterName.toLowerCase() ==
                    current.companyName.toLowerCase()))
          c.copyWith(promoterName: trimmed)
        else
          c,
    ];

    // Sinkronkan ke PromoterDataService
    final promService = PromoterDataService();
    if (current != null &&
        promService.promoterEmail.toLowerCase() ==
            current.email.toLowerCase()) {
      promService.promoterNameNotifier.value = trimmed;
      promService.pendingPromoterNameNotifier.value = null;
    }

    if (SupabaseService.isInitialized) {
      SupabaseService.client
          .from('promoter_profiles')
          .update({
            'company_name': trimmed,
            'responsible_name': trimmed,
            'pending_name': null,
            'profile_change_status': 'approved',
          })
          .eq('id', producerId)
          .catchError((_) {});

      SupabaseService.client
          .from('profiles')
          .update({
            'name': trimmed,
            'full_name': trimmed,
            'pending_name': null,
            'profile_change_status': 'approved',
          })
          .eq('id', producerId)
          .catchError((_) {});

      SupabaseService.client
          .from('concerts')
          .update({'producer_name': trimmed})
          .eq('producer_id', producerId)
          .catchError((_) {});
    }

    return updatedProducer;
  }

  ManagedUserModel? updateUserPassword(String userId, String newPassword) {
    final trimmed = newPassword.trim();
    if (trimmed.isEmpty) return null;
    final list = List<ManagedUserModel>.from(usersNotifier.value);
    final index = list.indexWhere((u) => u.id == userId);
    if (index == -1) return null;
    final updated = list[index].copyWith(password: trimmed);
    list[index] = updated;
    usersNotifier.value = list;

    final dataService = DataService();
    dataService.resetPasswordByEmail(
        email: updated.email, newPassword: trimmed);
    final active = dataService.currentUser;
    if (active != null &&
        (active.email.toLowerCase() == updated.email.toLowerCase() ||
            active.id == updated.id)) {
      dataService.currentUserNotifier.value =
          active.copyWith(password: trimmed);
    }
    return updated;
  }

  /// Menyetujui pengajuan Produser (pendaftaran baru, perubahan nama produser,
  /// maupun pembaruan dokumen legalitas) dan menyimpannya ke database.
  ProducerApplicationModel? approveProducer(String id) {
    final current = producerById(id);
    if (current == null || current.approvalStatus != ApprovalStatus.pending) {
      return null;
    }

    final approvedName =
        (current.pendingName != null && current.pendingName!.trim().isNotEmpty)
            ? current.pendingName!.trim()
            : current.companyName;

    final updated = current.copyWith(
      companyName: approvedName,
      approvalStatus: ApprovalStatus.approved,
      isVerified: true,
      requestType: 'registration',
      clearPendingName: true,
      clearPendingKtp: true,
      clearPendingLetter: true,
    );
    _replaceProducer(updated);

    // Sinkronkan ke daftar usersNotifier bila nama berubah
    final userList = List<ManagedUserModel>.from(usersNotifier.value);
    final uIdx = userList.indexWhere((u) =>
        u.id == id || u.email.toLowerCase() == updated.email.toLowerCase());
    if (uIdx != -1) {
      userList[uIdx] = userList[uIdx].copyWith(
        name: approvedName,
        isActive: true,
      );
      usersNotifier.value = userList;
    }

    // Sinkronkan nama produser pada konser jika berubah
    if (approvedName != current.companyName) {
      concertsNotifier.value = [
        for (final c in concertsNotifier.value)
          if (c.promoterId == id) c.copyWith(promoterName: approvedName) else c,
      ];
    }

    final stats = statsNotifier.value;
    statsNotifier.value =
        stats.copyWith(activeProducers: stats.activeProducers + 1);

    // Sinkronkan ke PromoterDataService (nama, dokumen legalitas, status verifikasi)
    PromoterDataService().onAdminApprovedProducer(updated);

    if (SupabaseService.isInitialized) {
      final promoterUpdate = <String, dynamic>{
        'company_name': approvedName,
        'responsible_name': approvedName,
        'approval_status': 'approved',
        'is_verified': true,
        'profile_change_status': 'approved',
        'pending_name': null,
        'pending_ktp_url': null,
        'pending_responsibility_letter_url': null,
        'rejection_reason': null,
      };
      if (current.pendingKtpUrl != null &&
          current.pendingKtpUrl!.trim().isNotEmpty) {
        promoterUpdate['ktp_image_url'] = current.pendingKtpUrl!.trim();
      }
      if (current.pendingResponsibilityLetterUrl != null &&
          current.pendingResponsibilityLetterUrl!.trim().isNotEmpty) {
        promoterUpdate['responsibility_letter_url'] =
            current.pendingResponsibilityLetterUrl!.trim();
      }

      SupabaseService.client
          .from('promoter_profiles')
          .update(promoterUpdate)
          .eq('id', id)
          .catchError((_) {});

      final profileUpdate = <String, dynamic>{
        'name': approvedName,
        'full_name': approvedName,
        'is_verified': true,
        'verification_status': 'approved',
        'approval_status': 'approved',
        'profile_change_status': 'approved',
        'pending_name': null,
        'pending_ktp_url': null,
        'pending_responsibility_letter_url': null,
      };
      if (current.pendingKtpUrl != null &&
          current.pendingKtpUrl!.trim().isNotEmpty) {
        profileUpdate['ktp_url'] = current.pendingKtpUrl!.trim();
      }
      if (current.pendingResponsibilityLetterUrl != null &&
          current.pendingResponsibilityLetterUrl!.trim().isNotEmpty) {
        profileUpdate['responsibility_letter_url'] =
            current.pendingResponsibilityLetterUrl!.trim();
      }

      SupabaseService.client
          .from('profiles')
          .update(profileUpdate)
          .eq('id', id)
          .catchError((_) {});

      if (approvedName != current.companyName) {
        SupabaseService.client
            .from('concerts')
            .update({'producer_name': approvedName})
            .eq('producer_id', id)
            .catchError((_) {});
      }

      _rebuildNotificationsFromDatabase();
    }

    return updated;
  }

  ProducerApplicationModel? rejectProducer(String id, String reason) {
    final current = producerById(id);
    final trimmed = reason.trim();
    if (current == null ||
        current.approvalStatus != ApprovalStatus.pending ||
        trimmed.isEmpty) {
      return null;
    }
    final isProfileEdit = current.requestType == 'profile_edit' ||
        current.pendingName != null ||
        current.pendingKtpUrl != null ||
        current.pendingResponsibilityLetterUrl != null;

    final now = DateTime.now();
    final updated = current.copyWith(
      approvalStatus:
          isProfileEdit ? ApprovalStatus.approved : ApprovalStatus.rejected,
      rejectionReason: trimmed,
      rejectedAt: now,
      requestType: 'registration',
      clearPendingName: true,
      clearPendingKtp: true,
      clearPendingLetter: true,
    );
    _replaceProducer(updated);

    if (!isProfileEdit) {
      PromoterDataService().onAdminRejectedProducer(trimmed, now);
    }

    if (SupabaseService.isInitialized) {
      SupabaseService.client
          .from('promoter_profiles')
          .update({
            'approval_status': isProfileEdit ? 'approved' : 'rejected',
            'rejection_reason': trimmed,
            'rejected_at': now.toIso8601String(),
            'is_verified': isProfileEdit ? current.isVerified : false,
            'profile_change_status': 'rejected',
            'pending_name': null,
            'pending_ktp_url': null,
            'pending_responsibility_letter_url': null,
          })
          .eq('id', id)
          .catchError((_) {});

      SupabaseService.client
          .from('profiles')
          .update({
            'approval_status': isProfileEdit ? 'approved' : 'rejected',
            'verification_status': isProfileEdit ? 'approved' : 'rejected',
            'is_verified': isProfileEdit ? current.isVerified : false,
            'profile_change_status': 'rejected',
            'pending_name': null,
            'pending_ktp_url': null,
            'pending_responsibility_letter_url': null,
          })
          .eq('id', id)
          .catchError((_) {});

      _rebuildNotificationsFromDatabase();
    }

    return updated;
  }

  ProducerApplicationModel? deactivateProducer(String id, String reason) {
    final current = producerById(id);
    final trimmed = reason.trim();
    if (current == null || trimmed.isEmpty) {
      return null;
    }
    final updated = current.copyWith(
      approvalStatus: ApprovalStatus.deactivated,
      rejectionReason: trimmed,
      isVerified: false,
    );
    _replaceProducer(updated);
    final stats = statsNotifier.value;
    if (stats.activeProducers > 0) {
      statsNotifier.value =
          stats.copyWith(activeProducers: stats.activeProducers - 1);
    }

    if (SupabaseService.isInitialized) {
      SupabaseService.client
          .from('promoter_profiles')
          .update({
            'approval_status': 'deactivated',
            'rejection_reason': trimmed,
            'is_verified': false,
          })
          .eq('id', id)
          .catchError((_) {});

      SupabaseService.client
          .from('profiles')
          .update({
            'approval_status': 'deactivated',
            'verification_status': 'deactivated',
            'is_verified': false,
          })
          .eq('id', id)
          .catchError((_) {});
    }

    return updated;
  }

  /// Menyetujui pengajuan konser baru maupun pengajuan EDIT konser dari Produser.
  /// Jika terdapat `pendingEditPayload`, seluruh perubahan konser & tier tiket
  /// diterapkan ke tabel `concerts` dan `ticket_tiers` di Supabase.
  ConcertSubmissionModel? approveConcert(String id) {
    final current = concertById(id);
    if (current == null || current.approvalStatus != ApprovalStatus.pending) {
      return null;
    }

    final editPayload = current.pendingEditPayload;
    String newTitle = current.title;
    String newSubtitle = current.subtitle;
    String newVenue = current.venue;
    int newCapacity = current.totalCapacity;
    String? newBanner = current.bannerUrl;
    DateTime newDateTime = current.dateTime;
    List<SubmissionTierModel> newTiers = current.tiers;

    if (editPayload != null) {
      newTitle = (editPayload['title'] ?? current.title).toString();
      newSubtitle = (editPayload['subtitle'] ??
              editPayload['description'] ??
              current.subtitle)
          .toString();
      newVenue = (editPayload['venue'] ?? current.venue).toString();
      newCapacity = (editPayload['total_capacity'] as num?)?.toInt() ??
          current.totalCapacity;
      newBanner =
          (editPayload['banner_image_url'] as String?) ?? current.bannerUrl;
      if (editPayload['date'] != null) {
        newDateTime = _parseIndonesianOrIsoDate(
          editPayload['date'].toString(),
          (editPayload['time'] ?? '').toString(),
          fallbackIso: current.dateTime.toIso8601String(),
        );
      }
      final rawEditedTiers = editPayload['ticket_tiers'];
      if (rawEditedTiers is List && rawEditedTiers.isNotEmpty) {
        newTiers = rawEditedTiers
            .whereType<Map<String, dynamic>>()
            .map((t) {
              final quotaVal =
                  ((t['total_quota'] ?? t['quota'] ?? 0) as num).toInt();
              return SubmissionTierModel(
                id: (t['id'] ?? '').toString(),
                concertId: id,
                name: (t['name'] ?? '').toString(),
                description: (t['description'] ?? '').toString(),
                price: (t['price'] as num?)?.toInt() ?? 0,
                totalQuota: quotaVal,
                remainingQuota: quotaVal,
              );
            })
            .toList();
      }
    }

    final updated = current.copyWith(
      title: newTitle,
      subtitle: newSubtitle,
      venue: newVenue,
      totalCapacity: newCapacity,
      bannerUrl: newBanner,
      dateTime: newDateTime,
      tiers: newTiers,
      approvalStatus: ApprovalStatus.approved,
      status: 'published',
      requestType: 'create',
      clearPendingEdit: true,
    );
    _replaceConcert(updated);
    final stats = statsNotifier.value;
    statsNotifier.value =
        stats.copyWith(activeConcerts: stats.activeConcerts + 1);

    // 1. Sync ke Supabase Cloud
    if (SupabaseService.isInitialized) {
      final updateMap = <String, dynamic>{
        'status': 'published',
        'approval_status': 'approved',
        'pending_edit_payload': null,
        'rejection_reason': null,
      };
      if (editPayload != null) {
        if (editPayload['title'] != null) {
          updateMap['title'] = editPayload['title'];
        }
        if (editPayload['subtitle'] != null) {
          updateMap['subtitle'] = editPayload['subtitle'];
        }
        if (editPayload['date'] != null) {
          updateMap['date'] = editPayload['date'];
        }
        if (editPayload['time'] != null) {
          updateMap['time'] = editPayload['time'];
        }
        if (editPayload['venue'] != null) {
          updateMap['venue'] = editPayload['venue'];
        }
        if (editPayload['venue_address'] != null) {
          updateMap['venue_address'] = editPayload['venue_address'];
        }
        if (editPayload['description'] != null) {
          updateMap['description'] = editPayload['description'];
        }
        if (editPayload['banner_image_url'] != null) {
          updateMap['banner_image_url'] = editPayload['banner_image_url'];
        }
        if (editPayload['logo_image_url'] != null) {
          updateMap['logo_image_url'] = editPayload['logo_image_url'];
        }
        if (editPayload['total_capacity'] != null) {
          updateMap['total_capacity'] = editPayload['total_capacity'];
        }
        if (editPayload['price'] != null) {
          updateMap['price'] = editPayload['price'];
        }
      }

      SupabaseService.client
          .from('concerts')
          .update(updateMap)
          .eq('id', id)
          .then((_) async {
        if (editPayload != null && editPayload['ticket_tiers'] is List) {
          final tiersData = <Map<String, dynamic>>[];
          for (final t in (editPayload['ticket_tiers'] as List)) {
            if (t is Map<String, dynamic>) {
              final map = <String, dynamic>{
                'concert_id': id,
                'name': t['name'],
                'description': t['description'] ?? '',
                'price': t['price'] ?? 0,
                'quota': t['quota'] ?? t['total_quota'] ?? 0,
                'benefits': t['benefits'] ?? const <String>[],
              };
              final tid = (t['id'] ?? '').toString();
              if (RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(tid)) {
                map['id'] = tid;
              }
              tiersData.add(map);
            }
          }
          if (tiersData.isNotEmpty) {
            try {
              await SupabaseService.client
                  .from('ticket_tiers')
                  .upsert(tiersData);
            } catch (e) {
              debugPrint('Error upserting edited ticket_tiers: $e');
            }
          }
        }
        DataService().fetchConcertsFromSupabase(forceRefresh: true);
      }).catchError((err) {
        debugPrint('Error update concert status in Supabase: $err');
      });

      _rebuildNotificationsFromDatabase();
    }

    // 2. Sync ke PromoterDataService agar status di halaman Produser berubah jadi 'Disetujui'
    final promoterService = PromoterDataService();
    final pList =
        List<PromoterConcertItem>.from(promoterService.concertsNotifier.value);
    final pIdx = pList.indexWhere((c) => c.id == id);
    if (pIdx != -1) {
      pList[pIdx] = pList[pIdx].copyWith(
        title: newTitle,
        dateAndVenue: newSubtitle,
        venueName: newVenue,
        status: ConcertStatus.disetujui,
      );
      promoterService.concertsNotifier.value = pList;
    }

    // 3. Refresh katalog penonton di DataService sehingga konser langsung muncul di Beranda
    DataService().fetchConcertsFromSupabase(forceRefresh: true);

    return updated;
  }

  ConcertSubmissionModel? rejectConcert(String id, String reason) {
    final current = concertById(id);
    final trimmed = reason.trim();
    if (current == null ||
        current.approvalStatus != ApprovalStatus.pending ||
        trimmed.isEmpty) {
      return null;
    }
    final now = DateTime.now();
    final isEdit =
        current.requestType == 'edit' || current.pendingEditPayload != null;
    final updated = current.copyWith(
      approvalStatus:
          isEdit ? ApprovalStatus.approved : ApprovalStatus.rejected,
      rejectionReason: trimmed,
      rejectedAt: now,
      status: isEdit ? 'published' : 'rejected',
      requestType: 'create',
      clearPendingEdit: true,
    );
    _replaceConcert(updated);

    // Simpan alasan & waktu penolakan di LocalStorage untuk sinkronisasi instan
    LocalStorage.setString('livetix_concert_rej_reason_$id', trimmed);
    LocalStorage.setString('livetix_concert_rej_at_$id', now.toIso8601String());

    // 1. Sync ke Supabase Cloud
    if (SupabaseService.isInitialized) {
      SupabaseService.client
          .from('concerts')
          .update({
            'status': isEdit ? 'published' : 'rejected',
            'approval_status': isEdit ? 'approved' : 'rejected',
            'rejection_reason': trimmed,
            'rejected_at': now.toIso8601String(),
            'pending_edit_payload': null,
          })
          .eq('id', id)
          .catchError((err) {
            debugPrint('Error reject concert in Supabase: $err');
          });
      _rebuildNotificationsFromDatabase();
    }

    // 2. Sync ke PromoterDataService beserta alasan penolakan & waktu penolakan asli dari Admin
    final promoterService = PromoterDataService();
    final pList =
        List<PromoterConcertItem>.from(promoterService.concertsNotifier.value);
    final pIdx = pList.indexWhere((c) => c.id == id);
    if (pIdx != -1) {
      pList[pIdx] = pList[pIdx].copyWith(
        status: isEdit ? ConcertStatus.disetujui : ConcertStatus.ditolak,
        rejectionReason: trimmed,
        rejectedAt: now,
      );
      promoterService.concertsNotifier.value = pList;
    }

    return updated;
  }

  /// Menyetujui pengajuan pembatalan konser.
  /// Status konser menjadi 'cancelled' dan kuota penjualan ditutup.
  ConcertSubmissionModel? approveCancellation(String id) {
    final current = concertById(id);
    if (current == null) return null;
    final updated = current.copyWith(
      status: 'cancelled',
      approvalStatus: ApprovalStatus.approved,
    );
    _replaceConcert(updated);
    final stats = statsNotifier.value;
    if (stats.activeConcerts > 0) {
      statsNotifier.value =
          stats.copyWith(activeConcerts: stats.activeConcerts - 1);
    }

    // 1. Sync ke Supabase Cloud
    if (SupabaseService.isInitialized) {
      SupabaseService.client
          .from('concerts')
          .update({
            'status': 'cancelled',
            'approval_status': 'approved',
            'cancellation_status': 'approved',
          })
          .eq('id', id)
          .catchError((err) {
            debugPrint('Error approve cancellation in Supabase: $err');
          });
      _recomputeRefundsFromConcerts(concertsNotifier.value);
      _rebuildNotificationsFromDatabase();
      // Kunci dana dan balikkan biaya admin 3% di ledger keuangan
      PaymentGatewayService().cancelConcertAndLockFunds(
        concertId: id,
        reason: 'Pembatalan konser disetujui oleh admin',
      );
    }

    // 2. Sync ke PromoterDataService
    PromoterDataService().approveConcertCancellation(concertId: id);

    // 3. Refresh penonton
    DataService().fetchConcertsFromSupabase(forceRefresh: true);

    return updated;
  }

  /// Menolak pengajuan pembatalan konser.
  /// Konser tetap berstatus aktif / published, pengajuan pembatalan ditolak.
  ConcertSubmissionModel? rejectCancellation(String id, String reason) {
    final current = concertById(id);
    final trimmed = reason.trim();
    if (current == null || trimmed.isEmpty) return null;
    final updated = current.copyWith(
      approvalStatus: ApprovalStatus.rejected,
      rejectionReason: trimmed,
      cancellationReviewReason: trimmed,
    );
    _replaceConcert(updated);

    if (SupabaseService.isInitialized) {
      SupabaseService.client
          .from('concerts')
          .update({
            'status': 'published',
            'approval_status': 'approved',
            'cancellation_status': 'rejected',
            'rejection_reason': trimmed,
          })
          .eq('id', id)
          .catchError((err) {
            debugPrint('Error reject cancellation in Supabase: $err');
          });
      _rebuildNotificationsFromDatabase();
    }

    return updated;
  }

  /// Admin menambahkan konser baru secara langsung ke database (status langsung Published).
  Future<ConcertSubmissionModel?> createConcertByAdmin({
    required String title,
    required String subtitle,
    required String promoterName,
    String? promoterId,
    required String genre,
    required String dateLabel,
    required String timeLabel,
    required String venue,
    required int totalCapacity,
    required int basePrice,
    String? bannerUrl,
    List<SubmissionTierModel> tiers = const [],
  }) async {
    String newId = 'con-${DateTime.now().millisecondsSinceEpoch}';
    final effectiveTiers = tiers.isNotEmpty
        ? tiers
        : <SubmissionTierModel>[
            SubmissionTierModel(
              id: '',
              concertId: newId,
              name: 'Regular Pass',
              description: 'Tiket masuk reguler',
              price: basePrice > 0 ? basePrice : 150000,
              totalQuota: totalCapacity > 0 ? totalCapacity : 1000,
            ),
          ];

    final parsedDate = _parseIndonesianOrIsoDate(dateLabel, timeLabel);

    if (SupabaseService.isInitialized) {
      try {
        final insertPayload = <String, dynamic>{
          'title': title.trim(),
          'subtitle': subtitle.trim(),
          'description': subtitle.trim(),
          'producer_name': promoterName.trim(),
          'category': genre.trim().isEmpty ? 'Pop' : genre.trim(),
          'date': dateLabel.trim(),
          'time': timeLabel.trim(),
          'venue': venue.trim(),
          'venue_address': venue.trim(),
          'total_capacity': totalCapacity,
          'price': basePrice,
          'status': 'published',
          'approval_status': 'approved',
          'banner_image_url': bannerUrl,
        };
        if (promoterId != null &&
            RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(promoterId)) {
          insertPayload['producer_id'] = promoterId;
        }

        final inserted = await SupabaseService.client
            .from('concerts')
            .insert(insertPayload)
            .select()
            .single();

        newId = (inserted['id'] ?? newId).toString();

        final tiersPayload = [
          for (final t in effectiveTiers)
            <String, dynamic>{
              'concert_id': newId,
              'name': t.name,
              'description': t.description,
              'price': t.price,
              'quota': t.totalQuota,
              'benefits': const ['E-Ticket Resmi', 'Akses Area Konser'],
            },
        ];
        if (tiersPayload.isNotEmpty) {
          await SupabaseService.client
              .from('ticket_tiers')
              .insert(tiersPayload);
        }
      } catch (e) {
        debugPrint('AdminService createConcertByAdmin error: $e');
      }
    }

    final created = ConcertSubmissionModel(
      id: newId,
      promoterId: promoterId ?? '',
      promoterName:
          promoterName.trim().isEmpty ? 'LiveTix Official' : promoterName.trim(),
      title: title.trim(),
      subtitle: subtitle.trim(),
      genre: genre.trim().isEmpty ? 'Pop' : genre.trim(),
      dateTime: parsedDate,
      venue: venue.trim(),
      totalCapacity: totalCapacity,
      status: 'published',
      bannerUrl: bannerUrl,
      approvalStatus: ApprovalStatus.approved,
      submittedAt: DateTime.now(),
      tiers: effectiveTiers,
      requestType: 'create',
    );

    concertsNotifier.value = [created, ...concertsNotifier.value];
    _recomputeStats();
    DataService().fetchConcertsFromSupabase(forceRefresh: true);
    return created;
  }

  /// Admin mengedit data konser secara langsung di database.
  Future<ConcertSubmissionModel?> updateConcertByAdmin({
    required String concertId,
    required String title,
    required String subtitle,
    required String genre,
    required String dateLabel,
    required String timeLabel,
    required String venue,
    required int totalCapacity,
    String? bannerUrl,
    List<SubmissionTierModel>? tiers,
  }) async {
    final current = concertById(concertId);
    if (current == null) return null;

    final parsedDate = _parseIndonesianOrIsoDate(
      dateLabel,
      timeLabel,
      fallbackIso: current.dateTime.toIso8601String(),
    );

    final updatedTiers = tiers ?? current.tiers;
    final minPrice = updatedTiers.isNotEmpty
        ? updatedTiers
            .map((t) => t.price)
            .reduce((a, b) => a < b ? a : b)
        : 150000;

    final updated = current.copyWith(
      title: title.trim(),
      subtitle: subtitle.trim(),
      genre: genre.trim(),
      dateTime: parsedDate,
      venue: venue.trim(),
      totalCapacity: totalCapacity,
      bannerUrl: bannerUrl ?? current.bannerUrl,
      tiers: updatedTiers,
      approvalStatus: ApprovalStatus.approved,
      status: 'published',
      clearPendingEdit: true,
    );
    _replaceConcert(updated);

    if (SupabaseService.isInitialized) {
      try {
        await SupabaseService.client
            .from('concerts')
            .update({
              'title': title.trim(),
              'subtitle': subtitle.trim(),
              'description': subtitle.trim(),
              'category': genre.trim(),
              'date': dateLabel.trim(),
              'time': timeLabel.trim(),
              'venue': venue.trim(),
              'total_capacity': totalCapacity,
              'price': minPrice,
              'banner_image_url': bannerUrl ?? current.bannerUrl,
              'status': 'published',
              'approval_status': 'approved',
              'pending_edit_payload': null,
            })
            .eq('id', concertId);

        if (tiers != null && tiers.isNotEmpty) {
          for (final t in tiers) {
            final map = <String, dynamic>{
              'concert_id': concertId,
              'name': t.name,
              'description': t.description,
              'price': t.price,
              'quota': t.totalQuota,
            };
            if (RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(t.id)) {
              map['id'] = t.id;
              await SupabaseService.client.from('ticket_tiers').upsert(map);
            } else {
              await SupabaseService.client.from('ticket_tiers').insert(map);
            }
          }
        }
      } catch (e) {
        debugPrint('AdminService updateConcertByAdmin error: $e');
      }
    }

    // Sinkronkan juga ke PromoterDataService & DataService
    final promoterService = PromoterDataService();
    final pList =
        List<PromoterConcertItem>.from(promoterService.concertsNotifier.value);
    final pIdx = pList.indexWhere((c) => c.id == concertId);
    if (pIdx != -1) {
      pList[pIdx] = pList[pIdx].copyWith(
        title: title.trim(),
        dateAndVenue: subtitle.trim(),
        venueName: venue.trim(),
        status: ConcertStatus.disetujui,
      );
      promoterService.concertsNotifier.value = pList;
    }
    DataService().fetchConcertsFromSupabase(forceRefresh: true);

    return updated;
  }

  /// Admin menghapus konser dari database beserta relasinya.
  Future<bool> deleteConcertByAdmin(String concertId) async {
    final existing = concertById(concertId);
    if (existing == null) return false;

    concertsNotifier.value = [
      for (final c in concertsNotifier.value)
        if (c.id != concertId) c,
    ];
    _recomputeStats();

    if (SupabaseService.isInitialized) {
      try {
        await SupabaseService.client
            .from('ticket_tiers')
            .delete()
            .eq('concert_id', concertId);
        await SupabaseService.client
            .from('concert_gate_crews')
            .delete()
            .eq('concert_id', concertId);
        await SupabaseService.client
            .from('concerts')
            .delete()
            .eq('id', concertId);
      } catch (e) {
        debugPrint('AdminService deleteConcertByAdmin error: $e');
      }
    }

    final promoterService = PromoterDataService();
    promoterService.concertsNotifier.value = [
      for (final c in promoterService.concertsNotifier.value)
        if (c.id != concertId) c,
    ];
    DataService().fetchConcertsFromSupabase(forceRefresh: true);
    return true;
  }

  RefundMonitoringModel? refundDetailByConcertId(String concertId) {
    for (final item in refundMonitoringNotifier.value) {
      if (item.concertId == concertId) return item;
    }
    return null;
  }

  void _replaceProducer(ProducerApplicationModel updated) {
    producersNotifier.value = [
      for (final p in producersNotifier.value) p.id == updated.id ? updated : p,
    ];
  }

  void _replaceConcert(ConcertSubmissionModel updated) {
    concertsNotifier.value = [
      for (final c in concertsNotifier.value) c.id == updated.id ? updated : c,
    ];
  }
}
