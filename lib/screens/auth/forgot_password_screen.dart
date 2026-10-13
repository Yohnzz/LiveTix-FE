import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/auth_header.dart';
import '../../widgets/primary_button.dart';
import 'otp_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    // TODO: panggil API kirim OTP ke email
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OtpScreen(email: _email.text.trim())),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AuthHeader(
                  height: 220,
                  child: Icon(Icons.lock_person_outlined, size: 90, color: Colors.white),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.chevron_left, size: 28),
                ),
                const SizedBox(height: 8),
                const Text('Lupa Kata Sandi',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                const SizedBox(height: 4),
                const Text('Masukkan Email Pemulihan',
                    style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                const SizedBox(height: 20),
                AppTextField(
                  label: 'Email',
                  icon: Icons.mail_outline,
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v == null || !v.contains('@')) ? 'Email tidak valid' : null,
                ),
                const SizedBox(height: 20),
                PrimaryButton(text: 'Masuk', onPressed: _submit),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
