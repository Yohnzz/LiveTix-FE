import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_colors.dart';
import '../../widgets/auth_header.dart';
import '../../widgets/primary_button.dart';

class OtpScreen extends StatefulWidget {
  final String email;
  const OtpScreen({super.key, required this.email});
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
    for (final c in _controllers) { c.dispose(); }
    for (final n in _nodes) { n.dispose(); }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  void _verify() {
    if (_code.length < _length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lengkapi kode OTP')),
      );
      return;
    }
    // TODO: panggil API verifikasi OTP lalu ke halaman reset kata sandi
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AuthHeader(
                height: 220,
                child: Icon(Icons.verified_user_outlined, size: 90, color: Colors.white),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.chevron_left, size: 28),
              ),
              const SizedBox(height: 8),
              const Text('Verifikasi OTP',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textDark)),
              const SizedBox(height: 4),
              const Text('Masukkan Kode OTP',
                  style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(_length, (i) => _otpBox(i)),
                ),
              ),
              const SizedBox(height: 20),
              PrimaryButton(text: 'Masuk', onPressed: _verify),
            ],
          ),
        ),
      ),
    );
  }

  Widget _otpBox(int i) {
    return SizedBox(
      width: 40,
      child: TextField(
        controller: _controllers[i],
        focusNode: _nodes[i],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        decoration: const InputDecoration(
          counterText: '',
          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.textGrey)),
          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary, width: 2)),
        ),
        onChanged: (v) {
          if (v.isNotEmpty && i < _length - 1) _nodes[i + 1].requestFocus();
          if (v.isEmpty && i > 0) _nodes[i - 1].requestFocus();
        },
      ),
    );
  }
}
