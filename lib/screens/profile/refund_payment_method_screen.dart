import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_colors.dart';
import '../../services/data_service.dart';

/// Halaman pengaturan metode pembayaran akun khusus penerimaan pencairan refund tiket.
/// Sesuai kebijakan keamanan LiveTix, penambahan atau perubahan rekening refund
/// menerapkan masa cooldown selama 1 minggu (7 hari) pasca pembaruan terakhir.
class RefundPaymentMethodScreen extends StatefulWidget {
  const RefundPaymentMethodScreen({super.key});

  @override
  State<RefundPaymentMethodScreen> createState() =>
      _RefundPaymentMethodScreenState();
}

class _RefundPaymentMethodScreenState extends State<RefundPaymentMethodScreen> {
  Timer? _ticker;

  final List<String> _bankOptions = const [
    'Bank BCA',
    'Bank Mandiri',
    'Bank BNI',
    'Bank BRI',
    'Bank SeaBank',
  ];

  final List<String> _ewalletOptions = const [
    'GoPay',
    'DANA',
    'ShopeePay',
    'OVO',
  ];

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _openEditAccountModal(UserRefundAccount? currentAccount, bool isDark) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _EditRefundAccountSheet(
        initialAccount: currentAccount,
        bankOptions: _bankOptions,
        ewalletOptions: _ewalletOptions,
        isDarkMode: isDark,
        onAccountSaved: () {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Rekening refund berhasil disimpan. Masa cooldown 1 minggu kini aktif.',
              ),
              backgroundColor: AppColors.primary,
            ),
          );
        },
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    final day = dt.day.toString().padLeft(2, '0');
    final month = months[dt.month - 1];
    final year = dt.year;
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day $month $year, $hour:$minute WIB';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: DataService().isDarkModeNotifier,
      builder: (context, isDark, _) {
        final bgColor = isDark ? AppColors.darkBg : const Color(0xFFF9FAFB);
        final titleColor = isDark ? AppColors.darkText : AppColors.textDark;

        return ValueListenableBuilder<UserRefundAccount?>(
          valueListenable: DataService().refundAccountNotifier,
          builder: (context, account, _) {
            final isCooldown = account?.isCooldownActive ?? false;

            return Scaffold(
              backgroundColor: bgColor,
              appBar: AppBar(
                backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
                elevation: 0,
                leading: IconButton(
                  tooltip: 'Kembali',
                  icon: Icon(Icons.arrow_back, color: titleColor),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  'Metode Penerima Refund',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
                centerTitle: false,
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Banner Penegasan Fungsi Khusus Refund
                    _buildRefundOnlyNoticeCard(isDark),
                    const SizedBox(height: 16),

                    // Kartu Status Cooldown Keamanan 1 Minggu
                    _buildCooldownStatusCard(
                      account: account,
                      isCooldown: isCooldown,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 20),

                    // Judul Seksi Rekening Aktif
                    Text(
                      'Rekening Pencairan Aktif',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Kartu Rekening Refund
                    if (account != null)
                      _buildActiveAccountCard(account, isDark)
                    else
                      _buildEmptyAccountCard(isDark),
                    const SizedBox(height: 24),

                    // Tombol Aksi Tambah / Ubah Rekening
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        key: const Key('edit_refund_account_button'),
                        onPressed: isCooldown
                            ? null
                            : () => _openEditAccountModal(account, isDark),
                        icon: Icon(
                          account == null
                              ? Icons.add_card_rounded
                              : Icons.edit_note_rounded,
                          size: 20,
                        ),
                        label: Text(
                          account == null
                              ? 'Daftarkan Rekening Refund'
                              : 'Ubah Rekening Refund',
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0),
                          disabledForegroundColor: isDark
                              ? const Color(0xFF64748B)
                              : const Color(0xFF94A3B8),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
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

  Widget _buildRefundOnlyNoticeCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2238) : const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF3730A3) : const Color(0xFFC7D2FE),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.shield_outlined,
            color: isDark ? const Color(0xFF818CF8) : AppColors.primary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Khusus Penerimaan Dana Refund',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFF818CF8) : AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Rekening atau e-wallet yang Anda tetapkan di halaman ini hanya digunakan untuk menerima pencairan dana refund tiket (misalnya saat konser dibatalkan). Metode ini tidak digunakan untuk pembayaran tiket baru.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCooldownStatusCard({
    required UserRefundAccount? account,
    required bool isCooldown,
    required bool isDark,
  }) {
    if (account == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 20,
              color: isDark ? AppColors.darkTextSecondary : const Color(0xFF475467),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Belum ada rekening refund terdaftar. Daftarkan sekarang untuk pencairan dana cepat.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : const Color(0xFF475467),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (isCooldown) {
      final timerText = account.cooldownTimerFormatted;

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2E2008) : const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? const Color(0xFF78350F) : const Color(0xFFFDE68A),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.hourglass_top_rounded,
              color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Masa Cooldown Aktif (Tersisa $timerText)',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFFFCD34D) : const Color(0xFF92400E),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Demi keamanan akun Anda dari pengambilalihan tidak sah, perubahan rekening refund hanya dapat dilakukan 1 kali setiap 1 minggu (7 hari pasca pembaruan terakhir pada ${_formatDateTime(account.lastUpdated)}). Tombol ubah akan aktif kembali saat waktu menunjukkan 00:00:00.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF78350F),
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF047857) : const Color(0xFFA7F3D0),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            color: isDark ? const Color(0xFF34D399) : const Color(0xFF065F46),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Masa Cooldown Selesai (00:00:00)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Anda dapat memperbarui rekening atau e-wallet penerima refund kapan saja jika diperlukan.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF065F46),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveAccountCard(UserRefundAccount account, bool isDark) {
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final titleColor = isDark ? Colors.white : AppColors.textDark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF283548) : const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        account.accountType == 'ewallet'
                            ? Icons.account_balance_wallet_outlined
                            : Icons.account_balance_outlined,
                        color: isDark ? const Color(0xFF818CF8) : AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            account.provider,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: titleColor,
                            ),
                          ),
                          Text(
                            account.accountType == 'ewallet'
                                ? 'Dompet Digital'
                                : 'Transfer Rekening Bank',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDark ? const Color(0xFF047857) : const Color(0xFFA7F3D0),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified,
                      size: 12,
                      color: isDark ? const Color(0xFF34D399) : const Color(0xFF065F46),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'TERVERIFIKASI',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFF34D399) : const Color(0xFF065F46),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Divider(
              height: 1,
              color: isDark ? AppColors.darkBorder : AppColors.border,
            ),
          ),
          _buildInfoRow('Nomor Rekening / Akun', account.maskedAccountNumber, isDark),
          const SizedBox(height: 8),
          _buildInfoRow('Nama Pemilik', account.accountHolderName, isDark),
          const SizedBox(height: 8),
          _buildInfoRow(
            'Terakhir Diperbarui',
            _formatDateTime(account.lastUpdated),
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyAccountCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.credit_card_off_outlined,
            size: 40,
            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF94A3B8),
          ),
          const SizedBox(height: 10),
          Text(
            'Belum Ada Rekening Refund',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tambahkan rekening bank atau e-wallet agar dana refund dapat langsung dikirim ke rekening Anda saat pengajuan disetujui.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.textDark,
            ),
          ),
        ),
      ],
    );
  }
}

