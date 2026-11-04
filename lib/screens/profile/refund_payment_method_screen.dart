import 'package:flutter/material.dart';
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

  void _openEditAccountModal(UserRefundAccount? currentAccount) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _EditRefundAccountSheet(
        initialAccount: currentAccount,
        bankOptions: _bankOptions,
        ewalletOptions: _ewalletOptions,
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
    return ValueListenableBuilder<UserRefundAccount?>(
      valueListenable: DataService().refundAccountNotifier,
      builder: (context, account, _) {
        final isCooldown = account?.isCooldownActive ?? false;
        final remainingDays = account?.remainingDays ?? 0;

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
              'Metode Penerima Refund',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
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
                _buildRefundOnlyNoticeCard(),
                const SizedBox(height: 16),

                // Kartu Status Cooldown Keamanan 1 Minggu
                _buildCooldownStatusCard(
                  account: account,
                  isCooldown: isCooldown,
                  remainingDays: remainingDays,
                ),
                const SizedBox(height: 20),

                // Judul Seksi Rekening Aktif
                const Text(
                  'Rekening Pencairan Aktif',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),

                // Kartu Rekening Refund
                if (account != null)
                  _buildActiveAccountCard(account)
                else
                  _buildEmptyAccountCard(),
                const SizedBox(height: 24),

                // Tombol Aksi Tambah / Ubah Rekening
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    key: const Key('edit_refund_account_button'),
                    onPressed: isCooldown
                        ? null
                        : () => _openEditAccountModal(account),
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
                      disabledBackgroundColor: const Color(0xFFE2E8F0),
                      disabledForegroundColor: const Color(0xFF94A3B8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Tombol Uji Coba Simulasi Cooldown untuk Pengujian Developer
                Center(
                  child: TextButton.icon(
                    key: const Key('simulate_cooldown_reset_button'),
                    onPressed: () {
                      if (isCooldown) {
                        // Atur pembaruan menjadi 8 hari yang lalu agar cooldown selesai
                        DataService().setRefundAccountCooldownDaysAgo(8);
                      } else {
                        // Atur pembaruan menjadi 1 hari yang lalu agar cooldown aktif kembali
                        DataService().setRefundAccountCooldownDaysAgo(1);
                      }
                      setState(() {});
                    },
                    icon: Icon(
                      isCooldown
                          ? Icons.lock_open_rounded
                          : Icons.lock_clock_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    label: Text(
                      isCooldown
                          ? 'Simulasi Testing: Buka Kunci Cooldown'
                          : 'Simulasi Testing: Kunci Cooldown 1 Minggu',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
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
  }

  Widget _buildRefundOnlyNoticeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC7D2FE)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.shield_outlined,
            color: AppColors.primary,
            size: 24,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Khusus Penerimaan Dana Refund',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Rekening atau e-wallet yang Anda tetapkan di halaman ini hanya digunakan untuk menerima pencairan dana refund tiket (misalnya saat konser dibatalkan). Metode ini tidak digunakan untuk pembayaran tiket baru.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF334155),
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
    required int remainingDays,
  }) {
    if (account == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline_rounded, size: 20, color: Color(0xFF475467)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Belum ada rekening refund terdaftar. Daftarkan sekarang untuk pencairan dana cepat.',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF475467),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (isCooldown) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.hourglass_top_rounded,
              color: Color(0xFFB45309),
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Masa Cooldown Aktif (Tersisa $remainingDays hari)',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF92400E),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Demi keamanan akun Anda dari pengambilalihan tidak sah, perubahan rekening refund hanya dapat dilakukan 1 kali setiap 1 minggu (7 hari pasca pembaruan terakhir pada ${_formatDateTime(account.lastUpdated)}).',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF78350F),
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
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            color: Color(0xFF065F46),
            size: 22,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Masa Cooldown Selesai',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF065F46),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Anda dapat memperbarui rekening atau e-wallet penerima refund kapan saja jika diperlukan.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF065F46),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveAccountCard(UserRefundAccount account) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
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
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        account.accountType == 'ewallet'
                            ? Icons.account_balance_wallet_outlined
                            : Icons.account_balance_outlined,
                        color: AppColors.primary,
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
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                          Text(
                            account.accountType == 'ewallet'
                                ? 'Dompet Digital'
                                : 'Transfer Rekening Bank',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF64748B),
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
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified, size: 12, color: Color(0xFF065F46)),
                    SizedBox(width: 4),
                    Text(
                      'TERVERIFIKASI',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF065F46),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: AppColors.border),
          ),
          _buildInfoRow('Nomor Rekening / Akun', account.maskedAccountNumber),
          const SizedBox(height: 8),
          _buildInfoRow('Nama Pemilik', account.accountHolderName),
          const SizedBox(height: 8),
          _buildInfoRow(
            'Terakhir Diperbarui',
            _formatDateTime(account.lastUpdated),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyAccountCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          Icon(Icons.credit_card_off_outlined, size: 40, color: Color(0xFF94A3B8)),
          SizedBox(height: 10),
          Text(
            'Belum Ada Rekening Refund',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Tambahkan rekening bank atau e-wallet agar dana refund dapat langsung dikirim ke rekening Anda saat pengajuan disetujui.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
        ),
      ],
    );
  }
}

class _EditRefundAccountSheet extends StatefulWidget {
  final UserRefundAccount? initialAccount;
  final List<String> bankOptions;
  final List<String> ewalletOptions;
  final VoidCallback onAccountSaved;

  const _EditRefundAccountSheet({
    required this.initialAccount,
    required this.bankOptions,
    required this.ewalletOptions,
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
      text: init?.accountHolderName ?? (user?.name ?? 'Rafi Firmansyah'),
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
    final viewInsets = MediaQuery.of(context).viewInsets;

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
                  color: const Color(0xFFD0D5DD),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Atur Rekening Penerima Refund',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Pastikan data rekening benar atas nama Anda. Rekening yang disimpan akan dikunci selama 1 minggu sebelum dapat diubah kembali.',
              style: TextStyle(fontSize: 12, color: Color(0xFF475467)),
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
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildTypeButton(
                    label: 'E-Wallet',
                    type: 'ewallet',
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Pilihan Provider
            const Text(
              'Penyedia Bank / E-Wallet',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedProvider,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  items: (_selectedType == 'bank'
                          ? widget.bankOptions
                          : widget.ewalletOptions)
                      .map((item) {
                    return DropdownMenuItem<String>(
                      value: item,
                      child: Text(
                        item,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
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

            // Nomor Rekening / E-Wallet
            const Text(
              'Nomor Rekening / Nomor HP E-Wallet',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              key: const Key('refund_account_number_input'),
              controller: _accountNumberController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: _selectedType == 'bank'
                    ? 'Contoh: 880812345678'
                    : 'Contoh: 081234567890',
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
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Nama Pemilik
            const Text(
              'Nama Pemilik Rekening / Akun',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              key: const Key('refund_account_name_input'),
              controller: _accountHolderController,
              decoration: InputDecoration(
                hintText: 'Nama lengkap sesuai rekening',
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
                    onChanged: (val) {
                      setState(() => _confirmAccuracy = val ?? false);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Saya mengonfirmasi bahwa rekening ini adalah atas nama saya sendiri untuk menerima dana refund dan memahami masa cooldown 1 minggu pasca pembaruan.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF475467),
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
  }) {
    final isSelected = _selectedType == type;

    return InkWell(
      onTap: () => _onTypeChanged(type),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEEF2FF) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? AppColors.primary : const Color(0xFF64748B),
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
                  color: isSelected ? AppColors.primary : const Color(0xFF334155),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
