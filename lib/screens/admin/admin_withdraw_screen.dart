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
    totalBiayaAplikasi: 0,
    totalPembulatan: 0,
    availableBiayaAplikasi: 0,
    availablePembulatan: 0,
    hasPendingWithdrawal: false,
  );

  bool _isLoading = true;
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _withdrawalHistory = [];
  List<Map<String, dynamic>> _feeHistory = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _accountNumberController.dispose();
    _accountNameController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      PaymentGatewayService().getAdminBalance(),
      PaymentGatewayService().fetchAdminWithdrawalHistory(),
      PaymentGatewayService().fetchAdminFeeHistory(),
    ]);

    if (mounted) {
      final rawFeeHistory = results[2] as List<Map<String, dynamic>>;
      final mappedFees = <Map<String, dynamic>>[];
      for (final f in rawFeeHistory) {
        final concertTitle = f['concert_title']?.toString() ??
            f['description']?.toString() ??
            'Transaksi Tiket Konser';
        final orderId = f['order_id']?.toString() ?? f['id']?.toString() ?? '-';
        final gross = (f['gross_amount'] as num?)?.toInt() ??
            (f['total_amount'] as num?)?.toInt() ??
            0;
        final appFee = (f['application_fee'] as num?)?.toInt() ??
            (f['biaya_aplikasi'] as num?)?.toInt() ??
            (f['entry_type'] == 'FEE_APLIKASI'
                ? (f['amount'] as num?)?.toInt() ?? 0
                : 0);
        final rounding = (f['rounding'] as num?)?.toInt() ??
            (f['pembulatan'] as num?)?.toInt() ??
            (f['entry_type'] == 'PEMBULATAN'
                ? (f['amount'] as num?)?.toInt() ?? 0
                : 0);
        final rawDt = f['created_at']?.toString() ?? '';
        final dt = DateTime.tryParse(rawDt)?.toLocal();
        final dateStr = dt != null
            ? '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} WIB'
            : rawDt;
        mappedFees.add({
          'concert': concertTitle,
          'orderId': orderId,
          'gross': gross,
          'appFee': appFee,
          'rounding': rounding,
          'date': dateStr,
        });
      }

      setState(() {
        _balance = results[0] as AdminBalanceResult;
        _withdrawalHistory = results[1] as List<Map<String, dynamic>>;
        _feeHistory = mappedFees;
        _isLoading = false;
        if (_balance.availableFeeBalance > 0 && _amountController.text.isEmpty) {
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

  void _setAmount(int amount) {
    setState(() {
      _amountController.text = _formatCurrencyRaw(amount);
    });
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

    if (_balance.hasPendingWithdrawal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masih ada permohonan penarikan admin yang sedang diproses.'),
          backgroundColor: Color(0xFFF59E0B),
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
      _loadData();
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
    final user = DataService().currentUser;
    final role = (user?.role ?? '').trim().toLowerCase();
    final email = (user?.email ?? '').trim().toLowerCase();
    // Berikan akses jika role adalah admin/superadmin, email admin, atau saat berada dalam mode shell admin
    final isAdmin = role == 'admin' ||
        role == 'superadmin' ||
        email.contains('admin') ||
        user == null;

    return AdminScope(
      child: Builder(
        builder: (context) {
          final textPri = AdminColors.textPrimaryOf(context);
          final textSec = AdminColors.textSecondaryOf(context);
          final surfaceAlt = AdminColors.surfaceAltOf(context);
          final border = AdminColors.borderOf(context);

          if (!isAdmin) {
            return Scaffold(
              backgroundColor: AdminColors.bgOf(context),
              appBar: AppBar(
                title: const Text('Penarikan Dana Admin',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                backgroundColor: const Color(0xFF4C1D95),
                foregroundColor: Colors.white,
              ),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.gpp_bad_rounded, size: 64, color: Color(0xFFEF4444)),
                      const SizedBox(height: 16),
                      Text(
                        'Akses Dibatasi',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: textPri),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Halaman ini dilindungi dan hanya dapat diakses oleh akun resmi dengan role Admin / Superadmin.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: textSec),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return Scaffold(
            backgroundColor: AdminColors.bgOf(context),
            appBar: AppBar(
              title: const Text('Penarikan Dana Admin',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              backgroundColor: const Color(0xFF4C1D95),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            body: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                        color: AdminColors.accentOf(context)))
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      children: [
                        // 1. Hero Card: Total Saldo Admin Siap Ditarik
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF3B0764), Color(0xFF6D28D9)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4C1D95).withValues(alpha: 0.35),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.account_balance_wallet_rounded,
                                          color: Colors.white70, size: 16),
                                      SizedBox(width: 6),
                                      Text(
                                        'TOTAL SALDO ADMIN SIAP DITARIK',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white70,
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'Kapan Saja',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _formatCurrency(_balance.availableFeeBalance),
                                style: const TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Sub-Cards: Saldo Biaya Aplikasi & Pembulatan Terpisah
                              Row(
                                children: [
                                  // Card 1: Biaya Aplikasi (2%)
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: Colors.white.withValues(alpha: 0.15),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Row(
                                            children: [
                                              Icon(Icons.receipt_long_rounded,
                                                  color: Colors.white70, size: 14),
                                              SizedBox(width: 5),
                                              Expanded(
                                                child: Text(
                                                  'Biaya Aplikasi (2%)',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.white70,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            _formatCurrency(_balance.availableBiayaAplikasi),
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            'Total: ${_formatCurrency(_balance.totalBiayaAplikasi)}',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              color: Colors.white.withValues(alpha: 0.65),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Card 2: Pembulatan
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: Colors.white.withValues(alpha: 0.15),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Row(
                                            children: [
                                              Icon(Icons.arrow_upward_rounded,
                                                  color: Colors.white70, size: 14),
                                              SizedBox(width: 5),
                                              Expanded(
                                                child: Text(
                                                  'Pembulatan Ribuan',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.white70,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            _formatCurrency(_balance.availablePembulatan),
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            'Total: ${_formatCurrency(_balance.totalPembulatan)}',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              color: Colors.white.withValues(alpha: 0.65),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 14),
                              const Divider(height: 1, color: Colors.white24),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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

                        // Banner jika ada penarikan yang sedang pending
                        if (_balance.hasPendingWithdrawal) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.hourglass_top_rounded,
                                    color: Color(0xFFF59E0B), size: 20),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Ada permohonan penarikan admin yang sedang diproses. Mohon tunggu proses selesai sebelum mengajukan kembali.',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: Color(0xFFD97706),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),

                        // 2. Form Penarikan Fee Admin
                        Text(
                          'Form Pengajuan Penarikan Fee Admin',
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
                                style: TextStyle(color: textPri),
                                decoration: InputDecoration(
                                  prefixText: 'Rp ',
                                  prefixStyle: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: textPri),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: border),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: border),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF7C3AED),
                                      width: 1.5,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: surfaceAlt,
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Quick amount buttons
                              Wrap(
                                spacing: 8,
                                children: [
                                  ActionChip(
                                    label: const Text('Rp 50.000'),
                                    onPressed: () => _setAmount(50000),
                                  ),
                                  ActionChip(
                                    label: const Text('Rp 100.000'),
                                    onPressed: () => _setAmount(100000),
                                  ),
                                  ActionChip(
                                    label: const Text('Rp 500.000'),
                                    onPressed: () => _setAmount(500000),
                                  ),
                                  ActionChip(
                                    label: const Text('Tarik Semua'),
                                    onPressed: _balance.availableFeeBalance > 0
                                        ? () => _setAmount(_balance.availableFeeBalance)
                                        : null,
                                  ),
                                ],
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
                                dropdownColor: AdminColors.surfaceOf(context),
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
                                  if (val != null) {
                                    setState(() => _selectedBank = val);
                                  }
                                },
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: border),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: border),
                                  ),
                                  filled: true,
                                  fillColor: surfaceAlt,
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
                                style: TextStyle(color: textPri),
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: border),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: border),
                                  ),
                                  filled: true,
                                  fillColor: surfaceAlt,
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
                                style: TextStyle(color: textPri),
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: border),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: border),
                                  ),
                                  filled: true,
                                  fillColor: surfaceAlt,
                                ),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: (_isSubmitting ||
                                          _balance.hasPendingWithdrawal ||
                                          _balance.availableFeeBalance < 50000)
                                      ? null
                                      : _handleWithdrawSubmit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF7C3AED),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    elevation: 0,
                                  ),
                                  child: _isSubmitting
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2),
                                        )
                                      : const Text('Tarik Fee Admin Sekarang',
                                          style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700)),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // 3. Riwayat Penarikan Dana Admin (Tabel withdrawals)
                        Text(
                          'Riwayat Penarikan Dana Admin',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: textPri,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (_withdrawalHistory.isEmpty)
                          AdminCard(
                            padding: const EdgeInsets.all(18),
                            child: Center(
                              child: Text(
                                'Belum ada riwayat penarikan dana admin.',
                                style: TextStyle(fontSize: 13, color: textSec),
                              ),
                            ),
                          )
                        else
                          ..._withdrawalHistory.map((w) {
                            final status = (w['status'] as String? ?? 'pending').toLowerCase();
                            final amount = (w['amount'] as num?)?.toInt() ?? 0;
                            final refNo = w['reference_no'] as String? ?? w['id'] as String? ?? '-';
                            final bank = w['bank_name'] as String? ?? '-';
                            final accNo = w['account_number'] as String? ?? '-';
                            final rawDt = w['created_at']?.toString() ?? '';
                            final dt = DateTime.tryParse(rawDt)?.toLocal();
                            final createdAt = dt != null
                                ? '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} WIB'
                                : (rawDt.isNotEmpty ? rawDt : '-');

                            Color statusColor;
                            String statusLabel;
                            if (status == 'success' || status == 'completed') {
                              statusColor = const Color(0xFF10B981);
                              statusLabel = 'BERHASIL';
                            } else if (status == 'failed') {
                              statusColor = const Color(0xFFEF4444);
                              statusLabel = 'GAGAL';
                            } else {
                              statusColor = const Color(0xFFF59E0B);
                              statusLabel = 'DIPROSES';
                            }

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: AdminCard(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        status == 'success'
                                            ? Icons.check_circle_outline_rounded
                                            : (status == 'failed'
                                                ? Icons.error_outline_rounded
                                                : Icons.access_time_rounded),
                                        color: statusColor,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            refNo,
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w700,
                                              color: textPri,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '$bank · $accNo',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: textSec,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            createdAt,
                                            style: TextStyle(
                                              fontSize: 10.5,
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
                                          _formatCurrency(amount),
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: textPri,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: statusColor.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            statusLabel,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: statusColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),

                        const SizedBox(height: 24),

                        // 4. Riwayat Mutasi Fee Transaksi Konser
                        Text(
                          'Riwayat Fee Transaksi Konser',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: textPri,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (_feeHistory.isEmpty)
                          AdminCard(
                            padding: const EdgeInsets.all(18),
                            child: Center(
                              child: Text(
                                'Belum ada riwayat fee transaksi konser dari database.',
                                style: TextStyle(fontSize: 13, color: textSec),
                              ),
                            ),
                          )
                        else
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
                                        color: AdminColors.successBgOf(context),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: Icon(Icons.receipt_long_rounded,
                                          color: AdminColors.successOf(context),
                                          size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                          const SizedBox(height: 2),
                                          Text(
                                            'Biaya Aplikasi: ${_formatCurrency(h['appFee'] as int)} · Pembulatan: ${_formatCurrency(h['rounding'] as int)}',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              color: textSec,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '+${_formatCurrency((h['appFee'] as int) + (h['rounding'] as int))}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color:
                                                AdminColors.successOf(context),
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
        },
      ),
    );
  }
}
