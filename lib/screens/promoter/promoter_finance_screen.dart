import 'package:flutter/material.dart';
import '../../models/promoter_models.dart';
import '../../services/promoter_data_service.dart';
import 'promoter_income_detail_screen.dart';
import 'promoter_withdrawal_screen.dart';

class PromoterFinanceScreen extends StatefulWidget {
  const PromoterFinanceScreen({super.key});

  @override
  State<PromoterFinanceScreen> createState() => _PromoterFinanceScreenState();
}

class _PromoterFinanceScreenState extends State<PromoterFinanceScreen> {
  String _selectedPeriod = 'Semua Periode';

  void _showPeriodFilterDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pilih Periode Laporan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF101828),
              ),
            ),
            const SizedBox(height: 14),
            ...['Semua Periode', 'Bulan Ini (Okt 2026)', '30 Hari Terakhir', 'Tahun 2026'].map((period) {
              final isSelected = _selectedPeriod == period;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  period,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? const Color(0xFFC2185B) : const Color(0xFF101828),
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_rounded, color: Color(0xFFC2185B))
                    : null,
                onTap: () {
                  setState(() => _selectedPeriod = period);
                  Navigator.pop(ctx);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = PromoterDataService();

    return ValueListenableBuilder<bool>(
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

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar with Title "Pembayaran" & Sun Theme Icon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pembayaran',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ringkasan keuangan dan hasil penjualan tiket',
                          style: TextStyle(
                            fontSize: 13,
                            color: subtextColor,
                          ),
                        ),
                      ],
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

              const SizedBox(height: 20),

              // Hero Card: SALDO TERSEDIA (Dark Navy Box with Tarik Dana Button)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF142478), // Deep vibrant navy
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF142478).withValues(alpha: 0.28),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SALDO TERSEDIA',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white70,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ValueListenableBuilder<int>(
                      valueListenable: service.activeBalanceNotifier,
                      builder: (context, balance, _) {
                        return FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Rp${PromoterTicketTier.formatNumber(balance)}',
                            style: const TextStyle(
                              fontSize: 27,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            'Total Pendapatan: ${service.formattedTotalRevenue}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const PromoterWithdrawalScreen(),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFC2185B), // Magenta
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Tarik Dana',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(color: Colors.white24, height: 1),
                    const SizedBox(height: 12),
                    ValueListenableBuilder<int>(
                      valueListenable: service.pendingBalanceNotifier,
                      builder: (context, pendingBalance, _) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.lock_clock_rounded,
                              size: 16,
                              color: Color(0xFFFBBF24),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        'Saldo Tertahan: ',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: Colors.white70,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        'Rp${PromoterTicketTier.formatNumber(pendingBalance)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFFFDE68A),
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Dapat ditarik setelah waktu mulai konser terlewati',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.white60,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Section Header: "Daftar Hasil Konser" + "Semua Periode ▾"
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Daftar Hasil Konser',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                  InkWell(
                    onTap: _showPeriodFilterDialog,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: cardBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _selectedPeriod,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: subtextColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Concert Finance Cards List
              ValueListenableBuilder<List<PromoterConcertFinanceSummary>>(
                valueListenable: service.concertFinanceSummariesNotifier,
                builder: (context, concertList, _) {
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: concertList.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = concertList[index];
                      return _buildConcertFinanceCard(
                        item: item,
                        cardBg: cardBg,
                        cardBorder: cardBorder,
                        textColor: textColor,
                        subtextColor: subtextColor,
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 28),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConcertFinanceCard({
    required PromoterConcertFinanceSummary item,
    required Color cardBg,
    required Color cardBorder,
    required Color textColor,
    required Color subtextColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Concert Title & Detail Magenta Link
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  item.concertTitle,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
              ),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          PromoterIncomeDetailScreen(summary: item),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    'Detail',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFC2185B), // Magenta
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Row 1: Tiket Terjual
          _buildInfoRow(
            label: 'Tiket Terjual',
            value: item.formattedTicketsRatio,
            textColor: textColor,
            subtextColor: subtextColor,
          ),
          const SizedBox(height: 6),

          // Row 2: Kotor
          _buildInfoRow(
            label: 'Kotor',
            value: item.formattedGross,
            textColor: textColor,
            subtextColor: subtextColor,
          ),
          const SizedBox(height: 6),

          // Row 3: Biaya Sistem (5%)
          _buildInfoRow(
            label: 'Biaya Sistem (${item.systemFeePercent.toInt()}%)',
            value: item.formattedSystemFee,
            valueColor: const Color(0xFFD92D20), // Red
            textColor: textColor,
            subtextColor: subtextColor,
          ),
          const SizedBox(height: 6),

          // Row 4: Pendapatan Bersih (Navy Highlighted)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Pendapatan Bersih',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1B2A8C), // Navy
                ),
              ),
              Text(
                item.formattedNet,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1B2A8C), // Navy
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
    Color? valueColor,
    required Color textColor,
    required Color subtextColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: subtextColor,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: valueColor ?? textColor,
          ),
        ),
      ],
    );
  }
}
