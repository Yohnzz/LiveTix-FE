import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/account_status.dart';
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
/// - Dinonaktifkan ('nonaktif') -> layar akun dinonaktifkan + alasan
/// - Disetujui ('approved') -> wajib memasukkan PIN 6 digit sebelum masuk ke Dasbor Produser
Widget resolveProducerEntryScreen({String? name, String? phone}) {
  final service = PromoterDataService();
  final rawStatus = service.verificationStatusNotifier.value.trim().toLowerCase();
  final status = AccountStatus.fromValue(rawStatus);

  // Guard ketat: hanya status 'approved' yang boleh masuk ke fitur produser.
  // 'pending' & 'rejected' tetap diblokir; status tak dikenal diperlakukan
  // sebagai belum verifikasi (tidak ada bypass ke dasbor).
  if (status == AccountStatus.nonaktif) {
    return ProducerVerificationFlow(
      initialStage: ProducerVerificationStage.akunDinonaktifkan,
      initialName: name,
      initialPhone: phone,
    );
  }
  if (status == AccountStatus.rejected) {
    return ProducerVerificationFlow(
      initialStage: ProducerVerificationStage.approvalDitolak,
      initialName: name,
      initialPhone: phone,
    );
  }
  if (rawStatus == 'pending' || rawStatus == 'pending_create') {
    return ProducerVerificationFlow(
      initialStage: ProducerVerificationStage.approvalMenunggu,
      initialName: name,
      initialPhone: phone,
    );
  }
  if (rawStatus != 'approved' && rawStatus != 'disetujui') {
    return ProducerVerificationFlow(
      initialStage: ProducerVerificationStage.lengkapiProfil,
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
  bool _isVerifying = false;
  Timer? _countdownTimer;
  Duration _remainingLockout = Duration.zero;

  bool get _isLockedOut =>
      _remainingLockout > Duration.zero ||
      PromoterDataService().isPinLockedOut;

  @override
  void initState() {
    super.initState();
    _checkLockout();
  }

  void _checkLockout() {
    final service = PromoterDataService();
    if (service.isPinLockedOut) {
      _remainingLockout = service.remainingPinLockoutDuration;
      _startCountdown();
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final remaining = PromoterDataService().remainingPinLockoutDuration;
      if (remaining <= Duration.zero) {
        timer.cancel();
        PromoterDataService().resetPinLockout();
        setState(() {
          _remainingLockout = Duration.zero;
          _errorMessage = null;
        });
      } else {
        setState(() {
          _remainingLockout = remaining;
        });
      }
    });
  }

  String _formatCountdown(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _verifyPinAndEnter() async {
    if (_isLockedOut || _isVerifying) return;
    final input = _pinController.text.trim();
    if (input.length != 6) {
      setState(() => _errorMessage = 'Masukkan 6 digit PIN keamanan Anda.');
      return;
    }

    setState(() => _isVerifying = true);
    final service = PromoterDataService();
    final ok = service.verifyPin(input);

    if (!ok) {
      _pinController.clear();
      final attempts = await service.recordFailedPinAttempt();
      if (!mounted) return;
      if (attempts >= 5) {
        _remainingLockout = service.remainingPinLockoutDuration;
        _startCountdown();
        setState(() {
          _isVerifying = false;
          _errorMessage =
              'PIN salah 5 kali berturut-turut. Akses dikunci selama 10 menit demi keamanan.';
        });
      } else {
        final remainingAttempts = 5 - attempts;
        setState(() {
          _isVerifying = false;
          _errorMessage =
              'PIN yang Anda masukkan salah. Sisa kesempatan: $remainingAttempts kali.';
        });
      }
      return;
    }

    await service.resetPinLockout();
    if (!mounted) return;
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
                            enabled: !_isLockedOut && !_isVerifying,
                            obscureText: _obscurePin,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            textAlign: TextAlign.center,
                            onChanged: (val) {
                              if (_isLockedOut || _isVerifying) return;
                              if (val.length == 6) {
                                _verifyPinAndEnter();
                              } else if (_errorMessage != null) {
                                setState(() => _errorMessage = null);
                              }
                            },
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
                        if (_isLockedOut) ...[
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? const Color(0xFF3B1219)
                                  : const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDarkMode
                                    ? const Color(0xFF991B1B)
                                    : const Color(0xFFFCA5A5),
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.timer_outlined,
                                      size: 18,
                                      color: Color(0xFFDC2626),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Terkunci: Coba lagi dalam ${_formatCountdown(_remainingLockout)}',
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFFDC2626),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Batas waktu tersinkronisasi realtime ke database.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDarkMode
                                        ? Colors.white70
                                        : const Color(0xFF7F1D1D),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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
                            onPressed: _isLockedOut || _isVerifying
                                ? null
                                : _verifyPinAndEnter,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isLockedOut
                                  ? (isDarkMode
                                      ? const Color(0xFF334155)
                                      : const Color(0xFFCBD5E1))
                                  : const Color(0xFF1B2A8C),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _isVerifying
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    _isLockedOut
                                        ? 'Terkunci (${_formatCountdown(_remainingLockout)})'
                                        : 'Buka Aplikasi Produser',
                                    style: const TextStyle(
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

