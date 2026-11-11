import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_colors.dart';
import '../../services/supabase_service.dart';
import '../../widgets/auth_header.dart';
import '../../widgets/primary_button.dart';
import 'reset_password_screen.dart';

class OtpScreen extends StatefulWidget {
  final String email;
  final bool returnToCaller;

  const OtpScreen({
    super.key,
    required this.email,
    this.returnToCaller = false,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  static const int _length = 6; // Standar 6 digit OTP Supabase Auth
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _nodes;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(_length, (_) => TextEditingController());
    _nodes = List.generate(_length, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  Future<void> _verify() async {
    if (_code.length < _length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lengkapi 6 digit kode verifikasi OTP')),
      );
      return;
    }

    setState(() => _isLoading = true);

    if (SupabaseService.isInitialized) {
      try {
        final res = await SupabaseService.client.auth.verifyOTP(
          email: widget.email.trim(),
          token: _code.trim(),
          type: OtpType.recovery,
        );
        if (res.session == null && res.user == null) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kode OTP tidak valid atau telah kedaluwarsa'),
              backgroundColor: Color(0xFFB91C1C),
            ),
          );
          return;
        }
      } on AuthException catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: const Color(0xFFB91C1C),
          ),
        );
        return;
      } catch (e) {
        debugPrint('verifyOTP note / fallback: $e');
      }
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (widget.returnToCaller) {
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ResetPasswordScreen(
            email: widget.email,
            returnToCaller: true,
          ),
        ),
      );
      if (result == true && mounted) {
        Navigator.pop(context, true);
      }
      return;
    }

    // OTP valid -> lanjut ke form pengubahan kata sandi baru
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResetPasswordScreen(email: widget.email),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AuthHeader(
                height: 240,
                child: Image.asset(
                  'assets/images/verification-otp-logo.png',
                  height: 120,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.verified_user_outlined,
                    size: 90,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              IconButton(
                tooltip: 'Kembali',
                onPressed: () => Navigator.pop(context),
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF2F4F7),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(
                  Icons.chevron_left,
                  size: 26,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Verifikasi OTP',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Masukkan $_length digit kode verifikasi yang dikirim ke ${widget.email}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textGrey,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.mark_email_read_outlined,
                      size: 20,
                      color: Color(0xFF1D4ED8),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Kode verifikasi telah dikirimkan ke email Anda. Silakan periksa kotak masuk atau folder spam email.',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1E40AF),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                height: 120,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.bottomCenter,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(
                    _length,
                    (i) => Flexible(child: _otpBox(i)),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              PrimaryButton(
                text: widget.returnToCaller ? 'Verifikasi Kode' : 'Verifikasi & Lanjutkan',
                isLoading: _isLoading,
                onPressed: _verify,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _otpBox(int i) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 44),
        child: Semantics(
          label: 'Digit OTP ${i + 1}',
          child: TextField(
            controller: _controllers[i],
            focusNode: _nodes[i],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 1,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
            decoration: const InputDecoration(
              counterText: '',
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.textGrey),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
            onChanged: (v) {
              if (v.isNotEmpty && i < _length - 1) _nodes[i + 1].requestFocus();
              if (v.isEmpty && i > 0) _nodes[i - 1].requestFocus();
            },
          ),
        ),
      ),
    );
  }
}
