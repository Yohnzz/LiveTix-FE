import 'package:flutter/material.dart';
import '../../models/approval_models.dart';
import '../../models/gate_crew_models.dart';
import '../../services/admin_service.dart';
import '../../services/gate_crew_service.dart';
import 'admin_cancellation_detail_screen.dart';
import 'admin_concert_detail_screen.dart';
import 'admin_producer_detail_screen.dart';
import 'admin_shell.dart';
import 'widgets/admin_theme.dart';
import 'widgets/admin_widgets.dart';

class AdminApprovalScreen extends StatefulWidget {
  const AdminApprovalScreen({super.key});

  @override
  State<AdminApprovalScreen> createState() => _AdminApprovalScreenState();
}

class _AdminApprovalScreenState extends State<AdminApprovalScreen> {
  final AdminService _service = AdminService();
  final GateCrewService _gateCrewService = GateCrewService();
  final TextEditingController _searchController = TextEditingController();
  ApprovalStatus _status = ApprovalStatus.pending;
  String _query = '';
  int _month = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _hasConcertFilter => _query.trim().isNotEmpty || _month != 0;

  void _resetConcertFilter() {
    _searchController.clear();
    setState(() {
      _query = '';
      _month = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ApprovalKind>(
      valueListenable: AdminNavigation.approvalKind,
      builder: (context, kind, _) {
        return ValueListenableBuilder<AdminLoadState>(
          valueListenable: _service.loadState,
          builder: (context, state, _) {
            return ListenableBuilder(
              listenable: Listenable.merge([
                _service.producersNotifier,
                _service.concertsNotifier,
                _gateCrewService.teamCrewNotifier,
              ]),
              builder: (context, _) => _buildScreen(kind, state),
            );
          },
        );
      },
    );
  }

  Widget _buildScreen(ApprovalKind kind, AdminLoadState state) {
    final pendingProdCount = _service.pendingProducerCount;
    final pendingConCount = _service.pendingConcertCount;
    final pendingCrewCount = _service.pendingGateCrewCount;

    final int activePendingCount = switch (kind) {
      ApprovalKind.producer => pendingProdCount,
      ApprovalKind.concert => pendingConCount,
      ApprovalKind.gatecrew => pendingCrewCount,
    };

    final (String headerTitle, String headerSubtitle) = switch (kind) {
      ApprovalKind.producer => (
          'Approval Produser',
          'Kelola pendaftaran dan verifikasi dokumen akun produser'
        ),
      ApprovalKind.concert => (
          'Approval Konser',
          'Verifikasi pengajuan tayang konser baru'
        ),
      ApprovalKind.gatecrew => (
          'Approval Gatecrew',
          'Tinjau pengajuan akun petugas gate yang dikelompokkan per produser'
        ),
    };

    return Column(
      children: [
        AdminHeader(
          eyebrow: 'PUSAT PERSETUJUAN ADMIN',
          title: headerTitle,
          subtitle: headerSubtitle,
        ),
        AdminTextTabs<ApprovalKind>(
          items: [
            AdminTabItem(
              'Produser',
              ApprovalKind.producer,
              badgeCount: pendingProdCount,
            ),
            AdminTabItem(
              'Konser',
              ApprovalKind.concert,
              badgeCount: pendingConCount,
            ),
            AdminTabItem(
              'Gatecrew',
              ApprovalKind.gatecrew,
              badgeCount: pendingCrewCount,
            ),
          ],
          selected: kind,
          onChanged: (value) => AdminNavigation.approvalKind.value = value,
        ),
        AdminTextTabs<ApprovalStatus>(
          items: [
            AdminTabItem(
              activePendingCount > 0
                  ? 'Menunggu ($activePendingCount)'
                  : 'Menunggu',
              ApprovalStatus.pending,
            ),
            const AdminTabItem('Disetujui', ApprovalStatus.approved),
            const AdminTabItem('Ditolak', ApprovalStatus.rejected),
          ],
          selected: _status,
          onChanged: (value) => setState(() => _status = value),
        ),
        Expanded(child: _content(kind, state)),
      ],
    );
  }

  Widget _content(ApprovalKind kind, AdminLoadState state) {
    switch (state) {
      case AdminLoadState.loading:
        return const AdminLoadingState();
      case AdminLoadState.error:
        return AdminMessageState(
          icon: Icons.cloud_off_rounded,
          title: 'Data belum bisa dimuat',
          message: 'Periksa koneksi lalu coba lagi.',
          actionLabel: 'Coba lagi',
          onAction: () => _service.load(force: true),
        );
      case AdminLoadState.ready:
        return switch (kind) {
          ApprovalKind.producer => _producerList(),
          ApprovalKind.concert => _concertList(),
          ApprovalKind.gatecrew => _gatecrewList(),
        };
    }
  }

  Widget _producerList() {
    final items = _service.producersNotifier.value
        .where((p) => p.approvalStatus == _status)
        .toList()
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

    if (items.isEmpty) {
      return AdminMessageState(
        icon: Icons.inbox_outlined,
        title: 'Belum ada data',
        message:
            'Tidak ada pengajuan produser dengan status ${_status.label.toLowerCase()}.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _ProducerRow(item: items[index]),
    );
  }

  Widget _gatecrewList() {
    final targetStatusStr = _status.value.toLowerCase();
    final allCrews = _gateCrewService.teamCrewNotifier.value;
    final filteredCrews = allCrews
        .where((c) => c.approvalStatus.toLowerCase() == targetStatusStr)
        .toList();

    if (filteredCrews.isEmpty) {
      return AdminMessageState(
        icon: Icons.badge_outlined,
        title: 'Belum ada data Gatecrew',
        message:
            'Tidak ada akun Gatecrew dengan status ${_status.label.toLowerCase()}.',
      );
    }

    // Kelompokkan Gatecrew berdasarkan Produser
    final producersById = <String, ProducerApplicationModel>{
      for (final p in _service.producersNotifier.value) p.id: p,
      for (final p in _service.producersNotifier.value) p.userId: p,
    };
    final producersByEmail = <String, ProducerApplicationModel>{
      for (final p in _service.producersNotifier.value)
        if (p.email.isNotEmpty) p.email.toLowerCase(): p,
    };

    final Map<String, _ProducerCrewGroup> groups = {};
    for (final crew in filteredCrews) {
      final prodModel = producersById[crew.producerId] ??
          producersByEmail[crew.producerEmail.toLowerCase()];
      final resolvedProdName = (prodModel?.companyName.isNotEmpty == true)
          ? prodModel!.companyName
          : (crew.producerName.isNotEmpty
              ? crew.producerName
              : 'Soundwave Entertainment');
      final resolvedProdEmail = (prodModel?.email.isNotEmpty == true)
          ? prodModel!.email
          : (crew.producerEmail.isNotEmpty
              ? crew.producerEmail
              : 'produser@livetix.com');
      final groupKey = resolvedProdEmail.toLowerCase();

      final group = groups.putIfAbsent(
        groupKey,
        () => _ProducerCrewGroup(
          producerId: prodModel?.id ?? crew.producerId,
          producerName: resolvedProdName,
          producerEmail: resolvedProdEmail,
          crews: [],
        ),
      );
      group.crews.add(crew);
    }

    final groupList = groups.values.toList();

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      itemCount: groupList.length,
      separatorBuilder: (_, __) => const SizedBox(height: 18),
      itemBuilder: (context, index) {
        final group = groupList[index];
        return _ProducerGatecrewGroupCard(
          group: group,
          statusFilter: _status,
          onApproveCrew: (crew) async {
            await _gateCrewService.approveGateCrewByAdmin(crew.id);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'Akun Gatecrew ${crew.email} telah disetujui dan diaktifkan.'),
                  backgroundColor: const Color(0xFF15803D),
                ),
              );
            }
          },
          onRejectCrew: (crew) async {
            await _gateCrewService.rejectGateCrewByAdmin(crew.id);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Akun Gatecrew ${crew.email} ditolak.'),
                  backgroundColor: AdminColors.danger,
                ),
              );
            }
          },
          onDeleteCrew: (crew) async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (dialogCtx) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                title: const Text(
                  'Hapus Gate Crew?',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                content: Text(
                  'Akun Gate Crew ${crew.name} (${crew.email}) akan dihapus permanen beserta penugasan gatenya.',
                  style: const TextStyle(fontSize: 14),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogCtx).pop(false),
                    child: const Text('Batal'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(dialogCtx).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: AdminColors.danger,
                    ),
                    child: const Text('Hapus'),
                  ),
                ],
              ),
            );
            if (confirmed == true) {
              await _service.deleteGateCrewByAdmin(
                userId: crew.id,
                email: crew.email,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Akun Gate Crew ${crew.name} berhasil dihapus.'),
                    backgroundColor: AdminColors.danger,
                  ),
                );
              }
            }
          },
        );
      },
    );
  }

  Widget _concertList() {
    final items = _service.concertsNotifier.value.where((c) {
      if (c.approvalStatus != _status) return false;
      if (_month != 0 && c.dateTime.month != _month) return false;
      final q = _query.trim().toLowerCase();
      if (q.isEmpty) return true;
      return c.title.toLowerCase().contains(q) ||
          c.promoterName.toLowerCase().contains(q) ||
          c.venue.toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    final surface = AdminColors.surfaceOf(context);
    final border = AdminColors.borderOf(context);
    final textPri = AdminColors.textPrimaryOf(context);
    final textSec = AdminColors.textSecondaryOf(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: border),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, color: textSec, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) => setState(() => _query = value),
                          textInputAction: TextInputAction.search,
                          style: TextStyle(fontSize: 13.5, color: textPri),
                          decoration: InputDecoration(
                            hintText: 'Cari konser atau produser...',
                            hintStyle: TextStyle(
                              fontSize: 13.5,
                              color: textSec,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              PopupMenuButton<int>(
                tooltip: 'Filter bulan',
                initialValue: _month,
                onSelected: (value) => setState(() => _month = value),
                itemBuilder: (context) => [
                  const PopupMenuItem<int>(
                      value: 0, child: Text('Semua bulan')),
                  for (var m = 1; m <= 12; m++)
                    PopupMenuItem<int>(
                      value: m,
                      child: Text(ApprovalFormat.monthNames[m - 1]),
                    ),
                ],
                child: Container(
                  height: 46,
                  constraints: const BoxConstraints(maxWidth: 140),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_month_rounded,
                        size: 16,
                        color: textSec,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _month == 0
                              ? 'Bulan'
                              : ApprovalFormat.monthNames[_month - 1],
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: textPri,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: textSec,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? AdminMessageState(
                  icon: _hasConcertFilter
                      ? Icons.search_off_rounded
                      : Icons.inbox_outlined,
                  title: _hasConcertFilter
                      ? 'Konser tidak ditemukan'
                      : 'Belum ada data',
                  message: _hasConcertFilter
                      ? 'Ubah kata kunci atau bulan yang dipilih.'
                      : 'Tidak ada pengajuan konser dengan status ${_status.label.toLowerCase()}.',
                  actionLabel: _hasConcertFilter ? 'Reset filter' : null,
                  onAction: _hasConcertFilter ? _resetConcertFilter : null,
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) =>
                      _ConcertRow(item: items[index]),
                ),
        ),
      ],
    );
  }
}

