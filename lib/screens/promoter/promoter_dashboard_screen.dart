import 'package:flutter/material.dart';
import '../../models/promoter_models.dart';
import '../../services/promoter_data_service.dart';

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
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TOTAL KONSER',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: subtextColor,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${service.totalConcerts}',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Aktif tahun ini',
                    style: TextStyle(
                      fontSize: 11.5,
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
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TIKET TERJUAL',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: subtextColor,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      service.formattedTicketsSold,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1B2A8C), // Navy
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    service.ticketsSoldGrowth,
                    style: const TextStyle(
                      fontSize: 11.5,
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
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cardBorder),
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
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: subtextColor,
                            letterSpacing: 0.4,
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
                                fontSize: 11,
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

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Brand & Avatar Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          service.promoterName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B), // Orange amber pill
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
                      const Spacer(),
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
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: onNavigateToProfile,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFCE7F3), // Soft pink
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              service.promoterInitials,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFC2185B), // Magenta
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // Headline
                  Text(
                    'Malam ini ada apa?',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                      letterSpacing: -0.3,
                    ),
                  ),

                  const SizedBox(height: 20),

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

                  const SizedBox(height: 24),

                  if (isWide) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tren Penjualan (7 Hari Terakhir)',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 18),
                              _buildSalesChart(isDarkMode),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Konser Mendatang',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: textColor,
                                    ),
                                  ),
                                  InkWell(
                                    onTap: onNavigateToConcerts,
                                    borderRadius: BorderRadius.circular(6),
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 2),
                                      child: Text(
                                        'Lihat Semua',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFFC2185B),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildUpcomingConcertCard(
                                service: service,
                                cardBg: cardBg,
                                cardBorder: cardBorder,
                                textColor: textColor,
                                subtextColor: subtextColor,
                              ),
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
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _buildSalesChart(isDarkMode),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'Konser Mendatang',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: onNavigateToConcerts,
                          borderRadius: BorderRadius.circular(6),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2),
                            child: Text(
                              'Lihat Semua',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFC2185B),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildUpcomingConcertCard(
                      service: service,
                      cardBg: cardBg,
                      cardBorder: cardBorder,
                      textColor: textColor,
                      subtextColor: subtextColor,
                    ),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSalesChart(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF161C28) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SizedBox(
        height: 90,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildBar(height: 28, isMagenta: false, tooltip: 'Sen: 850 tiket'),
            _buildBar(height: 44, isMagenta: false, tooltip: 'Sel: 1.150 tiket'),
            _buildBar(height: 24, isMagenta: false, tooltip: 'Rab: 720 tiket'),
            _buildBar(height: 52, isMagenta: false, tooltip: 'Kam: 1.480 tiket'),
            _buildBar(height: 72, isMagenta: true, tooltip: 'Jum (Peak): 2.150 tiket'),
            _buildBar(height: 38, isMagenta: false, tooltip: 'Sab: 1.050 tiket'),
            _buildBar(height: 64, isMagenta: false, tooltip: 'Min: 1.820 tiket'),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingConcertCard({
    required PromoterDataService service,
    required Color cardBg,
    required Color cardBorder,
    required Color textColor,
    required Color subtextColor,
  }) {
    return ValueListenableBuilder<List<PromoterConcertItem>>(
      valueListenable: service.concertsNotifier,
      builder: (context, concerts, _) {
        final concert = concerts.isNotEmpty
            ? concerts.first
            : const PromoterConcertItem(
                id: '1',
                title: 'Soundwave Fest 2026',
                dateAndVenue: '12 Okt · Stadion Gajayana',
                date: 'Minggu, 12 Oktober 2026',
                venueName: 'Stadion Gajayana',
                venueAddress: 'Malang',
              );

        return InkWell(
          onTap: onNavigateToConcerts,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cardBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCE7F3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.music_note_rounded,
                      color: Color(0xFFC2185B),
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        concert.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        concert.dateAndVenue,
                        style: TextStyle(
                          fontSize: 12,
                          color: subtextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.favorite_border_rounded,
                      size: 16,
                      color: Color(0xFFC2185B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      concert.likesCount,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFC2185B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBar({
    required double height,
    required bool isMagenta,
    String? tooltip,
  }) {
    final barWidget = Container(
      width: 20,
      height: height,
      decoration: BoxDecoration(
        color: isMagenta
            ? const Color(0xFFC2185B) // Magenta peak
            : const Color(0xFF1B2A8C), // Navy blue
        borderRadius: BorderRadius.circular(6),
      ),
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip,
        child: barWidget,
      );
    }
    return barWidget;
  }
}
