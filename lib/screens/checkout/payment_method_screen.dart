import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../models/ticket_order_model.dart';
import '../../services/data_service.dart';
import '../../services/payment_gateway_service.dart';
import '../../services/supabase_service.dart';
import 'payment_screen.dart';
import 'widgets/checkout_stepper.dart';

class PaymentMethodScreen extends StatefulWidget {
  final OrderModel order;

  const PaymentMethodScreen({
    super.key,
    required this.order,
  });

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  String _formatCurrency(int amount) => widget.order.formatCurrency(amount);

  void _selectMethod({
    required PaymentCategory category,
    required String provider,
  }) async {
    final fee = DataService().getTransactionFee(category, provider);

    var configuredOrder = widget.order.copyWithPayment(
      category: category,
      provider: provider,
      transactionFee: fee,
    );

    if (SupabaseService.isInitialized) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 14),
                  Text(
                    'Menyiapkan tagihan pembayaran...',
                    style:
                        TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Selalu generate orderId baru dan unik untuk mencegah konflik HTTP 406 dari Midtrans
      // jika user pernah menekan kembali lalu memilih metode pembayaran lagi
      final freshOrderId =
          'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

      final currentUser = DataService().currentUser;
      final chargeResult = await PaymentGatewayService().createPaymentCharge(
        orderId: freshOrderId,
        concertId: widget.order.concert.id,
        tierId: widget.order.tier.id,
        quantity: widget.order.quantity,
        paymentMethod: provider,
        customerName: widget.order.customerName,
        customerEmail: widget.order.customerEmail,
        customerPhone: currentUser?.phone ?? '081234567890',
        userId: currentUser?.id,
      );

      if (!mounted) return;
      Navigator.pop(context); // Tutup loading dialog

      configuredOrder = widget.order.copyWithPayment(
        orderId: freshOrderId,
        category: category,
        provider: provider,
        transactionFee: fee,
        qrString: chargeResult.qrString,
        qrCodeUrl: chargeResult.qrUrl,
        deeplinkUrl: chargeResult.deeplinkUrl,
        vaNumber: chargeResult.vaNumber,
        expiresAt: chargeResult.expiresAt,
      );

      // Simpan pesanan tiket berstatus pending ke menu Tiket Saya
      DataService().addPendingOrderTicket(configuredOrder);
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentScreen(order: configuredOrder),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          'Pilih metode pembayaran',
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CheckoutStepper(currentStep: 2),
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOrderTotalBanner(),
                  const SizedBox(height: 20),
                  const Text(
                    'Metode pembayaran tersedia',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Pembayaran universal melalui QRIS. Mendukung semua dompet digital dan m-banking di Indonesia dengan verifikasi otomatis.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF475467),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // QRIS Universal Card (Satu-satunya metode pembayaran resmi)
                  _buildQrisCard(),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderTotalBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.order.concert.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.order.quantity}x Tiket ${widget.order.tier.name} · Berlaku ${widget.order.quantity}x scan gate',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF475467),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Total tagihan',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF475467)),
              ),
              const SizedBox(height: 2),
              Text(
                widget.order.formatCurrency(widget.order.totalAmount),
                style: const TextStyle(
                  fontSize: 16.5,
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

  Widget _buildQrisCard() {
    final fee = DataService().getTransactionFee(PaymentCategory.qris);

    return Semantics(
      button: true,
      label:
          'Pilih metode pembayaran QRIS. Perkiraan biaya admin transaksi ${_formatCurrency(fee)}',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: const Key('payment_method_qris'),
          onTap: () => _selectMethod(
            category: PaymentCategory.qris,
            provider: 'QRIS',
          ),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            constraints: const BoxConstraints(minHeight: 80),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary, width: 1.5),
              color: Colors.white,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A1B2A8C),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F3FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.qr_code_scanner_rounded,
                        color: AppColors.primary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              const Text(
                                'QRIS (Universal)',
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textDark,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '+${_formatCurrency(fee)} admin',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Satu barcode resmi untuk semua e-wallet & m-banking',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF475467),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 12),
                const Text(
                  'Mendukung Pembayaran:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildBrandChip('GoPay'),
                    _buildBrandChip('OVO'),
                    _buildBrandChip('DANA'),
                    _buildBrandChip('ShopeePay'),
                    _buildBrandChip('BCA'),
                    _buildBrandChip('Mandiri'),
                    _buildBrandChip('BRI'),
                    _buildBrandChip('BNI'),
                    _buildBrandChip('SeaBank'),
                    _buildBrandChip('Semua Bank'),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Perkiraan biaya admin transaksi: ${_formatCurrency(fee)} (langsung ditambahkan)',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF065F46),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFF334155),
        ),
      ),
    );
  }

}
