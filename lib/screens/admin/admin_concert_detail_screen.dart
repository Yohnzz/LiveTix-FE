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
    final isEdit =
        item.requestType == 'edit' || item.pendingEditPayload != null;
    final confirmed = await showApproveConfirm(
      context,
      title: isEdit ? 'Setujui perubahan konser?' : 'Setujui konser?',
      message: isEdit
          ? 'Seluruh pembaruan data konser "${item.title}" akan langsung diterapkan di database.'
          : '${item.title} akan tayang di publik dan tiketnya bisa dibeli.',
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
            backgroundColor: AdminColors.bgOf(context),
            body: Column(
              children: [
                AdminHeader(
                  eyebrow: 'TINJAUAN PENGAJUAN KONSER',
                  title: 'Detail Konser',
                  subtitle: item?.approvalStatus == ApprovalStatus.rejected
                      ? 'Informasi pengajuan dan catatan penolakan Admin'
                      : 'Periksa detail konser yang diajukan oleh Produser',
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
    final editPayload = item.pendingEditPayload;
    final isEditSubmission = item.requestType == 'edit' || editPayload != null;
    final textPri = AdminColors.textPrimaryOf(context);
    final textSec = AdminColors.textSecondaryOf(context);
    final border = AdminColors.borderOf(context);

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.35,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          // 1. Kartu Poster & Judul Konser (tanpa tombol Edit/Hapus karena wewenang Produser)
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
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: textPri,
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
                    if (isEditSubmission)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDBEAFE),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Pengajuan Edit',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E40AF),
                          ),
                        ),
                      ),
                    StatusBadge(status: item.approvalStatus),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Produser: ${item.promoterName}',
                  style: TextStyle(
                    fontSize: 13,
                    color: textSec,
                  ),
                ),
              ],
            ),
          ),

          if (editPayload != null) ...[
            const SizedBox(height: 16),
            AdminCard(
              color: const Color(0xFFEFF6FF),
              borderColor: const Color(0xFFBFDBFE),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.edit_note_rounded,
                        color: Color(0xFF1D4ED8),
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Detail Perubahan Edit Konser oleh Produser',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (editPayload['title'] != null)
                    _buildMetaRow(
                        context, 'Judul Baru', editPayload['title'].toString()),
                  if (editPayload['date'] != null)
                    _buildMetaRow(context, 'Tanggal Baru',
                        editPayload['date'].toString()),
                  if (editPayload['time'] != null)
                    _buildMetaRow(
                        context, 'Waktu Baru', editPayload['time'].toString()),
                  if (editPayload['venue'] != null)
                    _buildMetaRow(
                        context, 'Venue Baru', editPayload['venue'].toString()),
                  if (editPayload['total_capacity'] != null)
                    _buildMetaRow(context, 'Kapasitas Baru',
                        '${editPayload['total_capacity']} Kursi'),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // 2. Kartu Metadata (Tanggal & Waktu, Lokasi Venue, Total Kapasitas)
          AdminCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              children: [
                _buildMetaRow(
                  context,
                  'Tanggal & Waktu',
                  '${ApprovalFormat.dayMonthYear(item.dateTime)} · ${ApprovalFormat.time(item.dateTime)}',
                ),
                Divider(height: 1, color: border),
                _buildMetaRow(context, 'Lokasi Venue', item.venue),
                Divider(height: 1, color: border),
                _buildMetaRow(
                  context,
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
            AdminCard(
              borderColor: const Color(0xFFFECACA),
              padding: const EdgeInsets.all(16),
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Alasan Penolakan',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Ditinjau oleh Admin',
                            style: TextStyle(
                              fontSize: 12,
                              color: textSec,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1, color: border),
                  ),
                  Text(
                    item.rejectionReason!,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: textPri,
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
              AdminCard(
                child: Text(
                  'Produser belum menambahkan kategori tiket.',
                  style: TextStyle(fontSize: 13, color: textSec),
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
                                    ? AdminColors.accentOf(context)
                                    : const Color(0xFFC2185B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              ApprovalFormat.rupiah(item.tiers[i].price),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: textPri,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Kapasitas: ${item.tiers[i].totalQuota} kursi',
                              style: TextStyle(
                                fontSize: 12,
                                color: textSec,
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

  Widget _buildMetaRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: AdminColors.textSecondaryOf(context),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AdminColors.textPrimaryOf(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
