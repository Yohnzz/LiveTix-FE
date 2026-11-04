import 'package:flutter/material.dart';
import '../../models/approval_models.dart';
import '../../services/admin_service.dart';
import 'admin_result_screen.dart';
import 'widgets/admin_theme.dart';
import 'widgets/admin_widgets.dart';

/// Layar Tinjau Pembatalan Konser untuk penolakan pembatalan (Image 4).
class AdminReviewCancellationScreen extends StatefulWidget {
  final ConcertSubmissionModel concert;

  const AdminReviewCancellationScreen({
    super.key,
    required this.concert,
  });

  @override
  State<AdminReviewCancellationScreen> createState() =>
      _AdminReviewCancellationScreenState();
}

class _AdminReviewCancellationScreenState
    extends State<AdminReviewCancellationScreen> {
  final TextEditingController _reasonController = TextEditingController();
  static const int _maxChars = 500;

  @override
  void initState() {
    super.initState();
    _reasonController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _applyQuickReason(String template) {
    setState(() {
      _reasonController.text = template;
      _reasonController.selection = TextSelection.fromPosition(
        TextPosition(offset: _reasonController.text.length),
      );
    });
  }

  void _submit() {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) return;

    AdminService().rejectCancellation(widget.concert.id, reason);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => AdminResultScreen(
          kind: ApprovalKind.concert,
          approved: false,
          topTitle: 'Approval Ditolak',
          title: 'Pengajuan Ditolak',
          message:
              'Pembatalan ${widget.concert.title} ditolak. Konser tetap berstatus aktif.',
          rows: [
            ('Nama Konser', widget.concert.title),
            (
              'Tanggal Penolakan',
              ApprovalFormat.dayFullMonthYear(DateTime.now()),
            ),
          ],
          reason: reason,
          itemId: widget.concert.id,
          decidedAt: DateTime.now(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final concert = widget.concert;
    final dateStr = ApprovalFormat.dayMonthYear(concert.dateTime);
    final timeStr = ApprovalFormat.time(concert.dateTime);
    final charCount = _reasonController.text.length;
    final isValid = _reasonController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          AdminHeader(
            title: 'Tinjau Pembatalan',
            subtitle: 'Periksa pengajuan dan berikan keputusan',
            onBack: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.35,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                children: [
                // 1. Kartu Ringkasan Konser
                AdminCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              concert.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AdminColors.textDark,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Pembatalan',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Produser: ${concert.promoterName}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AdminColors.textGrey,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildInfoRow('Tanggal & Waktu', '$dateStr · $timeStr'),
                      const SizedBox(height: 8),
                      _buildInfoRow('Lokasi Venue', concert.venue),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 2. Kartu Form Alasan Penolakan (Image 4)
                AdminCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFEE2E2),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              '!',
                              style: TextStyle(
                                color: Color(0xFFDC2626),
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Alasan Penolakan',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AdminColors.textDark,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Wajib diisi, akan dikirim ke produser',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AdminColors.textGrey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Quick Chips: Bukti kurang & Dokumen tidak valid
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          _buildQuickChip(
                            label: 'Bukti kurang',
                            template:
                                'Mohon lampirkan surat resmi dari Polres yang menyatakan izin keramaian tidak diterbitkan, lalu ajukan kembali pembatalan.',
                          ),
                          _buildQuickChip(
                            label: 'Dokumen tidak valid',
                            template:
                                'Dokumen bukti pembatalan yang dilampirkan tidak valid atau tidak terbaca dengan jelas. Mohon unggah dokumen resmi yang sah.',
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Textarea dengan Border Ungu/Indigo
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF818CF8),
                            width: 1.5,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Column(
                          children: [
                            TextField(
                              key: const Key(
                                  'admin_review_cancellation_reason_input'),
                              controller: _reasonController,
                              maxLines: 5,
                              maxLength: _maxChars,
                              decoration: const InputDecoration(
                                hintText:
                                    'Tulis alasan penolakan pembatalan konser ini...',
                                border: InputBorder.none,
                                isDense: true,
                                counterText: '',
                                contentPadding: EdgeInsets.zero,
                              ),
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                color: AdminColors.textDark,
                              ),
                            ),
                            Align(
                              alignment: Alignment.bottomRight,
                              child: Text(
                                '$charCount/$_maxChars',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AdminColors.textGrey,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Konser tetap aktif sampai disetujui.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AdminColors.textGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AdminColors.border)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: SafeArea(
          top: false,
          child: FilledButton(
            key: const Key('admin_review_cancellation_submit_button'),
            onPressed: isValid ? _submit : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: const Color(0xFFDC2626),
              disabledBackgroundColor: const Color(0xFFFCA5A5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: const Text('Kirim Penolakan'),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickChip({
    required String label,
    required String template,
  }) {
    return InkWell(
      onTap: () => _applyQuickReason(template),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFEEF2FF),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E3A8A),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AdminColors.textGrey,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AdminColors.textDark,
            ),
          ),
        ),
      ],
    );
  }
}
