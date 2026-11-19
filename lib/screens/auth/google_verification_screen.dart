import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../models/user_model.dart';
import '../../services/data_service.dart';
import '../../services/google_auth_service.dart';
import '../../widgets/auth_header.dart';
import '../../widgets/primary_button.dart';
import '../promoter/promoter_pin_lock_screen.dart';
import '../splash_screen.dart';
import 'login_screen.dart';
import 'user_verification_screen.dart';

/// Halaman wajib setelah autentikasi Google: menampilkan identitas Google dan
/// meminta pengguna menentukan role sebelum masuk ke verifikasi role tersebut.
class GoogleVerificationScreen extends StatefulWidget {
  const GoogleVerificationScreen({super.key, this.initialUser});

  final UserModel? initialUser;

  @override
  State<GoogleVerificationScreen> createState() =>
      _GoogleVerificationScreenState();
}

class _GoogleVerificationScreenState extends State<GoogleVerificationScreen> {
  String? _selectedRole;
  bool _isSubmitting = false;
  String? _errorMessage;

  UserModel? get _user => widget.initialUser ?? DataService().currentUser;

  GoogleAccountInfo? get _account => GoogleAuthService().currentGoogleAccount();

  Future<void> _continue() async {
    if (_isSubmitting) return;
    final role = _selectedRole;
    if (role == null || role.isEmpty) {
      setState(() {
        _errorMessage = 'Pilih role akun terlebih dahulu sebelum melanjutkan.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final result = await GoogleAuthService().selectRole(role);
    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = result.errorMessage ??
            'Role belum berhasil disimpan. Silakan coba lagi.';
      });
      return;
    }

    final user = DataService().currentUser;
    if (user == null) {
      setState(() {
        _isSubmitting = false;
        _errorMessage =
            'Sesi pengguna tidak ditemukan. Silakan masuk ulang dengan Google.';
      });
      return;
    }

    setState(() => _isSubmitting = false);

    if (result.role == 'Produser') {
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

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => UserVerificationScreen(initialUser: user),
      ),
      (route) => false,
    );
  }

  Future<void> _logout() async {
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
    final user = _user;
    final account = _account;
    final displayName = _firstNonEmpty([
      account?.name,
      user?.name,
    ]);
    final email = _firstNonEmpty([
      account?.email,
      user?.email,
    ]);
    final avatarUrl = _firstNonEmpty([
      account?.avatarUrl,
      user?.avatarUrl,
    ]);
    final initials = account?.initials ??
        (user?.initials ?? (displayName.isNotEmpty ? displayName[0] : 'G'));

    return ValueListenableBuilder<bool>(
      valueListenable: DataService().isDarkModeNotifier,
      builder: (context, isDarkMode, _) {
        final bg = isDarkMode ? AppColors.darkBg : Colors.white;
        final textColor = isDarkMode ? AppColors.darkText : AppColors.textDark;
        final subColor =
            isDarkMode ? AppColors.darkTextSecondary : AppColors.textGrey;
        final cardBg =
            isDarkMode ? AppColors.darkSurface : const Color(0xFFF8FAFC);
        final borderColor =
            isDarkMode ? AppColors.darkBorder : AppColors.border;
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            tooltip: 'Kembali ke login',
                            onPressed: _isSubmitting ? null : _logout,
                            icon: Icon(
                              Icons.arrow_back_rounded,
                              color: textColor,
                              size: 22,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.g_mobiledata_rounded,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  'Akun Google',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: subColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const AuthHeader(
                        height: 200,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: Color(0x33FFFFFF),
                              child: Icon(
                                Icons.verified_user_outlined,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Verifikasi Google',
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
                                'Lengkapi akun dan tentukan role sebelum masuk ke LiveTix',
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

                      // Informasi akun Google
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          children: [
                            _GoogleAvatar(
                              avatarUrl: avatarUrl.isEmpty ? null : avatarUrl,
                              initials: initials.isEmpty ? 'G' : initials,
                              isDarkMode: isDarkMode,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayName.isEmpty
                                        ? 'Pengguna Google'
                                        : displayName,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: textColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    email,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: subColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle_rounded,
                                        size: 14,
                                        color: isDarkMode
                                            ? const Color(0xFF4ADE80)
                                            : const Color(0xFF15803D),
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          'Email Google terverifikasi',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: isDarkMode
                                                ? const Color(0xFF4ADE80)
                                                : const Color(0xFF15803D),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      Container(
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
                              Icons.info_outline_rounded,
                              color: infoText,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Role menentukan fitur yang dapat kamu gunakan. Pembeli tiket memilih User, sedangkan penyelenggara acara memilih Produser.',
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

                      Text(
                        'Pilih Role Akun',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Role wajib dipilih dan tidak ditentukan otomatis.',
                        style: TextStyle(fontSize: 12, color: subColor),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: const Key('google_role_dropdown'),
                        initialValue: _selectedRole,
                        isExpanded: true,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: cardBg,
                          hintText: 'Pilih role akun',
                          hintStyle: TextStyle(
                            fontSize: 13.5,
                            color: subColor,
                          ),
                          prefixIcon: Icon(
                            Icons.badge_outlined,
                            size: 20,
                            color: subColor,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 1.4,
                            ),
                          ),
                        ),
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: textColor,
                        ),
                        dropdownColor:
                            isDarkMode ? AppColors.darkSurface : Colors.white,
                        items: const [
                          DropdownMenuItem(value: 'User', child: Text('User')),
                          DropdownMenuItem(
                            value: 'Produser',
                            child: Text('Produser'),
                          ),
                        ],
                        onChanged: _isSubmitting
                            ? null
                            : (value) {
                                setState(() {
                                  _selectedRole = value;
                                  _errorMessage = null;
                                });
                              },
                      ),

                      const SizedBox(height: 8),
                      Text(
                        'User untuk pembeli tiket. Produser untuk penyelenggara acara.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: subColor,
                          height: 1.4,
                        ),
                      ),

                      if (_errorMessage != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: errorBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: errorBorder),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
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

                      const SizedBox(height: 22),
                      PrimaryButton(
                        key: const Key('google_role_continue_btn'),
                        text: 'Lanjut ke Verifikasi',
                        isLoading: _isSubmitting,
                        onPressed: _continue,
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton.icon(
                          onPressed: _isSubmitting ? null : _logout,
                          icon: Icon(
                            Icons.logout_rounded,
                            size: 16,
                            color: subColor,
                          ),
                          label: Text(
                            'Keluar & Ganti Akun',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: subColor,
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
        );
      },
    );
  }
}

class _GoogleAvatar extends StatelessWidget {
  const _GoogleAvatar({
    required this.avatarUrl,
    required this.initials,
    required this.isDarkMode,
  });

  final String? avatarUrl;
  final String initials;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: 58,
      height: 58,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.darkSurfaceVariant : AppColors.avatarBg,
        shape: BoxShape.circle,
      ),
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.avatarText,
        ),
      ),
    );

    if (avatarUrl == null || avatarUrl!.trim().isEmpty) return fallback;

    return ClipOval(
      child: Image.network(
        avatarUrl!,
        width: 58,
        height: 58,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}

/// Layar kegagalan sinkronisasi akun Google. Pengguna tidak diarahkan ke
/// dashboard sampai profil berhasil disinkronkan.
class GoogleAuthErrorScreen extends StatelessWidget {
  const GoogleAuthErrorScreen({
    super.key,
    required this.message,
    this.accountName,
    this.email,
  });

  final String message;
  final String? accountName;
  final String? email;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: DataService().isDarkModeNotifier,
      builder: (context, isDarkMode, _) {
        final bg = isDarkMode ? AppColors.darkBg : Colors.white;
        final textColor = isDarkMode ? AppColors.darkText : AppColors.textDark;
        final subColor =
            isDarkMode ? AppColors.darkTextSecondary : AppColors.textGrey;
        final cardBg =
            isDarkMode ? AppColors.darkSurface : const Color(0xFFF8FAFC);
        final borderColor =
            isDarkMode ? AppColors.darkBorder : AppColors.border;

        return Scaffold(
          backgroundColor: bg,
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? const Color(0xFF450A0A)
                              : const Color(0xFFFEF2F2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.sync_problem_rounded,
                          size: 40,
                          color: isDarkMode
                              ? const Color(0xFFFCA5A5)
                              : const Color(0xFFB91C1C),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Akun Google belum dapat diproses',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Kamu belum diarahkan ke dashboard karena sinkronisasi profil gagal.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12.5, color: subColor),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if ((accountName ?? '').trim().isNotEmpty) ...[
                              Text(
                                accountName!.trim(),
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                            ],
                            if ((email ?? '').trim().isNotEmpty) ...[
                              Text(
                                email!.trim(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: subColor,
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                            Text(
                              message,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.45,
                                color: subColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      PrimaryButton(
                        text: 'Coba Lagi',
                        onPressed: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SplashScreen(),
                            ),
                            (route) => false,
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () {
                          DataService().logout();
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                            (route) => false,
                          );
                        },
                        child: Text(
                          'Keluar & Masuk dengan akun lain',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: subColor,
                          ),
                        ),
                      ),
                    ],
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

String _firstNonEmpty(List<Object?> values) {
  for (final value in values) {
    final text = (value ?? '').toString().trim();
    if (text.isNotEmpty) return text;
  }
  return '';
}
