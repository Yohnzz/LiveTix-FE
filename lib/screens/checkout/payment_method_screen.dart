import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../models/ticket_order_model.dart';
import '../../services/data_service.dart';
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
  bool _isEWalletExpanded = false;
  bool _isBankExpanded = false;

  String _formatCurrency(int amount) => widget.order.formatCurrency(amount);

  void _selectMethod({
    required PaymentCategory category,
    required String provider,
  }) {
    final fee = DataService().getTransactionFee(category, provider);
    final configuredOrder = widget.order.copyWithPayment(
      category: category,
      provider: provider,
      transactionFee: fee,
    );
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
                    'Pilih QRIS, E-Wallet, atau Transfer Bank. Batas waktu pembayaran berlaku 1 jam.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF475467),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 1. QRIS (1 jenis, langsung masuk ke menu barcode QRIS)
                  _buildQrisCard(),
                  const SizedBox(height: 12),

                  // 2. E-Wallet (Dropdown: GoPay, DANA, ShopeePay)
                  _buildEWalletDropdownCard(),
                  const SizedBox(height: 12),

                  // 3. Bank (Dropdown: BCA, Mandiri, BRI, SeaBank)
                  _buildBankDropdownCard(),
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
      label: 'Pilih metode pembayaran QRIS. Perkiraan biaya admin transaksi ${_formatCurrency(fee)}',
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
            constraints: const BoxConstraints(minHeight: 68),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F3FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: AppColors.primary,
                    size: 22,
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
                            'QRIS',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                        'Langsung tampilkan barcode QRIS untuk dipindai semua m-banking & dompet digital',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF475467),
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 4),
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
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textDark,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEWalletDropdownCard() {
    const providers = [
      ('GoPay', 'Terhubung ke aplikasi GoPay / Gojek (PIN 6 digit)'),
      ('DANA', 'Terhubung ke aplikasi DANA (PIN 6 digit)'),
      ('ShopeePay', 'Terhubung ke aplikasi ShopeePay (PIN 6 digit)'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isEWalletExpanded ? AppColors.primary : AppColors.border,
          width: _isEWalletExpanded ? 1.4 : 1.0,
        ),
      ),
      child: Column(
        children: [
          Semantics(
            button: true,
            toggled: _isEWalletExpanded,
            label: 'Metode E-Wallet, klik untuk memilih GoPay, DANA, atau ShopeePay',
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                key: const Key('payment_method_ewallet_toggle'),
                onTap: () {
                  setState(() {
                    _isEWalletExpanded = !_isEWalletExpanded;
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 68),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F3FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet_outlined,
                            color: AppColors.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'E-Wallet',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textDark,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'GoPay, DANA, ShopeePay (pembayaran instan dengan PIN aplikasi)',
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
                        Icon(
                          _isEWalletExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: AppColors.textDark,
                          size: 24,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_isEWalletExpanded) ...[
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: providers.map((entry) {
                  final code = entry.$1;
                  final subtitle = entry.$2;
                  final fee = DataService().getTransactionFee(PaymentCategory.ewallet, code);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildSubOptionTile(
                      tileKey: Key('ewallet_option_${code.toLowerCase()}'),
                      badgeLabel: code.toUpperCase(),
                      title: code,
                      subtitle: subtitle,
                      fee: fee,
                      onTap: () => _selectMethod(
                        category: PaymentCategory.ewallet,
                        provider: code,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBankDropdownCard() {
    const banks = [
      ('BCA', 'BCA Virtual Account via BCA Mobile (m-BCA) / myBCA'),
      ('Mandiri', 'Mandiri Multipayment (Kode 89022) via Livin\' by Mandiri'),
      ('BRI', 'BRIVA (Kode 77889) via aplikasi BRImo / ATM BRI'),
      ('SeaBank', 'SeaBank Virtual Account via aplikasi SeaBank'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isBankExpanded ? AppColors.primary : AppColors.border,
          width: _isBankExpanded ? 1.4 : 1.0,
        ),
      ),
      child: Column(
        children: [
          Semantics(
            button: true,
            toggled: _isBankExpanded,
            label: 'Metode Transfer Bank, klik untuk memilih BCA, Mandiri, BRI, atau SeaBank',
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                key: const Key('payment_method_bank_toggle'),
                onTap: () {
                  setState(() {
                    _isBankExpanded = !_isBankExpanded;
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 68),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F3FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.account_balance_outlined,
                            color: AppColors.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bank (Virtual Account)',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textDark,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'BCA, Mandiri, BRI, SeaBank sesuai aturan pembayaran tiap bank',
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
                        Icon(
                          _isBankExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: AppColors.textDark,
                          size: 24,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_isBankExpanded) ...[
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: banks.map((entry) {
                  final code = entry.$1;
                  final subtitle = entry.$2;
                  final fee = DataService().getTransactionFee(PaymentCategory.bank, code);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildSubOptionTile(
                      tileKey: Key('bank_option_${code.toLowerCase()}'),
                      badgeLabel: code.toUpperCase(),
                      title: 'Bank $code',
                      subtitle: subtitle,
                      fee: fee,
                      onTap: () => _selectMethod(
                        category: PaymentCategory.bank,
                        provider: code,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubOptionTile({
    required Key tileKey,
    required String badgeLabel,
    required String title,
    required String subtitle,
    required int fee,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: tileKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                constraints: const BoxConstraints(minWidth: 64),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  badgeLabel,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 2,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '+${_formatCurrency(fee)}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF475467),
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Perkiraan biaya admin transaksi: +${_formatCurrency(fee)} (langsung ditambahkan)',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF065F46),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppColors.textDark,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
