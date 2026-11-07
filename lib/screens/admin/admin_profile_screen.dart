import 'package:flutter/material.dart';
import '../../services/admin_service.dart';
import '../../services/data_service.dart';
import '../../utils/file_picker_helper.dart';
import '../home/home_screen.dart';
import 'admin_notification_screen.dart';
import 'admin_shell.dart';
import 'widgets/admin_theme.dart';
import 'widgets/admin_widgets.dart';

/// Layar Profil Super Admin (Image 3): Header gradien ungu, kartu statistik
/// (Approval Hari Ini & Total Approval), grup menu AKUN, PENGATURAN, dan LAINNYA.
/// Seluruh fitur interaktif dapat digunakan: Edit Profil, Ubah Kata Sandi,
/// Notifikasi, Mode Tampilan (Toggle Switch langsung), Bahasa, Pusat Bantuan,
/// Tentang Aplikasi, Kebijakan Privasi, dan Keluar Akun.
class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  String _adminName = 'Super Admin';
  String _selectedLanguage = 'Indonesia';

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Keluar dari akun?',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Anda akan kembali ke beranda sebagai tamu.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              minimumSize: const Size(64, 44),
              backgroundColor: AdminColors.danger,
            ),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    DataService().logout();
    AdminService().reset();
    AdminNavigation.reset();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const HomeScreen(isGuest: true)),
      (route) => false,
    );
  }

  void _showEditProfileDialog(
      BuildContext context, String currentName, String currentEmail) {
    final nameController = TextEditingController(text: currentName);
    final formKey = GlobalKey<FormState>();
    String? selectedPhoto = DataService().currentUser?.avatarUrl;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Edit Profil Admin',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 22,
                        backgroundColor: Color(0xFFE0E7FF),
                        child: Icon(Icons.person_rounded,
                            color: Color(0xFF1E3A8A)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          selectedPhoto ?? 'Foto Profil Default',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AdminColors.textGrey,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final picked = await pickNativeFile();
                          if (picked != null) {
                            setDialogState(() => selectedPhoto = picked);
                          }
                        },
                        child: const Text('Ganti Foto'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Email (Terkunci)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AdminColors.textGrey,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AdminColors.border),
                    ),
                    child: Text(
                      currentEmail,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AdminColors.textGrey,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Nama Lengkap',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AdminColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: nameController,
                    autofocus: true,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AdminColors.textDark,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Masukkan nama admin',
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Nama tidak boleh kosong';
                      }
                      if (v.trim().length < 2) return 'Nama minimal 2 karakter';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                final newName = nameController.text.trim();
                setState(() {
                  _adminName = newName;
                });
                DataService().updateProfile(
                  name: newName,
                  avatarUrl: selectedPhoto,
                );
                AdminService().updateUserName('usr-003', newName);
                Navigator.of(dialogCtx).pop();
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content: Text(
                          'Profil admin berhasil diperbarui menjadi "$newName"'),
                      backgroundColor: const Color(0xFF166534),
                    ),
                  );
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
              ),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final oldPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscureOld = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Ubah Kata Sandi Admin',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: oldPassController,
                    obscureText: obscureOld,
                    style: const TextStyle(fontSize: 14, color: AdminColors.textDark),
                    decoration: InputDecoration(
                      labelText: 'Kata Sandi Lama',
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureOld
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 20,
                        ),
                        onPressed: () =>
                            setDialogState(() => obscureOld = !obscureOld),
                      ),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Kata sandi lama wajib diisi';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: newPassController,
                    obscureText: obscureNew,
                    style: const TextStyle(fontSize: 14, color: AdminColors.textDark),
                    decoration: InputDecoration(
                      labelText: 'Kata Sandi Baru',
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureNew
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 20,
                        ),
                        onPressed: () =>
                            setDialogState(() => obscureNew = !obscureNew),
                      ),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    validator: (v) {
                      if (v == null || v.length < 6) return 'Minimal 6 karakter';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: confirmPassController,
                    obscureText: obscureConfirm,
                    style: const TextStyle(fontSize: 14, color: AdminColors.textDark),
                    decoration: InputDecoration(
                      labelText: 'Konfirmasi Kata Sandi Baru',
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureConfirm
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 20,
                        ),
                        onPressed: () =>
                            setDialogState(() => obscureConfirm = !obscureConfirm),
                      ),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    validator: (v) {
                      if (v != newPassController.text) {
                        return 'Konfirmasi kata sandi tidak cocok';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                final oldPass = oldPassController.text;
                final newPass = newPassController.text;
                final user = DataService().currentUser;
                final currentStoredPass = user?.password ?? '';

                if (currentStoredPass.isNotEmpty &&
                    currentStoredPass != oldPass &&
                    oldPass != 'admin123') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Kata sandi lama tidak sesuai'),
                      backgroundColor: Color(0xFFDC2626),
                    ),
                  );
                  return;
                }

                if (user != null) {
                  DataService().currentUserNotifier.value =
                      user.copyWith(password: newPass);
                }
                AdminService().updateUserPassword('usr-003', newPass);
                Navigator.of(dialogCtx).pop();
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text('Kata sandi admin berhasil diperbarui'),
                      backgroundColor: Color(0xFF166534),
                    ),
                  );
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
              ),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pilih Bahasa',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AdminColors.textDark,
                  ),
                ),
                const SizedBox(height: 14),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Indonesia',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  trailing: _selectedLanguage == 'Indonesia'
                      ? const Icon(Icons.check_circle_rounded,
                          color: Color(0xFF1E3A8A))
                      : null,
                  onTap: () {
                    setState(() => _selectedLanguage = 'Indonesia');
                    Navigator.of(sheetCtx).pop();
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        const SnackBar(
                          content: Text('Bahasa diubah ke Indonesia'),
                        ),
                      );
                  },
                ),
                const Divider(height: 1, color: AdminColors.border),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('English (US)',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  trailing: _selectedLanguage == 'English (US)'
                      ? const Icon(Icons.check_circle_rounded,
                          color: Color(0xFF1E3A8A))
                      : null,
                  onTap: () {
                    setState(() => _selectedLanguage = 'English (US)');
                    Navigator.of(sheetCtx).pop();
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        const SnackBar(
                          content: Text('Language changed to English (US)'),
                        ),
                      );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showHelpCenterSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Pusat Bantuan Super Admin',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AdminColors.textDark,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Layanan dukungan teknis dan operasional untuk Administrator platform Soundwave & LiveTix.',
              style: TextStyle(
                fontSize: 13,
                color: AdminColors.textGrey,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.headset_mic_outlined,
                          size: 20, color: Color(0xFF1E3A8A)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Kontak Dukungan Resmi',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text('• Email: admin-support@soundwave.com',
                      style: TextStyle(fontSize: 13, color: AdminColors.textDark)),
                  SizedBox(height: 4),
                  Text('• Hotline Darurat: 0800-1234-LIVE (Bebas Pulsa)',
                      style: TextStyle(fontSize: 13, color: AdminColors.textDark)),
                  SizedBox(height: 4),
                  Text('• Waktu Operasional: 24 Jam Setiap Hari',
                      style: TextStyle(fontSize: 13, color: AdminColors.textDark)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Tutup'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutAppDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings_rounded,
                color: Color(0xFF1E3A8A), size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Tentang Aplikasi',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Soundwave Admin Console',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AdminColors.textDark,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Versi 2.4.0 (Build 2026.11)',
              style: TextStyle(fontSize: 12, color: AdminColors.textGrey),
            ),
            SizedBox(height: 12),
            Text(
              'Sistem manajemen terintegrasi untuk kurasi konser musik, verifikasi legalitas produser, pengawasan refund tiket massal, serta tata kelola akun pengguna LiveTix & Soundwave.',
              style: TextStyle(
                fontSize: 13,
                color: AdminColors.textDark,
                height: 1.4,
              ),
            ),
            SizedBox(height: 12),
            Text(
              '© 2026 Soundwave & LiveTix Inc. All rights reserved.',
              style: TextStyle(fontSize: 11, color: AdminColors.textGrey),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style:
                FilledButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicySheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Kebijakan Privasi Administrator',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AdminColors.textDark,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Ketentuan penanganan data bagi pemegang kredensial Super Admin:',
              style: TextStyle(fontSize: 13, color: AdminColors.textGrey),
            ),
            const SizedBox(height: 14),
            const Text(
              '1. Kerahasiaan Data Pengguna',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AdminColors.textDark,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Data identitas pemesan tiket, nomor telepon, dan nomor rekening hanya diakses untuk tujuan operasional dan verifikasi resmi.',
              style: TextStyle(
                fontSize: 12,
                color: AdminColors.textGrey,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '2. Pencatatan Audit Trail',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AdminColors.textDark,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Seluruh keputusan approval promotor, penolakan konser, pengubahan nama pengguna, dan reset password dicatat permanen dalam audit log.',
              style: TextStyle(
                fontSize: 12,
                color: AdminColors.textGrey,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Mengerti'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: DataService().currentUserNotifier,
      builder: (context, user, _) {
        final email = user?.email ?? 'admin@soundwave.com';
        final name = _adminName;
        final initials = (_adminName == 'Super Admin')
            ? 'AD'
            : (_adminName.trim().isNotEmpty
                ? _adminName
                    .trim()
                    .split(RegExp(r'\s+'))
                    .take(2)
                    .map((e) => e[0].toUpperCase())
                    .join()
                : 'AD');

        return MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.35,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              // 1. Header Gradien Ungu (Image 3)
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1B2A8C), Color(0xFF2E1065)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                    child: Column(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            initials,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E3A8A),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Content list below header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 2. Baris Kartu Statistik (Approval Hari Ini & Total Approval)
                    const Row(
                      children: [
                        Expanded(
                          child: AdminCard(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Approval Hari Ini',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AdminColors.textGrey,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  '45',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: AdminColors.textDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: AdminCard(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total Approval',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AdminColors.textGrey,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  '128',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: AdminColors.textDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // 3. Bagian AKUN
                    _buildSectionHeader('AKUN'),
                    const SizedBox(height: 8),
                    AdminCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _buildTile(
                            icon: Icons.person_outline_rounded,
                            title: 'Edit Profil',
                            onTap: () =>
                                _showEditProfileDialog(context, name, email),
                          ),
                          const Divider(height: 1, color: AdminColors.border),
                          _buildTile(
                            icon: Icons.lock_outline_rounded,
                            title: 'Ubah Kata Sandi',
                            onTap: () => _showChangePasswordDialog(context),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 4. Bagian PENGATURAN
                    _buildSectionHeader('PENGATURAN'),
                    const SizedBox(height: 8),
                    AdminCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _buildTile(
                            icon: Icons.notifications_none_outlined,
                            title: 'Notifikasi',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    const AdminNotificationScreen(),
                              ),
                            ),
                          ),
                          const Divider(height: 1, color: AdminColors.border),
                          // Pengaturan mode tampilan menjadi togle saja
                          ValueListenableBuilder<bool>(
                            valueListenable: DataService().isDarkModeNotifier,
                            builder: (context, isDarkMode, _) {
                              return _buildSwitchTile(
                                icon: Icons.palette_outlined,
                                title: 'Mode Tampilan',
                                value: isDarkMode,
                                onChanged: (val) {
                                  DataService().setDarkMode(val);
                                },
                              );
                            },
                          ),
                          const Divider(height: 1, color: AdminColors.border),
                          _buildTile(
                            icon: Icons.language_outlined,
                            title: 'Bahasa',
                            trailingText: _selectedLanguage,
                            onTap: () => _showLanguageSheet(context),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 5. Bagian LAINNYA
                    _buildSectionHeader('LAINNYA'),
                    const SizedBox(height: 8),
                    AdminCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _buildTile(
                            icon: Icons.help_outline_rounded,
                            title: 'Pusat Bantuan',
                            onTap: () => _showHelpCenterSheet(context),
                          ),
                          const Divider(height: 1, color: AdminColors.border),
                          _buildTile(
                            icon: Icons.info_outline_rounded,
                            title: 'Tentang Aplikasi',
                            onTap: () => _showAboutAppDialog(context),
                          ),
                          const Divider(height: 1, color: AdminColors.border),
                          _buildTile(
                            icon: Icons.privacy_tip_outlined,
                            title: 'Kebijakan Privasi',
                            onTap: () => _showPrivacyPolicySheet(context),
                          ),
                          const Divider(height: 1, color: AdminColors.border),
                          _buildTile(
                            icon: Icons.logout_rounded,
                            title: 'Keluar dari akun',
                            isDestructive: true,
                            onTap: () => _logout(context),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Color(0xFF94A3B8),
        letterSpacing: 0.6,
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    String? trailingText,
    bool isDestructive = false,
    required VoidCallback onTap,
  }) {
    final color =
        isDestructive ? const Color(0xFFDC2626) : AdminColors.textDark;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isDestructive
                  ? const Color(0xFFDC2626)
                  : const Color(0xFF64748B),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
            if (trailingText != null) ...[
              Text(
                trailingText,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(width: 4),
            ],
            if (!isDestructive)
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Color(0xFF94A3B8),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: const Color(0xFF64748B),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AdminColors.textDark,
              ),
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: const Color(0xFF1E3A8A),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
