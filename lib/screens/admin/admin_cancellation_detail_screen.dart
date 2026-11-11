import 'package:flutter/material.dart';
import '../../models/approval_models.dart';
import '../../services/admin_service.dart';
import 'admin_cancellation_approved_screen.dart';
import 'admin_review_cancellation_screen.dart';
import 'widgets/admin_theme.dart';
import 'widgets/admin_widgets.dart';

/// Layar Detail Pembatalan Konser (Image 3) dan Modal Konfirmasi (Image 5).
class AdminCancellationDetailScreen extends StatelessWidget {
  final ConcertSubmissionModel concert;

  const AdminCancellationDetailScreen({
    super.key,
    required this.concert,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = ApprovalFormat.dayMonthYear(concert.dateTime);
    final timeStr = ApprovalFormat.time(concert.dateTime);
    final soldFormatted = ApprovalFormat.thousands(concert.soldTickets);
    final totalFormatted = ApprovalFormat.thousands(concert.totalCapacity);
    final progressValue = concert.totalCapacity > 0
        ? (concert.soldTickets / concert.totalCapacity).clamp(0.0, 1.0)
        : 0.84;

    return AdminScope(
      child: Builder(
        builder: (context) {
          final isDark = AdminColors.isDark(context);
          final textPri = AdminColors.textPrimaryOf(context);
          final textSec = AdminColors.textSecondaryOf(context);
          final accent = AdminColors.accentOf(context);
          final border = AdminColors.borderOf(context);
          final surface = AdminColors.surfaceOf(context);
          final surfaceAlt = AdminColors.surfaceAltOf(context);
          final dangerCol = AdminColors.dangerOf(context);

          return Scaffold(
            backgroundColor: AdminColors.bgOf(context),
            body: Column(
              children: [
                AdminHeader(
                  title: 'Detail Pembatalan',
                  subtitle: 'Tinjau pengajuan pembatalan konser',
                  onBack: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: MediaQuery.withClampedTextScaling(
                    maxScaleFactor: 1.35,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                      children: [
                        // 1. Kartu Info Ringkasan Konser
                        AdminCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      concert.title,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: textPri,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AdminColors.dangerBgOf(context),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      'Pembatalan',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: dangerCol,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Produser: ${concert.promoterName}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: textSec,
                                ),
                              ),
                              const SizedBox(height: 14),
                              _buildInfoRow(
                                context,
                                'Tanggal & Waktu',
                                '$dateStr · $timeStr',
                              ),
                              const SizedBox(height: 8),
                              _buildInfoRow(
                                context,
                                'Lokasi Venue',
                                concert.venue,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // 2. Kartu Alasan Pembatalan dengan Aksen Merah di Sisi Kiri
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            decoration: BoxDecoration(
                              color: surface,
                              border: Border.all(
                                  color: AdminColors.dangerBorderOf(context)),
                              boxShadow: isDark
                                  ? null
                                  : [
                                      BoxShadow(
                                        color:
                                            Colors.black.withValues(alpha: 0.03),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                            ),
                            child: Stack(
                              children: [
                                Positioned(
                                  left: 0,
                                  top: 0,
                                  bottom: 0,
                                  width: 4.5,
                                  child:
                                      Container(color: const Color(0xFFDC2626)),
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(18, 16, 16, 16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              'Alasan Pembatalan',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: dangerCol,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            concert.cancellationDate ??
                                                '19 Okt 2026, 14:02',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: textSec,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        concert.cancellationReason ??
                                            'Izin keramaian dari kepolisian belum terbit sehingga acara tidak dapat dilaksanakan sesuai jadwal. Kami memutuskan membatalkan konser.',
                                        style: TextStyle(
                                          fontSize: 13,
                                          height: 1.5,
                                          color: textPri,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: surfaceAlt,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(color: border),
                                        ),
                                        child: Text(
                                          'Lampiran: ${concert.attachmentName ?? 'surat_izin_polres.pdf'}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: accent,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // 3. Kartu Dampak Pembatalan atau Status Pembelian Tiket
                        AdminCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (concert.soldTickets == 0) ...[
                                // Image 4: Status Pembelian Tiket (Belum ada tiket terjual)
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'Status Pembelian Tiket',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: textPri,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: surfaceAlt,
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        'Belum ada',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: textSec,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'Tiket terjual',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: textSec,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        '0 / $totalFormatted',
                                        textAlign: TextAlign.end,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: accent,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: LinearProgressIndicator(
                                    value: 0.0,
                                    minHeight: 8,
                                    backgroundColor: AdminColors.disabledBgOf(
                                        context),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      accent,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AdminColors.infoBgOf(context),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Tidak ada pembeli, jadi tidak ada refund.',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: AdminColors.infoOf(context),
                                          height: 1.4,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Konser langsung ditutup setelah disetujui.',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: AdminColors.infoOf(context),
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ] else ...[
                                Text(
                                  'Dampak Pembatalan',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: textPri,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'Tiket terjual',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: textSec,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        '$soldFormatted / $totalFormatted',
                                        textAlign: TextAlign.end,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: accent,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: LinearProgressIndicator(
                                    value: progressValue,
                                    minHeight: 8,
                                    backgroundColor: AdminColors.disabledBgOf(
                                        context),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      accent,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                _buildInfoRow(
                                  context,
                                  'Pembeli terdampak',
                                  '${ApprovalFormat.thousands(concert.affectedBuyers)} orang',
                                ),
                                const SizedBox(height: 8),
                                _buildInfoRow(
                                  context,
                                  'Refund 100% ke pembeli',
                                  ApprovalFormat.rupiah(concert.refundAmount),
                                ),
                                const SizedBox(height: 8),
                                _buildInfoRow(
                                  context,
                                  'Dana produser ditahan',
                                  ApprovalFormat.rupiah(
                                      concert.escrowWithheldAmount),
                                ),
                              ],
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
              decoration: BoxDecoration(
                color: surface,
                border: Border(top: BorderSide(color: border)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('admin_cancellation_reject_button'),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  AdminReviewCancellationScreen(concert: concert),
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
                        child: const Text('Tolak Pembatalan'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        key: const Key('admin_cancellation_approve_button'),
                        onPressed: () => _openConfirmationSheet(context),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor:
                              AdminColors.primaryButtonBgOf(context),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: const Text('Setujui Pembatalan'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: AdminColors.textSecondaryOf(context),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AdminColors.textPrimaryOf(context),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openConfirmationSheet(BuildContext context) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConfirmCancellationSheet(concert: concert),
    );

    if (confirmed == true && context.mounted) {
      AdminService().approveCancellation(concert.id);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => AdminCancellationApprovedScreen(
            concert: concert,
            decidedAt: DateTime.now(),
          ),
        ),
      );
    }
  }
}

/// Modal BottomSheet Konfirmasi Pembatalan Konser (Image 5).
class _ConfirmCancellationSheet extends StatelessWidget {
  final ConcertSubmissionModel concert;

  const _ConfirmCancellationSheet({required this.concert});

  @override
  Widget build(BuildContext context) {
    final buyerCountFormatted =
        ApprovalFormat.thousands(concert.affectedBuyers);
    final refundAmountFormatted = ApprovalFormat.rupiah(concert.refundAmount);

    return AdminScope(
      child: Builder(
        builder: (context) {
          final textPri = AdminColors.textPrimaryOf(context);
          final textSec = AdminColors.textSecondaryOf(context);
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
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.35,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AdminColors.borderOf(context),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Setujui pembatalan konser?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: textPri,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Yang akan terjadi otomatis:',
                        style: TextStyle(
                          fontSize: 13,
                          color: textSec,
                        ),
                      ),
                      const SizedBox(height: 18),

                      // 4 Langkah Otomatis
                      _buildStepRow(
                        context,
                        number: '1',
                        title: 'Konser berstatus Dibatalkan',
                        subtitle: 'Penjualan tiket ditutup seketika',
                      ),
                      const SizedBox(height: 14),
                      if (concert.soldTickets == 0) ...[
                        _buildStepRow(
                          context,
                          number: '2',
                          title: 'Tidak ada refund ke pembeli',
                          subtitle: '0 pembeli terdampak pembatalan',
                        ),
                      ] else ...[
                        _buildStepRow(
                          context,
                          number: '2',
                          title: 'Refund 100% ke $buyerCountFormatted pembeli',
                          subtitle:
                              'Total $refundAmountFormatted termasuk biaya layanan',
                        ),
                      ],
                      const SizedBox(height: 14),
                      _buildStepRow(
                        context,
                        number: '3',
                        title: 'Pembeli dinotifikasi',
                        subtitle: 'Mengisi rekening / e-wallet di aplikasi',
                      ),
                      const SizedBox(height: 14),
                      _buildStepRow(
                        context,
                        number: '4',
                        title: 'Produser diberi tahu',
                        subtitle: 'Laporan refund tersedia di dasbor produser',
                      ),

                      const SizedBox(height: 18),

                      // Peringatan Amber
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AdminColors.warningBgOf(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AdminColors.warningBorderOf(context)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: AdminColors.warningOf(context),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Tindakan ini tidak dapat diurungkan.',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AdminColors.warningOf(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Tombol Aksi
                      FilledButton(
                        key: const Key(
                            'admin_confirm_cancellation_submit_button'),
                        onPressed: () => Navigator.of(context).pop(true),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor:
                              AdminColors.primaryButtonBgOf(context),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: const Text('Ya, Setujui Pembatalan'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          foregroundColor: accent,
                          side: BorderSide(color: accent, width: 1.2),
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
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStepRow(
    BuildContext context, {
    required String number,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AdminColors.primaryButtonBgOf(context),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
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
                  color: AdminColors.textPrimaryOf(context),
                ),
              ),
              const SizedBox(height: 2),
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
      ],
    );
  }
}
