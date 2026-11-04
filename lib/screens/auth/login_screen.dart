import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/auth_header.dart';
import '../../widgets/primary_button.dart';
import '../../services/dummy_data_service.dart';
import '../home/home_screen.dart';
import '../promoter/promoter_main_screen.dart';
import '../promoter/verification/producer_verification_flow.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _login() {
    if (!_formKey.currentState!.validate()) return;
    final emailText = _email.text.trim();
    final passwordText = _password.text.trim();

    final user = DummyDataService().login(emailText, passwordText);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email atau kata sandi tidak sesuai'),
          backgroundColor: Color(0xFFB91C1C),
        ),
      );
      return;
    }

    // Jika akun terdaftar sebagai Produser, arahkan ke Portal Produser
    if (user.role == 'Produser') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PromoterMainScreen()),
      );
      return;
    }

    // Navigasi ke Home User (Logged-in state)
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          isGuest: false,
          userName: user.name,
          userInitials: user.initials,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewTop = MediaQuery.of(context).viewPadding.top;
    final topSpacing = viewTop > 0 ? viewTop + 12 : 32.0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, topSpacing, 20, 16),
        child: Form(
            key: _formKey,
            child: Column(
              children: [
                AuthHeader(
                  height: 190,
                  child: Image.asset(
                    'assets/images/livetix-logo.png',
                    height: 100,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Selamat datang',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                const SizedBox(height: 4),
                const Text('Masuk untuk lanjut memesan tiket',
                    style: TextStyle(fontSize: 13, color: AppColors.textGrey)),
                const SizedBox(height: 24),
                AppTextField(
                  label: 'Email',
                  icon: Icons.mail_outline,
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v == null || !v.contains('@')) ? 'Email tidak valid' : null,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Kata sandi',
                  icon: Icons.lock_outline,
                  controller: _password,
                  isPassword: true,
                  validator: (v) => (v == null || v.length < 6) ? 'Minimal 6 karakter' : null,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                    child: const Text('Lupa kata sandi?',
                        style: TextStyle(fontSize: 12, color: AppColors.accent)),
                  ),
                ),
                const SizedBox(height: 4),
                PrimaryButton(text: 'Masuk', onPressed: _login),
                const SizedBox(height: 16),
                const OrDivider(),
                const SizedBox(height: 16),
                GoogleButton(onPressed: () {/* TODO: Google Sign-In */}),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Belum punya akun? ',
                        style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                    GestureDetector(
                      onTap: () => Navigator.push(
                          context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                      child: const Text('Daftar',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.accent)),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PromoterMainScreen()),
                    );
                  },
                  icon: const Icon(Icons.campaign_outlined,
                      size: 18, color: AppColors.accent),
                  label: const Text(
                    'Masuk Cepat: Portal Produser (Dasbor Produser)',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFCE7F3)),
                    backgroundColor: const Color(0xFFFDF2F8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ProducerVerificationFlow(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.verified_user_outlined,
                      size: 18, color: AppColors.primary),
                  label: const Text(
                    'Alur Verifikasi Produser (Lengkapi Profil & KTP)',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFD0D5DD)),
                    backgroundColor: const Color(0xFFF8FAFC),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }
}
