import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_colors.dart';
import '../../models/ticket_order_model.dart';
import '../../services/data_service.dart';
import '../../widgets/qr_code_view.dart';
import '../home/home_screen.dart';
import 'ewallet_app_screen.dart';
import 'payment_success_screen.dart';
import 'widgets/checkout_stepper.dart';

class PaymentScreen extends StatefulWidget {
  final OrderModel order;

  const PaymentScreen({
    super.key,
    required this.order,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  // Batas waktu pembayaran 1 jam (3600 detik)
  static const int _initialExpirySeconds = 3600;

  late int _remainingSeconds;
  Timer? _timer;
  bool _hasReturnedFromEWalletApp = false;
  String? _ewalletCheckMessage;

  bool get _isOrderPaid => DataService().isOrderPaid(widget.order.orderId);

  @override
  void initState() {
    super.initState();
    _remainingSeconds = _initialExpirySeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatNumber(int n) => n.toString().padLeft(2, '0');

  String _formatCurrency(int amount) => widget.order.formatCurrency(amount);

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label berhasil disalin ke clipboard'),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _navigateToUserTicketsTab() {
    DataService().completeOrderPayment(widget.order);
    final currentUser = DataService().currentUser;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          isGuest: false,
          userName: currentUser?.name ?? widget.order.customerName,
          userInitials: currentUser?.initials ?? 'U',
          initialNavIndex: 2,
        ),
      ),
      (route) => false,
    );
  }

  Future<void> _openEWalletApp() async {
    if (_remainingSeconds <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Waktu pembayaran 1 jam telah berakhir. Silakan ulangi pesanan.'),
          backgroundColor: Color(0xFFB91C1C),
        ),
      );
      return;
    }

    if (_isOrderPaid) {
      _navigateToUserTicketsTab();
      return;
    }

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EWalletPaymentAppScreen(
          order: widget.order,
          providerName: widget.order.paymentProvider,
        ),
      ),
    );

    if (!mounted) return;
    setState(() {
      _hasReturnedFromEWalletApp = true;
      if (result == true || _isOrderPaid) {
        _ewalletCheckMessage =
            'Pembayaran di ${widget.order.paymentProvider} telah diterima. Tekan Cek Pembayaran untuk masuk ke menu Tiket.';
      } else {
        _ewalletCheckMessage =
            'Menunggu penyelesaian PIN di aplikasi ${widget.order.paymentProvider}. Selesaikan sebelum batas waktu 1 jam habis.';
      }
    });
  }

  void _handleCheckEWalletPayment() {
    if (_isOrderPaid) {
      _navigateToUserTicketsTab();
      return;
    }

    setState(() {
      _ewalletCheckMessage =
          'Pembayaran belum berhasil diterima dari ${widget.order.paymentProvider}. Status masih menunggu pembayaran sesuai batas waktu 1 jam.';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Status masih menunggu pembayaran di ${widget.order.paymentProvider} (batas waktu 1 jam)',
        ),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handlePaymentConfirmation() {
    if (_remainingSeconds <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Waktu pembayaran 1 jam telah habis. Silakan buat pesanan baru.'),
          backgroundColor: Color(0xFFB91C1C),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.primary),
                SizedBox(height: 16),
                Text(
                  'Memverifikasi pembayaran...',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      DataService().completeOrderPayment(widget.order);
      Navigator.pop(context);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentSuccessScreen(order: widget.order),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final hours = _remainingSeconds ~/ 3600;
    final minutes = (_remainingSeconds % 3600) ~/ 60;
    final seconds = _remainingSeconds % 60;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Kembali',
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Selesaikan pembayaran',
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
            const CheckoutStepper(currentStep: 2),
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCountdownSection(hours, minutes, seconds),
                  const SizedBox(height: 16),
                  _buildPrimaryPaymentCard(),
                  const SizedBox(height: 16),
                  _buildItemizedBreakdownCard(),
                  const SizedBox(height: 16),
                  _buildPaymentGuideCard(),
                  const SizedBox(height: 16),
                  _buildWarningBanner(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildCountdownSection(int hours, int minutes, int seconds) {
    final isExpired = _remainingSeconds <= 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            isExpired
                ? 'Batas waktu pembayaran 1 jam telah habis'
                : 'Selesaikan pembayaran dalam (batas waktu 1 jam)',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isExpired ? FontWeight.w700 : FontWeight.w500,
              color: isExpired ? const Color(0xFFB91C1C) : const Color(0xFF475467),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildTimerBox(_formatNumber(hours), 'Jam'),
              const Text(':', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              _buildTimerBox(_formatNumber(minutes), 'Menit'),
              const Text(':', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              _buildTimerBox(_formatNumber(seconds), 'Detik'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimerBox(String value, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF475467)),
        ),
      ],
    );
  }

  Widget _buildStatusBadge() {
    if (widget.order.paymentCategory == PaymentCategory.ewallet && _isOrderPaid) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'Pembayaran berhasil',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF065F46),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'Menunggu pembayaran',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF92400E),
        ),
      ),
    );
  }

  Widget _buildPrimaryPaymentCard() {
    switch (widget.order.paymentCategory) {
      case PaymentCategory.qris:
        return _buildQrisBarcodeCard();
      case PaymentCategory.ewallet:
        return _buildEWalletSummaryCard();
      case PaymentCategory.bank:
        return _buildBankVirtualAccountCard();
    }
  }

  Widget _buildQrisBarcodeCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7A1C79),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'QRIS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Flexible(
                      child: Text(
                        'Barcode QRIS',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                  ],
                ),
                _buildStatusBadge(),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: AppColors.border),
          ),
          const Text(
            'LiveTix Official',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'NMID: ${widget.order.vaNumber}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF475467)),
          ),
          const SizedBox(height: 16),
          AppQrCodeView(
            qrCodeUrl: widget.order.qrCodeUrl,
            qrCodeBytes: widget.order.qrCodeBytes,
            size: 184,
            padding: 14,
            semanticLabel: 'Kode Barcode QRIS Pembayaran LiveTix',
          ),
          const SizedBox(height: 14),
          const Text(
            'Pindai kode QRIS di atas dengan m-banking atau e-wallet Anda',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Color(0xFF475467)),
          ),
          const SizedBox(height: 14),
          _buildCopyableTotalRow(),
        ],
      ),
    );
  }

  Widget _buildEWalletSummaryCard() {
    final rule = EWalletProviderRule.of(widget.order.paymentProvider);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: rule.brandColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        rule.displayName.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        'E-Wallet ${rule.displayName}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                  ],
                ),
                _buildStatusBadge(),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: AppColors.border),
          ),
          const Text(
            'Total Pembayaran Otomatis',
            style: TextStyle(fontSize: 12, color: Color(0xFF475467)),
          ),
          const SizedBox(height: 4),
          Text(
            _formatCurrency(widget.order.totalAmount),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text(
                'ID Transaksi',
                style: TextStyle(fontSize: 12, color: Color(0xFF475467)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.order.orderId,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
          if (_ewalletCheckMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isOrderPaid
                    ? const Color(0xFFECFDF5)
                    : const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _isOrderPaid
                      ? const Color(0xFFA7F3D0)
                      : const Color(0xFFFDE68A),
                ),
              ),
              child: Text(
                _ewalletCheckMessage!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _isOrderPaid
                      ? const Color(0xFF065F46)
                      : const Color(0xFF92400E),
                  height: 1.35,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBankVirtualAccountCard() {
    final bankRule = BankPaymentRule.of(widget.order.paymentProvider);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: bankRule.badgeColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        bankRule.badgeText,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        bankRule.methodTitle,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                  ],
                ),
                _buildStatusBadge(),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: AppColors.border),
          ),

          Text(
            bankRule.code == 'Mandiri'
                ? 'Kode Bayar / Nomor Virtual Account (Kode 89022)'
                : bankRule.code == 'BRI'
                    ? 'Nomor BRIVA (Kode 77889)'
                    : 'Nomor Virtual Account',
            style: const TextStyle(fontSize: 12, color: Color(0xFF475467)),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.order.vaNumber,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                button: true,
                label: 'Salin nomor Virtual Account',
                child: InkWell(
                  onTap: () => _copyToClipboard(
                    widget.order.vaNumber.replaceAll(' ', ''),
                    'Nomor Virtual Account',
                  ),
                  borderRadius: BorderRadius.circular(8),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F3FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.copy_rounded, size: 14, color: AppColors.primary),
                            SizedBox(width: 4),
                            Text(
                              'Salin',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildCopyableTotalRow(),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nama Akun',
                style: TextStyle(fontSize: 12, color: Color(0xFF475467)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.order.vaName,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              bankRule.ruleNote,
              style: const TextStyle(
                fontSize: 11.5,
                color: Color(0xFF475467),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCopyableTotalRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Total Pembayaran',
          style: TextStyle(fontSize: 12, color: Color(0xFF475467)),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                _formatCurrency(widget.order.totalAmount),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              button: true,
              label: 'Salin total pembayaran',
              child: InkWell(
                onTap: () => _copyToClipboard(
                  widget.order.totalAmount.toString(),
                  'Total Pembayaran',
                ),
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F3FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.copy_rounded, size: 14, color: AppColors.primary),
                          SizedBox(width: 4),
                          Text(
                            'Salin',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildItemizedBreakdownCard() {
    final subtotal = widget.order.ticketPrice * widget.order.quantity;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Rincian pembayaran & biaya admin',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 14),
          _buildBreakdownRow(
            '${widget.order.quantity}x Tiket ${widget.order.tier.name}',
            _formatCurrency(subtotal),
          ),
          const SizedBox(height: 8),
          _buildBreakdownRow(
            'Biaya layanan platform',
            _formatCurrency(widget.order.serviceFee),
          ),
          const SizedBox(height: 8),
          _buildBreakdownRow(
            'Biaya admin & pajak',
            _formatCurrency(widget.order.taxAndAdmin),
          ),
          if (widget.order.transactionFee > 0) ...[
            const SizedBox(height: 8),
            _buildBreakdownRow(
              'Biaya transaksi (${widget.order.paymentProvider})',
              _formatCurrency(widget.order.transactionFee),
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: AppColors.border),
          ),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Harga Total',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              Text(
                _formatCurrency(widget.order.totalAmount),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(String label, String amount) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF475467)),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          amount,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentGuideCard() {
    List<String> guideSteps;
    String title = 'Cara membayar';

    switch (widget.order.paymentCategory) {
      case PaymentCategory.qris:
        title = 'Cara membayar via QRIS';
        guideSteps = [
          'Buka aplikasi mobile banking atau dompet digital pendukung QRIS di ponsel Anda.',
          'Pilih menu Scan / Bayar QRIS lalu pindai barcode QRIS LiveTix di atas.',
          'Pastikan nama merchant LiveTix Official dan nominal ${_formatCurrency(widget.order.totalAmount)} sesuai, lalu masukkan PIN Anda.',
        ];
      case PaymentCategory.ewallet:
        final provider = widget.order.paymentProvider;
        title = 'Cara membayar via $provider';
        guideSteps = [
          'Tekan tombol Lanjut ke Aplikasi $provider di bagian bawah layar ini.',
          'Aplikasi $provider akan terbuka dengan nominal tagihan ${_formatCurrency(widget.order.totalAmount)} yang sudah diatur otomatis.',
          'Masukkan 6 digit PIN $provider Anda, lalu kembali ke LiveTix dan tekan Cek Pembayaran untuk melihat tiket di menu Tiket.',
        ];
      case PaymentCategory.bank:
        final bankRule = BankPaymentRule.of(widget.order.paymentProvider);
        title = 'Cara membayar (${bankRule.appName})';
        final cleanVa = widget.order.vaNumber.replaceAll(' ', '');
        guideSteps = bankRule.steps
            .map(
              (s) => s
                  .replaceAll('{VA}', cleanVa)
                  .replaceAll('{TOTAL}', _formatCurrency(widget.order.totalAmount)),
            )
            .toList();
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 14),
          ...List.generate(guideSteps.length, (idx) {
            return Padding(
              padding: EdgeInsets.only(bottom: idx == guideSteps.length - 1 ? 0 : 12),
              child: _buildGuideItem(idx + 1, guideSteps[idx]),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildGuideItem(int step, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            color: Color(0xFFF1F5F9),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            '$step',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            description,
            style: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFF475467),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWarningBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Selesaikan transaksi sebelum batas waktu 1 jam berakhir agar pesanan tiket tidak dibatalkan otomatis.',
              style: TextStyle(
                fontSize: 11.5,
                color: Color(0xFF92400E),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    if (widget.order.paymentCategory == PaymentCategory.ewallet) {
      return _buildEWalletBottomBar();
    }

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
            onPressed: _handlePaymentConfirmation,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Saya Sudah Bayar',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEWalletBottomBar() {
    final provider = widget.order.paymentProvider;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        child: !_hasReturnedFromEWalletApp
            ? SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  key: const Key('continue_to_ewallet_app_button'),
                  onPressed: _openEWalletApp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Lanjut ke Aplikasi $provider',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final stackVertically = constraints.maxWidth < 310;
                  final checkBtn = SizedBox(
                    height: 48,
                    width: stackVertically ? double.infinity : null,
                    child: ElevatedButton(
                      key: const Key('check_ewallet_payment_button'),
                      onPressed: _handleCheckEWalletPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cek Pembayaran',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );

                  final reopenBtn = SizedBox(
                    height: 48,
                    width: stackVertically ? double.infinity : null,
                    child: OutlinedButton(
                      key: const Key('reopen_ewallet_app_button'),
                      onPressed: _openEWalletApp,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary, width: 1.3),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Lanjut ke Aplikasi',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );

                  if (stackVertically) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        checkBtn,
                        const SizedBox(height: 8),
                        reopenBtn,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: checkBtn),
                      const SizedBox(width: 10),
                      Expanded(child: reopenBtn),
                    ],
                  );
                },
              ),
      ),
    );
  }
}
