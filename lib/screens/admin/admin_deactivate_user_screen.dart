import 'package:flutter/material.dart';
import '../../models/approval_models.dart';
import '../../services/admin_service.dart';
import 'admin_result_screen.dart';
import 'widgets/admin_theme.dart';
import 'widgets/admin_widgets.dart';

/// Layar Nonaktifkan User / Produser (Image 1, 2 & Image 4, 5):
/// Form penonaktifan produser (atau user biasa) dengan pratinjau profil,
/// statistik metrik, daftar konser aktif, banner peringatan penghentian konser,
/// validasi alasan 0/300 dengan border merah dinamis, dan tombol aksi "Nonaktifkan Akun".
class AdminDeactivateUserScreen extends StatefulWidget {
  final ProducerApplicationModel producer;
  final bool isProducer;

  const AdminDeactivateUserScreen({
    super.key,
    required this.producer,
    this.isProducer = true,
  });

  @override
  State<AdminDeactivateUserScreen> createState() =>
      _AdminDeactivateUserScreenState();
}

class _AdminDeactivateUserScreenState extends State<AdminDeactivateUserScreen> {
  static const int _maxLength = 300;
  static const int _minLength = 5;

  final TextEditingController _reasonController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final AdminService _service = AdminService();

  @override
  void initState() {
    super.initState();
    _reasonController.addListener(() => setState(() {}));
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool get _isValid => _reasonController.text.trim().length >= _minLength;

  void _submit() {
    if (!_isValid) return;
    final reason = _reasonController.text.trim();
    final updated = _service.deactivateProducer(widget.producer.id, reason);

    if (updated == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Akun tidak ditemukan atau sudah nonaktif.')),
      );
      Navigator.of(context).pop();
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => AdminResultScreen(
          kind: ApprovalKind.producer,
          approved: false,
          topTitle: 'Akun Nonaktif',
          title: 'Penonaktifan Akun User',
          message: '',
          itemId: updated.id,
          decidedAt: DateTime(2026, 10, 24),
          reason: reason,
          rows: [
            ('Produser', updated.companyName),
            ('Status', 'Ditolak'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.producer;
    final textLength = _reasonController.text.length;
    final isFocusedOrFilled =
        _focusNode.hasFocus || _reasonController.text.isNotEmpty;

    return AdminScope(
      child: Builder(
        builder: (context) {
          final textPri = AdminColors.textPrimaryOf(context);
          final textSec = AdminColors.textSecondaryOf(context);
          final border = AdminColors.borderOf(context);
          final accent = AdminColors.accentOf(context);

          return Scaffold(
            backgroundColor: AdminColors.bgOf(context),
            body: Column(
              children: [
                AdminHeader(
                  title: widget.isProducer
                      ? 'Nonaktifkan Produser'
                      : 'Nonaktifkan User',
                  subtitle: 'Tinjau akun sebelum menonaktifkan',
                  onBack: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: MediaQuery.withClampedTextScaling(
                    maxScaleFactor: 1.35,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                      children: [
                        // 1. Kartu Profil Produser (Image 1 & Image 4)
                        AdminCard(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 20),
                          child: Column(
                            children: [
                              Container(
                                width: 68,
                                height: 68,
                                decoration: BoxDecoration(
                                  color: AdminColors.infoBgOf(context),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  item.initials,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: accent,
                                  ),
                                ),
                              ),
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
                              const SizedBox(height: 3),
                              Text(
                                item.email,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: textSec,
                                ),
                              ),
                              const SizedBox(height: 10),
                              // Badge Terverifikasi
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AdminColors.successBgOf(context),
                                  border: Border.all(
                                      color: AdminColors.successBorderOf(
                                          context)),
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

                        if (widget.isProducer) ...[
                          // 2. Statistik Produser (Image 4 & 5)
                          const AdminSectionTitle('Statistik Produser'),
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
                                  '12.450',
                                  valueColor: AdminColors.pinkAccentOf(context),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // 3. Konser Aktif (Image 4 & 5)
                          const AdminSectionTitle('Konser Aktif'),
                          _buildActiveConcertCard(
                            context,
                            title: 'Soundwave Fest 2026',
                            subtitle: '12 Okt 2026 · Gate B',
                          ),
                          const SizedBox(height: 10),
                          _buildActiveConcertCard(
                            context,
                            title: 'Jazz Night 2026',
                            subtitle: '15 Nov 2026 · Balai Sarbini',
                          ),

                          const SizedBox(height: 16),

                          // 4. Banner Peringatan Konser (Image 4 & 5)
                          _buildWarningBanner(context),

                          const SizedBox(height: 16),

                          // 5. Input Alasan Penonaktifan Produser (Image 4 & 5)
                          _buildProducerReasonInput(
                              context, isFocusedOrFilled, textLength),
                        ] else ...[
                          // 2. Statistik User (Image 1)
                          const AdminSectionTitle('Statistik User'),
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

                          const SizedBox(height: 20),

                          // 3. Card Form Alasan Penonaktifan User (Image 1 & 2)
                          _buildUserReasonCard(
                              context, isFocusedOrFilled, textLength),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
            bottomNavigationBar: _buildBottomBar(context),
          );
        },
      ),
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

  Widget _buildActiveConcertCard(
    BuildContext context, {
    required String title,
    required String subtitle,
  }) {
    return AdminCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AdminColors.surfaceAltOf(context),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AdminColors.borderOf(context)),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.music_note_rounded,
              color: AdminColors.textSecondaryOf(context),
              size: 22,
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
                    color: AdminColors.textPrimaryOf(context),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AdminColors.textSecondaryOf(context),
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

  Widget _buildWarningBanner(BuildContext context) {
    final isDark = AdminColors.isDark(context);
    final fg = AdminColors.warningOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? AdminColors.warningBgOf(context)
            : const Color(0xFFFEF9C3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? AdminColors.warningBorderOf(context)
              : const Color(0xFFFDE047),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: Color(0xFFFACC15),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.priority_high_rounded,
              color: Color(0xFF78350F),
              size: 14,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '2 konser aktif akan otomatis dihentikan sementara',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? fg : const Color(0xFF78350F),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProducerReasonInput(
      BuildContext context, bool isFocusedOrFilled, int textLength) {
    final textPri = AdminColors.textPrimaryOf(context);
    final border = AdminColors.borderOf(context);
    return Container(
      decoration: BoxDecoration(
        color: AdminColors.surfaceAltOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isFocusedOrFilled ? AdminColors.dangerOf(context) : border,
          width: isFocusedOrFilled ? 1.5 : 1.0,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          TextField(
            key: const Key('admin_deactivate_reason_input'),
            controller: _reasonController,
            focusNode: _focusNode,
            minLines: 3,
            maxLines: 5,
            maxLength: _maxLength,
            buildCounter: (_,
                    {required currentLength,
                    required isFocused,
                    maxLength}) =>
                null,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: textPri,
            ),
            decoration: InputDecoration(
              hintText:
                  'Tulis alasan akun produser ini dinonaktifkan...\nContoh: pelanggaran kebijakan penjualan tiket.',
              hintStyle: TextStyle(
                fontSize: 13,
                color: AdminColors.textMutedOf(context),
                height: 1.45,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 8),
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
    );
  }

  Widget _buildUserReasonCard(
      BuildContext context, bool isFocusedOrFilled, int textLength) {
    final textPri = AdminColors.textPrimaryOf(context);
    final textSec = AdminColors.textSecondaryOf(context);
    final border = AdminColors.borderOf(context);
    return AdminCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AdminColors.dangerBgOf(context),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.priority_high_rounded,
                  color: AdminColors.dangerOf(context),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alasan Penonaktifan',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: textPri,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Wajib diisi. Alasan ini dikirim ke produser.',
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
          Container(
            decoration: BoxDecoration(
              color: AdminColors.surfaceAltOf(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    isFocusedOrFilled ? AdminColors.dangerOf(context) : border,
                width: isFocusedOrFilled ? 1.5 : 1.0,
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  key: const Key('admin_deactivate_reason_input'),
                  controller: _reasonController,
                  focusNode: _focusNode,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: _maxLength,
                  buildCounter: (_,
                          {required currentLength,
                          required isFocused,
                          maxLength}) =>
                      null,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: textPri,
                  ),
                  decoration: InputDecoration(
                    hintText:
                        'Tulis alasan akun produser ini dinonaktifkan...\nContoh: pelanggaran kebijakan penjualan tiket.',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: AdminColors.textMutedOf(context),
                      height: 1.4,
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

  Widget _buildBottomBar(BuildContext context) {
    final disabledBg = AdminColors.disabledBgOf(context);
    final disabledFg = AdminColors.disabledFgOf(context);
    return Container(
      decoration: BoxDecoration(
        color: AdminColors.surfaceOf(context),
        border: Border(top: BorderSide(color: AdminColors.borderOf(context))),
      ),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: SizedBox(
        height: 48,
        child: FilledButton.icon(
          key: const Key('admin_deactivate_confirm_button'),
          onPressed: _isValid ? _submit : null,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            disabledBackgroundColor: disabledBg,
            foregroundColor: Colors.white,
            disabledForegroundColor: disabledFg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
          icon: Icon(
            Icons.access_time_rounded,
            size: 20,
            color: _isValid ? Colors.white : disabledFg,
          ),
          label: const Text(
            'Nonaktifkan Akun',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
