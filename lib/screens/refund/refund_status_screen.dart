import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../models/ticket_order_model.dart';
import '../home/home_screen.dart';

class RefundStatusScreen extends StatelessWidget {
  final RefundModel refund;

  const RefundStatusScreen({
    super.key,
    required this.refund,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Gradasi Ungu-Magenta Sesuai Figma
            _buildHeader(context),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Vertical Timeline Stepper
                  _buildTimelineStepper(),
                  const SizedBox(height: 24),

                  // Kartu Info Tujuan Transfer
                  _buildDestinationCard(),
                  const SizedBox(height: 36),

                  // Tombol "Kembali Ke Beranda"
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const HomeScreen(isGuest: false),
                          ),
                          (route) => false,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B2A8C), // Navy
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Kembali Ke Beranda',
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Tombol "Hubungi bantuan"
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Pusat Bantuan LiveTix: Hubungi support@livetix.com atau WhatsApp 0812-3456-7890 (24 Jam)',
                            ),
                            backgroundColor: Color(0xFF1B2A8C),
                            duration: Duration(seconds: 4),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF1B2A8C)),
                        foregroundColor: const Color(0xFF1B2A8C),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Hubungi bantuan',
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final viewTop = MediaQuery.of(context).viewPadding.top;
    final topSpacing = viewTop > 0 ? viewTop + 14 : 36.0;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, topSpacing, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back Button
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chevron_left, color: Colors.white, size: 22),
                    SizedBox(width: 4),
                    Text(
                      'Status refund',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Badge Status "Sedang diproses" (Putih dengan teks navy)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Text(
                  'Sedang diproses',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1B2A8C),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Jumlah Total Refund
              Text(
                refund.formattedTotal,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),

              // ID Refund & Estimasi
              Text(
                'ID ${refund.refundId} · estimasi 3–7 hari kerja',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      );
  }

  Widget _buildTimelineStepper() {
    return Column(
      children: [
        // Step 1: Refund diajukan
        _buildTimelineItem(
          title: 'Refund diajukan',
          subtitle: refund.requestedAt,
          isDone: true,
          isActive: false,
          isFirst: true,
          isLast: false,
        ),
        // Step 2: Diverifikasi penyelenggara
        _buildTimelineItem(
          title: 'Diverifikasi penyelenggara',
          subtitle: refund.verifiedAt,
          isDone: true,
          isActive: false,
          isFirst: false,
          isLast: false,
        ),
        // Step 3: Dana sedang dikirim
        _buildTimelineItem(
          title: 'Dana sedang dikirim',
          subtitle: 'Menunggu transfer ke ${refund.providerName} ${refund.maskAccount}',
          isDone: false,
          isActive: true,
          isFirst: false,
          isLast: false,
        ),
        // Step 4: Refund selesai
        _buildTimelineItem(
          title: 'Refund selesai',
          subtitle: 'Kamu akan dapat notifikasi',
          isDone: false,
          isActive: false,
          isFirst: false,
          isLast: true,
        ),
      ],
    );
  }

  Widget _buildTimelineItem({
    required String title,
    required String subtitle,
    required bool isDone,
    required bool isActive,
    required bool isFirst,
    required bool isLast,
  }) {
    Color circleColor;
    Widget iconWidget;

    if (isDone) {
      circleColor = const Color(0xFF1B2A8C);
      iconWidget = const Icon(Icons.check, size: 14, color: Colors.white);
    } else if (isActive) {
      circleColor = const Color(0xFFB02A8F); // Magenta aktif
      iconWidget = Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      );
    } else {
      circleColor = const Color(0xFFD1D5DB);
      iconWidget = const SizedBox();
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Garis Vertikal & Titik
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: circleColor,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: iconWidget,
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isDone ? const Color(0xFF1B2A8C) : const Color(0xFFE4E7EC),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Teks Judul & Subtitle
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF667085),
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

  Widget _buildDestinationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tujuan',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF667085),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${refund.providerName} ${refund.accountNumber}',
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'a.n. ${refund.accountHolderName}',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF667085),
            ),
          ),
        ],
      ),
    );
  }
}
