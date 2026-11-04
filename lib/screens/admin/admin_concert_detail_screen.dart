import 'package:flutter/material.dart';
import '../../models/approval_models.dart';
import '../../services/admin_service.dart';
import 'admin_result_screen.dart';
import 'admin_review_concert_screen.dart';
import 'widgets/admin_theme.dart';
import 'widgets/admin_widgets.dart';

class AdminConcertDetailScreen extends StatelessWidget {
  final String concertId;

  const AdminConcertDetailScreen({super.key, required this.concertId});

  Future<void> _approve(
      BuildContext context, ConcertSubmissionModel item) async {
    final confirmed = await showApproveConfirm(
      context,
      title: 'Setujui konser?',
      message: '${item.title} akan tayang di publik dan tiketnya bisa dibeli.',
      confirmLabel: 'Setujui',
    );
    if (!confirmed || !context.mounted) return;

    final updated = AdminService().approveConcert(item.id);
    if (updated == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Pengajuan ini sudah diputuskan sebelumnya.')),
      );
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => AdminResultScreen(
          kind: ApprovalKind.concert,
          approved: true,
          title: 'Konser Disetujui',
          message: '${updated.title} sekarang tayang di publik.',
          itemId: updated.id,
          rows: [
            ('Konser', updated.title),
            ('Produser', updated.promoterName),
            ('Tanggal', ApprovalFormat.dayMonthYear(updated.dateTime)),
            ('Status', updated.approvalStatus.label),
          ],
        ),
      ),
    );
  }

  void _reject(BuildContext context, ConcertSubmissionModel item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminReviewConcertScreen(concertId: item.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = AdminService();
    return AdminScope(
      child: ListenableBuilder(
        listenable: service.concertsNotifier,
        builder: (context, _) {
          final item = service.concertById(concertId);
          final canDecide = item?.approvalStatus == ApprovalStatus.pending;
          return Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            body: Column(
              children: [
                AdminHeader(
                  title: 'Detail Konser',
                  subtitle: item?.approvalStatus == ApprovalStatus.rejected
                      ? 'Informasi penjualan dan performa tiket'
                      : null,
                  onBack: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: item == null
                      ? const AdminMessageState(
                          icon: Icons.search_off_rounded,
                          title: 'Pengajuan tidak ditemukan',
                          message: 'Data konser ini sudah tidak tersedia.',
                        )
                      : _Body(item: item),
                ),
              ],
            ),
            bottomNavigationBar: item != null && canDecide
                ? AdminDecisionBar(
                    rejectLabel: 'Tolak Konser',
                    approveLabel: 'Setujui Konser',
                    onReject: () => _reject(context, item),
                    onApprove: () => _approve(context, item),
                  )
                : null,
          );
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final ConcertSubmissionModel item;

  const _Body({required this.item});

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.35,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          // 1. Kartu Poster & Judul Konser (Image 3 & 4)
          AdminCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PosterThumb(
                  url: item.bannerUrl,
                  width: double.infinity,
                  height: 180,
                  radius: 14,
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AdminColors.textDark,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3E8FF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        item.genre,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF7C3AED),
                        ),
                      ),
                    ),
                    if (item.approvalStatus == ApprovalStatus.rejected)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Ditolak',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    if (item.approvalStatus == ApprovalStatus.pending)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Menunggu',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Produser: ${item.promoterName}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AdminColors.textGrey,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 2. Kartu Metadata (Tanggal & Waktu, Lokasi Venue, Total Kapasitas)
          AdminCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              children: [
                _buildMetaRow(
                  'Tanggal & Waktu',
                  '${ApprovalFormat.dayMonthYear(item.dateTime)} · ${ApprovalFormat.time(item.dateTime)}',
                ),
                const Divider(height: 1, color: AdminColors.border),
                _buildMetaRow('Lokasi Venue', item.venue),
                const Divider(height: 1, color: AdminColors.border),
                _buildMetaRow(
                  item.approvalStatus == ApprovalStatus.rejected
                      ? 'Kapasitas Total'
                      : 'Total Kapasitas',
                  item.approvalStatus == ApprovalStatus.rejected
                      ? '${ApprovalFormat.thousands(item.totalCapacity).replaceAll(',', '.')} Kursi'
                      : '${ApprovalFormat.thousands(item.totalCapacity)} Kursi',
                ),
              ],
            ),
          ),

          if (item.approvalStatus == ApprovalStatus.rejected &&
              (item.rejectionReason ?? '').isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x08000000),
                    offset: Offset(0, 2),
                    blurRadius: 8,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 6,
                      color: const Color(0xFFDC2626),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFEE2E2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.error_outline_rounded,
                                color: Color(0xFFDC2626),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Alasan Penolakan',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF991B1B),
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Ditinjau oleh Admin',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AdminColors.textGrey,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                        ),
                        Text(
                          item.rejectionReason!,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 20),

            // 3. Bagian Kategori Tiket
            const AdminSectionTitle('Kategori Tiket'),
            if (item.tiers.isEmpty)
              const AdminCard(
                child: Text(
                  'Produser belum menambahkan kategori tiket.',
                  style: TextStyle(fontSize: 13, color: AdminColors.textGrey),
                ),
              )
            else
              Row(
                children: [
                  for (var i = 0; i < item.tiers.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(
                      child: AdminCard(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.tiers[i].name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: i == 0
                                    ? const Color(0xFF1E3A8A)
                                    : const Color(0xFFC2185B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              ApprovalFormat.rupiah(item.tiers[i].price),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AdminColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Kapasitas: ${item.tiers[i].totalQuota} kursi',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AdminColors.textGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: AdminColors.textGrey),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AdminColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

