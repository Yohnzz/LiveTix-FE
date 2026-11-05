import 'package:flutter/material.dart';
import '../../models/promoter_models.dart';
import '../../services/promoter_data_service.dart';
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
                    color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.03),
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
                      Text(
                        'TOTAL KONSER',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: subtextColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B2A8C).withValues(alpha: 0.08),
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
                    color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.03),
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
                      Text(
                        'TIKET TERJUAL',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: subtextColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC2185B).withValues(alpha: 0.08),
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
                    color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.03),
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
                            fontSize: 14.5,
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
                            color: Color(0xFFF3E8FF), // Soft purple-pink
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              service.promoterInitials,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF7E22CE), // Purple/Magenta
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
                  const SizedBox(height: 4),
                  Text(
                    'Pantau performa penjualan tiket & event konser aktif',
                    style: TextStyle(
                      fontSize: 12.5,
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

                  const SizedBox(height: 24),

                  // Section: Tren Penjualan 7 Hari Terakhir (Sesuai Referensi Gambar User)
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
                                  fontWeight: FontWeight.w800,
                                  color: textColor,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 14),
                              SalesTrendBarChart(isDarkMode: isDarkMode),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
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
                                      fontWeight: FontWeight.w800,
                                      color: textColor,
                                      letterSpacing: -0.2,
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
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFFC2185B),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              _buildUpcomingConcertCard(
                                service: service,
                                cardBg: cardBg,
                                cardBorder: cardBorder,
                                textColor: textColor,
                                subtextColor: subtextColor,
                                isDarkMode: isDarkMode,
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
                        fontWeight: FontWeight.w800,
                        color: textColor,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Mobile Bar Chart exactly matching user reference image
                    SalesTrendBarChart(isDarkMode: isDarkMode),
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
                              fontWeight: FontWeight.w800,
                              color: textColor,
                              letterSpacing: -0.2,
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
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFC2185B),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildUpcomingConcertCard(
                      service: service,
                      cardBg: cardBg,
                      cardBorder: cardBorder,
                      textColor: textColor,
                      subtextColor: subtextColor,
                      isDarkMode: isDarkMode,
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

  Widget _buildUpcomingConcertCard({
    required PromoterDataService service,
    required Color cardBg,
    required Color cardBorder,
    required Color textColor,
    required Color subtextColor,
    required bool isDarkMode,
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
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: cardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDarkMode ? 0.25 : 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                // Modern Artwork Container
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF1B2A8C), // Navy
                        Color(0xFFC2185B), // Magenta
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1B2A8C).withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.music_note_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Title and Metadata
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              concert.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF3),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'AKTIF',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF027A48),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            size: 12,
                            color: Color(0xFFC2185B),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              concert.dateAndVenue,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: subtextColor,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            size: 12,
                            color: subtextColor,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              concert.venueName,
                              style: TextStyle(
                                fontSize: 11,
                                color: subtextColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF667085),
                  size: 20,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
