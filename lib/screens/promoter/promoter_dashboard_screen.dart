import 'package:flutter/material.dart';
import '../../models/promoter_models.dart';
import '../../services/promoter_data_service.dart';
import '../../widgets/notification_bell_button.dart';
import 'widgets/concert_image_widget.dart';
import 'widgets/sales_trend_bar_chart.dart';

class PromoterDashboardScreen extends StatelessWidget {
  final VoidCallback? onNavigateToConcerts;
  final VoidCallback? onNavigateToProfile;
  final VoidCallback? onAddConcertPressed;

  const PromoterDashboardScreen({
    super.key,
    this.onNavigateToConcerts,
    this.onNavigateToProfile,
    this.onAddConcertPressed,
  });

  @override
  Widget build(BuildContext context) {
    final service = PromoterDataService();

    return ValueListenableBuilder<bool>(
      valueListenable: service.isDarkModeNotifier,
      builder: (context, isDarkMode, _) {
        return ValueListenableBuilder<List<PromoterConcertItem>>(
          valueListenable: service.concertsNotifier,
          builder: (context, _, __) {
            return ValueListenableBuilder<String>(
              valueListenable: service.promoterNameNotifier,
              builder: (context, ___, ____) {
                final textColor =
                    isDarkMode ? Colors.white : const Color(0xFF101828);
                final subtextColor =
                    isDarkMode ? Colors.white70 : const Color(0xFF667085);
                final cardBg =
                    isDarkMode ? const Color(0xFF1B2232) : Colors.white;
                final cardBorder =
                    isDarkMode ? Colors.white12 : const Color(0xFFE4E7EC);

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 850;

                    final totalKonserCard = Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: cardBorder),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black
                                .withValues(alpha: isDarkMode ? 0.2 : 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'TOTAL KONSER',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: subtextColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1B2A8C)
                                      .withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.festival_outlined,
                                  size: 16,
                                  color: Color(0xFF1B2A8C),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${service.totalConcerts}',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Aktif tahun ini',
                            style: TextStyle(
                              fontSize: 11,
                              color: subtextColor,
                            ),
                          ),
                        ],
                      ),
                    );

                    final tiketTerjualCard = Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: cardBorder),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black
                                .withValues(alpha: isDarkMode ? 0.2 : 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'TIKET TERJUAL',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: subtextColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFC2185B)
                                      .withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.confirmation_number_outlined,
                                  size: 16,
                                  color: Color(0xFFC2185B),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              service.formattedTicketsSold,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1B2A8C), // Navy
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            service.ticketsSoldGrowth,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFC2185B), // Magenta
                            ),
                          ),
                        ],
                      ),
                    );

                    final totalPendapatanCard = Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: cardBorder),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black
                                .withValues(alpha: isDarkMode ? 0.2 : 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  'TOTAL PENDAPATAN',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: subtextColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8FDF0), // Mint
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.arrow_drop_up_rounded,
                                      size: 16,
                                      color: Color(0xFF039855),
                                    ),
                                    Text(
                                      '${service.revenueGrowth}%',
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF039855),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              service.formattedTotalRevenue,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFC2185B), // Magenta
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );

                    return RefreshIndicator(
                      onRefresh: () async {
                        await service.refreshAllData();
                      },
                      color: const Color(0xFF1B2A8C),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top Brand & Avatar Row (Mepet Kanan)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          service.promoterName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: textColor,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7, vertical: 2.5),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                              0xFFF59E0B), // Orange amber pill
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          service.verificationBadge,
                                          style: const TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Matahari / Dark Mode Toggle & Profil Avatar (Mepet Kanan)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const NotificationBellButton(),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 36,
                                        minHeight: 36,
                                      ),
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
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: onNavigateToProfile,
                                      child: Container(
                                        width: 38,
                                        height: 38,
                                        decoration: const BoxDecoration(
                                          color: Color(
                                              0xFFF3E8FF), // Soft purple-pink
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            service.promoterInitials,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: Color(
                                                  0xFF7E22CE), // Purple/Magenta
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            const SizedBox(height: 6),

                            // Subtitle Headline
                            Text(
                              'Pantau performa penjualan tiket & event konser aktif',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: subtextColor,
                              ),
                            ),

                            const SizedBox(height: 18),

                            // Responsive Metrics Cards
                            if (isWide) ...[
                              Row(
                                children: [
                                  Expanded(child: totalKonserCard),
                                  const SizedBox(width: 12),
                                  Expanded(child: tiketTerjualCard),
                                  const SizedBox(width: 12),
                                  Expanded(child: totalPendapatanCard),
                                ],
                              ),
                            ] else ...[
                              Row(
                                children: [
                                  Expanded(child: totalKonserCard),
                                  const SizedBox(width: 12),
                                  Expanded(child: tiketTerjualCard),
                                ],
                              ),
                              const SizedBox(height: 12),
                              totalPendapatanCard,
                            ],

                            const SizedBox(height: 12),

                            // Section: Tren Penjualan 7 Hari Terakhir
                            if (isWide) ...[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Tren Penjualan (7 Hari Terakhir)',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: textColor,
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                        const SizedBox(height: 14),
                                        SalesTrendBarChart(
                                          isDarkMode: isDarkMode,
                                          salesData: service.weeklySales,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Konser Mendatang',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                                color: textColor,
                                                letterSpacing: -0.2,
                                              ),
                                            ),
                                            InkWell(
                                              onTap: onNavigateToConcerts,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              child: const Padding(
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: 4, vertical: 2),
                                                child: Text(
                                                  'Lihat Semua',
                                                  style: TextStyle(
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFFC2185B),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 14),
                                        // Upcoming concert card removed - keeping only the chart
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              Text(
                                'Tren Penjualan (7 Hari Terakhir)',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: textColor,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 14),
                              // Mobile Bar Chart: data nyata dari database (datar di 0 jika belum ada penjualan)
                              SalesTrendBarChart(
                                isDarkMode: isDarkMode,
                                salesData: service.weeklySales,
                              ),
                              const SizedBox(height: 12),
                            ],

                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}