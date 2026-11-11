import 'package:flutter/material.dart';
import '../../models/approval_models.dart';
import '../../services/admin_service.dart';
import '../../services/supabase_service.dart';
import 'admin_deactivate_user_screen.dart';
import 'admin_result_screen.dart';
import 'admin_review_producer_screen.dart';
import 'widgets/admin_theme.dart';
import 'widgets/admin_widgets.dart';

/// Layar Detail Produser (Sesuai Desain Image 3).
/// Menampilkan data profil, telepon, alamat, daftar Dokumen Legalitas (KTP, SIUP/TDUP, Akta),
/// Catatan Review Admin, serta tombol aksi "Tolak Pendaftaran" dan "Setujui Produser".
class AdminProducerDetailScreen extends StatefulWidget {
  final String producerId;

  const AdminProducerDetailScreen({super.key, required this.producerId});

  @override
  State<AdminProducerDetailScreen> createState() =>
      _AdminProducerDetailScreenState();
}

class _AdminProducerDetailScreenState extends State<AdminProducerDetailScreen> {
  final AdminService _service = AdminService();
  final TextEditingController _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _approve(ProducerApplicationModel item) async {
    final confirmed = await showApproveConfirm(
      context,
      title: 'Setujui produser?',
      message:
          '${item.companyName} akan terverifikasi dan bisa mengajukan konser.',
      confirmLabel: 'Setujui',
    );
    if (!confirmed || !mounted) return;

    final updated = _service.approveProducer(item.id);
    if (updated == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pengajuan ini sudah diputuskan sebelumnya.'),
        ),
      );
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => AdminResultScreen(
          kind: ApprovalKind.producer,
          approved: true,
          itemId: updated.id,
          topTitle: 'Approval Sukses',
          title: 'Approval Berhasil!',
          message: 'Produser telah berhasil diverifikasi',
          finishLabel: 'Kembali ke Beranda',
          rows: [
            ('Nama Produser', updated.companyName),
            ('Tanggal Approval', '24 Oktober 2026'),
          ],
        ),
      ),
    );
  }

  void _openRejectScreen(ProducerApplicationModel item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminReviewProducerScreen(
          producerId: item.id,
          initialReason: _notesController.text.trim(),
        ),
      ),
    );
  }

  void _previewDocument(ProducerDocumentModel doc) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LegalDocPreviewSheet(doc: doc),
    );
  }

  Future<void> _showEditProducerNameDialog(
    ProducerApplicationModel item,
  ) async {
    final controller = TextEditingController(text: item.companyName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final textPri = AdminColors.textPrimaryOf(ctx);
        final textSec = AdminColors.textSecondaryOf(ctx);
        return AlertDialog(
          backgroundColor: AdminColors.surfaceOf(ctx),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Ubah Nama Profil Produser',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: textPri,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Perubahan nama akan langsung disimpan ke database dan disinkronkan ke seluruh konser produser.',
                style: TextStyle(fontSize: 12.5, color: textSec),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('admin_edit_producer_name_input'),
                controller: controller,
                autofocus: true,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textPri,
                ),
                decoration: InputDecoration(
                  labelText: 'Nama Produser / Perusahaan',
                  filled: true,
                  fillColor: AdminColors.surfaceAltOf(ctx),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Batal'),
            ),
            FilledButton(
              key: const Key('admin_save_producer_name_button'),
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              style: FilledButton.styleFrom(
                backgroundColor: AdminColors.primaryButtonBgOf(ctx),
                foregroundColor: Colors.white,
              ),
              child: const Text('Simpan ke Database'),
            ),
          ],
        );
      },
    );

    if (newName == null || newName.isEmpty || !mounted) return;
    final updated = _service.updateProducerNameByAdmin(item.id, newName);
    if (updated != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nama produser berhasil diubah menjadi "$newName".'),
          backgroundColor: AdminColors.navy,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminScope(
      child: Builder(
        builder: (context) => ListenableBuilder(
          listenable: _service.producersNotifier,
          builder: (context, _) {
            final item = _service.producerById(widget.producerId);
            final canDecide = item?.approvalStatus == ApprovalStatus.pending;
            return Scaffold(
              backgroundColor: AdminColors.bgOf(context),
              body: Column(
                children: [
                  AdminHeader(
                    title: item != null &&
                            item.approvalStatus == ApprovalStatus.deactivated &&
                            !_isProducerProfile(item)
                        ? 'Detail User'
                        : 'Detail Produser',
                    subtitle: item?.approvalStatus == ApprovalStatus.rejected
                        ? 'Profil produser yang pengajuannya ditolak'
                        : (item?.approvalStatus == ApprovalStatus.approved ||
                                item?.approvalStatus ==
                                    ApprovalStatus.deactivated
                            ? 'Profil produser yang telah disetujui'
                            : 'Periksa kelengkapan dokumen dan data produser'),
                    onBack: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: item == null
                        ? const AdminMessageState(
                            icon: Icons.search_off_rounded,
                            title: 'Pengajuan tidak ditemukan',
                            message: 'Data produser ini sudah tidak tersedia.',
                          )
                        : _buildBody(context, item),
                  ),
                ],
              ),
              bottomNavigationBar: item != null
                  ? (canDecide
                      ? _buildBottomBar(context, item)
                      : (item.approvalStatus == ApprovalStatus.approved
                          ? _buildApprovedBottomBar(context, item)
                          : (item.approvalStatus == ApprovalStatus.rejected
                              ? _buildRejectedBottomBar(context)
                              : null)))
                  : null,
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ProducerApplicationModel item) {
    if (item.approvalStatus == ApprovalStatus.approved) {
      return _buildApprovedBody(context, item);
    }
    if (item.approvalStatus == ApprovalStatus.deactivated) {
      return _buildDeactivatedBody(context, item);
    }
    if (item.approvalStatus == ApprovalStatus.rejected) {
      return _buildRejectedBody(context, item);
    }
    return _buildPendingBody(context, item);
  }

  Widget _buildPendingBody(
      BuildContext context, ProducerApplicationModel item) {
    final docs = item.legalDocuments.isNotEmpty
        ? item.legalDocuments
        : ProducerDocumentModel.defaultLegalDocuments();
    final hasPendingProfileEdit = item.requestType == 'profile_edit' ||
        (item.pendingName != null && item.pendingName!.isNotEmpty) ||
        (item.pendingKtpUrl != null && item.pendingKtpUrl!.isNotEmpty) ||
        (item.pendingResponsibilityLetterUrl != null &&
            item.pendingResponsibilityLetterUrl!.isNotEmpty);
    final textPri = AdminColors.textPrimaryOf(context);
    final textSec = AdminColors.textSecondaryOf(context);
    final border = AdminColors.borderOf(context);
    final accent = AdminColors.accentOf(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        // 1. Kartu Info Produser (Avatar, Nama, Email, Divider, Telepon, Alamat)
        AdminCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            children: [
              InitialAvatar(initials: item.initials, size: 64),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      item.companyName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textPri,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    key: const Key('admin_edit_producer_name_button_pending'),
                    onTap: () => _showEditProducerNameDialog(item),
                    borderRadius: BorderRadius.circular(999),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.edit_outlined,
                        size: 16,
                        color: accent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                item.email,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: textSec),
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: border),
              const SizedBox(height: 12),
              _buildRow(context, 'Telepon', item.phone),
              const SizedBox(height: 8),
              _buildRow(context, 'Alamat', item.address),
            ],
          ),
        ),

        if (hasPendingProfileEdit) ...[
          const SizedBox(height: 16),
          AdminCard(
            color: AdminColors.warningBgOf(context),
            borderColor: AdminColors.warningBorderOf(context),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.published_with_changes_rounded,
                      color: AdminColors.warningOf(context),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pengajuan Perubahan Profil / Legalitas Produser',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AdminColors.warningOf(context),
                        ),
                      ),
                    ),
                  ],
                ),
                if (item.pendingName != null &&
                    item.pendingName!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Nama Baru Diajukan: ${item.pendingName}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: textPri,
                    ),
                  ),
                ],
                if (item.pendingKtpUrl != null &&
                    item.pendingKtpUrl!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'KTP Baru: ${item.pendingKtpUrl!.split('/').last}',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: textPri,
                    ),
                  ),
                ],
                if (item.pendingResponsibilityLetterUrl != null &&
                    item.pendingResponsibilityLetterUrl!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Lembar Penanggung Jawab Baru: ${item.pendingResponsibilityLetterUrl!.split('/').last}',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: textPri,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),
        const AdminSectionTitle('Dokumen Legalitas'),

        // 2. Daftar Dokumen Legalitas (KTP, SIUP / TDUP, Akta)
        for (final doc in docs)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AdminCard(
              onTap: () => _previewDocument(doc),
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AdminColors.infoBgOf(context),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.description_outlined,
                      color: AdminColors.infoOf(context),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doc.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textPri,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${doc.type} · ${doc.fileSize}',
                          style: TextStyle(
                            fontSize: 12,
                            color: textSec,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _previewDocument(doc),
                    tooltip: 'Unduh dokumen',
                    icon: Icon(
                      Icons.file_download_outlined,
                      color: textSec,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 12),
        const AdminSectionTitle('Catatan Review Admin'),

        // 3. Catatan Review Admin (Input box)
        AdminCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: TextField(
            key: const Key('admin_review_notes_input'),
            controller: _notesController,
            minLines: 1,
            maxLines: 3,
            style: TextStyle(fontSize: 13, color: textPri),
            decoration: InputDecoration(
              hintText: 'Tulis alasan jika menolak pendaftaran...',
              hintStyle: TextStyle(
                fontSize: 13,
                color: AdminColors.textMutedOf(context),
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),

        if (item.approvalStatus == ApprovalStatus.rejected &&
            (item.rejectionReason ?? '').isNotEmpty) ...[
          const SizedBox(height: 20),
          const AdminSectionTitle('Alasan Penolakan'),
          AdminCard(
            color: AdminColors.dangerSoftBgOf(context),
            borderColor: AdminColors.dangerBorderOf(context),
            child: Text(
              item.rejectionReason!,
              style: TextStyle(fontSize: 13, height: 1.5, color: textPri),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRow(BuildContext context, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: AdminColors.textSecondaryOf(context),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '-' : value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AdminColors.textPrimaryOf(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context, ProducerApplicationModel item) {
    final dangerCol = AdminColors.dangerOf(context);
    return Container(
      decoration: BoxDecoration(
        color: AdminColors.surfaceOf(context),
        border: Border(top: BorderSide(color: AdminColors.borderOf(context))),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _openRejectScreen(item),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: dangerCol,
                  side: BorderSide(color: dangerCol, width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Tolak Pendaftaran'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () => _approve(item),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: AdminColors.primaryButtonBgOf(context),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Setujui Produser'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRejectedBottomBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AdminColors.surfaceOf(context),
        border: Border(top: BorderSide(color: AdminColors.borderOf(context))),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: SafeArea(
        top: false,
        child: FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            backgroundColor: AdminColors.primaryButtonBgOf(context),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: const Text('Kembali'),
        ),
      ),
    );
  }

  Widget _buildRejectedBody(
      BuildContext context, ProducerApplicationModel item) {
    final reasonText = (item.rejectionReason != null &&
            item.rejectionReason!.isNotEmpty)
        ? item.rejectionReason!
        : 'NIB yang dilampirkan tidak sesuai dengan nama perusahaan yang didaftarkan, dan nomor telepon penanggung jawab tidak dapat diverifikasi. Silakan perbaiki data tersebut lalu ajukan kembali.';
    final dateStr = ApprovalFormat.dayMonthYear(item.submittedAt);
    final textPri = AdminColors.textPrimaryOf(context);
    final textSec = AdminColors.textSecondaryOf(context);
    final border = AdminColors.borderOf(context);
    final dangerCol = AdminColors.dangerOf(context);
    final dangerBg = AdminColors.dangerBgOf(context);
    final dangerBorder = AdminColors.dangerBorderOf(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        // 1. Kartu Info Produser (Avatar, Nama, Email, Badge Ditolak, Telepon, Alamat)
        AdminCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            children: [
              InitialAvatar(initials: item.initials, size: 64),
              const SizedBox(height: 12),
              Text(
                item.companyName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textPri,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.email,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: textSec),
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: dangerBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: dangerBorder, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cancel_outlined,
                      size: 14,
                      color: dangerCol,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Ditolak · $dateStr',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: dangerCol,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: border),
              const SizedBox(height: 12),
              _buildRow(context, 'Telepon', item.phone),
              const SizedBox(height: 8),
              _buildRow(context, 'Alamat', item.address),
            ],
          ),
        ),

        const SizedBox(height: 20),
        const AdminSectionTitle('Alasan Penolakan'),

        // 2. Kartu Alasan Penolakan (Admin Verifikasi)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AdminColors.dangerSoftBgOf(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: dangerBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AdminColors.primaryButtonBgOf(context),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'A',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Admin Verifikasi',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: textPri,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '24 Okt 2026 · 14.20 WIB',
                          style: TextStyle(
                            fontSize: 12,
                            color: textSec,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: dangerBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Ditolak',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: dangerCol,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: dangerBorder),
              const SizedBox(height: 12),
              Text(
                reasonText,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: textPri,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        const AdminSectionTitle('Statistik Produser'),

        // 3. Statistik Produser (3 cards)
        Row(
          children: [
            Expanded(
              child: _buildMiniStat(context, 'Konser Diajukan', '0'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMiniStat(context, 'Konser Aktif', '0'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMiniStat(context, 'Tiket Terjual', '0'),
            ),
          ],
        ),

        const SizedBox(height: 20),
        const AdminSectionTitle('Konser Aktif'),

        // 4. Konser Aktif (Empty state)
        AdminCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AdminColors.purpleBgOf(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.confirmation_number_outlined,
                  color: AdminColors.purpleOf(context),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Belum ada konser',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: textPri,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Konser dapat diajukan setelah produser disetujui.',
                      style: TextStyle(
                        fontSize: 12,
                        color: textSec,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStat(BuildContext context, String label, String value,
      {Color? valueColor}) {
    return AdminCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: AdminColors.textSecondaryOf(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: valueColor ?? AdminColors.textPrimaryOf(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovedBottomBar(
      BuildContext context, ProducerApplicationModel item) {
    final dangerCol = AdminColors.dangerOf(context);
    return Container(
      decoration: BoxDecoration(
        color: AdminColors.surfaceOf(context),
        border: Border(top: BorderSide(color: AdminColors.borderOf(context))),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const Key('admin_producer_deactivate_button'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          AdminDeactivateUserScreen(producer: item),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: dangerCol,
                  side: BorderSide(color: dangerCol, width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('Nonaktifkan Produser'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: AdminColors.primaryButtonBgOf(context),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('Kembali'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovedBody(
      BuildContext context, ProducerApplicationModel item) {
    final activeSummaries = item.activeConcertSummaries;
    final textPri = AdminColors.textPrimaryOf(context);
    final textSec = AdminColors.textSecondaryOf(context);
    final border = AdminColors.borderOf(context);
    final accent = AdminColors.accentOf(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        // 1. Kartu Info Produser Terverifikasi (Image 5)
        AdminCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            children: [
              InitialAvatar(initials: item.initials, size: 64),
              const SizedBox(height: 12),
              Text(
                item.companyName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textPri,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.email,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: textSec,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: AdminColors.successBgOf(context),
                      border: Border.all(
                          color: AdminColors.successBorderOf(context)),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: AdminColors.successOf(context),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Terverifikasi · 24 Okt 2026',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AdminColors.successOf(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const Key('admin_edit_producer_name_button'),
                    onPressed: () => _showEditProducerNameDialog(item),
                    icon: const Icon(Icons.edit_outlined, size: 15),
                    label: const Text('Ubah Nama Produser'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: accent,
                      side: BorderSide(color: border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: border),
              const SizedBox(height: 12),
              _buildRow(context, 'Telepon', item.phone),
              const SizedBox(height: 8),
              _buildRow(context, 'Alamat', item.address),
            ],
          ),
        ),

        const SizedBox(height: 20),
        const AdminSectionTitle('Statistik Produser'),

        // 2. Statistik Produser (3 cards)
        Row(
          children: [
            Expanded(
              child: _buildMiniStat(
                context,
                'Konser Diajukan',
                '${item.proposedConcertsCount}',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMiniStat(
                context,
                'Konser Aktif',
                '${item.activeConcertsCount}',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMiniStat(
                context,
                'Tiket Terjual',
                ApprovalFormat.thousands(item.ticketsSold),
                valueColor: AdminColors.pinkAccentOf(context),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),
        const AdminSectionTitle('Konser Aktif'),

        // 3. Daftar Konser Aktif (dari database ketika terhubung ke Supabase)
        if (activeSummaries.isNotEmpty)
          for (int i = 0; i < activeSummaries.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _buildActiveConcertCard(
              context,
              title: activeSummaries[i]['title'] ?? '',
              subtitle: activeSummaries[i]['subtitle'] ?? '',
              posterUrl: activeSummaries[i]['posterUrl'],
            ),
          ]
        else if (SupabaseService.isInitialized)
          AdminCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AdminColors.purpleBgOf(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.confirmation_number_outlined,
                    color: AdminColors.purpleOf(context),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Belum ada konser aktif',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: textPri,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Produser ini belum memiliki konser aktif di database.',
                        style: TextStyle(
                          fontSize: 12,
                          color: textSec,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else ...[
          _buildActiveConcertCard(
            context,
            title: 'Soundwave Fest 2026',
            subtitle: '12 Okt 2026 · Gate B',
            posterUrl: null,
          ),
          const SizedBox(height: 10),
          _buildActiveConcertCard(
            context,
            title: 'Jazz Night 2026',
            subtitle: '15 Nov 2026 · Balai Sarbini',
            posterUrl: null,
          ),
        ],
      ],
    );
  }

  Widget _buildActiveConcertCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    String? posterUrl,
  }) {
    final textPri = AdminColors.textPrimaryOf(context);
    final textSec = AdminColors.textSecondaryOf(context);
    return AdminCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: posterUrl == null
                  ? const Center(
                      child: Icon(
                        Icons.music_note_rounded,
                        color: Colors.white70,
                        size: 22,
                      ),
                    )
                  : Image.network(
                      posterUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.music_note_rounded,
                        color: Colors.white70,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textPri,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: textSec,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AdminColors.successBgOf(context),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Aktif',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AdminColors.successOf(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isProducerProfile(ProducerApplicationModel item) {
    final name = item.companyName.toLowerCase();
    return name.contains('pt ') ||
        name.contains('cv ') ||
        name.contains('productions') ||
        name.contains('entertainment') ||
        name.contains('organizer') ||
        name.contains('promosi') ||
        name.contains('event');
  }

  Widget _buildDeactivatedBody(
      BuildContext context, ProducerApplicationModel item) {
    final textPri = AdminColors.textPrimaryOf(context);
    final textSec = AdminColors.textSecondaryOf(context);
    final border = AdminColors.borderOf(context);
    final dangerCol = AdminColors.dangerOf(context);
    final dangerBg = AdminColors.dangerBgOf(context);
    final dangerBorder = AdminColors.dangerBorderOf(context);

    if (_isProducerProfile(item)) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          // 1. Kartu Info Produser Nonaktif (Image 1)
          AdminCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              children: [
                InitialAvatar(initials: item.initials, size: 64),
                const SizedBox(height: 12),
                Text(
                  item.companyName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textPri,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.email,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: textSec,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: dangerBg,
                    border: Border.all(color: dangerBorder),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Nonaktif · 24 Okt 2026',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: dangerCol,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: border),
                const SizedBox(height: 12),
                _buildRow(context, 'Telepon', item.phone),
                const SizedBox(height: 8),
                _buildRow(context, 'Alamat', item.address),
              ],
            ),
          ),

          const SizedBox(height: 20),
          const AdminSectionTitle('Statistik Produser'),

          // 2. Statistik Produser (Image 1: Konser Diajukan, Konser Dihentikan, Tiket Terjual)
          Row(
            children: [
              Expanded(
                child: _buildMiniStat(
                  context,
                  'Konser Diajukan',
                  SupabaseService.isInitialized
                      ? '${item.proposedConcertsCount}'
                      : '${item.proposedConcertsCount == 0 ? 8 : item.proposedConcertsCount}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMiniStat(
                  context,
                  'Konser Dihentikan',
                  SupabaseService.isInitialized
                      ? '${item.activeConcertsCount}'
                      : '${item.activeConcertsCount == 0 ? 5 : item.activeConcertsCount}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMiniStat(
                  context,
                  'Tiket Terjual',
                  SupabaseService.isInitialized
                      ? ApprovalFormat.thousands(item.ticketsSold)
                      : (item.ticketsSold == 0
                          ? '12,450'
                          : ApprovalFormat.thousands(item.ticketsSold)),
                  valueColor: AdminColors.pinkAccentOf(context),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        // 1. Kartu Info User Dinonaktifkan
        AdminCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            children: [
              InitialAvatar(initials: item.initials, size: 64),
              const SizedBox(height: 12),
              Text(
                item.companyName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textPri,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.email,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: textSec,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: dangerBg,
                  border: Border.all(color: dangerBorder),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Nonaktif · 24 Okt 2026',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: dangerCol,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: border),
              const SizedBox(height: 12),
              _buildRow(context, 'Telepon', item.phone),
              const SizedBox(height: 8),
              _buildRow(context, 'Alamat', item.address),
            ],
          ),
        ),

        const SizedBox(height: 20),
        const AdminSectionTitle('Statistik User'),

        // 2. Statistik User
        AdminCard(
          padding: const EdgeInsets.all(14),
          child: SizedBox(
            width: 120,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pembelian Tiket',
                  style: TextStyle(
                    fontSize: 12,
                    color: textSec,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${item.ticketPurchases}',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: textPri,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Modal BottomSheet untuk melihat dan mengunduh Dokumen Legalitas.
class _LegalDocPreviewSheet extends StatelessWidget {
  final ProducerDocumentModel doc;

  const _LegalDocPreviewSheet({required this.doc});

  @override
  Widget build(BuildContext context) {
    return AdminScope(
      child: Builder(
        builder: (context) {
          final textPri = AdminColors.textPrimaryOf(context);
          final textSec = AdminColors.textSecondaryOf(context);
          final surfaceAlt = AdminColors.surfaceAltOf(context);
          final border = AdminColors.borderOf(context);
          final accent = AdminColors.accentOf(context);
          return Container(
            decoration: BoxDecoration(
              color: AdminColors.surfaceOf(context),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AdminColors.infoBgOf(context),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.description_outlined,
                          color: AdminColors.infoOf(context),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              doc.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: textPri,
                              ),
                            ),
                            Text(
                              'Format ${doc.type} · Ukuran ${doc.fileSize}',
                              style: TextStyle(
                                fontSize: 12,
                                color: textSec,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close_rounded, color: textPri),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    height: 160,
                    decoration: BoxDecoration(
                      color: surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: border),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            size: 40,
                            color: AdminColors.infoOf(context),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Dokumen Legalitas: ${doc.name}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: textPri,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Terverifikasi resmi dalam arsip LiveTix',
                            style: TextStyle(
                              fontSize: 11,
                              color: textSec,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text('Mengunduh salinan ${doc.name}...'),
                                backgroundColor: AdminColors.navy,
                              ),
                            );
                          },
                          icon:
                              const Icon(Icons.file_download_outlined, size: 18),
                          label: const Text('Unduh Salinan'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(46),
                            foregroundColor: accent,
                            side: BorderSide(color: accent),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(46),
                            backgroundColor:
                                AdminColors.primaryButtonBgOf(context),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Tutup'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
