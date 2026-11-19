import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_colors.dart';
import '../../models/user_model.dart';
import '../../services/data_service.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/auth_header.dart';
import '../../widgets/offline_banner.dart';
import '../../widgets/primary_button.dart';
import '../home/home_screen.dart';
import 'account_blocked_screen.dart';
import 'login_screen.dart';

/// Mengarahkan User ke Beranda bila NIK + Nama Lengkap sudah terverifikasi,
/// atau ke [UserVerificationScreen] bila belum terverifikasi.
Widget resolveUserEntryScreen(UserModel user) {
  if (user.isBlocked) {
    return AccountBlockedScreen(
      accountName: user.name,
      email: user.email,
      status: user.accountStatus,
      reason: user.deactivationReason,
    );
  }
  if (!user.isIdentityVerified) {
    return UserVerificationScreen(initialUser: user);
  }
  return HomeScreen(
    isGuest: false,
    userName: user.name,
    userInitials: user.initials,
  );
}

/// Halaman verifikasi identitas satu kali untuk role User (Penonton):
/// wajib mengisi NIK (16 digit) dan Nama Lengkap sebelum masuk Beranda.
class UserVerificationScreen extends StatefulWidget {
  final UserModel? initialUser;

  const UserVerificationScreen({super.key, this.initialUser});

  @override
  State<UserVerificationScreen> createState() => _UserVerificationScreenState();
}

class _UserVerificationScreenState extends State<UserVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nikController = TextEditingController();
  final _nameController = TextEditingController();
  final _nikFocus = FocusNode();
  final _nameFocus = FocusNode();

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final user = widget.initialUser ?? DataService().currentUser;
    if (user != null) {
      if (user.nik.trim().isNotEmpty) {
        _nikController.text = user.nik.trim();
      }
      if (user.name.trim().isNotEmpty) {
        _nameController.text = user.name.trim();
      }
    }
  }

  @override
  void dispose() {
    _nikController.dispose();
    _nameController.dispose();
    _nikFocus.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  Future<void> _submitVerification() async {
    if (_isSubmitting) return;
    setState(() => _errorMessage = null);

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isSubmitting = true);

    final result = await DataService().verifyUserIdentity(
      nik: _nikController.text.trim(),
      fullName: _nameController.text.trim(),
    );

    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _isSubmitting = false;
        _errorMessage =
            result.errorMessage ?? 'Gagal menyimpan verifikasi data diri.';
      });
      return;
    }

    final updated = DataService().currentUser;
    setState(() => _isSubmitting = false);

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          isGuest: false,
          userName: updated?.name ?? _nameController.text.trim(),
          userInitials: updated?.initials ?? 'U',
        ),
      ),
      (route) => false,
    );
  }

  Future<void> _logoutToLogin() async {
    DataService().logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: DataService().isDarkModeNotifier,
      builder: (context, isDarkMode, _) {
        final bg = isDarkMode ? AppColors.darkBg : Colors.white;
        final textCol = isDarkMode ? AppColors.darkText : AppColors.textDark;
        final subCol =
            isDarkMode ? AppColors.darkTextSecondary : const Color(0xFF475467);
        final cardBg =
            isDarkMode ? AppColors.darkSurface : const Color(0xFFF8FAFC);
        final borderCol = isDarkMode ? AppColors.darkBorder : AppColors.border;
        final infoBg =
            isDarkMode ? const Color(0xFF172554) : const Color(0xFFEFF6FF);
        final infoBorder =
            isDarkMode ? const Color(0xFF1E40AF) : const Color(0xFFBFDBFE);
        final infoText =
            isDarkMode ? const Color(0xFFBFDBFE) : const Color(0xFF1E3A8A);
        final errorBg =
            isDarkMode ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2);
        final errorBorder =
            isDarkMode ? const Color(0xFF991B1B) : const Color(0xFFFECACA);
        final errorText =
            isDarkMode ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C);

        return Scaffold(
          backgroundColor: bg,
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AuthHeader(
                          height: 210,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: Color(0x33FFFFFF),
                                child: Icon(
                                  Icons.badge_outlined,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Verifikasi Data Diri',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 4),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 24),
                                child: Text(
                                  'Lengkapi identitas untuk keamanan pembelian tiket',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        const OfflineBanner(),

                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: infoBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: infoBorder),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.verified_user_outlined,
                                color: infoText,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Masukkan NIK dan Nama Lengkap sesuai KTP. Data ini hanya dilakukan satu kali saat login pertama sebelum masuk ke Beranda. NIK digunakan sebagai identitas unik pada setiap tiket yang kamu beli dan sebagai bentuk pertanggungjawaban apabila terdapat kesalahan atau indikasi kecurangan pada tiket.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.4,
                                    color: infoText,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderCol),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Data Identitas Penonton',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: textCol,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Pastikan NIK dan nama sesuai kartu identitas resmi.',
                                style: TextStyle(fontSize: 12, color: subCol),
                              ),
                              const SizedBox(height: 16),

                              AppTextField(
                                key: const Key('user_verification_nik_field'),
                                label: 'NIK (16 Digit Angka)',
                                icon: Icons.credit_card_outlined,
                                controller: _nikController,
                                focusNode: _nikFocus,
                                keyboardType: TextInputType.number,
                                maxLength: 16,
                                textInputAction: TextInputAction.next,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(16),
                                ],
                                helperText: 'Contoh: 3573011205950001',
                                onFieldSubmitted: (_) => FocusScope.of(context)
                                    .requestFocus(_nameFocus),
                                validator: (v) {
                                  final digits = (v ?? '')
                                      .replaceAll(RegExp(r'[^0-9]'), '');
                                  if (digits.isEmpty) {
                                    return 'NIK wajib diisi';
                                  }
                                  if (digits.length != 16) {
                                    return 'NIK harus tepat 16 digit angka';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),

                              AppTextField(
                                key: const Key('user_verification_name_field'),
                                label: 'Nama Lengkap Sesuai KTP',
                                icon: Icons.person_outline_rounded,
                                controller: _nameController,
                                focusNode: _nameFocus,
                                keyboardType: TextInputType.name,
                                textCapitalization: TextCapitalization.words,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _submitVerification(),
                                validator: (v) {
                                  if ((v ?? '').trim().length < 2) {
                                    return 'Nama lengkap minimal 2 karakter';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),

                        if (_errorMessage != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: errorBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: errorBorder),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline_rounded,
                                  color: errorText,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: errorText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),

                        PrimaryButton(
                          key: const Key('user_verification_submit_btn'),
                          text: 'Verifikasi & Masuk Beranda',
                          isLoading: _isSubmitting,
                          onPressed: _submitVerification,
                        ),

                        const SizedBox(height: 12),

                        Center(
                          child: TextButton.icon(
                            onPressed: _isSubmitting ? null : _logoutToLogin,
                            icon: Icon(
                              Icons.logout_rounded,
                              size: 16,
                              color: subCol,
                            ),
                            label: Text(
                              'Keluar & Ganti Akun',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: subCol,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
