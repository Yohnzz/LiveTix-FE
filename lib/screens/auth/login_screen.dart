import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/auth_header.dart';
import '../../widgets/primary_button.dart';
import '../../services/dummy_data_service.dart';
import '../admin/admin_shell.dart';
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
        MaterialPageRoute(builder: (_) => const PromoterMainScreen()),
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
  }

  void _quickLogin(String email, String password) {
    _email.text = email;
    _password.text = password;
    _login();
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
              PrimaryButton(text: 'Masuk', onPressed: _login),
              const SizedBox(height: 16),
              const OrDivider(),
              const SizedBox(height: 16),
              GoogleButton(onPressed: () {/* TODO: Google Sign-In */}),
              const SizedBox(height: 20),
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
              const SizedBox(height: 24),

              // Bagian Uji Coba Cepat Role untuk kemudahan review antarmuka & logika tiap role
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.flash_on_rounded,
                            size: 16, color: AppColors.accent),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Uji Coba Cepat Role (1-Klik Masuk)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Pilih role untuk langsung menguji tampilan & logika:',
                      style: TextStyle(fontSize: 11, color: AppColors.textGrey),
                    ),
                    const SizedBox(height: 10),
                    _buildRoleQuickButton(
                      title: 'Role: Penonton / User',
                      subtitle: 'rafi@email.com (Katalog, Beli Tiket, QR Gate)',
                      icon: Icons.person_rounded,
                      color: AppColors.primary,
                      onTap: () => _quickLogin('rafi@email.com', '123456'),
                    ),
                    const SizedBox(height: 8),
                    _buildRoleQuickButton(
                      title: 'Role: Produser / Promotor',
                      subtitle: 'producer@soundwave.com (Dasbor, Konser, Escrow)',
                      icon: Icons.campaign_rounded,
                      color: AppColors.accent,
                      onTap: () =>
                          _quickLogin('producer@soundwave.com', 'producer123'),
                    ),
                    const SizedBox(height: 8),
                    _buildRoleQuickButton(
                      title: 'Role: Super Admin',
                      subtitle: 'admin@livetix.com (Approval Konser & EO, Monitoring)',
                      icon: Icons.admin_panel_settings_rounded,
                      color: const Color(0xFFB91C1C),
                      onTap: () => _quickLogin('admin@livetix.com', 'admin123'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
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
                    size: 16, color: AppColors.primary),
                label: const Text(
                  'Alur Verifikasi Produser (Lengkapi Profil & KTP)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFD0D5DD)),
                  backgroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleQuickButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 15, color: color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textGrey,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 11, color: color.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }
}
