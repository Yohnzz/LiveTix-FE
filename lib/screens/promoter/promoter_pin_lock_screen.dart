import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/data_service.dart';
import '../../services/promoter_data_service.dart';
import '../home/home_screen.dart';
import 'promoter_main_screen.dart';
import 'verification/producer_verification_flow.dart';
import 'widgets/responsive_promoter_wrapper.dart';

/// Menentukan layar masuk Produser berdasarkan status verifikasi Admin dan kunci PIN:
/// - Belum verifikasi ('unverified') -> wajib isi data diri, unggah dokumen & buat PIN
/// - Sedang ditinjau ('pending') -> tidak bisa masuk dasbor hingga disetujui Admin
/// - Ditolak ('rejected') -> layar penolakan verifikasi
/// - Disetujui ('approved') -> wajib memasukkan PIN 6 digit sebelum masuk ke Dasbor Produser
Widget resolveProducerEntryScreen({String? name, String? phone}) {
  final service = PromoterDataService();
  final status = service.verificationStatusNotifier.value.toLowerCase();

  if (status == 'unverified') {
    return ProducerVerificationFlow(
      initialStage: ProducerVerificationStage.lengkapiProfil,
      initialName: name,
      initialPhone: phone,
    );
  }
  if (status == 'pending') {
    return ProducerVerificationFlow(
      initialStage: ProducerVerificationStage.approvalMenunggu,
      initialName: name,
      initialPhone: phone,
    );
  }
  if (status == 'rejected') {
    return ProducerVerificationFlow(
      initialStage: ProducerVerificationStage.approvalDitolak,
      initialName: name,
      initialPhone: phone,
    );
  }

  if (!service.isPinUnlockedThisSession) {
    return const PromoterPinLockScreen();
  }
  return const PromoterMainScreen();
}

class PromoterPinLockScreen extends StatefulWidget {
  const PromoterPinLockScreen({super.key});

  @override
  State<PromoterPinLockScreen> createState() => _PromoterPinLockScreenState();
}

class _PromoterPinLockScreenState extends State<PromoterPinLockScreen> {
  final TextEditingController _pinController = TextEditingController();
  bool _obscurePin = true;
  String? _errorMessage;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _verifyPinAndEnter() {
    final input = _pinController.text.trim();
    if (input.length != 6) {
      setState(() => _errorMessage = 'Masukkan 6 digit PIN keamanan Anda.');
      return;
    }

    final ok = PromoterDataService().verifyPin(input);
    if (!ok) {
      setState(() => _errorMessage = 'PIN yang Anda masukkan tidak sesuai.');
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const PromoterMainScreen()),
    );
  }

  void _logout() {
    DataService().logout();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen(isGuest: true)),
      (route) => false,
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

          return Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 24),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 420),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: cardBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                              alpha: isDarkMode ? 0.25 : 0.05),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton.icon(
                              onPressed: _logout,
                              icon: const Icon(Icons.logout_rounded,
                                  size: 16, color: Color(0xFFC2185B)),
                              label: const Text(
                                'Keluar Akun',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFC2185B),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                isDarkMode
                                    ? Icons.dark_mode_outlined
                                    : Icons.wb_sunny_outlined,
                                size: 20,
                                color: textColor,
                              ),
                              tooltip: 'Ganti Tema',
                              onPressed: service.toggleTheme,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF1B2A8C),
                                Color(0xFFC2185B),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.lock_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Masukkan PIN Produser',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Demi keamanan akun ${service.promoterName}, masukkan 6 digit PIN yang telah Anda atur untuk membuka Dasbor Produser.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: subtextColor,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Container(
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? const Color(0xFF141A29)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: cardBorder),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: TextField(
                            controller: _pinController,
                            autofocus: true,
                            obscureText: _obscurePin,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            textAlign: TextAlign.center,
                            onSubmitted: (_) => _verifyPinAndEnter(),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 10,
                              color: textColor,
                            ),
                            decoration: InputDecoration(
                              counterText: '',
                              border: InputBorder.none,
                              hintText: '••••••',
                              hintStyle: TextStyle(
                                fontSize: 22,
                                letterSpacing: 10,
                                color: subtextColor.withValues(alpha: 0.4),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePin
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 20,
                                  color: subtextColor,
                                ),
                                onPressed: () =>
                                    setState(() => _obscurePin = !_obscurePin),
                              ),
                            ),
                          ),
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFD92D20),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _verifyPinAndEnter,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1B2A8C),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'Buka Aplikasi Produser',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
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
        },
      ),
    );
  }
}

