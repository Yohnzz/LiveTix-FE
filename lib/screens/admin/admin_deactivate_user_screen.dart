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
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
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
                            decoration: const BoxDecoration(
                              color: Color(0xFFE8EEF5),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              item.initials,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E3A8A),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            item.companyName,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AdminColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.email,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AdminColors.textGrey,
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Badge Terverifikasi
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              border: Border.all(color: const Color(0xFF10B981)),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_rounded,
                                  size: 16,
                                  color: Color(0xFF10B981),
                                ),
                                SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Terverifikasi · 24 Okt 2026',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF059669),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Divider(height: 1, color: AdminColors.border),
                          const SizedBox(height: 12),
                          _buildRow('Telepon', item.phone),
                          const SizedBox(height: 8),
                          _buildRow('Alamat', item.address),
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
                              'Konser Diajukan',
                              '${item.proposedConcertsCount}',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMiniStat(
                              'Konser Aktif',
                              '${item.activeConcertsCount}',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMiniStat(
                              'Tiket Terjual',
                              '12.450',
                              valueColor: const Color(0xFFC2185B),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // 3. Konser Aktif (Image 4 & 5)
                      const AdminSectionTitle('Konser Aktif'),
                      _buildActiveConcertCard(
                        title: 'Soundwave Fest 2026',
                        subtitle: '12 Okt 2026 · Gate B',
                      ),
                      const SizedBox(height: 10),
                      _buildActiveConcertCard(
                        title: 'Jazz Night 2026',
                        subtitle: '15 Nov 2026 · Balai Sarbini',
                      ),

                      const SizedBox(height: 16),

                      // 4. Banner Peringatan Konser (Image 4 & 5)
                      _buildWarningBanner(),

                      const SizedBox(height: 16),

                      // 5. Input Alasan Penonaktifan Produser (Image 4 & 5)
                      _buildProducerReasonInput(isFocusedOrFilled, textLength),
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
                              const Text(
                                'Pembelian Tiket',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AdminColors.textGrey,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${item.ticketPurchases}',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AdminColors.textDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 3. Card Form Alasan Penonaktifan User (Image 1 & 2)
                      _buildUserReasonCard(isFocusedOrFilled, textLength),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, {Color? valueColor}) {
    return AdminCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: AdminColors.textGrey,
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
              color: valueColor ?? AdminColors.textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveConcertCard({
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
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.music_note_rounded,
              color: AdminColors.textGrey,
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
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AdminColors.textDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AdminColors.textGrey,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Aktif',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF059669),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF9C3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE047)),
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
          const Expanded(
            child: Text(
              '2 konser aktif akan otomatis dihentikan sementara',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF78350F),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProducerReasonInput(bool isFocusedOrFilled, int textLength) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isFocusedOrFilled
              ? const Color(0xFFDC2626)
              : const Color(0xFFCBD5E1),
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
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: AdminColors.textDark,
            ),
            decoration: const InputDecoration(
              hintText:
                  'Tulis alasan akun produser ini dinonaktifkan...\nContoh: pelanggaran kebijakan penjualan tiket.',
              hintStyle: TextStyle(
                fontSize: 13,
                color: Color(0xFF94A3B8),
                height: 1.45,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.bottomRight,
            child: Text(
              '$textLength/$_maxLength',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF94A3B8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserReasonCard(bool isFocusedOrFilled, int textLength) {
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
                decoration: const BoxDecoration(
                  color: Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.priority_high_rounded,
                  color: Color(0xFFEF4444),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alasan Penonaktifan',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AdminColors.textDark,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Wajib diisi. Alasan ini dikirim ke produser.',
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
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isFocusedOrFilled
                    ? const Color(0xFFDC2626)
                    : const Color(0xFFCBD5E1),
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
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AdminColors.textDark,
                  ),
                  decoration: const InputDecoration(
                    hintText:
                        'Tulis alasan akun produser ini dinonaktifkan...\nContoh: pelanggaran kebijakan penjualan tiket.',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF94A3B8),
                      height: 1.4,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Text(
                    '$textLength/$_maxLength',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
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

  Widget _buildRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AdminColors.textGrey,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '-' : value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AdminColors.textDark,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: const BoxDecoration(
        color: AdminColors.surface,
        border: Border(top: BorderSide(color: AdminColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: SizedBox(
        height: 48,
        child: FilledButton.icon(
          key: const Key('admin_deactivate_confirm_button'),
          onPressed: _isValid ? _submit : null,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            disabledBackgroundColor: const Color(0xFFE2E8F0),
            foregroundColor: Colors.white,
            disabledForegroundColor: const Color(0xFF94A3B8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
          icon: Icon(
            Icons.access_time_rounded,
            size: 20,
            color: _isValid ? Colors.white : const Color(0xFF94A3B8),
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
