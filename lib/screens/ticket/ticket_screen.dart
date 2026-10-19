import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../models/ticket_order_model.dart';
import '../../services/dummy_data_service.dart';
import '../auth/login_screen.dart';
import '../refund/cancelled_ticket_detail_screen.dart';
import '../refund/refund_status_screen.dart';

class TicketScreen extends StatefulWidget {
  final bool isGuest;

  const TicketScreen({super.key, this.isGuest = false});

  @override
  State<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends State<TicketScreen> {
  int _selectedTabIndex = 0; // 0: Aktif, 1: Riwayat

  void _goToLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _onViewTicketPressed(UserTicketModel ticket) {
    if (ticket.status == 'Reffund' || ticket.isCancelled) {
      if (ticket.refundData != null) {
        // Jika sudah diajukan, tampilkan tracking status refund
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RefundStatusScreen(refund: ticket.refundData!),
          ),
        );
      } else {
        // Jika belum diajukan, tampilkan detail tiket dibatalkan untuk mengajukan refund
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CancelledTicketDetailScreen(ticket: ticket),
          ),
        );
      }
    } else {
      // Tiket Aktif normal -> Tampilkan modal E-Tiket Aktif
      _showActiveTicketModal(ticket);
    }
  }

  void _showActiveTicketModal(UserTicketModel ticket) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD0D5DD),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'TIKET RESMI AKTIF',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ),
                  Text(
                    ticket.bookingCode,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                ticket.concertTitle,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark),
              ),
              const SizedBox(height: 4),
              Text(
                '${ticket.date} · ${ticket.venue}',
                style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey),
              ),
              const SizedBox(height: 20),
              // QR Code
              Container(
                width: 140,
                height: 140,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Center(
                  child: Icon(Icons.qr_code_2_rounded, size: 110, color: Color(0xFF1D2939)),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Tunjukkan QR ini saat scan di gerbang masuk.',
                style: TextStyle(fontSize: 12, color: AppColors.textGrey),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B2A8C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Judul Sesuai Figma
              const Text(
                'Tiket saya',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 18),

              // Segmented Tab Toggle: "Aktif" & "Riwayat"
              _buildSegmentedTab(),
              const SizedBox(height: 20),

              // Konten Berdasarkan Role (Guest vs Logged-In User)
              Expanded(
                child: widget.isGuest
                    ? _buildGuestEmptyTicketView()
                    : _buildUserTicketView(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentedTab() {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTabIndex = 0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: _selectedTabIndex == 0 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _selectedTabIndex == 0
                      ? const [
                          BoxShadow(
                            color: Color(0x0A000000),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  'Aktif',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: _selectedTabIndex == 0 ? FontWeight.w700 : FontWeight.w500,
                    color: _selectedTabIndex == 0 ? AppColors.textDark : AppColors.textGrey,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTabIndex = 1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: _selectedTabIndex == 1 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _selectedTabIndex == 1
                      ? const [
                          BoxShadow(
                            color: Color(0x0A000000),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  'Riwayat',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: _selectedTabIndex == 1 ? FontWeight.w700 : FontWeight.w500,
                    color: _selectedTabIndex == 1 ? AppColors.textDark : AppColors.textGrey,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestEmptyTicketView() {
    return Center(
      child: CustomPaint(
        painter: _DashedRectPainter(
          color: const Color(0xFFD0D5DD),
          strokeWidth: 1.5,
          gap: 6.0,
          dash: 8.0,
          radius: 18,
        ),
        child: Container(
          width: double.infinity,
          height: 180,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Tidak Ada Tiket',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF344054),
                ),
              ),
              const SizedBox(height: 8),
              // Link Href interaktif menuju halaman Login
              GestureDetector(
                onTap: _goToLogin,
                child: const Text(
                  'Silahkan Login Terlebih Dahulu',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserTicketView() {
    return ValueListenableBuilder<List<UserTicketModel>>(
      valueListenable: DummyDataService().userTicketsNotifier,
      builder: (context, tickets, _) {
        final filteredTickets = _selectedTabIndex == 0
            ? tickets.where((t) => !t.isCompleted).toList()
            : tickets.where((t) => t.isCompleted).toList();

        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            ...filteredTickets.map((ticket) => _buildFigmaTicketCard(ticket)),
            const SizedBox(height: 8),

            // Kotak Bergaris Putus-putus "Belum ada tiket lain"
            _buildEmptyStateDashedBox(),
          ],
        );
      },
    );
  }

  Widget _buildFigmaTicketCard(UserTicketModel ticket) {
    final isRefund = ticket.status == 'Reffund' || ticket.isCancelled;
    final stripeColor = ticket.stripeColor ??
        (isRefund ? const Color(0xFFC2185B) : const Color(0xFF1B2A8C));
    final iconBgColor = ticket.iconBgColor ??
        (isRefund ? const Color(0xFFFCE7F3) : const Color(0xFFE0EAFF));
    final iconColor = ticket.iconColor ??
        (isRefund ? const Color(0xFFC2185B) : const Color(0xFF1B2A8C));

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Garis Warna Sisi Kiri (Biru / Magenta)
              Container(
                width: 5,
                color: stripeColor,
              ),

              // Isi Konten Tiket
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Bagian Atas: Icon + Title/Subtitle + Status Badge
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Kotak Icon Rounded dengan Lingkaran Konsentris
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: iconBgColor,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: iconColor, width: 2.2),
                                ),
                                child: Center(
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: iconColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Judul Konser & Subtitle
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ticket.concertTitle,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  ticket.concertSubtitle,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF667085),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${ticket.quantity} tiket · ${ticket.category}',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: stripeColor,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Kolom Kanan: Star Badge & Status Pill
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (ticket.hasStar)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF59E0B),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.star, size: 14, color: Colors.white),
                                ),
                              // Status Pill Badge (Aktif vs Reffund)
                              _buildStatusBadge(ticket.status),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Garis Putus-Putus Separator
                      const _CardDashedLine(),
                      const SizedBox(height: 10),

                      // Bagian Bawah: Sisa Hari & Tombol "Lihat tiket"
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${ticket.daysLeft} hari lagi',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF667085),
                            ),
                          ),
                          SizedBox(
                            height: 36,
                            child: ElevatedButton(
                              onPressed: () => _onViewTicketPressed(ticket),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1D2939), // Tombol gelap
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text(
                                'Lihat tiket',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color text;

    if (status == 'Aktif') {
      bg = const Color(0xFFECFDF5);
      text = const Color(0xFF10B981);
    } else if (status == 'Reffund' || status.toLowerCase().contains('refund')) {
      bg = const Color(0xFFFEE2E2);
      text = const Color(0xFFEF4444);
    } else {
      bg = const Color(0xFFF2F4F7);
      text = const Color(0xFF667085);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: text,
        ),
      ),
    );
  }

  Widget _buildEmptyStateDashedBox() {
    return CustomPaint(
      painter: _DashedRectPainter(
        color: const Color(0xFFD0D5DD),
        strokeWidth: 1.2,
        gap: 5.0,
        dash: 6.0,
        radius: 18,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        alignment: Alignment.center,
        child: const Column(
          children: [
            Text(
              'Belum ada tiket lain',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF344054),
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Cari konser berikutnya di beranda',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF667085),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardDashedLine extends StatelessWidget {
  const _CardDashedLine();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 5.0;
        const dashHeight = 1.0;
        const dashSpace = 4.0;
        final dashCount = (boxWidth / (dashWidth + dashSpace)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return const SizedBox(
              width: dashWidth,
              height: dashHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Color(0xFFE4E7EC)),
              ),
            );
          }),
        );
      },
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final double dash;
  final double radius;

  _DashedRectPainter({
    required this.color,
    this.strokeWidth = 1.0,
    this.gap = 5.0,
    this.dash = 5.0,
    this.radius = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );

    final Path path = Path()..addRRect(rrect);
    final Path dashedPath = _createDashedPath(path, dash, gap);

    canvas.drawPath(dashedPath, paint);
  }

  Path _createDashedPath(Path source, double dashLength, double gapLength) {
    final Path dest = Path();
    for (final metric in source.computeMetrics()) {
      double distance = 0.0;
      bool draw = true;
      while (distance < metric.length) {
        final double len = draw ? dashLength : gapLength;
        if (draw) {
          dest.addPath(metric.extractPath(distance, distance + len), Offset.zero);
        }
        distance += len;
        draw = !draw;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
