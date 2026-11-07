import 'package:flutter/foundation.dart';
import '../data/admin_dummy.dart';
import '../models/approval_models.dart';
import '../models/promoter_models.dart';
import 'data_service.dart';
import 'promoter_data_service.dart';
import 'supabase_service.dart';

enum AdminLoadState { loading, ready, error }

/// Akses data Super Admin. Lapisan ini yang nanti diganti dengan Supabase,
/// layar admin hanya membaca notifier dan memanggil method di bawah.
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
      totalRefundedLabel: 'Rp1,74 M',
      totalRefundedAmount: 1742900000,
      actionNeededCount: 210,
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
    if (!_hasData) _seed();

    if (SupabaseService.isInitialized) {
      try {
        final response = await SupabaseService.client
            .from('concerts')
            .select('*, ticket_tiers(*)')
            .order('created_at', ascending: false);

        if (response.isNotEmpty) {
          final List<ConcertSubmissionModel> supaConcerts = [];
          for (final row in response) {
            try {
              final rawTiers = row['ticket_tiers'] as List<dynamic>?;
              final tiersList = rawTiers is List
                  ? rawTiers
                      .whereType<Map<String, dynamic>>()
                      .map(SubmissionTierModel.fromJson)
                      .toList()
                  : const <SubmissionTierModel>[];

              ApprovalStatus status = ApprovalStatus.pending;
              final st = (row['status'] as String?)?.toLowerCase();
              if (st == 'published' || st == 'disetujui' || st == 'approved') {
                status = ApprovalStatus.approved;
              } else if (st == 'rejected' ||
                  st == 'ditolak' ||
                  st == 'cancelled') {
                status = ApprovalStatus.rejected;
              }

              supaConcerts.add(ConcertSubmissionModel(
                id: row['id'] as String,
                promoterId: (row['producer_id'] ?? 'prd-006') as String,
                promoterName:
                    (row['producer_name'] ?? 'Java Promotor') as String,
                title: row['title'] as String,
                subtitle: (row['subtitle'] ?? '') as String,
                genre: (row['category'] ?? 'Pop') as String,
                dateTime: DateTime.tryParse(row['date'] as String? ?? '') ??
                    DateTime.now(),
                venue: (row['venue'] ?? '') as String,
                totalCapacity:
                    (row['total_capacity'] as num?)?.toInt() ?? 5000,
                status: (row['status'] ?? 'pending') as String,
                bannerUrl: row['banner_image_url'] as String?,
                approvalStatus: status,
                rejectionReason: row['rejection_reason'] as String?,
                submittedAt:
                    DateTime.tryParse(row['created_at'] as String? ?? '') ??
                        DateTime.now(),
                tiers: tiersList,
                cancellationReason: row['cancellation_reason'] as String?,
                cancellationDate: row['cancellation_date'] as String?,
                attachmentName: row['cancellation_attachment'] as String?,
              ));
            } catch (e) {
              debugPrint('Error parse supa concert for admin: $e');
            }
          }
          if (supaConcerts.isNotEmpty) {
            final merged =
                List<ConcertSubmissionModel>.from(concertsNotifier.value);
            for (final sc in supaConcerts) {
              final idx = merged.indexWhere((c) => c.id == sc.id);
              if (idx != -1) {
                merged[idx] = sc;
              } else {
                merged.insert(0, sc);
              }
            }
            concertsNotifier.value = merged;
          }
        }
      } catch (err) {
        debugPrint('AdminService fetch Supabase error: $err');
      }
    }

    loadState.value = AdminLoadState.ready;
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

  int get pendingTotal => pendingProducerCount + pendingConcertCount;

  /// Pengajuan menunggu, yang terbaru di atas.
  List<ApprovalQueueItem> recentPending({int limit = 2}) {
    final items = <ApprovalQueueItem>[
      for (final p in producersNotifier.value)
        if (p.approvalStatus == ApprovalStatus.pending)
          ApprovalQueueItem(
            kind: ApprovalKind.producer,
            id: p.id,
            title: p.companyName,
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
      list[index] = list[index].copyWith(isActive: !list[index].isActive);
      usersNotifier.value = list;
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

    final dataService = DataService();
    final active = dataService.currentUser;
    if (active != null &&
        (active.email.toLowerCase() == updated.email.toLowerCase() ||
            active.id == updated.id)) {
      dataService.updateProfile(name: trimmed);
    }
    return updated;
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
    dataService.resetPasswordByEmail(email: updated.email, newPassword: trimmed);
    final active = dataService.currentUser;
    if (active != null &&
        (active.email.toLowerCase() == updated.email.toLowerCase() ||
            active.id == updated.id)) {
      dataService.currentUserNotifier.value =
          active.copyWith(password: trimmed);
    }
    return updated;
  }

  /// Mengembalikan model terbaru, atau null bila id tidak ada atau sudah diputuskan.
  ProducerApplicationModel? approveProducer(String id) {
    final current = producerById(id);
    if (current == null || current.approvalStatus != ApprovalStatus.pending) {
      return null;
    }
    final updated = current.copyWith(
      approvalStatus: ApprovalStatus.approved,
      isVerified: true,
    );
    _replaceProducer(updated);
    final stats = statsNotifier.value;
    statsNotifier.value =
        stats.copyWith(activeProducers: stats.activeProducers + 1);

    // Sinkronkan ke PromoterDataService (nama, dokumen legalitas, status verifikasi)
    PromoterDataService().onAdminApprovedProducer(updated);

    if (SupabaseService.isInitialized) {
      SupabaseService.client.from('promoter_profiles').update({
        'company_name': updated.companyName,
        'approval_status': 'approved',
        'is_verified': true,
      }).eq('id', id).catchError((_) {});
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
    final updated = current.copyWith(
      approvalStatus: ApprovalStatus.rejected,
      rejectionReason: trimmed,
    );
    _replaceProducer(updated);

    if (SupabaseService.isInitialized) {
      SupabaseService.client.from('promoter_profiles').update({
        'approval_status': 'rejected',
        'rejection_reason': trimmed,
        'is_verified': false,
      }).eq('id', id).catchError((_) {});
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
    return updated;
  }

  ConcertSubmissionModel? approveConcert(String id) {
    final current = concertById(id);
    if (current == null || current.approvalStatus != ApprovalStatus.pending) {
      return null;
    }
    final updated = current.copyWith(
      approvalStatus: ApprovalStatus.approved,
      status: 'published',
    );
    _replaceConcert(updated);
    final stats = statsNotifier.value;
    statsNotifier.value =
        stats.copyWith(activeConcerts: stats.activeConcerts + 1);

    // 1. Sync ke Supabase Cloud
    if (SupabaseService.isInitialized) {
      SupabaseService.client.from('concerts').update({
        'status': 'published',
      }).eq('id', id).catchError((err) {
        debugPrint('Error update concert status in Supabase: $err');
      });
    }

    // 2. Sync ke PromoterDataService agar status di halaman Produser berubah jadi 'Disetujui'
    final promoterService = PromoterDataService();
    final pList =
        List<PromoterConcertItem>.from(promoterService.concertsNotifier.value);
    final pIdx = pList.indexWhere((c) => c.id == id);
    if (pIdx != -1) {
      pList[pIdx] = pList[pIdx].copyWith(status: ConcertStatus.disetujui);
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
    final updated = current.copyWith(
      approvalStatus: ApprovalStatus.rejected,
      rejectionReason: trimmed,
      status: 'rejected',
    );
    _replaceConcert(updated);

    // 1. Sync ke Supabase Cloud
    if (SupabaseService.isInitialized) {
      SupabaseService.client.from('concerts').update({
        'status': 'rejected',
        'rejection_reason': trimmed,
      }).eq('id', id).catchError((err) {
        debugPrint('Error reject concert in Supabase: $err');
      });
    }

    // 2. Sync ke PromoterDataService
    final promoterService = PromoterDataService();
    final pList =
        List<PromoterConcertItem>.from(promoterService.concertsNotifier.value);
    final pIdx = pList.indexWhere((c) => c.id == id);
    if (pIdx != -1) {
      pList[pIdx] = pList[pIdx].copyWith(status: ConcertStatus.ditolak);
      promoterService.concertsNotifier.value = pList;
    }

    return updated;
  }

  /// Menyetujui pengajuan pembatalan konser (Image 5).
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
      SupabaseService.client.from('concerts').update({
        'status': 'cancelled',
      }).eq('id', id).catchError((err) {
        debugPrint('Error approve cancellation in Supabase: $err');
      });
    }

    // 2. Sync ke PromoterDataService
    PromoterDataService().approveConcertCancellation(concertId: id);

    // 3. Refresh penonton
    DataService().fetchConcertsFromSupabase(forceRefresh: true);

    return updated;
  }

  /// Menolak pengajuan pembatalan konser (Image 4).
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
    return updated;
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
