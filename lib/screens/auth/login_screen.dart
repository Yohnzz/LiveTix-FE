import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/auth_header.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/ribbon_logo.dart';
import '../home/home_screen.dart';
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
    final name = emailText.isNotEmpty
        ? emailText.split('@').first
        : 'Rafi';
    final capitalized = name[0].toUpperCase() + name.substring(1);

    // Navigasi ke Home User (Logged-in state)
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          isGuest: false,
          userName: capitalized,
          userInitials: capitalized.substring(0, capitalized.length >= 2 ? 2 : 1).toUpperCase(),
        ),
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
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const AuthHeader(height: 180, child: RibbonLogo(size: 84)),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
