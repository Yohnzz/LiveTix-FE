import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/custom_checkbox.dart';
import '../../widgets/primary_button.dart';
import '../home/home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();

  final _roles = const ['User', 'Produser'];
  String _role = 'User';
  bool _agree = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  void _register() {
    if (!_formKey.currentState!.validate()) return;
    if (!_agree) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Setujui syarat & ketentuan terlebih dahulu')),
      );
      return;
    }

    // Registrasi berhasil -> langsung masuk ke Home User
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          isGuest: false,
          userName: _name.text.split(' ').first,
          userInitials: _getInitials(_name.text),
        ),
      ),
      (route) => false,
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
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
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.chevron_left, size: 28, color: AppColors.textDark),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Buat akun baru',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Isi datamu untuk mulai memesan tiket',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textGrey,
                  ),
                ),
                const SizedBox(height: 24),

                // Nama Lengkap
                AppTextField(
                  label: 'Nama lengkap',
                  icon: Icons.person_outline,
                  controller: _name,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
                ),
                const SizedBox(height: 14),

                // Email
                AppTextField(
                  label: 'Email',
                  icon: Icons.mail_outline,
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v == null || !v.contains('@')) ? 'Email tidak valid' : null,
                ),
                const SizedBox(height: 14),

                // Nomor HP
                AppTextField(
                  label: 'Nomor HP',
                  icon: Icons.phone_android_outlined,
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  validator: (v) => (v == null || v.length < 9) ? 'Nomor HP tidak valid' : null,
                ),
                const SizedBox(height: 14),

                // Kata Sandi
                AppTextField(
                  label: 'Kata sandi',
                  icon: Icons.lock_outline,
                  controller: _password,
                  isPassword: true,
                  validator: (v) => (v == null || v.length < 6) ? 'Minimal 6 karakter' : null,
                ),
                const SizedBox(height: 14),

                // Role Dropdown dengan style Figma (Star icon & circular dropdown arrow)
                DropdownButtonFormField<String>(
                  initialValue: _role,
                  items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (v) => setState(() => _role = v!),
                  icon: const Icon(
                    Icons.arrow_drop_down_circle_outlined,
                    size: 20,
                    color: AppColors.textGrey,
                  ),
                  style: const TextStyle(fontSize: 13, color: AppColors.textDark),
                  decoration: InputDecoration(
                    labelText: 'Role',
                    labelStyle: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                    prefixIcon: const Icon(
                      Icons.stars_rounded,
                      size: 20,
                      color: AppColors.textGrey,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Checkbox Persetujuan Syarat & Ketentuan
                AppCheckbox(
                  value: _agree,
                  onChanged: (v) => setState(() => _agree = v ?? false),
                  label: const Text(
                    'Saya menyetujui Syarat & Ketentuan',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF344054)),
                  ),
                ),
                const SizedBox(height: 18),

                // Tombol Daftar
                PrimaryButton(text: 'Daftar', onPressed: _register),
                const SizedBox(height: 18),

                // Divider Atau
                const OrDivider(),
                const SizedBox(height: 18),

                // Tombol Google
                GoogleButton(onPressed: () {/* TODO: Google Sign-In */}),
                const SizedBox(height: 24),

                // Link Masuk
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Sudah punya akun? ',
                        style: TextStyle(fontSize: 12.5, color: AppColors.textGrey),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Text(
                          'Masuk',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