class _ProducerCrewGroup {
  final String producerId;
  final String producerName;
  final String producerEmail;
  final List<GateCrewMemberModel> crews;

  _ProducerCrewGroup({
    required this.producerId,
    required this.producerName,
    required this.producerEmail,
    required this.crews,
  });
}

/// Kartu kelompok Produser beserta daftar Gatecrew di bawahnya:
/// [Produser (foto profil kecil, nama produser, email)]
///    - [Gatecrew]
///    - [Gatecrew]
class _ProducerGatecrewGroupCard extends StatelessWidget {
  final _ProducerCrewGroup group;
  final ApprovalStatus statusFilter;
  final ValueChanged<GateCrewMemberModel> onApproveCrew;
  final ValueChanged<GateCrewMemberModel> onRejectCrew;
  final ValueChanged<GateCrewMemberModel> onDeleteCrew;

  const _ProducerGatecrewGroupCard({
    required this.group,
    required this.statusFilter,
    required this.onApproveCrew,
    required this.onRejectCrew,
    required this.onDeleteCrew,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AdminColors.isDark(context);
    final surface = AdminColors.surfaceOf(context);
    final border = AdminColors.borderOf(context);
    final textPri = AdminColors.textPrimaryOf(context);
    final textSec = AdminColors.textSecondaryOf(context);
    final accent = AdminColors.accentOf(context);

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Produser (kecil & ringkas karena berfungsi sebagai pengelompokan/filter)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF0F172A).withValues(alpha: 0.6)
                  : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(17),
              ),
              border: Border(bottom: BorderSide(color: border)),
            ),
            child: Row(
              children: [
                InitialAvatar(
                  initials: ApprovalFormat.initialsOf(group.producerName),
                  size: 32,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              group.producerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: textPri,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Produser',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        group.producerEmail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: textSec,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${group.crews.length} Gatecrew',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Daftar Gatecrew di bawah Produser ini
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
              children: [
                for (int i = 0; i < group.crews.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Garis indentasi hierarki "- [Gatecrew]"
                      Padding(
                        padding: const EdgeInsets.only(left: 6, right: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 10,
                              height: 2,
                              decoration: BoxDecoration(
                                color: border,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.badge_outlined,
                              size: 16,
                              color: textSec,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF0F172A).withValues(alpha: 0.45)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: border),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      group.crews[i].name,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: textPri,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      group.crews[i].email,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: textSec,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (statusFilter == ApprovalStatus.pending) ...[
                                TextButton(
                                  onPressed: () =>
                                      onRejectCrew(group.crews[i]),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AdminColors.dangerOf(context),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  child: const Text(
                                    'Tolak',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                FilledButton(
                                  onPressed: () =>
                                      onApproveCrew(group.crews[i]),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF059669),
                                    foregroundColor: Colors.white,
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                  ),
                                  child: const Text(
                                    'Setujui',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ] else ...[
                                StatusBadge(status: statusFilter),
                                const SizedBox(width: 4),
                                IconButton(
                                  onPressed: () =>
                                      onDeleteCrew(group.crews[i]),
                                  tooltip: 'Hapus Gate Crew',
                                  visualDensity: VisualDensity.compact,
                                  constraints: const BoxConstraints(
                                      minWidth: 32, minHeight: 32),
                                  padding: EdgeInsets.zero,
                                  icon: Icon(
                                    Icons.delete_outline_rounded,
                                    size: 18,
                                    color: AdminColors.dangerOf(context),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProducerRow extends StatelessWidget {
  final ProducerApplicationModel item;

  const _ProducerRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final date = ApprovalFormat.dayMonthYear(item.submittedAt);
    final hasPendingProfileEdit = item.requestType == 'profile_edit' ||
        (item.pendingName != null && item.pendingName!.isNotEmpty) ||
        (item.pendingKtpUrl != null && item.pendingKtpUrl!.isNotEmpty) ||
        (item.pendingResponsibilityLetterUrl != null &&
            item.pendingResponsibilityLetterUrl!.isNotEmpty);

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.35,
      child: AdminCard(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AdminProducerDetailScreen(producerId: item.id),
          ),
        ),
        semanticLabel:
            '${item.companyName}, ${item.email}, $date, ${item.approvalStatus.label}',
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            InitialAvatar(initials: item.initials),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.companyName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AdminColors.textPrimaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.email} · $date',
                    style: TextStyle(
                      fontSize: 12,
                      color: AdminColors.textSecondaryOf(context),
                    ),
                  ),
                  if (hasPendingProfileEdit) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.pendingName != null && item.pendingName!.isNotEmpty
                          ? 'Pengajuan Ubah Nama → ${item.pendingName}'
                          : 'Pengajuan Pembaruan Dokumen Legalitas',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AdminColors.isDark(context)
                            ? const Color(0xFFFBBF24)
                            : const Color(0xFFD97706),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusBadge(status: item.approvalStatus),
          ],
        ),
      ),
    );
  }
}

class _ConcertRow extends StatelessWidget {
  final ConcertSubmissionModel item;

  const _ConcertRow({required this.item});

  String _getConcertInitials(String title) {
    final words =
        title.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isNotEmpty && words.first.length >= 2) {
      return words.first.substring(0, 2).toUpperCase();
    }
    return ApprovalFormat.initialsOf(title);
  }

  @override
  Widget build(BuildContext context) {
    final date = ApprovalFormat.dayMonthYear(item.dateTime);
    final submittedDate = item.cancellationDate != null
        ? item.cancellationDate!.split(',').first.trim()
        : ApprovalFormat.dayMonthYear(item.submittedAt);
    final initials = _getConcertInitials(item.title);
    final showRequestBadge =
        item.requestType != null && item.requestType != 'create';

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.35,
      child: AdminCard(
        onTap: () {
          if (item.requestType == 'cancellation') {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => AdminCancellationDetailScreen(concert: item),
              ),
            );
          } else {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => AdminConcertDetailScreen(concertId: item.id),
              ),
            );
          }
        },
        semanticLabel:
            '${item.title}, ${item.promoterName}, ${item.venue}, $date, ${item.approvalStatus.label}',
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            InitialAvatar(initials: initials, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AdminColors.textPrimaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${item.promoterName} · $submittedDate',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: AdminColors.textSecondaryOf(context),
                    ),
                  ),
                  if (showRequestBadge) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: item.requestType == 'cancellation'
                            ? AdminColors.dangerBgOf(context)
                            : AdminColors.infoBgOf(context),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        item.requestType == 'cancellation'
                            ? 'Pembatalan'
                            : 'Perubahan',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: item.requestType == 'cancellation'
                              ? AdminColors.dangerOf(context)
                              : AdminColors.infoOf(context),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 105),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  StatusBadge(status: item.approvalStatus),
                  if (item.requestInfo != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      item.requestInfo!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 12,
                        color: AdminColors.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
