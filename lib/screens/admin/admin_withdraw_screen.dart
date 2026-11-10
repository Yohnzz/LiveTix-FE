import 'package:flutter/material.dart';
import '../../services/data_service.dart';
import '../../services/payment_gateway_service.dart';
import 'widgets/admin_theme.dart';
import 'widgets/admin_widgets.dart';

class AdminWithdrawScreen extends StatefulWidget {
  const AdminWithdrawScreen({super.key});

  @override
  State<AdminWithdrawScreen> createState() => _AdminWithdrawScreenState();
}

class _AdminWithdrawScreenState extends State<AdminWithdrawScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _accountNumberController =
      TextEditingController(text: '1234567890');
  final TextEditingController _accountNameController =
      TextEditingController(text: 'PT LiveTix Indonesia');

  String _selectedBank = 'BCA';
  final List<String> _bankList = ['BCA', 'Mandiri', 'BNI', 'BRI'];

  AdminBalanceResult _balance = const AdminBalanceResult(
    totalFeeCollected: 0,
    availableFeeBalance: 0,
    totalFeeWithdrawn: 0,
  );

  bool _isLoading = true;
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _feeHistory = [
    {
      'concert': 'Soundwave Fest 2026',
      'orderId': 'ORD-20261109-8891',
      'gross': 1500000,
      'fee': 45000,
      'date': 'Hari ini, 14:20 WIB',
    },
    {
      'concert': 'Harmoni Nusantara 2026',
      'orderId': 'ORD-20261109-7712',
      'gross': 2800000,
      'fee': 84000,
      'date': 'Hari ini, 11:05 WIB',
    },
    {
      'concert': 'Jazz Kota Lama 2026',
      'orderId': 'ORD-20261108-6623',
      'gross': 950000,
      'fee': 28500,
      'date': 'Kemarin, 19:40 WIB',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _accountNumberController.dispose();
    _accountNameController.dispose();
    super.dispose();
  }

  Future<void> _loadBalance() async {
    setState(() => _isLoading = true);
    final res = await PaymentGatewayService().getAdminBalance();
    if (mounted) {
      setState(() {
        _balance = res;
        _isLoading = false;
        if (_balance.availableFeeBalance > 0) {
          _amountController.text = _formatCurrencyRaw(_balance.availableFeeBalance);
        }
      });
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

  String _formatCurrencyRaw(int amount) {
    final buffer = StringBuffer();
    final str = amount.toString();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  Future<void> _handleWithdrawSubmit() async {
    final clean = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final amount = int.tryParse(clean) ?? 0;

    if (amount < 50000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nominal penarikan minimum fee admin adalah Rp 50.000'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    if (amount > _balance.availableFeeBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Nominal melebihi saldo fee tersedia (${_formatCurrency(_balance.availableFeeBalance)})'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final user = DataService().currentUser;
    final res = await PaymentGatewayService().requestAdminWithdrawal(
      adminId: user?.id ?? 'a0000000-0000-0000-0000-000000000001',
      amount: amount,
      bankName: _selectedBank,
      accountNumber: _accountNumberController.text.trim(),
      accountName: _accountNameController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (res['success'] == true) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFF10B981)),
              SizedBox(width: 8),
              Text('Penarikan Diproses',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          content: Text(
            res['message'] as String? ??
                'Penarikan fee admin ${_formatCurrency(amount)} sedang diproses melalui Midtrans Iris.',
            style: const TextStyle(fontSize: 13.5),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      _loadBalance();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] as String? ?? 'Gagal memproses penarikan'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPri = AdminColors.textPrimaryOf(context);
    final textSec = AdminColors.textSecondaryOf(context);

    return Scaffold(
      backgroundColor: AdminColors.surfaceOf(context),
      appBar: AppBar(
        title: const Text('Penarikan Dana Admin',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF4C1D95),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)))
          : RefreshIndicator(
              onRefresh: _loadBalance,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                children: [
                  // 1. Hero Card: Saldo Fee Admin 3%
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4C1D95), Color(0xFF6D28D9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4C1D95).withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.account_balance_wallet_rounded,
                                color: Colors.white70, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'SALDO FEE ADMIN TERSEDIA (3%)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white70,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _formatCurrency(_balance.availableFeeBalance),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Divider(height: 1, color: Colors.white24),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Terkumpul: ${_formatCurrency(_balance.totalFeeCollected)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              'Telah Ditarik: ${_formatCurrency(_balance.totalFeeWithdrawn)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 2. Form Penarikan Fee Admin
                  Text(
                    'Form Pengajuan Penarikan Fee',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: textPri,
                    ),
                  ),
                  const SizedBox(height: 10),
                  AdminCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Nominal Penarikan (Rp)',
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: textSec)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _amountController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            prefixText: 'Rp ',
                            prefixStyle: TextStyle(
                                fontWeight: FontWeight.w700, color: textPri),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: Color(0xFF7C3AED), width: 1.5),
                            ),
                            filled: true,
                            fillColor: AdminColors.surfaceOf(context),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text('Bank Tujuan',
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: textSec)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedBank,
                          items: _bankList
                              .map((b) => DropdownMenuItem(
                                    value: b,
                                    child: Text(b,
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: textPri)),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedBank = val);
                          },
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: AdminColors.surfaceOf(context),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text('Nomor Rekening',
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: textSec)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _accountNumberController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: AdminColors.surfaceOf(context),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text('Nama Pemilik Rekening',
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: textSec)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _accountNameController,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: AdminColors.surfaceOf(context),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _handleWithdrawSubmit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7C3AED),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text('Tarik Fee Admin Sekarang',
                                    style: TextStyle(
                                        fontSize: 14, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 3. Riwayat Mutasi Fee 3%
                  Text(
                    'Riwayat Fee Transaksi Konser (3%)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: textPri,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ..._feeHistory.map((h) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AdminCard(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.percent_rounded,
                                    color: Color(0xFF059669), size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      h['concert'] as String,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: textPri,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${h['orderId']} · ${h['date']}',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: textSec,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '+${_formatCurrency(h['fee'] as int)}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF059669),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Gross: ${_formatCurrency(h['gross'] as int)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: textSec,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      )),
                ],
              ),
            ),
    );
  }
}
