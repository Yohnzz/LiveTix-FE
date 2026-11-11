import 'package:flutter/material.dart';
import '../../models/approval_models.dart';
import '../../services/admin_service.dart';
import 'admin_result_screen.dart';
import 'widgets/admin_theme.dart';
import 'widgets/admin_widgets.dart';

/// Layar Tinjau Produser (Sesuai Desain Image 4 & 5).
/// Digunakan oleh Super Admin untuk memeriksa data pengajuan lengkap,
/// meninjau dokumen legalitas (NIB, KTP), mengisi alasan penolakan dengan counter 0/300,
/// dan mengeksekusi penolakan produser.
class AdminReviewProducerScreen extends StatefulWidget {
  final String producerId;
  final String initialReason;

  const AdminReviewProducerScreen({
    super.key,
    required this.producerId,
    this.initialReason = '',
  });

  @override
  State<AdminReviewProducerScreen> createState() =>
      _AdminReviewProducerScreenState();
}

class _AdminReviewProducerScreenState extends State<AdminReviewProducerScreen> {
  static const int _minLength = 10;
  static const int _maxLength = 300;

  final AdminService _service = AdminService();
  late final TextEditingController _reasonController;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController(text: widget.initialReason);
    _reasonController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool get _isValid => _reasonController.text.trim().length >= _minLength;

  void _submit(ProducerApplicationModel item) {
    if (!_isValid) return;
    final reason = _reasonController.text.trim();
    final updated = _service.rejectProducer(item.id, reason);

    if (updated == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pengajuan ini sudah diputuskan sebelumnya.'),
        ),
      );
      Navigator.of(context).pop();
      return;
    }

    final screen = AdminResultScreen(
      kind: ApprovalKind.producer,
      approved: false,
      title: 'Pengajuan Ditolak',
      message: 'Pendaftaran produser telah ditolak',
      itemId: updated.id,
      decidedAt: DateTime(2026, 10, 24),
      rows: [
        ('Produser', updated.companyName),
        ('Email', updated.email),
        ('Status', updated.approvalStatus.label),
      ],
      reason: reason,
    );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  void _openDocumentPreview(ProducerDocumentModel doc) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DocumentViewerSheet(doc: doc),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminScope(
      child: Builder(
        builder: (context) => ListenableBuilder(
          listenable: _service.producersNotifier,
          builder: (context, _) {
            final item = _service.producerById(widget.producerId);
            return Scaffold(
              backgroundColor: AdminColors.bgOf(context),
              body: Column(
                children: [
                  AdminHeader(
                    title: 'Tinjau Produser',
                    subtitle: 'Periksa data pengajuan dan berikan keputusan',
                    onBack: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: item == null
                        ? const AdminMessageState(
                            icon: Icons.search_off_rounded,
                            title: 'Pengajuan tidak ditemukan',
                            message: 'Data produser ini sudah tidak tersedia.',
                          )
                        : _buildForm(context, item),
                  ),
                ],
              ),
              bottomNavigationBar:
                  item != null ? _buildBottomBar(context, item) : null,
            );
          },
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context, ProducerApplicationModel item) {
    final docs = item.submissionDocuments.isNotEmpty
        ? item.submissionDocuments
        : ProducerDocumentModel.defaultSubmissionDocuments();
    final dateStr = ApprovalFormat.dayMonthYear(item.submittedAt);
    final textLength = _reasonController.text.length;
    final textPri = AdminColors.textPrimaryOf(context);
    final textSec = AdminColors.textSecondaryOf(context);
    final border = AdminColors.borderOf(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        // 1. Kartu Info Produser
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
              // Pill Badge Menunggu Verifikasi dengan icon jam
              MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.2,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AdminColors.warningBgOf(context),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AdminColors.warningBorderOf(context),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: AdminColors.warningOf(context),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Menunggu Verifikasi · $dateStr',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AdminColors.warningOf(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: border),
              const SizedBox(height: 12),
              _buildDetailRow(context, 'Telepon', item.phone),
              const SizedBox(height: 8),
              _buildDetailRow(context, 'Alamat', item.address),
            ],
          ),
        ),

        const SizedBox(height: 20),
        const AdminSectionTitle('Dokumen Pengajuan'),

        // 2. Daftar Dokumen Pengajuan (NIB Perusahaan & KTP)
        for (final doc in docs)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AdminCard(
              padding: const EdgeInsets.all(14),
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
                      Icons.description_rounded,
                      color: AdminColors.purpleOf(context),
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
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
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
                  InkWell(
                    onTap: () => _openDocumentPreview(doc),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AdminColors.purpleBgOf(context),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Lihat',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AdminColors.purpleOf(context),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 12),

        // 3. Card Alasan Penolakan dengan Icon Warning
        AdminCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AdminColors.dangerBgOf(context),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.error_outline_rounded,
                      color: AdminColors.dangerOf(context),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Alasan Penolakan',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: textPri,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Wajib diisi. Alasan ini dikirim ke calon produser.',
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
              const SizedBox(height: 14),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: AdminColors.surfaceAltOf(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _focusNode.hasFocus
                        ? AdminColors.purpleOf(context)
                        : border,
                    width: _focusNode.hasFocus ? 1.5 : 1,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                child: Column(
                  children: [
                    TextField(
                      key: const Key('admin_review_producer_reason_input'),
                      controller: _reasonController,
                      focusNode: _focusNode,
                      minLines: 4,
                      maxLines: 6,
                      maxLength: _maxLength,
                      style:
                          TextStyle(fontSize: 13, height: 1.5, color: textPri),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText:
                            'Tulis alasan pengajuan produser ini ditolak...\nContoh: dokumen legalitas belum sesuai.',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: AdminColors.textMutedOf(context),
                          height: 1.5,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        '$textLength/$_maxLength',
                        style: TextStyle(
                          fontSize: 12,
                          color: AdminColors.textMutedOf(context),
                        ),
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

  Widget _buildDetailRow(BuildContext context, String label, String value) {
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
    return Container(
      decoration: BoxDecoration(
        color: AdminColors.surfaceOf(context),
        border: Border(top: BorderSide(color: AdminColors.borderOf(context))),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: SafeArea(
        top: false,
        child: FilledButton.icon(
          onPressed: _isValid ? () => _submit(item) : null,
          icon: const Icon(Icons.near_me_rounded, size: 20),
          label: const Text('Kirim Penolakan'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
            disabledBackgroundColor: AdminColors.disabledBgOf(context),
            disabledForegroundColor: AdminColors.disabledFgOf(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// Modal BottomSheet untuk melihat dan mengunduh pratinjau dokumen.
class _DocumentViewerSheet extends StatelessWidget {
  final ProducerDocumentModel doc;

  const _DocumentViewerSheet({required this.doc});

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
                          color: AdminColors.purpleBgOf(context),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.description_rounded,
                          color: AdminColors.purpleOf(context),
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
                    height: 180,
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
                            doc.type == 'PDF'
                                ? Icons.picture_as_pdf_rounded
                                : Icons.image_rounded,
                            size: 48,
                            color: AdminColors.purpleOf(context),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Pratinjau Resmi: ${doc.name}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: textPri,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tervalidasi oleh Sistem LiveTix Super Admin',
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
