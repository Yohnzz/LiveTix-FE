import 'package:flutter/material.dart';
import '../../models/approval_models.dart';
import 'admin_refund_monitoring_screen.dart';
import 'admin_shell.dart';
import 'widgets/admin_theme.dart';
import 'widgets/admin_widgets.dart';

/// Layar Konfirmasi Hasil Pembatalan Disetujui (Image 1).
class AdminCancellationApprovedScreen extends StatelessWidget {
  final ConcertSubmissionModel concert;
  final DateTime decidedAt;

  const AdminCancellationApprovedScreen({
    super.key,
    required this.concert,
    required this.decidedAt,
  });

  @override
  Widget build(BuildContext context) {
    final buyerCount = ApprovalFormat.thousands(concert.affectedBuyers);
    final refundAmount = ApprovalFormat.rupiah(concert.refundAmount);
    final refundSummary = concert.soldTickets == 0
        ? '0 orang · Rp0'
        : '$buyerCount orang · $refundAmount';
    final dateStr = ApprovalFormat.dayMonthYear(decidedAt);
    final timeStr =
        '${decidedAt.hour.toString().padLeft(2, '0')}:${decidedAt.minute.toString().padLeft(2, '0')}';

    return AdminScope(
      child: Builder(
        builder: (context) {
          final textPri = AdminColors.textPrimaryOf(context);
          final textSec = AdminColors.textSecondaryOf(context);
          final accent = AdminColors.accentOf(context);
          final border = AdminColors.borderOf(context);
          final surface = AdminColors.surfaceOf(context);

          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) {
                AdminNavigation.reset();
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
            child: Scaffold(
              backgroundColor: AdminColors.bgOf(context),
              body: Column(
                children: [
                  // Header Gradien dengan Ikon Centang (Image 1)
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF5B21B6),
                          Color(0xFF7C3AED),
                          Color(0xFF9333EA),
                          Color(0xFFC026D3),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 36, 20, 48),
                        child: Column(
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 16,
                                    offset: Offset(0, 6),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.check_rounded,
                                size: 40,
                                color: Color(0xFF6D28D9),
                              ),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'Pembatalan Disetujui!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Refund otomatis diproses ke pembeli',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Kartu Ringkasan Pembatalan
                  Expanded(
                    child: MediaQuery.withClampedTextScaling(
                      maxScaleFactor: 1.35,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                        children: [
                          AdminCard(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Nama Konser',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: textSec,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  concert.title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: textPri,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Divider(height: 1, color: border),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Tanggal Disetujui',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: textSec,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '$dateStr, $timeStr',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: textPri,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AdminColors.dangerBgOf(context),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        'Dibatalkan',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AdminColors.dangerOf(context),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Divider(height: 1, color: border),
                                const SizedBox(height: 16),
                                Text(
                                  'Refund ke pembeli',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: textSec,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  refundSummary,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: accent,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Pembeli dan produser sudah dinotifikasi.',
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  const AdminRefundMonitoringScreen(),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          side: BorderSide(color: accent, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Lihat Pantau Refund',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: accent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      FilledButton(
                        onPressed: () {
                          AdminNavigation.reset();
                          Navigator.of(context)
                              .popUntil((route) => route.isFirst);
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
                        child: const Text(
                          'Kembali ke Beranda',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
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
}
