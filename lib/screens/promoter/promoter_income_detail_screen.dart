import 'package:flutter/material.dart';
import '../../models/promoter_models.dart';
import '../../services/promoter_data_service.dart';
import 'promoter_withdrawal_history_screen.dart';
import 'widgets/responsive_promoter_wrapper.dart';

class PromoterIncomeDetailScreen extends StatelessWidget {
  final PromoterConcertFinanceSummary summary;

  const PromoterIncomeDetailScreen({
    super.key,
    required this.summary,
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

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Bar with Kembali & Theme Toggle
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
                            tooltip: 'Ganti Tema',
                            onPressed: service.toggleTheme,
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Title & Subtitle
                      Text(
                        'Detail Pendapatan',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        summary.concertTitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: subtextColor,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Card 1: PENDAPATAN BERSIH AKHIR (Hero Card)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PENDAPATAN BERSIH AKHIR',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: subtextColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                summary.formattedNet,
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFC2185B), // Magenta
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  summary.payoutStatus,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF039855), // Emerald green
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '•',
                                  style: TextStyle(
                                      fontSize: 11.5, color: subtextColor),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    summary.transferDestination,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: subtextColor,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Card 2: Rincian Transaksi
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Rincian Transaksi',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // VIP Tier row
                            _buildBreakdownRow(
                              label:
                                  'Tiket VIP (${PromoterTicketTier.formatNumber(summary.vipTicketsSold)} terjual)',
                              value:
                                  'Rp${PromoterTicketTier.formatNumber(summary.vipGross)}',
                              textColor: textColor,
                              subtextColor: subtextColor,
                            ),
                            const SizedBox(height: 12),

                            // Festival Tier row
                            _buildBreakdownRow(
                              label:
                                  'Tiket Festival (${PromoterTicketTier.formatNumber(summary.festivalTicketsSold)} terjual)',
                              value:
                                  'Rp${PromoterTicketTier.formatNumber(summary.festivalGross)}',
                              textColor: textColor,
                              subtextColor: subtextColor,
                            ),
                            const SizedBox(height: 14),

                            // Dashed Divider
                            CustomPaint(
                              painter: _DashedLinePainter(
                                color: isDarkMode
                                    ? Colors.white24
                                    : const Color(0xFFE4E7EC),
                              ),
                              child: const SizedBox(
                                width: double.infinity,
                                height: 1,
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Total Penjualan Kotor
                            _buildBreakdownRow(
                              label: 'Total Penjualan Kotor',
                              value: summary.formattedGross,
                              isBold: true,
                              textColor: textColor,
                              subtextColor: textColor,
                            ),
                            const SizedBox(height: 10),

                            // Potongan Pajak & Sistem (5%)
                            _buildBreakdownRow(
                              label:
                                  'Potongan Pajak & Sistem (${summary.systemFeePercent.toInt()}%)',
                              value: summary.formattedSystemFee,
                              valueColor: const Color(0xFFD92D20), // Red
                              textColor: textColor,
                              subtextColor: subtextColor,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Card 3: Status & Metode Pencairan
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Status & Metode Pencairan',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Tanggal Transfer',
                                  style: TextStyle(
                                      fontSize: 12.5, color: subtextColor),
                                ),
                                Text(
                                  summary.transferDate,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: textColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'ID Transaksi Payout',
                                  style: TextStyle(
                                      fontSize: 12.5, color: subtextColor),
                                ),
                                Text(
                                  summary.payoutTransactionId,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1B2A8C), // Navy
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // Bottom Sticky Navy Button: "Riwayat Penarikan"
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const PromoterWithdrawalHistoryScreen(),
                        ),
                      );
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
                      'Riwayat Penarikan',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBreakdownRow({
    required String label,
    required String value,
    Color? valueColor,
    bool isBold = false,
    required Color textColor,
    required Color subtextColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: isBold ? textColor : subtextColor,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: valueColor ?? textColor,
          ),
        ),
      ],
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;

  const _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    const dashWidth = 4.0;
    const dashSpace = 3.0;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, 0),
        Offset(startX + dashWidth, 0),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