/// Bottom Sheet untuk menambah atau mengubah data rekening / e-wallet penerima refund
class _EditRefundAccountSheet extends StatefulWidget {
  final UserRefundAccount? initialAccount;
  final List<String> bankOptions;
  final List<String> ewalletOptions;
  final bool isDarkMode;
  final VoidCallback onAccountSaved;

  const _EditRefundAccountSheet({
    required this.initialAccount,
    required this.bankOptions,
    required this.ewalletOptions,
    this.isDarkMode = false,
    required this.onAccountSaved,
  });

  @override
  State<_EditRefundAccountSheet> createState() =>
      _EditRefundAccountSheetState();
}

class _EditRefundAccountSheetState extends State<_EditRefundAccountSheet> {
  late String _selectedType;
  late String _selectedProvider;
  late final TextEditingController _accountNumberController;
  late final TextEditingController _accountHolderController;
  bool _confirmAccuracy = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final init = widget.initialAccount;
    _selectedType = init?.accountType ?? 'bank';
    _selectedProvider = init?.provider ?? widget.bankOptions.first;
    _accountNumberController = TextEditingController(
      text: init?.accountNumber ?? '',
    );
    final user = DataService().currentUser;
    _accountHolderController = TextEditingController(
      text: init?.accountHolderName ?? (user?.name ?? ''),
    );
  }

  @override
  void dispose() {
    _accountNumberController.dispose();
    _accountHolderController.dispose();
    super.dispose();
  }

  void _onTypeChanged(String type) {
    setState(() {
      _selectedType = type;
      _selectedProvider = type == 'bank'
          ? widget.bankOptions.first
          : widget.ewalletOptions.first;
    });
  }

  void _handleSave() {
    final number = _accountNumberController.text.trim();
    final name = _accountHolderController.text.trim();

    if (number.length < 8) {
      setState(() {
        _errorMessage = 'Nomor rekening atau e-wallet minimal 8 digit angka.';
      });
      return;
    }

    if (name.length < 3) {
      setState(() {
        _errorMessage = 'Nama pemilik rekening wajib diisi sesuai identitas.';
      });
      return;
    }

    if (!_confirmAccuracy) {
      setState(() {
        _errorMessage =
            'Harap centang kotak konfirmasi data rekening terlebih dahulu.';
      });
      return;
    }

    final success = DataService().updateRefundAccount(
      provider: _selectedProvider,
      accountNumber: number,
      accountHolderName: name,
      accountType: _selectedType,
      ignoreCooldown: false,
    );

    if (success) {
      Navigator.pop(context);
      widget.onAccountSaved();
    } else {
      setState(() {
        _errorMessage =
            'Masa cooldown 1 minggu sedang aktif. Rekening belum dapat diubah.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final viewInsets = MediaQuery.of(context).viewInsets;
    final titleColor = isDark ? Colors.white : AppColors.textDark;
    final subtitleColor = isDark ? AppColors.darkTextSecondary : const Color(0xFF475467);
    final inputFill = isDark ? AppColors.darkSurfaceVariant : const Color(0xFFF8FAFC);
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final textColor = isDark ? Colors.white : const Color(0xFF101828);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 14, 20, viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF475569) : const Color(0xFFD0D5DD),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Atur Rekening Penerima Refund',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Pastikan data rekening benar atas nama Anda. Rekening yang disimpan akan dikunci selama 1 minggu sebelum dapat diubah kembali.',
              style: TextStyle(fontSize: 12, color: subtitleColor),
            ),
            const SizedBox(height: 16),

            // Tipe Akun: Bank vs E-Wallet
            Row(
              children: [
                Expanded(
                  child: _buildTypeButton(
                    label: 'Bank',
                    type: 'bank',
                    icon: Icons.account_balance_outlined,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildTypeButton(
                    label: 'E-Wallet',
                    type: 'ewallet',
                    icon: Icons.account_balance_wallet_outlined,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Pilihan Provider
            Text(
              'Penyedia Bank / E-Wallet',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: inputFill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedProvider,
                  isExpanded: true,
                  dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: subtitleColor,
                  ),
                  items: (_selectedType == 'bank'
                          ? widget.bankOptions
                          : widget.ewalletOptions)
                      .map((item) {
                    return DropdownMenuItem<String>(
                      value: item,
                      child: Text(
                        item,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: titleColor,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedProvider = val);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Nomor Rekening / E-Wallet (HANYA ANGKA & WARNA TEKS KONTRAS JELAS)
            Text(
              'Nomor Rekening / Nomor HP E-Wallet',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              key: const Key('refund_account_number_input'),
              controller: _accountNumberController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
              decoration: InputDecoration(
                hintText: _selectedType == 'bank'
                    ? 'Contoh: 880812345678'
                    : 'Contoh: 081234567890',
                hintStyle: TextStyle(
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  fontWeight: FontWeight.normal,
                ),
                filled: true,
                fillColor: inputFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF818CF8) : AppColors.primary,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Nama Pemilik (WARNA TEKS KONTRAS JELAS)
            Text(
              'Nama Pemilik Rekening / Akun',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              key: const Key('refund_account_name_input'),
              controller: _accountHolderController,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
              decoration: InputDecoration(
                hintText: 'Nama lengkap sesuai rekening',
                hintStyle: TextStyle(
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  fontWeight: FontWeight.normal,
                ),
                filled: true,
                fillColor: inputFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF818CF8) : AppColors.primary,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Konfirmasi Checkbox
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    key: const Key('refund_confirm_checkbox'),
                    value: _confirmAccuracy,
                    activeColor: AppColors.primary,
                    checkColor: Colors.white,
                    side: BorderSide(color: borderColor),
                    onChanged: (val) {
                      setState(() => _confirmAccuracy = val ?? false);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Saya mengonfirmasi bahwa rekening ini adalah atas nama saya sendiri untuk menerima dana refund dan memahami masa cooldown 1 minggu pasca pembaruan.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: subtitleColor,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFDC2626),
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Tombol Simpan
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                key: const Key('save_refund_account_submit_button'),
                onPressed: _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Simpan Rekening Refund',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeButton({
    required String label,
    required String type,
    required IconData icon,
    required bool isDark,
  }) {
    final isSelected = _selectedType == type;

    return InkWell(
      onTap: () => _onTypeChanged(type),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF283548) : const Color(0xFFEEF2FF))
              : (isDark ? AppColors.darkSurfaceVariant : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? (isDark ? const Color(0xFF818CF8) : AppColors.primary)
                : (isDark ? AppColors.darkBorder : AppColors.border),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? (isDark ? const Color(0xFF818CF8) : AppColors.primary)
                  : (isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected
                      ? (isDark ? Colors.white : AppColors.primary)
                      : (isDark ? AppColors.darkTextSecondary : const Color(0xFF334155)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
