import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../models/ticket_order_model.dart';
import '../../services/data_service.dart';
import '../../widgets/qr_code_view.dart';
import '../../widgets/share_gate_qr_sheet.dart';
import '../home/home_screen.dart';
import 'widgets/checkout_stepper.dart';

class PaymentSuccessScreen extends StatefulWidget {
  final OrderModel order;

  const PaymentSuccessScreen({
    super.key,
    required this.order,
  });

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen> {
  late final UserTicketModel _issuedTicket;

  @override
  void initState() {
    super.initState();
    _issuedTicket = DataService().completeOrderPayment(widget.order);
  }

  void _openUserHome({required int initialNavIndex}) {
    final currentUser = DataService().currentUser;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          isGuest: false,
          userName: currentUser?.name ?? widget.order.customerName,
          userInitials: currentUser?.initials ?? 'U',
          initialNavIndex: initialNavIndex,
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookingCode = _issuedTicket.bookingCode;

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
            const CheckoutStepper(currentStep: 3),
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                children: [
                  _buildSuccessHeader(),
                  const SizedBox(height: 24),
                  _buildTicketCard(context, bookingCode),
                  const SizedBox(height: 20),
                  _buildActionButtons(context),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomButtons(context),
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
              color: Color(0xFF065F46),
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
          'Tiket resmi telah diterbitkan dan tersimpan di menu Tiket akun Anda',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: Color(0xFF475467)),
        ),
      ],
    );
  }

  Widget _buildTicketCard(BuildContext context, String bookingCode) {
    final order = widget.order;
    final concertTime =
        order.concert.time.isNotEmpty ? order.concert.time : '19.00 WIB';

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
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified, size: 13, color: Color(0xFF065F46)),
                            SizedBox(width: 4),
                            Text(
                              'TIKET RESMI',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF065F46),
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
                          color: Color(0xFF475467),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
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
                  '${order.concert.date} · $concertTime',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF475467),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  order.concert.venue,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF475467),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _buildTicketInfoColumn(
                        'Nama Pemesan',
                        order.customerName,
                      ),
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
                      child: _buildTicketInfoColumn('Gate', _issuedTicket.gate),
                    ),
                    Expanded(
                      child: _buildTicketInfoColumn(
                        'Sektor / Blok',
                        _issuedTicket.block,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          _buildTicketNotchSeparator(),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              children: [
                AppQrCodeView(
                  qrData: _issuedTicket.effectiveQrData,
                  qrCodeUrl: _issuedTicket.qrCodeUrl,
                  qrCodeBytes: _issuedTicket.qrCodeBytes,
                  size: 160,
                  padding: 12,
                  showWatermark: true,
                  semanticLabel: 'Kode QR E-Tiket ${order.concert.title}',
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Text(
                    '1 QR Berlaku untuk ${_issuedTicket.qrScanQuota}x Scan di Gate (${order.quantity} Tiket)',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF065F46),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
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
                Text(
                  order.quantity > 1
                      ? 'Satu kode QR ini berlaku untuk ${order.quantity} orang di gerbang masuk. Gunakan tombol Bagikan QR untuk mengirimkannya ke temanmu.'
                      : 'Tunjukkan kode QR ini kepada petugas di pintu masuk saat gate dibuka.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF475467),
                    height: 1.35,
                  ),
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
          style: const TextStyle(fontSize: 11.5, color: Color(0xFF475467)),
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
          Positioned(
            left: 20,
            right: 20,
            child: CustomPaint(
              size: const Size(double.infinity, 1),
              painter: _DashedLinePainter(color: const Color(0xFFD1D5DB)),
            ),
          ),
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

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 46,
            child: OutlinedButton.icon(
              onPressed: () => ShareGateQrSheet.show(context, _issuedTicket),
              icon: const Icon(
                Icons.share_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              label: const Text(
                'Bagikan QR',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary, width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 46,
            child: OutlinedButton.icon(
              onPressed: () => _openUserHome(initialNavIndex: 0),
              icon: const Icon(
                Icons.home_outlined,
                size: 18,
                color: AppColors.textDark,
              ),
              label: const Text(
                'Ke Beranda',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomButtons(BuildContext context) {
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
            onPressed: () => _openUserHome(initialNavIndex: 2),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Lihat di Menu Tiket',
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
