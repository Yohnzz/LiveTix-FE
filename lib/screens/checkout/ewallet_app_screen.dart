import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_colors.dart';
import '../../models/ticket_order_model.dart';
import '../../services/data_service.dart';

/// Simulasi halaman pembayaran di dalam aplikasi E-Wallet (ShopeePay / GoPay / DANA).
/// Catatan Arsitektur: Layar simulasi ini digunakan khusus untuk kebutuhan debug dan pengujian frontend.
/// Pada integrasi backend, sistem akan menghubungkan Payment Gateway Midtrans untuk memperoleh
/// deeplink redirect langsung ke aplikasi e-wallet masing-masing di perangkat pengguna.
/// Nominal tagihan sudah otomatis dikunci sesuai pesanan LiveTix sehingga pengguna
/// cukup memasukkan 6 digit PIN E-Wallet, lalu kembali ke aplikasi LiveTix.
class EWalletPaymentAppScreen extends StatefulWidget {
  final OrderModel order;
  final String providerName;

  const EWalletPaymentAppScreen({
    super.key,
    required this.order,
    required this.providerName,
  });

  @override
  State<EWalletPaymentAppScreen> createState() =>
      _EWalletPaymentAppScreenState();
}

class _EWalletPaymentAppScreenState extends State<EWalletPaymentAppScreen> {
  final TextEditingController _pinController = TextEditingController();
  String? _pinError;
  bool _paymentCompleted = false;

  EWalletProviderRule get _rule =>
      EWalletProviderRule.of(widget.providerName);

  @override
  void initState() {
    super.initState();
    _paymentCompleted = DataService().isOrderPaid(widget.order.orderId);
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _submitPinPayment() {
    final pin = _pinController.text.trim();
    if (pin.length != 6) {
      setState(() {
        _pinError = 'Masukkan tepat 6 digit angka PIN ${_rule.displayName}';
      });
      return;
    }

    DataService().markOrderPaid(widget.order.orderId);
    setState(() {
      _pinError = null;
      _paymentCompleted = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final rule = _rule;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: rule.brandColor,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Kembali ke LiveTix',
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context, _paymentCompleted),
        ),
        title: Text(
          'Aplikasi ${rule.displayName}',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: _paymentCompleted
            ? _buildCompletedReceiptCard(rule)
            : _buildPinPaymentFormCard(rule),
      ),
    );
  }

  Widget _buildPinPaymentFormCard(EWalletProviderRule rule) {
    final enteredLen = _pinController.text.trim().length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: rule.brandColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      rule.displayName.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Konfirmasi Pembayaran Merchant',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1, color: AppColors.border),
              ),
              const Text(
                'Merchant Tujuan',
                style: TextStyle(fontSize: 12, color: Color(0xFF475467)),
              ),
              const SizedBox(height: 3),
              Text(
                'LiveTix Official · ${widget.order.concert.title}',
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Nominal Pembayaran (Otomatis dari LiveTix)',
                style: TextStyle(fontSize: 12, color: Color(0xFF475467)),
              ),
              const SizedBox(height: 4),
              Text(
                widget.order.formatCurrency(widget.order.totalAmount),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: rule.brandColor,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 14,
                      color: Color(0xFF475467),
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Nominal sudah diatur otomatis oleh aplikasi LiveTix',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475467),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Input PIN E-Wallet 6 Digit
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Masukkan PIN ${rule.displayName}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Masukkan 6 digit PIN ${rule.displayName} Anda untuk menyelesaikan transaksi ini.',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF475467),
                ),
              ),
              const SizedBox(height: 16),

              // Indikator 6 titik PIN
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (idx) {
                  final filled = idx < enteredLen;
                  return Container(
                    width: 16,
                    height: 16,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? rule.brandColor : const Color(0xFFE2E8F0),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),

              TextField(
                key: const Key('ewallet_pin_field'),
                controller: _pinController,
                obscureText: true,
                maxLength: 6,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) {
                  setState(() {
                    if (_pinError != null) _pinError = null;
                  });
                },
                onSubmitted: (_) => _submitPinPayment(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 8,
                  color: AppColors.textDark,
                ),
                decoration: InputDecoration(
                  labelText: 'PIN ${rule.displayName} (6 digit)',
                  hintText: '••••••',
                  counterText: '',
                  errorText: _pinError,
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: rule.brandColor, width: 1.8),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  key: const Key('ewallet_pay_now_button'),
                  onPressed: _submitPinPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: rule.brandColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Bayar ${widget.order.formatCurrency(widget.order.totalAmount)}',
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF475467),
                  ),
                  child: const Text(
                    'Nanti Saja, Kembali ke LiveTix',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompletedReceiptCard(EWalletProviderRule rule) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: const BoxDecoration(
              color: Color(0xFFECFDF5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF065F46),
              size: 42,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Pembayaran ${rule.displayName} Berhasil',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Nominal ${widget.order.formatCurrency(widget.order.totalAmount)} untuk LiveTix Official telah terbayar.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF475467),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              key: const Key('ewallet_return_to_livetix_button'),
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: rule.brandColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Kembali ke Aplikasi LiveTix',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
