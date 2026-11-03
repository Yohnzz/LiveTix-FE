import 'package:flutter/material.dart';
import '../../../models/promoter_models.dart';
import '../../../services/promoter_data_service.dart';
import '../widgets/responsive_promoter_wrapper.dart';

class PromoterCancellationApprovedScreen extends StatelessWidget {
  final PromoterConcertItem concert;

  const PromoterCancellationApprovedScreen({
    super.key,
    required this.concert,
  });

  @override
  Widget build(BuildContext context) {
    final service = PromoterDataService();

    return ResponsivePromoterWrapper(
      child: ValueListenableBuilder<bool>(
        valueListenable: service.isDarkModeNotifier,
        builder: (context, isDarkMode, _) {
          final textColor =
              isDarkMode ? Colors.white : const Color(0xFF101828);
          final subtextColor =
              isDarkMode ? Colors.white70 : const Color(0xFF667085);
          final cardBg =
              isDarkMode ? const Color(0xFF1B2232) : Colors.white;
          final cardBorder =
              isDarkMode ? Colors.white12 : const Color(0xFFE4E7EC);

          final ticketsSold = concert.ticketsSold > 0 ? concert.ticketsSold : 4200;
          final refundDone = concert.refundDoneCount > 0 ? concert.refundDoneCount : 2940;
          final refundProcessing = concert.refundProcessingCount > 0 ? concert.refundProcessingCount : 1050;
          final refundPending = concert.refundPendingAccountCount > 0 ? concert.refundPendingAccountCount : 210;
          final progressRatio = (refundDone / ticketsSold).clamp(0.0, 1.0);

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Bar with < Kembali
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          InkWell(
                            onTap: () => Navigator.pop(context),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.chevron_left_rounded,
                                    size: 22,
                                    color: textColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Kembali',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: textColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              isDarkMode
                                  ? Icons.dark_mode_outlined
                                  : Icons.wb_sunny_outlined,
                              size: 22,
                              color: textColor,
                            ),
                            onPressed: service.toggleTheme,
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Title & Concert Name
                      Text(
                        'Pembatalan Disetujui',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        concert.title,
                        style: TextStyle(
                          fontSize: 13,
                          color: subtextColor,
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Card 1: Konser resmi dibatalkan [Disetujui]
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cardBorder),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Konser resmi dibatalkan',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: textColor,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 3.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8FDF0), // Mint green
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'Disetujui',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF039855), // Green
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Disetujui admin pada ${concert.cancellationApprovalDate ?? '20 Okt 2026, 09:15'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: subtextColor,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Card 2: Progres refund pembeli
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cardBorder),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Progres refund pembeli',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Main Stat: 2,940 / 4,200 tiket selesai
                            Text(
                              '${PromoterTicketTier.formatNumber(refundDone)} / ${PromoterTicketTier.formatNumber(ticketsSold)} tiket selesai',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1B2A8C), // Navy
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Green Progress Bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: progressRatio,
                                minHeight: 8,
                                backgroundColor: isDarkMode
                                    ? Colors.white12
                                    : const Color(0xFFE4E7EC),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    Color(0xFF039855)), // Green
                              ),
                            ),

                            const SizedBox(height: 18),

                            // Breakdown items
                            _buildRefundStatRow(
                              dotColor: const Color(0xFF039855), // Green
                              label: 'Refund selesai',
                              value: PromoterTicketTier.formatNumber(refundDone),
                              textColor: textColor,
                              subtextColor: subtextColor,
                            ),
                            const SizedBox(height: 10),
                            _buildRefundStatRow(
                              dotColor: const Color(0xFF1B2A8C), // Navy
                              label: 'Sedang diproses',
                              value:
                                  PromoterTicketTier.formatNumber(refundProcessing),
                              textColor: textColor,
                              subtextColor: subtextColor,
                            ),
                            const SizedBox(height: 10),
                            _buildRefundStatRow(
                              dotColor: const Color(0xFFD92D20), // Red
                              label: 'Menunggu data rekening pembeli',
                              value:
                                  PromoterTicketTier.formatNumber(refundPending),
                              textColor: textColor,
                              subtextColor: subtextColor,
                            ),

                            const SizedBox(height: 16),
                            const Divider(height: 1),
                            const SizedBox(height: 12),

                            Text(
                              'Total ${PromoterTicketTier.formatNumber(ticketsSold)} tiket · ${concert.formattedTotalRefund}',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: subtextColor,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Info banner (light purple/periwinkle)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? const Color(0xFF1A1F36)
                              : const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          'Pembeli sudah diberi tahu lewat notifikasi dan mengisi tujuan refund di aplikasi mereka.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode
                                ? Colors.white70
                                : const Color(0xFF475467),
                            height: 1.4,
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Action Button 1: Unduh Laporan Refund (Outlined)
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(Icons.download_done_rounded,
                                        color: Colors.white, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Laporan refund ${concert.title} berhasil diunduh (PDF)!',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                                backgroundColor: const Color(0xFF1B2A8C),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                                color: Color(0xFF1B2A8C), width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Unduh Laporan Refund',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1B2A8C),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Action Button 2: Kembali ke Dasbor (Solid Navy)
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.popUntil(
                                context, (route) => route.isFirst);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1B2A8C), // Navy
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Kembali ke Dasbor',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRefundStatRow({
    required Color dotColor,
    required String label,
    required String value,
    required Color textColor,
    required Color subtextColor,
  }) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              color: subtextColor,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: textColor,
          ),
        ),
      ],
    );
  }
}
