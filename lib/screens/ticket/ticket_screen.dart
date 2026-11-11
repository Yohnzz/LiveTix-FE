import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../models/concert_model.dart';
import '../../models/ticket_order_model.dart';
import '../../services/data_service.dart';
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

  OrderModel _reconstructOrderFromTicket(UserTicketModel ticket) {
    final price = ticket.totalPrice ~/ (ticket.quantity > 0 ? ticket.quantity : 1);
    final tax = (ticket.totalPrice * 0.05).round();

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
      serviceFee: 5000,
      taxAndAdmin: tax,
      transactionFee: 0,
      totalAmount: ticket.totalPrice,
      customerName: DataService().currentUser?.name ?? 'Penonton LiveTix',
      customerEmail: DataService().currentUser?.email ?? 'user@livetix.com',
      paymentCategory: cat,
      paymentProvider: ticket.paymentMethod,
      qrString: ticket.qrData,
      qrCodeUrl: ticket.qrCodeUrl,
      expiresAt: DateTime.now().add(const Duration(minutes: 60)),
    );
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
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'TIKET RESMI AKTIF',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF065F46),
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
                  qrData: (ticket.qrData != null && ticket.qrData!.isNotEmpty)
                      ? ticket.qrData
                      : (ticket.bookingCode.isNotEmpty
                          ? ticket.bookingCode
                          : ticket.id),
                  qrCodeUrl: ticket.qrCodeUrl,
                  qrCodeBytes: ticket.qrCodeBytes,
                  size: 164,
                  padding: 12,
                  showWatermark: true,
                  semanticLabel: 'Kode QR E-Tiket ${ticket.concertTitle}',
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
            ? tickets.where((t) => !t.isCompleted).toList()
            : tickets.where((t) => t.isCompleted).toList();

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
                                  ? 'Batas waktu 1 jam · ${ticket.paymentMethod}'
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
                                      child: OutlinedButton.icon(
                                        onPressed: () =>
                                            ShareGateQrSheet.show(context, ticket),
                                        icon: const Icon(
                                          Icons.share_rounded,
                                          size: 15,
                                          color: AppColors.primary,
                                        ),
                                        label: const Text(
                                          'Bagikan QR',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          side: const BorderSide(
                                            color: AppColors.primary,
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

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color text;

    if (status == 'Aktif') {
      bg = const Color(0xFFECFDF5);
      text = const Color(0xFF065F46);
    } else if (status.toLowerCase().contains('menunggu') ||
        status.toLowerCase().contains('pending')) {
      bg = const Color(0xFFFEF3C7);
      text = const Color(0xFF92400E);
    } else if (status == 'Reffund' || status.toLowerCase().contains('refund')) {
      bg = const Color(0xFFFEE2E2);
      text = const Color(0xFF991B1B);
    } else {
      bg = const Color(0xFFF2F4F7);
      text = const Color(0xFF475467);
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
