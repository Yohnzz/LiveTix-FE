import 'package:flutter/material.dart';
import '../../models/promoter_models.dart';
import '../../services/promoter_data_service.dart';
import 'promoter_withdrawal_history_screen.dart';
import 'widgets/responsive_promoter_wrapper.dart';

class PromoterWithdrawalScreen extends StatefulWidget {
  const PromoterWithdrawalScreen({super.key});

  @override
  State<PromoterWithdrawalScreen> createState() =>
      _PromoterWithdrawalScreenState();
}

class _PromoterWithdrawalScreenState extends State<PromoterWithdrawalScreen> {
  final TextEditingController _amountController =
      TextEditingController(text: '150.000.000');
  static const int _adminFee = 6500;

  int _parsedAmount = 150000000;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _recalculateAmount();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _recalculateAmount() {
    final clean = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final val = int.tryParse(clean) ?? 0;
    setState(() {
      _parsedAmount = val;
      _errorMessage = null;
    });
  }

  int get _netReceived {
    final net = _parsedAmount - _adminFee;
    return net > 0 ? net : 0;
  }

  void _openPinSecurityDialog() {
    final service = PromoterDataService();
    final currentBalance = service.activeBalanceNotifier.value;

    if (_parsedAmount <= 0) {
      setState(() => _errorMessage = 'Nominal penarikan harus lebih dari Rp 0.');
      return;
    }

    if (_parsedAmount > currentBalance) {
      setState(
          () => _errorMessage = 'Nominal melebihi saldo tersedia untuk ditarik.');
      return;
    }

    String pinCode = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          void onKeyTap(String digit) {
            if (pinCode.length >= 6) return;
            setModalState(() => pinCode += digit);

            if (pinCode.length == 6) {
              Navigator.pop(ctx);
              _executeWithdrawal();
            }
          }

          void onBackspace() {
            if (pinCode.isNotEmpty) {
              setModalState(
                  () => pinCode = pinCode.substring(0, pinCode.length - 1));
            }
          }

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE4E7EC),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFCE7F3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.shield_rounded,
                    color: Color(0xFFC2185B),
                    size: 26,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Masukkan PIN Keamanan 6-Digit',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF101828),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Otorisasi penarikan Rp ${PromoterDataService.formatCurrency(_parsedAmount)} ke BCA (***9901)',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF667085)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // 6 Bullets
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(6, (index) {
                    final isFilled = index < pinCode.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 7),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isFilled
                            ? const Color(0xFF1B2A8C)
                            : const Color(0xFFE4E7EC),
                        border: Border.all(
                          color: isFilled
                              ? const Color(0xFF1B2A8C)
                              : const Color(0xFFD0D5DD),
                          width: 1.5,
                        ),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 24),

                // Keypad
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: ['1', '2', '3']
                          .map((d) => _buildKeypadBtn(d, onKeyTap))
                          .toList(),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: ['4', '5', '6']
                          .map((d) => _buildKeypadBtn(d, onKeyTap))
                          .toList(),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: ['7', '8', '9']
                          .map((d) => _buildKeypadBtn(d, onKeyTap))
                          .toList(),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        InkWell(
                          onTap: () => setModalState(() => pinCode = ''),
                          borderRadius: BorderRadius.circular(30),
                          child: Container(
                            width: 62,
                            height: 62,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2F4F7),
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: const Color(0xFFE4E7EC)),
                            ),
                            child: const Text('C',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF667085))),
                          ),
                        ),
                        _buildKeypadBtn('0', onKeyTap),
                        InkWell(
                          onTap: onBackspace,
                          borderRadius: BorderRadius.circular(30),
                          child: Container(
                            width: 62,
                            height: 62,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2F4F7),
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: const Color(0xFFE4E7EC)),
                            ),
                            child: const Icon(Icons.backspace_outlined,
                                color: Color(0xFF667085), size: 22),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildKeypadBtn(String digit, ValueChanged<String> onTap) {
    return InkWell(
      onTap: () => onTap(digit),
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 62,
        height: 62,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE4E7EC)),
        ),
        child: Text(
          digit,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Color(0xFF101828),
          ),
        ),
      ),
    );
  }

  void _executeWithdrawal() {
    final service = PromoterDataService();
    service.withdrawBalance(
      amount: _parsedAmount,
      targetBank: 'BCA',
      targetAccount: '***9901',
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                color: Color(0xFFE8FDF0),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF039855),
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Pengajuan Berhasil!',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Pencairan dana sebesar Rp ${PromoterDataService.formatCurrency(_parsedAmount)} sedang diproses transfer ke rekening BCA Rafi Firmansyah (***9901).',
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF667085),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B2A8C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(ctx); // Close dialog
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PromoterWithdrawalHistoryScreen(),
                    ),
                  );
                },
                child: const Text('Lihat Riwayat Penarikan'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = PromoterDataService();

    return ResponsivePromoterWrapper(
      child: ValueListenableBuilder<bool>(
        valueListenable: service.isDarkModeNotifier,
        builder: (context, isDarkMode, _) {
          final textColor =
              isDarkMode ? Colors.white : const Color(0xFF101828);
          final subtextColor =
              isDarkMode ? Colors.white70 : const Color(0xFF667085);
          final cardBg =
              isDarkMode ? const Color(0xFF1B2232) : Colors.white;
          final cardBorder =
              isDarkMode ? Colors.white12 : const Color(0xFFE4E7EC);

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Bar with Kembali & Theme Toggle
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          InkWell(
                            onTap: () => Navigator.pop(context),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.chevron_left_rounded,
                                    size: 22,
                                    color: textColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Kembali',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: textColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              isDarkMode
                                  ? Icons.dark_mode_outlined
                                  : Icons.wb_sunny_outlined,
                              size: 22,
                              color: textColor,
                            ),
                            tooltip: 'Ganti Tema',
                            onPressed: service.toggleTheme,
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Title & Subtitle
                      Text(
                        'Tarik Saldo',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tarik dana aman langsung ke rekening Anda',
                        style: TextStyle(
                          fontSize: 13,
                          color: subtextColor,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Card: SALDO TERSEDIA UNTUK DITARIK
                      ValueListenableBuilder<int>(
                        valueListenable: service.activeBalanceNotifier,
                        builder: (context, balance, _) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: cardBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'SALDO TERSEDIA UNTUK DITARIK',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: subtextColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Rp${PromoterTicketTier.formatNumber(balance)}',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1B2A8C), // Navy
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 20),

                      // Field: NOMINAL PENARIKAN
                      Text(
                        'NOMINAL PENARIKAN',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: subtextColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _errorMessage != null
                                ? const Color(0xFFD92D20)
                                : cardBorder,
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              'Rp',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _amountController,
                                keyboardType: TextInputType.number,
                                onChanged: (val) => _recalculateAmount(),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: '0',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (_errorMessage != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFD92D20),
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Field: REKENING TUJUAN
                      Text(
                        'REKENING TUJUAN',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: subtextColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cardBorder),
                        ),
                        child: Row(
                          children: [
                            // BCA Badge Box
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F1FF),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'BCA',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1B2A8C),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'BCA - Rafi Firmansyah',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Nomor Rekening: ****9901',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: subtextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: subtextColor,
                              size: 22,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Fee rows
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Biaya Administrasi Portal',
                            style:
                                TextStyle(fontSize: 12.5, color: subtextColor),
                          ),
                          Text(
                            'Rp${PromoterTicketTier.formatNumber(_adminFee)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Dana Diterima',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFC2185B), // Magenta
                            ),
                          ),
                          Text(
                            'Rp${PromoterTicketTier.formatNumber(_netReceived)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFC2185B), // Magenta
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),

              // Bottom Sticky Primary Button: "Ajukan Penarikan Dana"
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _openPinSecurityDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B2A8C), // Navy
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Ajukan Penarikan Dana',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
