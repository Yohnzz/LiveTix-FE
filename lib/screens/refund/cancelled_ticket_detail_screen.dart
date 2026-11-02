import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../models/ticket_order_model.dart';
import '../../widgets/qr_code_view.dart';
import 'refund_destination_screen.dart';

class CancelledTicketDetailScreen extends StatelessWidget {
  final UserTicketModel ticket;

  const CancelledTicketDetailScreen({
    super.key,
    required this.ticket,
  });

  String _formatCurrency(int amount) {
    final buffer = StringBuffer('Rp');
    final str = amount.toString();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    // Menghitung rincian refund: tiket dasar + biaya layanan
    final ticketBasePrice = ticket.totalPrice > 10000 ? ticket.totalPrice - 6500 : ticket.totalPrice;
    const serviceFee = 6500;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Ungu-Magenta Bergradasi Sesuai Figma
            _buildHeader(context),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Kartu QR Code Tidak Berlaku
                  _buildDisabledQrCard(),
                  const SizedBox(height: 16),

                  // Kartu Rincian Refund
                  _buildRefundDetailsCard(ticketBasePrice, serviceFee),
                  const SizedBox(height: 14),

                  // Informasi Batas Waktu & Estimasi
                  const Text(
                    'Batas pengajuan: 30 Nov 2026.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF475467),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Dana kembali dalam 3–7 hari kerja.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF475467),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 100), // Spacing untuk sticky button
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(context),
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
        padding: EdgeInsets.fromLTRB(20, topSpacing, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tombol Back
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chevron_left, color: Colors.white, size: 22),
                    SizedBox(width: 4),
                    Text(
                      'Detail tiket',
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

              // Badge "Event dibatalkan" (Oranye / Amber)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Text(
                  'Event dibatalkan',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1D2939),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Judul Konser
              Text(
                ticket.concertTitle,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 4),

              // Tanggal & Venue
              Text(
                '${ticket.date} · ${ticket.venue}',
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      );
  }

  Widget _buildDisabledQrCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          AppQrCodeView(
            qrCodeUrl: ticket.qrCodeUrl,
            qrCodeBytes: ticket.qrCodeBytes,
            size: 124,
            padding: 10,
            isDisabled: true,
            semanticLabel: 'Kode QR tidak berlaku karena tiket dibatalkan',
          ),
          const SizedBox(height: 14),
          const Text(
            'QR tidak berlaku · tiket dibatalkan',
            style: TextStyle(
              fontSize: 12.5,
              color: Color(0xFF475467),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefundDetailsCard(int ticketBasePrice, int serviceFee) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Rincian refund',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 14),

          // Baris 1: Tiket
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tiket ${ticket.category} x ${ticket.quantity}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF475467)),
              ),
              Text(
                _formatCurrency(ticketBasePrice),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Baris 2: Biaya Layanan
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Biaya layanan',
                style: TextStyle(fontSize: 13, color: Color(0xFF475467)),
              ),
              Text(
                _formatCurrency(serviceFee),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: AppColors.border),
          ),

          // Baris Total Refund 100%
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total refund 100%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              Text(
                _formatCurrency(ticket.totalPrice),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1B2A8C),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
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
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RefundDestinationScreen(ticket: ticket),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB02A8F), // Magenta ungu sesuai Figma
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Ajukan refund',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
