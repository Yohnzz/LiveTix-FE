import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/primary_button.dart';

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

  // Admin sebaiknya dibuat dari backend, bukan dari form registrasi publik.
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
    // TODO: panggil API register
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
                InkWell(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.chevron_left, size: 28),
                ),
                const SizedBox(height: 8),
                const Text('Buat akun baru',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                const SizedBox(height: 4),
                const Text('Isi datamu untuk mulai memesan tiket',
                    style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                const SizedBox(height: 20),
                AppTextField(
                  label: 'Nama lengkap',
                  icon: Icons.person_outline,
                  controller: _name,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Email',
                  icon: Icons.mail_outline,
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v == null || !v.contains('@')) ? 'Email tidak valid' : null,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Nomor HP',
                  icon: Icons.phone_android,
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  validator: (v) => (v == null || v.length < 9) ? 'Nomor HP tidak valid' : null,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Kata sandi',
                  icon: Icons.lock_outline,
                  controller: _password,
                  isPassword: true,
                  validator: (v) => (v == null || v.length < 6) ? 'Minimal 6 karakter' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _role,
                  items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (v) => setState(() => _role = v!),
                  style: const TextStyle(fontSize: 13, color: AppColors.textDark),
                  decoration: InputDecoration(
                    labelText: 'Role',
                    labelStyle: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                    prefixIcon: const Icon(Icons.badge_outlined, size: 18, color: AppColors.textGrey),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Checkbox(
                      value: _agree,
                      activeColor: AppColors.primary,
                      onChanged: (v) => setState(() => _agree = v ?? false),
                    ),
                    const Expanded(
                      child: Text('Saya menyetujui Syarat & Ketentuan',
                          style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                PrimaryButton(text: 'Daftar', onPressed: _register),
                const SizedBox(height: 16),
                const OrDivider(),
                const SizedBox(height: 16),
                GoogleButton(onPressed: () {/* TODO: Google Sign-In */}),
                const SizedBox(height: 20),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Sudah punya akun? ',
                          style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Text('Masuk',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.accent)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
