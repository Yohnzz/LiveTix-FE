import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_colors.dart';
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
  static const int _length = 5; // sesuai desain (5 kolom)
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _nodes;

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
        const SnackBar(content: Text('Lengkapi 5 digit kode verifikasi OTP')),
      );
      return;
    }

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
                'Masukkan 5 digit kode verifikasi yang dikirim ke ${widget.email}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textGrey,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0EAFF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primary),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Kode verifikasi simulasi: 12345',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                height: 120,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
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
                text: widget.returnToCaller ? 'Verifikasi Kode' : 'Masuk',
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
