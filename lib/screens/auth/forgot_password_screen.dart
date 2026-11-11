import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../services/data_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/auth_header.dart';
import '../../widgets/primary_button.dart';
import 'otp_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String? initialEmail;
  final bool returnToCaller;

  const ForgotPasswordScreen({
    super.key,
    this.initialEmail,
    this.returnToCaller = false,
  });

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final emailText = _email.text.trim();

    setState(() => _isLoading = true);

    if (SupabaseService.isInitialized) {
      try {
        await SupabaseService.client.auth.resetPasswordForEmail(emailText);
      } catch (e) {
        debugPrint('resetPasswordForEmail note: $e');
      }
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (widget.returnToCaller) {
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => OtpScreen(
            email: emailText,
            returnToCaller: true,
          ),
        ),
      );
      if (result == true && mounted) {
        Navigator.pop(context, true);
      }
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OtpScreen(email: emailText)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeUserEmail = DataService().currentUser?.email;

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
                  height: 240,
                  child: Image.asset(
                    'assets/images/forgot-password-logo.png',
                    height: 110,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.lock_person_outlined,
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
                  'Lupa Kata Sandi',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.returnToCaller
                      ? 'Verifikasi email akunmu untuk menerima kode verifikasi 5 digit'
                      : 'Masukkan Email Pemulihan',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textGrey,
                  ),
                ),
                const SizedBox(height: 24),
                AppTextField(
                  label: 'Email',
                  icon: Icons.mail_outline,
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || !v.trim().contains('@')) {
                      return 'Email tidak valid';
                    }
                    if (widget.returnToCaller &&
                        activeUserEmail != null &&
                        activeUserEmail.isNotEmpty &&
                        v.trim().toLowerCase() != activeUserEmail.toLowerCase()) {
                      return 'Email harus sesuai akun aktif ($activeUserEmail)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),
                PrimaryButton(
                  text: widget.returnToCaller ? 'Kirim Kode Verifikasi' : 'Kirim Kode Verifikasi',
                  isLoading: _isLoading,
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
