import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../models/ticket_order_model.dart';
import '../../services/dummy_data_service.dart';
import '../home/home_screen.dart';
import 'widgets/checkout_stepper.dart';

class PaymentSuccessScreen extends StatelessWidget {
  final OrderModel order;

  const PaymentSuccessScreen({
    super.key,
    required this.order,
  });

  void _returnHome(BuildContext context) {
    // 1. Simpan tiket baru ke DummyDataService
    final bookingCode = 'SWF-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}-2A';
    final newTicket = UserTicketModel(
      id: order.orderId,
      bookingCode: bookingCode,
      concertTitle: order.concert.title,
      concertSubtitle: '${order.concert.tag} · ${order.quantity} tiket',
      category: order.tier.name,
      date: order.concert.date.contains('Oktober') ? order.concert.date : '12 Okt 2026',
      time: order.concert.time.isNotEmpty ? order.concert.time : '17.00 WIB',
      gate: 'Gate B',
      block: 'FEST-04',
      venue: order.concert.venue,
      quantity: order.quantity,
      totalPrice: order.totalAmount,
      status: 'Siap Digunakan',
      isCompleted: false,
    );

    DummyDataService().addPurchasedTicket(newTicket);

    final currentUser = DummyDataService().currentUserNotifier.value;

    // 2. Navigasi kembali ke HomeScreen User
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          isGuest: false,
          userName: currentUser?.name.split(' ').first ?? 'Rafi',
          userInitials: currentUser?.initials ?? 'RF',
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookingCode = 'SWF-${order.orderId.replaceAll('ORD-', '')}-2A';

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'E-Tiket Konser',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 3-Step Stepper (Step 3 Complete)
            const CheckoutStepper(currentStep: 3),
            const Divider(height: 1, color: AppColors.border),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                children: [
                  // Icon Sukses & Aura Hijau
                  _buildSuccessHeader(),
                  const SizedBox(height: 24),

                  // Kartu E-Ticket dengan Cutout Notch & Dashed Separator
                  _buildTicketCard(context, bookingCode),
                  const SizedBox(height: 20),

                  // Tombol Unduh & Bagikan
                  _buildActionButtons(context),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomHomeButton(context),
    );
  }

  Widget _buildSuccessHeader() {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFFD1FAE5),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFA7F3D0), width: 4),
          ),
          child: const Center(
            child: Icon(
              Icons.check_rounded,
              color: Color(0xFF10B981),
              size: 40,
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Pembayaran berhasil!',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Tiket resmi telah diterbitkan dan tersimpan di akun Anda',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: AppColors.textGrey),
        ),
      ],
    );
  }

  Widget _buildTicketCard(BuildContext context, String bookingCode) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bagian Atas Tiket
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tag Tiket Resmi
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified, size: 13, color: Color(0xFF059669)),
                          SizedBox(width: 4),
                          Text(
                            'TIKET RESMI',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Text(
                      'LiveTix Pass',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Judul Konser & Waktu
                Text(
                  order.concert.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  order.concert.date.contains('Oktober')
                      ? '${order.concert.date} · 19.00 WIB'
                      : 'Minggu, 12 Oktober 2026 · 19.00 WIB',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey),
                ),
                const SizedBox(height: 2),
                Text(
                  order.concert.venue,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey),
                ),
                const SizedBox(height: 18),

                // Grid 2x2 Info Tiket
                Row(
                  children: [
                    Expanded(
                      child: _buildTicketInfoColumn('Nama Pemesan', order.customerName),
                    ),
                    Expanded(
                      child: _buildTicketInfoColumn(
                        'Kategori',
                        '${order.tier.name} (${order.quantity} Tiket)',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _buildTicketInfoColumn('Gate', 'Gate B'),
                    ),
                    Expanded(
                      child: _buildTicketInfoColumn('Sektor / Blok', 'FEST-04'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Notch Potongan Tiket & Garis Putus-putus
          _buildTicketNotchSeparator(),

          // Bagian Bawah: QR Code & Kode Booking
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              children: [
                _buildQrCodeGraphic(),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Kode Booking: $bookingCode',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tunjukkan kode QR ini kepada petugas di pintu masuk saat gate dibuka.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, color: AppColors.textGrey, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketInfoColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }

  Widget _buildTicketNotchSeparator() {
    return SizedBox(
      height: 24,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Garis Putus-putus
          Positioned(
            left: 20,
            right: 20,
            child: CustomPaint(
              size: const Size(double.infinity, 1),
              painter: _DashedLinePainter(color: const Color(0xFFD1D5DB)),
            ),
          ),
          // Setengah lingkaran kiri
          Positioned(
            left: -12,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
            ),
          ),
          // Setengah lingkaran kanan
          Positioned(
            right: -12,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrCodeGraphic() {
    return Container(
      width: 140,
      height: 140,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Stack(
        children: [
          // Simulasi visual pola QR Code
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _qrCorner(),
                    _qrSmallBox(),
                    _qrCorner(),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _qrSmallBox(),
                    Container(width: 16, height: 16, color: AppColors.primary),
                    _qrSmallBox(),
                    _qrSmallBox(),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _qrCorner(),
                    _qrSmallBox(),
                    _qrSmallBox(),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _qrCorner() {
    return Container(
      width: 32,
      height: 32,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.textDark, width: 3),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Container(
        color: AppColors.textDark,
      ),
    );
  }

  Widget _qrSmallBox() {
    return Container(
      width: 8,
      height: 8,
      color: AppColors.textDark,
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('E-Tiket berhasil diunduh ke perangkat Anda'),
                  backgroundColor: AppColors.primary,
                ),
              );
            },
            icon: const Icon(Icons.download_rounded, size: 18, color: AppColors.textDark),
            label: const Text(
              'Unduh',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tautan e-tiket disalin ke clipboard'),
                  backgroundColor: AppColors.primary,
                ),
              );
            },
            icon: const Icon(Icons.share_outlined, size: 18, color: AppColors.textDark),
            label: const Text(
              'Bagikan',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomHomeButton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () => _returnHome(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Kembali ke Home',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const double dashWidth = 5;
    const double dashSpace = 4;
    double startX = 0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
