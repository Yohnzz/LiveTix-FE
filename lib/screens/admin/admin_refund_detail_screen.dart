import 'package:flutter/material.dart';
import '../../models/approval_models.dart';
import '../../services/admin_service.dart';
import 'widgets/admin_theme.dart';
import 'widgets/admin_widgets.dart';

/// Layar Detail Refund per Konser (Image 3).
class AdminRefundDetailScreen extends StatelessWidget {
  final String concertId;

  const AdminRefundDetailScreen({
    super.key,
    required this.concertId,
  });

  @override
  Widget build(BuildContext context) {
    final service = AdminService();
    final detail = service.refundDetailByConcertId(concertId) ??
        service.refundMonitoringNotifier.value.firstOrNull ??
        const RefundMonitoringModel(
          concertId: 'cnc-001',
          title: 'Soundwave Fest 2026',
          status: 'Berjalan',
          refundedTickets: 2940,
          totalTickets: 4200,
          percent: 70,
          refundedAmount: 1480500000,
          totalAmount: 2115000000,
          processingTickets: 1050,
          needDataTickets: 210,
          deadlineDate: '30 Nov 2026',
          remainingDays: 42,
          buyers: [
            RefundBuyerModel(
              name: 'Rafi Ardiansyah',
              tickets: 2,
              paymentInfo: 'BCA ••9012',
              status: 'Selesai',
            ),
            RefundBuyerModel(
              name: 'Budi Santoso',
              tickets: 4,
              paymentInfo: 'Belum isi rekening',
              status: 'Perlu data',
            ),
            RefundBuyerModel(
              name: 'Nadia Putri',
              tickets: 1,
              paymentInfo: 'GoPay ••4410',
              status: 'Diproses',
            ),
          ],
        );

    final progress = detail.totalTickets > 0
        ? (detail.refundedTickets / detail.totalTickets).clamp(0.0, 1.0)
        : 0.0;
    final refundedFormatted = ApprovalFormat.thousands(detail.refundedTickets);
    final totalFormatted = ApprovalFormat.thousands(detail.totalTickets);
    final currentAmountFormatted = ApprovalFormat.rupiah(detail.refundedAmount);
    final totalAmountFormatted = ApprovalFormat.rupiah(detail.totalAmount);
    final selesaiCountFormatted =
        ApprovalFormat.thousands(detail.refundedTickets);
    final diprosesCountFormatted =
        ApprovalFormat.thousands(detail.processingTickets);
    final perluDataCountFormatted =
        ApprovalFormat.thousands(detail.needDataTickets);

    return AdminScope(
      child: Builder(
        builder: (context) {
          final textPri = AdminColors.textPrimaryOf(context);
          final textSec = AdminColors.textSecondaryOf(context);
          final accent = AdminColors.accentOf(context);
          final surface = AdminColors.surfaceOf(context);
          final border = AdminColors.borderOf(context);

          return Scaffold(
            backgroundColor: AdminColors.bgOf(context),
            body: Column(
              children: [
                // Header Gradien dengan Tombol Kembali (Image 3)
                AdminHeader(
                  title: 'Detail Refund',
                  subtitle: detail.title,
                  onBack: () => Navigator.of(context).maybePop(),
                ),

                // Konten Layar Detail Refund
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    children: [
                      // 1. Kartu Progres Refund
                      AdminCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Progres Refund',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: textPri,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AdminColors.warningBgOf(context),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    'Berjalan',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AdminColors.warningOf(context),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '$refundedFormatted / $totalFormatted tiket',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: accent,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 8,
                                backgroundColor: AdminColors.isDark(context)
                                    ? AdminColors.darkBorder
                                    : const Color(0xFFE5E7EB),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF10B981),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '$currentAmountFormatted dari $totalAmountFormatted',
                              style: TextStyle(
                                fontSize: 13,
                                color: textSec,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // 2. Tiga Kartu Metrik Selesai, Diproses, Perlu Data
                      Row(
                        children: [
                          Expanded(
                            child: AdminCard(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    selesaiCountFormatted,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: AdminColors.successOf(context),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Selesai',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: textSec,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: AdminCard(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    diprosesCountFormatted,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: accent,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Diproses',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: textSec,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: AdminCard(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    perluDataCountFormatted,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: AdminColors.dangerOf(context),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Perlu data',
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
                      ),

                      const SizedBox(height: 12),

                      // 3. Kartu Batas Refund Pembeli
                      AdminCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Batas refund pembeli',
                              style: TextStyle(
                                fontSize: 12,
                                color: textSec,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${detail.deadlineDate} · sisa ${detail.remainingDays} hari',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: textPri,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 4. Section Daftar Pembeli
                      const AdminSectionTitle('Daftar Pembeli'),
                      const SizedBox(height: 8),

                      for (final buyer in detail.buyers) ...[
                        _buildBuyerCard(context, buyer),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                color: surface,
                border: Border(top: BorderSide(color: border)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Pengingat berhasil dikirim ke ${detail.needDataTickets} pembeli yang belum mengisi rekening.',
                                ),
                              ),
                            );
                        },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          side: BorderSide(
                            color: accent,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Kirim Pengingat (${detail.needDataTickets})',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: accent,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Laporan refund berhasil diekspor.'),
                              ),
                            );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              AdminColors.primaryButtonBgOf(context),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Ekspor Laporan',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
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

  Widget _buildBuyerCard(BuildContext context, RefundBuyerModel buyer) {
    final textPri = AdminColors.textPrimaryOf(context);
    final textSec = AdminColors.textSecondaryOf(context);
    final (Color bg, Color fg) = switch (buyer.status) {
      'Selesai' => (
          AdminColors.successBgOf(context),
          AdminColors.successOf(context),
        ),
      'Perlu data' => (
          AdminColors.dangerBgOf(context),
          AdminColors.dangerOf(context),
        ),
      _ => (
          AdminColors.warningBgOf(context),
          AdminColors.warningOf(context),
        ),
    };

    return AdminCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  buyer.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textPri,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${buyer.tickets} tiket · ${buyer.paymentInfo}',
                  style: TextStyle(
                    fontSize: 12,
                    color: textSec,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              buyer.status,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
