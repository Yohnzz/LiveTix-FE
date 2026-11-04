import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../services/data_service.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/auth_header.dart';
import '../../widgets/primary_button.dart';
import 'login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;
  final bool returnToCaller;

  const ResetPasswordScreen({
    super.key,
    required this.email,
    this.returnToCaller = false,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();

  @override
  void dispose() {
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    if (_newPassword.text != _confirmPassword.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Konfirmasi kata sandi tidak cocok'),
          backgroundColor: Color(0xFFB91C1C),
        ),
      );
      return;
    }

    DataService().resetPasswordByEmail(
      email: widget.email,
      newPassword: _newPassword.text,
    );

    if (widget.returnToCaller) {
      Navigator.pop(context, true);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Kata sandi berhasil diperbarui! Silakan masuk kembali.'),
        backgroundColor: Color(0xFF166534),
      ),
    );

    // Navigasi kembali ke halaman Login jika diakses dari luar sesi profil
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AuthHeader(
                  height: 220,
                  child: Image.asset(
                    'assets/images/forgot-password-logo.png',
                    height: 100,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.lock_reset_rounded,
                      size: 80,
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
                  'Buat Kata Sandi Baru',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Perbarui kata sandi untuk akun ${widget.email}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textGrey,
                  ),
                ),
                const SizedBox(height: 24),

                // Kata Sandi Baru
                AppTextField(
                  label: 'Kata sandi baru',
                  icon: Icons.lock_outline,
                  controller: _newPassword,
                  isPassword: true,
                  validator: (v) => (v == null || v.length < 6)
                      ? 'Minimal 6 karakter'
                      : null,
                ),
                const SizedBox(height: 14),

                // Konfirmasi Kata Sandi Baru
                AppTextField(
                  label: 'Konfirmasi kata sandi',
                  icon: Icons.lock_outline,
                  controller: _confirmPassword,
                  isPassword: true,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Wajib diisi';
                    if (v != _newPassword.text) return 'Kata sandi tidak cocok';
                    return null;
                  },
                ),
                const SizedBox(height: 28),

                PrimaryButton(
                  text: widget.returnToCaller ? 'Simpan Kata Sandi' : 'Kirim data',
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
