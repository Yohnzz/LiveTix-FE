import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_colors.dart';
import '../../models/user_model.dart';
import '../../services/data_service.dart';
import '../../utils/photo_picker.dart';
import '../../widgets/user_avatar.dart';
import '../auth/forgot_password_screen.dart';

class EditProfileScreen extends StatefulWidget {
  final bool isDarkMode;

  const EditProfileScreen({
    super.key,
    this.isDarkMode = false,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final DataService _dataService = DataService();
  final _nameFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isPasswordFormOpen = false;
  bool _isSavingPassword = false;
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _statusBannerMessage;

  Color get _bgColor =>
      widget.isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF9FAFB);
  Color get _cardColor =>
      widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white;
  Color get _borderColor =>
      widget.isDarkMode ? const Color(0xFF334155) : AppColors.border;
  Color get _titleColor =>
      widget.isDarkMode ? const Color(0xFFF8FAFC) : AppColors.textDark;
  Color get _subtitleColor =>
      widget.isDarkMode ? const Color(0xFFCBD5E1) : AppColors.textGrey;
  Color get _inputFillColor =>
      widget.isDarkMode ? const Color(0xFF334155) : Colors.white;
  Color get _lockedFillColor =>
      widget.isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF2F4F7);
  Color get _errorColor =>
      widget.isDarkMode ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C);
  Color get _linkColor =>
      widget.isDarkMode ? const Color(0xFF93C5FD) : AppColors.accent;
  Color get _successBgColor =>
      widget.isDarkMode ? const Color(0xFF14532D) : const Color(0xFFDCFCE7);
  Color get _successTextColor =>
      widget.isDarkMode ? const Color(0xFFDCFCE7) : const Color(0xFF166534);

  @override
  void initState() {
    super.initState();
    final user = _dataService.currentUser ??
        _dataService.ensureSessionForLoggedInView(
          name: 'Pengguna LiveTix',
          email: 'rafi@email.com',
        );
    _nameController = TextEditingController(text: user.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showSuccessFeedback(String message) {
    setState(() {
      _statusBannerMessage = message;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF166534),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _saveName() {
    if (!_nameFormKey.currentState!.validate()) return;
    final nextName = _nameController.text.trim();
    _dataService.updateProfile(name: nextName);
    FocusScope.of(context).unfocus();
    _showSuccessFeedback('Nama profil berhasil diperbarui');
  }

  Future<void> _submitChangePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    setState(() => _isSavingPassword = true);

    final res = await _dataService.changePassword(
      oldPassword: _oldPasswordController.text,
      newPassword: _newPasswordController.text,
    );

    if (!mounted) return;
    setState(() => _isSavingPassword = false);

    if (!res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message ?? 'Password lama tidak sesuai'),
          backgroundColor: const Color(0xFFB91C1C),
        ),
      );
      return;
    }

    _oldPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
    FocusScope.of(context).unfocus();
    setState(() {
      _isPasswordFormOpen = false;
    });
    _showSuccessFeedback('Kata sandi berhasil diperbarui');
  }

  Future<void> _openForgotPasswordFlow(String currentEmail) async {
    final didReset = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ForgotPasswordScreen(
          initialEmail: currentEmail,
          returnToCaller: true,
        ),
      ),
    );

    if (didReset == true && mounted) {
      _oldPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      setState(() {
        _isPasswordFormOpen = false;
      });
      _showSuccessFeedback(
        'Kata sandi berhasil diperbarui melalui verifikasi email',
      );
    }
  }

  void _showChangePhotoSheet(UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): () =>
                Navigator.pop(ctx),
          },
          child: Focus(
            autofocus: true,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Ganti Foto Profil',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: _titleColor,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Tutup dialog foto profil',
                          onPressed: () => Navigator.pop(ctx),
                          constraints: const BoxConstraints(
                            minWidth: 44,
                            minHeight: 44,
                          ),
                          icon: Icon(Icons.close_rounded, color: _subtitleColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Unggah foto dari perangkatmu atau pilih tema warna avatar inisial.',
                      style: TextStyle(fontSize: 13, color: _subtitleColor),
                    ),
                    const SizedBox(height: 18),
                    if (PhotoPicker.canPickFromDevice) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final bytes = await PhotoPicker.pickImageBytes();
                            if (!ctx.mounted) return;
                            if (bytes != null && bytes.isNotEmpty) {
                              Navigator.pop(ctx);
                              await _dataService.updateProfile(
                                profileImageBytes: bytes,
                              );
                              if (!mounted) return;
                              _showSuccessFeedback(
                                'Foto profil berhasil diperbarui',
                              );
                            }
                          },
                          icon: const Icon(Icons.photo_library_outlined, size: 18),
                          label: const Text(
                            'Pilih Foto dari Perangkat',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],
                    Text(
                      'Tema Warna Avatar Inisial',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _titleColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        Tooltip(
                          message: 'Ikon Profil Default',
                          child: Semantics(
                            button: true,
                            selected: user.profileImageBytes == null &&
                                user.avatarColorIndex < 0,
                            excludeSemantics: true,
                            label: 'Ikon Profil Default',
                            child: InkWell(
                              onTap: () {
                                _dataService.updateProfile(
                                  clearProfileImage: true,
                                  avatarColorIndex: -1,
                                );
                                Navigator.pop(ctx);
                                _showSuccessFeedback(
                                  'Avatar profil dikembalikan ke ikon default',
                                );
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                constraints: const BoxConstraints(
                                  minWidth: 52,
                                  minHeight: 52,
                                ),
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: (user.profileImageBytes == null &&
                                            user.avatarColorIndex < 0)
                                        ? AppColors.primary
                                        : _borderColor,
                                    width: (user.profileImageBytes == null &&
                                            user.avatarColorIndex < 0)
                                        ? 2
                                        : 1,
                                  ),
                                ),
                                child: const GuestAvatarIcon(size: 36),
                              ),
                            ),
                          ),
                        ),
                        ...List.generate(UserAvatar.themes.length, (i) {
                          final theme = UserAvatar.themes[i];
                          final isSelected =
                              user.profileImageBytes == null &&
                              user.avatarColorIndex == i;
                          return Tooltip(
                            message: 'Tema ${theme.name}',
                            child: Semantics(
                              button: true,
                              selected: isSelected,
                              excludeSemantics: true,
                              label: 'Tema ${theme.name}',
                              child: InkWell(
                                onTap: () {
                                  _dataService.updateProfile(
                                    clearProfileImage: true,
                                    avatarColorIndex: i,
                                  );
                                  Navigator.pop(ctx);
                                  _showSuccessFeedback(
                                    'Avatar profil diubah ke tema ${theme.name}',
                                  );
                                },
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  constraints: const BoxConstraints(
                                    minWidth: 52,
                                    minHeight: 52,
                                  ),
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.primary
                                          : _borderColor,
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: theme.bgColor,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: isSelected
                                              ? Icon(
                                                  Icons.check_rounded,
                                                  size: 18,
                                                  color: theme.textColor,
                                                )
                                              : Text(
                                                  user.initials,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: theme.textColor,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                    if (user.profileImageBytes != null ||
                        (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            _dataService.updateProfile(clearProfileImage: true);
                            Navigator.pop(ctx);
                            _showSuccessFeedback(
                              'Foto profil dihapus, kembali ke inisial',
                            );
                          },
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: _errorColor,
                          ),
                          label: Text(
                            'Hapus Foto Profil',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: _errorColor,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: _errorColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        },
      },
      child: Scaffold(
        backgroundColor: _bgColor,
        appBar: AppBar(
          backgroundColor: _cardColor,
          elevation: 0,
          leading: IconButton(
            tooltip: 'Kembali ke profil',
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back, color: _titleColor),
          ),
          title: Text(
            'Edit Profil',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _titleColor,
            ),
          ),
          centerTitle: false,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: _borderColor),
          ),
        ),
        body: ValueListenableBuilder<UserModel?>(
          valueListenable: _dataService.currentUserNotifier,
          builder: (context, currentUser, _) {
            final user = currentUser ??
                const UserModel(
                  name: 'Pengguna LiveTix',
                  email: 'rafi@email.com',
                  phone: '081234567890',
                  password: '123456',
                );

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_statusBannerMessage != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: _successBgColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            size: 18,
                            color: _successTextColor,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _statusBannerMessage!,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _successTextColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 1. Kartu Foto Profil
                  _buildPhotoSectionCard(user),
                  const SizedBox(height: 16),

                  // 2. Kartu Edit Nama
                  _buildEditNameCard(user),
                  const SizedBox(height: 16),

                  // 3. Kartu Ganti Password (2 Alur: Password Lama & Lupa Password)
                  _buildChangePasswordCard(user),
                  const SizedBox(height: 28),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPhotoSectionCard(UserModel user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          Semantics(
            button: true,
            label: 'Ubah foto profil',
            child: InkWell(
              onTap: () => _showChangePhotoSheet(user),
              customBorder: const CircleBorder(),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  UserAvatar(
                    initials: user.initials,
                    imageBytes: user.profileImageBytes,
                    avatarUrl: user.avatarUrl,
                    colorIndex: user.avatarColorIndex,
                    size: 84,
                    fontSize: 26,
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: _cardColor, width: 2),
                      ),
                      child: const Icon(
                        Icons.camera_alt_outlined,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            user.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _titleColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'ID : ${user.displayId}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: _subtitleColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            user.email,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: _subtitleColor),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 44,
            child: OutlinedButton.icon(
              onPressed: () => _showChangePhotoSheet(user),
              icon: Icon(
                Icons.photo_camera_outlined,
                size: 18,
                color: widget.isDarkMode ? _titleColor : AppColors.primary,
              ),
              label: Text(
                'Ganti Foto Profil',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: widget.isDarkMode ? _titleColor : AppColors.primary,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                side: BorderSide(
                  color: widget.isDarkMode ? _borderColor : AppColors.primary,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditNameCard(UserModel user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
      ),
      child: Form(
        key: _nameFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Informasi Profil',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _titleColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Perbarui nama tampilan yang tercetak pada tiketmu.',
              style: TextStyle(fontSize: 12.5, color: _subtitleColor),
            ),
            const SizedBox(height: 16),
            _buildFieldLabel('Nama Lengkap'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _nameController,
              style: TextStyle(fontSize: 14, color: _titleColor),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Nama tidak boleh kosong';
                }
                if (v.trim().length < 2) {
                  return 'Nama minimal 2 karakter';
                }
                return null;
              },
              decoration: _inputDecoration(
                hintText: 'Masukkan nama lengkap',
                prefixIcon: Icons.person_outline_rounded,
              ),
            ),
            const SizedBox(height: 14),
            _buildFieldLabel('Email Terdaftar'),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: _lockedFillColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _borderColor),
              ),
              child: Row(
                children: [
                  Icon(Icons.mail_outline_rounded, size: 18, color: _subtitleColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      user.email,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: _subtitleColor,
                      ),
                    ),
                  ),
                  Icon(Icons.lock_outline_rounded, size: 16, color: _subtitleColor),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _saveName,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Simpan Nama',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChangePasswordCard(UserModel user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: widget.isDarkMode
                      ? const Color(0xFF334155)
                      : const Color(0xFFE0EAFF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.lock_outline_rounded,
                  size: 20,
                  color: widget.isDarkMode ? _titleColor : AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Keamanan Kata Sandi',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _titleColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ubah kata sandi akun secara berkala',
                      style: TextStyle(fontSize: 12.5, color: _subtitleColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!_isPasswordFormOpen)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _isPasswordFormOpen = true;
                  });
                },
                icon: Icon(
                  Icons.key_rounded,
                  size: 18,
                  color: widget.isDarkMode ? _titleColor : AppColors.primary,
                ),
                label: Text(
                  'Ganti Password',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: widget.isDarkMode ? _titleColor : AppColors.primary,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: widget.isDarkMode ? _borderColor : AppColors.primary,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            )
          else
            Form(
              key: _passwordFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(height: 1, color: _borderColor),
                  const SizedBox(height: 16),

                  // 1. Masukkan Password Lama
                  _buildFieldLabel('Masukkan Password Lama'),
                  const SizedBox(height: 6),
                  TextFormField(
                    key: const Key('old_password_field'),
                    controller: _oldPasswordController,
                    obscureText: _obscureOld,
                    style: TextStyle(fontSize: 14, color: _titleColor),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Masukkan password lama terlebih dahulu';
                      }
                      if (user.password.isNotEmpty && v != user.password) {
                        return 'Password lama tidak sesuai';
                      }
                      return null;
                    },
                    decoration: _inputDecoration(
                      hintText: 'Masukkan password saat ini',
                      prefixIcon: Icons.lock_clock_outlined,
                      suffixIcon: IconButton(
                        tooltip: _obscureOld
                            ? 'Tampilkan password lama'
                            : 'Sembunyikan password lama',
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                        icon: Icon(
                          _obscureOld
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 18,
                          color: _subtitleColor,
                        ),
                        onPressed: () =>
                            setState(() => _obscureOld = !_obscureOld),
                      ),
                    ),
                  ),

                  // Tombol Lupa Password (Alur 2)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => _openForgotPasswordFlow(user.email),
                      style: TextButton.styleFrom(
                        foregroundColor: _linkColor,
                        minimumSize: const Size(44, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: Text(
                        'Lupa Password?',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _linkColor,
                        ),
                      ),
                    ),
                  ),

                  // 2. Password Baru
                  _buildFieldLabel('Password Baru'),
                  const SizedBox(height: 6),
                  TextFormField(
                    key: const Key('new_password_field'),
                    controller: _newPasswordController,
                    obscureText: _obscureNew,
                    style: TextStyle(fontSize: 14, color: _titleColor),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Masukkan password baru';
                      }
                      if (v.length < 6) {
                        return 'Password baru minimal 6 karakter';
                      }
                      return null;
                    },
                    decoration: _inputDecoration(
                      hintText: 'Minimal 6 karakter',
                      prefixIcon: Icons.lock_outline_rounded,
                      suffixIcon: IconButton(
                        tooltip: _obscureNew
                            ? 'Tampilkan password baru'
                            : 'Sembunyikan password baru',
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                        icon: Icon(
                          _obscureNew
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 18,
                          color: _subtitleColor,
                        ),
                        onPressed: () =>
                            setState(() => _obscureNew = !_obscureNew),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 3. Confirm Password
                  _buildFieldLabel('Confirm Password'),
                  const SizedBox(height: 6),
                  TextFormField(
                    key: const Key('confirm_password_field'),
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirm,
                    style: TextStyle(fontSize: 14, color: _titleColor),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Konfirmasi password baru wajib diisi';
                      }
                      if (v != _newPasswordController.text) {
                        return 'Konfirmasi password tidak cocok';
                      }
                      return null;
                    },
                    decoration: _inputDecoration(
                      hintText: 'Ulangi password baru',
                      prefixIcon: Icons.verified_user_outlined,
                      suffixIcon: IconButton(
                        tooltip: _obscureConfirm
                            ? 'Tampilkan konfirmasi password'
                            : 'Sembunyikan konfirmasi password',
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 18,
                          color: _subtitleColor,
                        ),
                        onPressed: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Tombol Batal & Simpan Password (Done)
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SizedBox(
                        height: 46,
                        child: OutlinedButton(
                          onPressed: () {
                            _oldPasswordController.clear();
                            _newPasswordController.clear();
                            _confirmPasswordController.clear();
                            setState(() {
                              _isPasswordFormOpen = false;
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            side: BorderSide(color: _borderColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Batal',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: _subtitleColor,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 46,
                        child: ElevatedButton(
                          onPressed: _isSavingPassword ? null : _submitChangePassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 22),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isSavingPassword
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Simpan Password',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                  ),
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
    );
  }

  Widget _buildFieldLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: _titleColor,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(fontSize: 13, color: _subtitleColor),
      filled: true,
      fillColor: _inputFillColor,
      prefixIcon: Icon(prefixIcon, size: 18, color: _subtitleColor),
      suffixIcon: suffixIcon,
      errorStyle: TextStyle(fontSize: 11.5, color: _errorColor),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: widget.isDarkMode ? const Color(0xFF93C5FD) : AppColors.primary,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _errorColor),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _errorColor, width: 1.5),
      ),
    );
  }
}
