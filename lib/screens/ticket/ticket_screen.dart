import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../models/concert_model.dart';
import '../../models/ticket_order_model.dart';
import '../../services/data_service.dart';
import '../../services/ticket_validator_service.dart';
import '../../widgets/qr_code_view.dart';
import '../../widgets/share_gate_qr_sheet.dart';
import '../auth/login_screen.dart';
import '../checkout/payment_screen.dart';
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

  @override
  void initState() {
    super.initState();
    DataService().fetchUserTicketsFromSupabase();
  }

  void _goToLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _onViewTicketPressed(UserTicketModel ticket) {
    if (ticket.isPendingPayment) {
      final orderToPay = ticket.pendingOrder ?? _reconstructOrderFromTicket(ticket);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentScreen(order: orderToPay),
        ),
      );
      return;
    }

    if (ticket.status.toLowerCase().contains('expired') ||
        ticket.status.toLowerCase().contains('cancelled') ||
        ticket.status == 'Dibatalkan') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pesanan tiket ini telah dibatalkan atau melewati batas waktu pembayaran.'),
          backgroundColor: Color(0xFFB91C1C),
        ),
      );
      return;
    }

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
    } else if (_selectedTabIndex == 1 &&
        (ticket.isCompleted || ticket.status.toLowerCase() == 'selesai') &&
        !ticket.isValidated) {
      // Tiket Riwayat / Selesai lama -> Tampilkan rincian transaksi tiket riwayat
      _showHistoryTicketModal(ticket);
    } else {
      // Tiket Aktif & Tiket yang divalidasi -> Tampilkan modal E-Tiket Aktif / Status Divalidasi
      _showActiveTicketModal(ticket);
    }
  }

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

  Widget _buildPricingRow(String label, String value, {bool isDark = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppColors.textDark,
          ),
        ),
      ],
    );
  }

  Widget _buildTransparentPricingCard(
    TransactionPricing pricing,
    String tierName,
    int quantity, {
    bool isDark = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_rounded, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'Rincian Transaksi',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildPricingRow('Harga Tiket (${quantity}x $tierName)', _formatCurrency(pricing.totalBayar), isDark: isDark),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Divider(
              height: 1,
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Bayar',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppColors.textDark,
                ),
              ),
              Text(
                _formatCurrency(pricing.totalBayar),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Harga sudah termasuk tiket, pajak hiburan, dan seluruh biaya aplikasi.',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModalIdentityRow(String label, String value, {bool isCode = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: isCode ? 11.5 : 12.5,
              fontWeight: isCode ? FontWeight.w700 : FontWeight.w600,
              fontFamily: isCode ? 'monospace' : null,
              color: isCode ? const Color(0xFF1B2A8C) : const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }

  OrderModel _reconstructOrderFromTicket(UserTicketModel ticket) {
    final pricing = ticket.pricing;
    final price = pricing.hargaSatuan;

    final tier = TicketTierModel(
      id: 'tier-${ticket.category}',
      name: ticket.category,
      description: ticket.category,
      price: price,
    );

    final defaultConcert = ConcertModel(
      id: 'c-pending-${ticket.id}',
      title: ticket.concertTitle,
      subtitle: ticket.displaySubtitle,
      date: ticket.date.isNotEmpty ? ticket.date : '2026-11-20',
      time: ticket.time.isNotEmpty ? ticket.time : '19.00 WIB',
      venue: ticket.venue.isNotEmpty ? ticket.venue : 'LiveTix Arena',
      price: price,
      category: 'Pop',
      tag: 'Trending',
      badgeColor: const Color(0xFF1B2A8C),
      iconBgColor: const Color(0xFFE0EAFF),
      iconColor: const Color(0xFF1B2A8C),
      ticketTiers: [tier],
      gates: [ticket.gate],
    );

    PaymentCategory cat = PaymentCategory.qris;
    final mUpper = ticket.paymentMethod.toUpperCase();
    if (mUpper.contains('VA') || mUpper.contains('BANK')) {
      cat = PaymentCategory.bank;
    } else if (mUpper.contains('GOPAY') ||
        mUpper.contains('DANA') ||
        mUpper.contains('SHOPEE')) {
      cat = PaymentCategory.ewallet;
    }

    return OrderModel(
      orderId: ticket.id,
      concert: defaultConcert,
      tier: tier,
      quantity: ticket.quantity,
      ticketPrice: price,
      serviceFee: pricing.biayaAplikasi,
      taxAndAdmin: pricing.pajakHiburan,
      transactionFee: 0,
      totalAmount: pricing.totalBayar,
      entertainmentTax: pricing.pajakHiburan,
      applicationFee: pricing.biayaAplikasi,
      rounding: pricing.pembulatan,
      producerShare: pricing.produserShare,
      adminShare: pricing.adminShare,
      customerName: ticket.buyerName ??
          DataService().currentUser?.name ??
          'Penonton LiveTix',
      customerEmail: ticket.buyerEmail ??
          DataService().currentUser?.email ??
          'user@livetix.com',
      paymentCategory: cat,
      paymentProvider: ticket.paymentMethod,
      qrString: ticket.qrData,
      qrCodeUrl: ticket.qrCodeUrl,
      expiresAt: DateTime.now().add(const Duration(minutes: 15)),
    );
  }

  void _showActiveTicketModal(UserTicketModel ticket) {
    String effectiveQr = (ticket.qrData != null && ticket.qrData!.isNotEmpty)
        ? ticket.qrData!
        : (ticket.bookingCode.isNotEmpty ? ticket.bookingCode : ticket.id);
    bool hasFetched = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Jika QR belum berformat 3 segmen (ticket_id.kode_tiket.signature), coba ambil dari server
            if (!hasFetched && (!effectiveQr.contains('.') || effectiveQr.split('.').length != 3)) {
              hasFetched = true;
              TicketValidatorService().fetchTicketQrPayload(ticket.id).then((payload) {
                if (payload != null && payload.isNotEmpty && payload != effectiveQr) {
                  if (context.mounted) {
                    setModalState(() {
                      effectiveQr = payload;
                    });
                  }
                }
              });
            }

            final user = DataService().currentUser;
            final buyerName = (ticket.buyerName != null &&
                    ticket.buyerName!.trim().isNotEmpty)
                ? ticket.buyerName!.trim()
                : (user?.name.trim().isNotEmpty == true
                    ? user!.name.trim()
                    : 'Pengunjung LiveTix');
            final buyerEmail = (ticket.buyerEmail != null &&
                    ticket.buyerEmail!.trim().isNotEmpty)
                ? ticket.buyerEmail!.trim()
                : (user?.email.trim().isNotEmpty == true
                    ? user!.email.trim()
                    : '—');
            final rawNik = (ticket.buyerNik != null &&
                    ticket.buyerNik!.trim().isNotEmpty)
                ? ticket.buyerNik!.trim()
                : (user?.nik.trim() ?? '');
            final maskedNik = rawNik.length >= 8
                ? '${rawNik.substring(0, 4)}••••${rawNik.substring(rawNik.length - 4)}'
                : (rawNik.isNotEmpty ? rawNik : '—');

            return SafeArea(
              top: false,
              child: SingleChildScrollView(
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: ticket.isValidated
                                ? const Color(0xFFEFF6FF)
                                : const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: ticket.isValidated
                                  ? const Color(0xFFBFDBFE)
                                  : const Color(0xFFA7F3D0),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                ticket.isValidated
                                    ? Icons.verified_rounded
                                    : Icons.check_circle_outline_rounded,
                                size: 13,
                                color: ticket.isValidated
                                    ? const Color(0xFF1D4ED8)
                                    : const Color(0xFF065F46),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                ticket.isValidated
                                    ? 'TIKET SUDAH DIVALIDASI'
                                    : 'TIKET RESMI AKTIF',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: ticket.isValidated
                                      ? const Color(0xFF1D4ED8)
                                      : const Color(0xFF065F46),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Flexible(
                          child: Text(
                            '#${ticket.displayShortCode}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                              letterSpacing: 0.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      ticket.concertTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${ticket.date} · ${ticket.venue}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF475467),
                      ),
                    ),
                    const SizedBox(height: 18),
                    AppQrCodeView(
                      qrData: effectiveQr,
                      qrCodeUrl: ticket.qrCodeUrl,
                      qrCodeBytes: ticket.qrCodeBytes,
                      size: 220,
                      padding: 12,
                      showWatermark: true,
                      semanticLabel: 'Kode QR E-Tiket ${ticket.concertTitle}',
                    ),
                    // Indikator Status Validasi Scan
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 14, bottom: 2),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: ticket.isValidated
                            ? const Color(0xFFEFF6FF)
                            : const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: ticket.isValidated
                              ? const Color(0xFFBFDBFE)
                              : const Color(0xFFA7F3D0),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            ticket.isValidated
                                ? Icons.verified_rounded
                                : Icons.qr_code_scanner_rounded,
                            color: ticket.isValidated
                                ? const Color(0xFF1D4ED8)
                                : const Color(0xFF059669),
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ticket.isValidated
                                      ? 'TIKET SUDAH DIVALIDASI'
                                      : 'TIKET AKTIF (BELUM DI-SCAN)',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: ticket.isValidated
                                        ? const Color(0xFF1E40AF)
                                        : const Color(0xFF065F46),
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  ticket.isValidated
                                      ? 'Tiket ini telah berhasil di-scan oleh petugas di pos ${ticket.gate}. Akses masuk konser telah terpakai.'
                                      : 'Tunjukkan kode QR ini ke petugas Gate Crew di pos ${ticket.gate} saat verifikasi masuk venue konser.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: ticket.isValidated
                                        ? const Color(0xFF2563EB)
                                        : const Color(0xFF047857),
                                    height: 1.35,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Pos Gate Masuk (Besar & Ter-highlight sesuai konfigurasi Produser)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(vertical: 14),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1B2A8C), Color(0xFF27389B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1B2A8C).withValues(alpha: 0.22),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.door_front_door_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'POS GATE MASUK',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFC7D2FE),
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  ticket.gate,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              ticket.category,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1B2A8C),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Identitas Resmi Pemilik Tiket (Nama, Email, NIK sebagai bukti)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.badge_rounded,
                                  size: 16, color: Color(0xFF475467)),
                              SizedBox(width: 6),
                              Text(
                                'Identitas Pembeli (Bukti Resmi)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 16, color: Color(0xFFE2E8F0)),
                          _buildModalIdentityRow('Nama Pembeli', buyerName),
                          const SizedBox(height: 6),
                          _buildModalIdentityRow('Email Pembeli', buyerEmail),
                          const SizedBox(height: 6),
                          _buildModalIdentityRow('NIK', maskedNik),
                          const SizedBox(height: 6),
                          _buildModalIdentityRow(
                              'Kode Tiket', '#${ticket.displayShortCode}',
                              isCode: true),
                        ],
                      ),
                    ),
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
                        '1 QR Berlaku ${ticket.qrScanQuota}x Scan di Gate (${ticket.quantity} Tiket · ${ticket.gate})',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF065F46),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      ticket.quantity > 1
                          ? 'Satu QR Code ini dapat digunakan sebanyak ${ticket.qrScanQuota} kali sesuai jumlah tiket. Bagikan ke teman rombonganmu melalui tombol di bawah.'
                          : 'Tunjukkan QR ini saat scan di gerbang masuk.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF475467),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTransparentPricingCard(
                      ticket.pricing,
                      ticket.category,
                      ticket.quantity,
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          ShareGateQrSheet.show(context, ticket);
                        },
                        icon: const Icon(Icons.share_rounded, size: 18),
                        label: const Text(
                          'Bagikan QR',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textDark,
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Tutup',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showHistoryTicketModal(UserTicketModel ticket) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'RIWAYAT TRANSAKSI',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                    Text(
                      '#${ticket.displayShortCode}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  ticket.concertTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${ticket.date} · ${ticket.venue}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF475467),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    'Kategori: ${ticket.category} · ${ticket.quantity} Tiket (${ticket.gate})',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildTransparentPricingCard(
                  ticket.pricing,
                  ticket.category,
                  ticket.quantity,
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF059669)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Pembayaran lunas via ${ticket.paymentMethod.toUpperCase()}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF065F46),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textDark,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Tutup',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final viewTop = MediaQuery.of(context).viewPadding.top;
    final topSpacing = viewTop > 0 ? viewTop + 16 : 38.0;

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      body: Padding(
        padding: EdgeInsets.fromLTRB(20, topSpacing, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Judul Sesuai Figma
            Text(
              'Tiket saya',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.darkText : AppColors.textDark,
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
    );
  }

  Widget _buildSegmentedTab() {
    final isDark = AppColors.isDark(context);

    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : const Color(0xFFF2F4F7),
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
                  color: _selectedTabIndex == 0
                      ? (isDark ? AppColors.darkSurface : Colors.white)
                      : Colors.transparent,
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
                    fontWeight:
                        _selectedTabIndex == 0 ? FontWeight.w700 : FontWeight.w500,
                    color: _selectedTabIndex == 0
                        ? (isDark ? AppColors.darkText : AppColors.textDark)
                        : (isDark ? AppColors.darkTextSecondary : AppColors.textGrey),
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
                  color: _selectedTabIndex == 1
                      ? (isDark ? AppColors.darkSurface : Colors.white)
                      : Colors.transparent,
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
                    fontWeight:
                        _selectedTabIndex == 1 ? FontWeight.w700 : FontWeight.w500,
                    color: _selectedTabIndex == 1
                        ? (isDark ? AppColors.darkText : AppColors.textDark)
                        : (isDark ? AppColors.darkTextSecondary : AppColors.textGrey),
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
    final isDark = AppColors.isDark(context);
    return Center(
      child: CustomPaint(
        painter: _DashedRectPainter(
          color: isDark ? AppColors.darkBorder : const Color(0xFFD0D5DD),
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
              Text(
                'Tidak Ada Tiket',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text(context),
                ),
              ),
              const SizedBox(height: 8),
              // Link Href interaktif menuju halaman Login
              GestureDetector(
                onTap: _goToLogin,
                child: Text(
                  'Silahkan Login Terlebih Dahulu',
                  style: TextStyle(
                    fontSize: 13,
                    color:
                        isDark ? const Color(0xFFF472B6) : AppColors.accent,
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
      valueListenable: DataService().userTicketsNotifier,
      builder: (context, tickets, _) {
        final filteredTickets = _selectedTabIndex == 0
            ? tickets.where((t) => t.isActiveTabTicket).toList()
            : tickets.where((t) => t.isHistoryTabTicket).toList();

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            await DataService().fetchUserTicketsFromSupabase();
          },
          child: filteredTickets.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(top: 24, bottom: 24),
                  children: [
                    _buildEmptyUserTickets(_selectedTabIndex == 0),
                  ],
                )
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    ...filteredTickets.map((ticket) => _buildFigmaTicketCard(ticket)),
                    const SizedBox(height: 8),

                    // Kotak Bergaris Putus-putus "Belum ada tiket lain"
                    _buildEmptyStateDashedBox(),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildEmptyUserTickets(bool isActiveTab) {
    final isDark = AppColors.isDark(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : const Color(0xFFF2F4F7),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isActiveTab ? Icons.confirmation_number_outlined : Icons.history_rounded,
                size: 32,
                color: isDark ? AppColors.darkTextSecondary : const Color(0xFF667085),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isActiveTab ? 'Belum Ada Tiket Aktif' : 'Belum Ada Riwayat Tiket',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkText : AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isActiveTab
                  ? 'Kamu belum memiliki tiket konser aktif saat ini. Jelajahi konser seru dan pesan tiket favoritmu sekarang!'
                  : 'Tiket konser yang telah selesai dihadiri atau dibatalkan akan muncul di riwayat ini.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textGrey,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFigmaTicketCard(UserTicketModel ticket) {
    final isPending = ticket.isPendingPayment;
    final isRefund = ticket.status == 'Reffund' || ticket.isCancelled;
    final stripeColor = ticket.stripeColor ??
        (isPending
            ? const Color(0xFFF59E0B)
            : isRefund
                ? const Color(0xFFC2185B)
                : const Color(0xFF1B2A8C));
    final iconBgColor = ticket.iconBgColor ??
        (isPending
            ? const Color(0xFFFEF3C7)
            : isRefund
                ? const Color(0xFFFCE7F3)
                : const Color(0xFFE0EAFF));
    final iconColor = ticket.iconColor ??
        (isPending
            ? const Color(0xFFD97706)
            : isRefund
                ? const Color(0xFFC2185B)
                : const Color(0xFF1B2A8C));

    final isDark = AppColors.isDark(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x33000000) : const Color(0x06000000),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _onViewTicketPressed(ticket),
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
                          // Logo Konser dari Database / Cache (dengan fallback icon)
                          _buildTicketConcertLogo(
                            ticket,
                            isDark: isDark,
                            iconBgColor: iconBgColor,
                            iconColor: iconColor,
                          ),
                          const SizedBox(width: 12),

                          // Judul Konser & Subtitle
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ticket.concertTitle,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? AppColors.darkText : AppColors.textDark,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  ticket.displaySubtitle,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFF667085),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${ticket.quantity} tiket · ${ticket.category}',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? AppColors.primaryDark : stripeColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: (isDark ? AppColors.primaryDark : stripeColor).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.door_front_door_rounded,
                                          size: 13,
                                          color: isDark ? AppColors.primaryDark : stripeColor),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          'Pos: ${ticket.gate}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? AppColors.primaryDark : stripeColor,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
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
                              _buildStatusBadge(ticket),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Garis Putus-Putus Separator
                      const _CardDashedLine(),
                      const SizedBox(height: 10),

                      // Bagian Bawah: Sisa Hari & Tombol Aksi ("Bagikan QR" & "Lihat tiket")
                      SizedBox(
                        width: double.infinity,
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Text(
                              isPending
                                  ? 'Batas waktu 15 menit · ${ticket.paymentMethod}'
                                  : isRefund
                                      ? '${ticket.daysLeft} hari lagi'
                                      : '${ticket.daysLeft} hari lagi · ${ticket.qrScanQuota}x scan',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight:
                                    isPending ? FontWeight.w600 : FontWeight.normal,
                                color: isPending
                                    ? const Color(0xFFD97706)
                                    : (isDark
                                        ? AppColors.darkTextSecondary
                                        : const Color(0xFF475467)),
                              ),
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (isPending)
                                  SizedBox(
                                    height: 44,
                                    child: ElevatedButton.icon(
                                      onPressed: () =>
                                          _onViewTicketPressed(ticket),
                                      icon: const Icon(Icons.payment_rounded,
                                          size: 16),
                                      label: const Text(
                                        'Bayar Sekarang',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFD97706),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                      ),
                                    ),
                                  )
                                else ...[
                                  if (!isRefund && !ticket.isCompleted)
                                    SizedBox(
                                      height: 44,
                                      child: ElevatedButton.icon(
                                        onPressed: () =>
                                            ShareGateQrSheet.show(context, ticket),
                                        icon: const Icon(
                                          Icons.share_rounded,
                                          size: 15,
                                          color: Color(0xFF1B2A8C),
                                        ),
                                        label: const Text(
                                          'Bagikan QR',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF1B2A8C),
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor: const Color(0xFF1B2A8C),
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          side: BorderSide(
                                            color: isDark
                                                ? Colors.white
                                                : const Color(0xFFCBD5E1),
                                            width: 1,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                      ),
                                    ),
                                  SizedBox(
                                    height: 44,
                                    child: ElevatedButton(
                                      onPressed: () =>
                                          _onViewTicketPressed(ticket),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF1D2939),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
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
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);
  }

  Widget _buildStatusBadge(UserTicketModel ticket) {
    final status = ticket.status;
    Color bg;
    Color text;
    IconData? icon;

    if (ticket.isValidated) {
      bg = const Color(0xFFEFF6FF);
      text = const Color(0xFF1D4ED8);
      icon = Icons.verified_rounded;
    } else if (status == 'Aktif') {
      bg = const Color(0xFFECFDF5);
      text = const Color(0xFF065F46);
      icon = Icons.check_circle_outline_rounded;
    } else if (status.toLowerCase().contains('menunggu') ||
        status.toLowerCase().contains('pending')) {
      bg = const Color(0xFFFEF3C7);
      text = const Color(0xFF92400E);
      icon = null;
    } else if (status == 'Reffund' ||
        status.toLowerCase().contains('refund') ||
        status.toLowerCase().contains('expired') ||
        status.toLowerCase().contains('cancelled')) {
      bg = const Color(0xFFFEE2E2);
      text = const Color(0xFF991B1B);
      icon = null;
    } else {
      bg = const Color(0xFFF2F4F7);
      text = const Color(0xFF475467);
      icon = null;
    }

    final label = ticket.isValidated ? 'Sudah Divalidasi' : status;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: text),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: text,
            ),
          ),
        ],
      ),
    );
  }

  /// Menampilkan logo konser tiket dari database (foto poster/logo konser)
  /// dengan graceful fallback ke cache lokal konser atau ikon bertema musik.
  Widget _buildTicketConcertLogo(
    UserTicketModel ticket, {
    required bool isDark,
    required Color iconBgColor,
    required Color iconColor,
  }) {
    String? resolvedLogoUrl = ticket.logoImageUrl;
    Uint8List? resolvedLogoBytes = ticket.logoImageBytes;

    // Jika belum ada di model tiket, cari dari cache konser lokal (DataService.rawConcerts)
    if ((resolvedLogoUrl == null || resolvedLogoUrl.trim().isEmpty) &&
        resolvedLogoBytes == null) {
      try {
        final allConcerts = DataService().rawConcerts;
        final cid = ticket.concertId;
        final matched = allConcerts.cast<ConcertModel?>().firstWhere(
              (c) =>
                  c != null &&
                  ((cid != null && cid.isNotEmpty && c.id == cid) ||
                      c.title.trim().toLowerCase() ==
                          ticket.concertTitle.trim().toLowerCase()),
              orElse: () => null,
            );
        if (matched != null) {
          resolvedLogoUrl =
              matched.logoImageUrl ?? matched.bannerImageUrl;
          resolvedLogoBytes =
              matched.logoImageBytes ?? matched.bannerImageBytes;
        }
      } catch (_) {}
    }

    Widget? imageContent;
    if (resolvedLogoBytes != null && resolvedLogoBytes.isNotEmpty) {
      imageContent = Image.memory(
        resolvedLogoBytes,
        width: 52,
        height: 52,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildTicketFallbackLogo(iconBgColor, iconColor),
      );
    } else if (resolvedLogoUrl != null && resolvedLogoUrl.trim().isNotEmpty) {
      imageContent = Image.network(
        resolvedLogoUrl.trim(),
        width: 52,
        height: 52,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildTicketFallbackLogo(iconBgColor, iconColor),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: 52,
            height: 52,
            color: iconBgColor,
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                ),
              ),
            ),
          );
        },
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: imageContent ?? _buildTicketFallbackLogo(iconBgColor, iconColor),
    );
  }

  Widget _buildTicketFallbackLogo(Color iconBgColor, Color iconColor) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: iconBgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          color: iconColor,
          size: 26,
        ),
      ),
    );
  }

  Widget _buildEmptyStateDashedBox() {
    final isDark = AppColors.isDark(context);
    return CustomPaint(
      painter: _DashedRectPainter(
        color: isDark ? AppColors.darkBorder : const Color(0xFFD0D5DD),
        strokeWidth: 1.2,
        gap: 5.0,
        dash: 6.0,
        radius: 18,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        alignment: Alignment.center,
        child: Column(
          children: [
            Text(
              'Belum ada tiket lain',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.text(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Cari konser berikutnya di beranda',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.subtext(context),
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
    return const SizedBox(
      height: 1,
      width: double.infinity,
      child: CustomPaint(
        painter: _HorizontalDashedLinePainter(
          color: Color(0xFFE4E7EC),
          dashWidth: 5.0,
          dashSpace: 4.0,
        ),
      ),
    );
  }
}

class _HorizontalDashedLinePainter extends CustomPainter {
  final Color color;
  final double dashWidth;
  final double dashSpace;

  const _HorizontalDashedLinePainter({
    required this.color,
    this.dashWidth = 5.0,
    this.dashSpace = 4.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0;

    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, 0.5),
        Offset(startX + dashWidth, 0.5),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _HorizontalDashedLinePainter oldDelegate) => false;
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
