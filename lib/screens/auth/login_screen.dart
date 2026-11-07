import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_colors.dart';
import '../../services/data_service.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/auth_header.dart';
import '../../widgets/primary_button.dart';
import '../admin/admin_shell.dart';
import '../home/home_screen.dart';
import '../promoter/promoter_pin_lock_screen.dart';
import '../gate_crew/gate_crew_main_screen.dart';
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
  bool _isLoading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final emailText = _email.text.trim();
    final passwordText = _password.text.trim();

    setState(() => _isLoading = true);

    try {
      final user = await DataService().login(emailText, passwordText);
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email atau kata sandi tidak sesuai'),
            backgroundColor: Color(0xFFB91C1C),
          ),
        );
        return;
      }

      final role = user.role.trim().toLowerCase();
      if (role == 'admin') {
        AdminNavigation.reset();
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            settings: const RouteSettings(name: AdminShell.routeName),
            builder: (_) => const AdminShell(),
          ),
          (route) => false,
        );
        return;
      }

      if (role == 'produser' || role == 'producer' || role == 'promoter') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => resolveProducerEntryScreen(
              name: user.name,
              phone: user.phone,
            ),
          ),
          (route) => false,
        );
        return;
      }

      if (role == 'gatecrew' || role == 'crew') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            settings: const RouteSettings(name: GateCrewMainScreen.routeName),
            builder: (_) => const GateCrewMainScreen(),
          ),
          (route) => false,
        );
        return;
      }

      // Navigasi ke Home User (Logged-in state)
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            isGuest: false,
            userName: user.name,
            userInitials: user.initials,
          ),
        ),
        (route) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      String errorMessage = e.message;
      if (e.message.contains('Invalid login credentials')) {
        errorMessage = 'Email atau kata sandi tidak sesuai di Supabase';
      } else if (e.code == 'email_not_confirmed' ||
          e.message.toLowerCase().contains('email not confirmed')) {
        errorMessage =
            'Email belum dikonfirmasi. Silakan periksa inbox email atau nonaktifkan Confirm Email di Supabase Auth.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: const Color(0xFFB91C1C),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal masuk: ${e.toString()}'),
          backgroundColor: const Color(0xFFB91C1C),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewTop = MediaQuery.of(context).viewPadding.top;
    final topSpacing = viewTop > 0 ? viewTop + 12 : 32.0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, topSpacing, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              const Center(
                child: Text(
                  'Selamat datang',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Center(
                child: Text(
                  'Masuk untuk lanjut memesan tiket',
                  style: TextStyle(fontSize: 13, color: AppColors.textGrey),
                ),
              ),
              const SizedBox(height: 24),
              AppTextField(
                label: 'Email',
                icon: Icons.mail_outline,
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                validator: (v) =>
                    (v == null || !v.contains('@')) ? 'Email tidak valid' : null,
              ),
              const SizedBox(height: 14),
              AppTextField(
                label: 'Kata sandi',
                icon: Icons.lock_outline,
                controller: _password,
                isPassword: true,
                validator: (v) =>
                    (v == null || v.length < 6) ? 'Minimal 6 karakter' : null,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ForgotPasswordScreen(),
                    ),
                  ),
                  child: const Text(
                    'Lupa kata sandi?',
                    style: TextStyle(fontSize: 12, color: AppColors.accent),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              PrimaryButton(
                text: _isLoading ? 'Memproses...' : 'Masuk',
                onPressed: _isLoading ? () {} : _login,
              ),
              const SizedBox(height: 16),
              const OrDivider(),
              const SizedBox(height: 16),
              GoogleButton(onPressed: () {/* TODO: Google Sign-In */}),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Belum punya akun? ',
                    style: TextStyle(fontSize: 12, color: AppColors.textGrey),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RegisterScreen(),
                      ),
                    ),
                    child: const Text(
                      'Daftar',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
