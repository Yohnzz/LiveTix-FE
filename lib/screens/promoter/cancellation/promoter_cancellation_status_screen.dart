import 'package:flutter/material.dart';
import '../../../models/promoter_models.dart';
import '../../../services/promoter_data_service.dart';
import '../producer_customer_service_screen.dart';
import '../widgets/responsive_promoter_wrapper.dart';

class PromoterCancellationStatusScreen extends StatefulWidget {
  final PromoterConcertItem concert;
  final bool initialZeroTickets;

  const PromoterCancellationStatusScreen({
    super.key,
    required this.concert,
    this.initialZeroTickets = false,
  });

  @override
  State<PromoterCancellationStatusScreen> createState() =>
      _PromoterCancellationStatusScreenState();
}

class _PromoterCancellationStatusScreenState
    extends State<PromoterCancellationStatusScreen> {
  bool get _hasZeroTickets =>
      widget.initialZeroTickets || widget.concert.ticketsSold == 0;

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

          final ticketsSold = _hasZeroTickets ? 0 : widget.concert.ticketsSold;
          final totalCapacity = widget.concert.totalCapacity > 0
              ? widget.concert.totalCapacity
              : 5000;
          final progressRatio = (ticketsSold / totalCapacity).clamp(0.0, 1.0);

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Bar with < Kembali and Theme Toggle
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
                        'Status Pembatalan',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.concert.title,
                        style: TextStyle(
                          fontSize: 13,
                          color: subtextColor,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Purple Alert Banner: Menunggu Persetujuan Admin
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? const Color(0xFF28182E)
                              : const Color(0xFFFDF2FA), // Soft purple/magenta
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFD946EF).withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              decoration: const BoxDecoration(
                                color: Color(0xFF9333EA), // Purple circle
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Text(
                                  '!',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Menunggu Persetujuan Admin',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF9333EA),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Pengajuan sedang ditinjau. Estimasi 1x24 jam. Konser tetap aktif sampai disetujui.',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: isDarkMode
                                          ? Colors.white70
                                          : const Color(0xFF475467),
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Stepper Card
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
                          children: [
                            // Step 1: Pengajuan dikirim (Completed)
                            _buildTimelineStep(
                              icon: Container(
                                width: 24,
                                height: 24,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1B2A8C), // Navy checkmark
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 15,
                                ),
                              ),
                              title: 'Pengajuan dikirim',
                              subtitle: widget.concert.cancellationSubmissionDate,
                              isLast: false,
                              textColor: textColor,
                              subtextColor: subtextColor,
                            ),

                            // Step 2: Ditinjau admin (Active)
                            _buildTimelineStep(
                              icon: Container(
                                width: 24,
                                height: 24,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF9333EA), // Purple dot
                                  shape: BoxShape.circle,
                                ),
                              ),
                              title: 'Ditinjau admin',
                              subtitle: 'Sedang berlangsung',
                              isLast: false,
                              textColor: textColor,
                              subtextColor: subtextColor,
                            ),

                            // Step 3: Refund otomatis (Only shown if tickets sold > 0)
                            if (!_hasZeroTickets)
                              _buildTimelineStep(
                                icon: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFE4E7EC), // Grey dot
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                title: 'Refund otomatis ke pembeli',
                                subtitle: 'Menunggu persetujuan',
                                isLast: false,
                                textColor: textColor,
                                subtextColor: subtextColor,
                              ),

                            // Step 4 (or 3): Konser resmi dibatalkan
                            _buildTimelineStep(
                              icon: Container(
                                width: 24,
                                height: 24,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE4E7EC), // Grey dot
                                  shape: BoxShape.circle,
                                ),
                              ),
                              title: 'Konser resmi dibatalkan',
                              subtitle: 'Menunggu persetujuan',
                              isLast: true,
                              textColor: textColor,
                              subtextColor: subtextColor,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Card: Status pembelian tiket
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
                            // Header Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Status pembelian tiket',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: textColor,
                                  ),
                                ),
                                if (_hasZeroTickets)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isDarkMode
                                          ? Colors.white12
                                          : const Color(0xFFF2F4F7),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Belum ada',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: subtextColor,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Label: TIKET TERJUAL
                            Text(
                              'TIKET TERJUAL',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: subtextColor,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 4),

                            // Number: 4,200 / 5,000 or 0 / 5,000
                            Text(
                              '${PromoterTicketTier.formatNumber(ticketsSold)} / ${PromoterTicketTier.formatNumber(totalCapacity)}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1B2A8C), // Navy
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Progress Bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: progressRatio,
                                minHeight: 8,
                                backgroundColor: isDarkMode
                                    ? Colors.white12
                                    : const Color(0xFFE4E7EC),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    Color(0xFF1B2A8C)),
                              ),
                            ),
                            const SizedBox(height: 14),

                            if (!_hasZeroTickets) ...[
                              // Details: Pembeli terdampak & Dana dikembalikan
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Pembeli terdampak',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: subtextColor,
                                    ),
                                  ),
                                  Text(
                                    '${PromoterTicketTier.formatNumber(widget.concert.affectedBuyersCount)} orang',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: textColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Dana dikembalikan',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: subtextColor,
                                    ),
                                  ),
                                  Text(
                                    widget.concert.formattedTotalRefund,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: textColor,
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              Text(
                                'Tidak ada pembeli, jadi tidak ada refund yang perlu diproses.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: subtextColor,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Action Button 1: Hubungi Admin Konser (Outlined)
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const ProducerCustomerServiceScreen(),
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
                            'Hubungi Admin Konser',
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
                            Navigator.pop(context);
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

  Widget _buildTimelineStep({
    required Widget icon,
    required String title,
    required String subtitle,
    required bool isLast,
    required Color textColor,
    required Color subtextColor,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon and connecting line
          Column(
            children: [
              icon,
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: const Color(0xFFE4E7EC),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          // Texts
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: subtextColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
