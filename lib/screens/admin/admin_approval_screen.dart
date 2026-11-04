import 'package:flutter/material.dart';
import '../../models/approval_models.dart';
import '../../services/admin_service.dart';
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
              ]),
              builder: (context, _) => _buildScreen(kind, state),
            );
          },
        );
      },
    );
  }

  Widget _buildScreen(ApprovalKind kind, AdminLoadState state) {
    final isProducer = kind == ApprovalKind.producer;
    final pendingCount = isProducer
        ? _service.pendingProducerCount
        : _service.pendingConcertCount;
    return Column(
      children: [
        AdminHeader(
          title: isProducer ? 'Approval Produser' : 'Approval Konser',
          subtitle: isProducer
              ? 'Kelola pendaftaran akun produser musik baru'
              : 'Verifikasi pengajuan tayang konser baru',
        ),
        AdminTextTabs<ApprovalKind>(
          items: const [
            AdminTabItem('Produser', ApprovalKind.producer),
            AdminTabItem('Konser', ApprovalKind.concert),
          ],
          selected: kind,
          onChanged: (value) => AdminNavigation.approvalKind.value = value,
        ),
        AdminTextTabs<ApprovalStatus>(
          items: [
            AdminTabItem(
              pendingCount > 0 ? 'Menunggu ($pendingCount)' : 'Menunggu',
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
        return kind == ApprovalKind.producer ? _producerList() : _concertList();
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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: AdminColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AdminColors.border),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded,
                          color: AdminColors.textGrey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) => setState(() => _query = value),
                          textInputAction: TextInputAction.search,
                          style: const TextStyle(fontSize: 14),
                          decoration: const InputDecoration(
                            hintText: 'Cari konser...',
                            hintStyle: TextStyle(
                              fontSize: 14,
                              color: AdminColors.textGrey,
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
                  height: 48,
                  constraints: const BoxConstraints(maxWidth: 140),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AdminColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AdminColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          _month == 0
                              ? 'Bulan'
                              : ApprovalFormat.monthNames[_month - 1],
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
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

class _ProducerRow extends StatelessWidget {
  final ProducerApplicationModel item;

  const _ProducerRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final date = ApprovalFormat.dayMonthYear(item.submittedAt);
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
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.email} · $date',
                    style: const TextStyle(
                        fontSize: 12, color: AdminColors.textGrey),
                  ),
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
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Circular Avatar dengan Inisial Dua Huruf (Image 2: SO, HA, JA)
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFFEEF2FF),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E3A8A),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AdminColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${item.promoterName} · $submittedDate',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AdminColors.textGrey,
                    ),
                  ),
                  if (item.requestType != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: item.requestType == 'cancellation'
                            ? const Color(0xFFFEE2E2)
                            : const Color(0xFFEEF2FF),
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
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF4338CA),
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
                      style: const TextStyle(
                        fontSize: 12,
                        color: AdminColors.textGrey,
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
