import 'package:flutter/material.dart';
import '../../models/approval_models.dart';
import '../../services/admin_service.dart';
import 'admin_result_screen.dart';
import 'widgets/admin_theme.dart';
import 'widgets/admin_widgets.dart';

/// Layar Tinjau Konser (Image 5): Form penolakan konser dengan pratinjau data,
/// validasi alasan minimal 10 karakter, counter 0/300, dan tombol Kirim Penolakan.
class AdminReviewConcertScreen extends StatefulWidget {
  final String concertId;
  final String initialReason;

  const AdminReviewConcertScreen({
    super.key,
    required this.concertId,
    this.initialReason = '',
  });

  @override
  State<AdminReviewConcertScreen> createState() =>
      _AdminReviewConcertScreenState();
}

class _AdminReviewConcertScreenState extends State<AdminReviewConcertScreen> {
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

  void _submit(ConcertSubmissionModel item) {
    if (!_isValid) return;
    final reason = _reasonController.text.trim();
    final updated = _service.rejectConcert(item.id, reason);

    if (updated == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pengajuan konser ini sudah diputuskan sebelumnya.'),
        ),
      );
      Navigator.of(context).pop();
      return;
    }

    final screen = AdminResultScreen(
      kind: ApprovalKind.concert,
      approved: false,
      title: 'Pengajuan Ditolak',
      message: 'Pengajuan konser telah ditolak',
      itemId: updated.id,
      decidedAt: DateTime(2026, 10, 24),
      rows: [
        ('Konser', updated.title),
        ('Produser', updated.promoterName),
        ('Status', updated.approvalStatus.label),
      ],
      reason: reason,
    );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminScope(
      child: ListenableBuilder(
        listenable: _service.concertsNotifier,
        builder: (context, _) {
          final item = _service.concertById(widget.concertId);
          return Scaffold(
            backgroundColor: AdminColors.bgOf(context),
            body: Column(
              children: [
                AdminHeader(
                  title: 'Tinjau Konser',
                  subtitle: 'Periksa pengajuan dan berikan keputusan',
                  onBack: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: item == null
                      ? const AdminMessageState(
                          icon: Icons.search_off_rounded,
                          title: 'Konser tidak ditemukan',
                          message: 'Data konser ini sudah tidak tersedia.',
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
    );
  }

  Widget _buildForm(BuildContext context, ConcertSubmissionModel item) {
    final textLength = _reasonController.text.length;
    final textPri = AdminColors.textPrimaryOf(context);
    final textSec = AdminColors.textSecondaryOf(context);
    final border = AdminColors.borderOf(context);

    return MediaQuery.withClampedTextScaling(
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
                PosterThumb(
                  url: item.bannerUrl,
                  width: double.infinity,
                  height: 170,
                  radius: 12,
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textPri,
                      ),
                    ),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: AdminColors.purpleBgOf(context),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        item.genre,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AdminColors.purpleOf(context),
                        ),
                      ),
                    ),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: AdminColors.warningBgOf(context),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Menunggu',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AdminColors.warningOf(context),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
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

          const SizedBox(height: 16),

          // 2. Kartu Metadata Konser
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
                  'Kapasitas Total',
                  '${ApprovalFormat.thousands(item.totalCapacity).replaceAll(',', '.')} Kursi',
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 3. Card Form Alasan Penolakan dengan Icon Warning
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
                            'Wajib diisi. Alasan ini dikirim ke penyelenggara.',
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
                        key: const Key('admin_review_concert_reason_input'),
                        controller: _reasonController,
                        focusNode: _focusNode,
                        minLines: 4,
                        maxLines: 6,
                        maxLength: _maxLength,
                        style: TextStyle(
                            fontSize: 13, height: 1.5, color: textPri),
                        decoration: InputDecoration(
                          counterText: '',
                          hintText:
                              'Tulis alasan konser ini ditolak...\nContoh: dokumen izin belum lengkap.',
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
                            fontWeight: FontWeight.w500,
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
                  fontSize: 13, color: AdminColors.textSecondaryOf(context)),
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

  Widget _buildBottomBar(BuildContext context, ConcertSubmissionModel item) {
    final active = _isValid;
    final disabledBg = AdminColors.disabledBgOf(context);
    final disabledFg = AdminColors.disabledFgOf(context);
    return Container(
      decoration: BoxDecoration(
        color: AdminColors.surfaceOf(context),
        border: Border(top: BorderSide(color: AdminColors.borderOf(context))),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: SafeArea(
        top: false,
        child: FilledButton.icon(
          onPressed: active ? () => _submit(item) : null,
          icon: Icon(
            Icons.send_rounded,
            size: 18,
            color: active ? Colors.white : disabledFg,
          ),
          label: Text(
            'Kirim Penolakan',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : disabledFg,
            ),
          ),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            backgroundColor: active ? const Color(0xFFDC2626) : disabledBg,
            disabledBackgroundColor: disabledBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}
