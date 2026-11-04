import 'package:flutter/material.dart';
import '../../services/admin_service.dart';
import '../../services/data_service.dart';
import '../home/home_screen.dart';
import 'admin_notification_screen.dart';
import 'admin_shell.dart';
import 'widgets/admin_theme.dart';
import 'widgets/admin_widgets.dart';

/// Layar Profil Super Admin (Image 3): Header gradien ungu, kartu statistik
/// (Approval Hari Ini & Total Approval), grup menu AKUN, PENGATURAN, dan LAINNYA.
class AdminProfileScreen extends StatelessWidget {
  const AdminProfileScreen({super.key});

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

  void _showNotice(BuildContext context, String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title akan tersedia pada pembaruan mendatang.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: DataService().currentUserNotifier,
      builder: (context, user, _) {
        final email = user?.email ?? 'admin@soundwave.com';
        const name = 'Super Admin';
        const initials = 'AD';

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
                            child: const Text(
                              initials,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1E3A8A),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            name,
                            style: TextStyle(
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
                              onTap: () => _showNotice(context, 'Edit Profil'),
                            ),
                            const Divider(height: 1, color: AdminColors.border),
                            _buildTile(
                              icon: Icons.lock_outline_rounded,
                              title: 'Ubah Kata Sandi',
                              onTap: () =>
                                  _showNotice(context, 'Ubah Kata Sandi'),
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
                            _buildTile(
                              icon: Icons.palette_outlined,
                              title: 'Mode Tampilan',
                              trailingText: 'Light',
                              onTap: () => _showNotice(context, 'Mode Tampilan'),
                            ),
                            const Divider(height: 1, color: AdminColors.border),
                            _buildTile(
                              icon: Icons.language_outlined,
                              title: 'Bahasa',
                              trailingText: 'Indonesia',
                              onTap: () => _showNotice(context, 'Bahasa'),
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
                              onTap: () => _showNotice(context, 'Pusat Bantuan'),
                            ),
                            const Divider(height: 1, color: AdminColors.border),
                            _buildTile(
                              icon: Icons.info_outline_rounded,
                              title: 'Tentang Aplikasi',
                              onTap: () =>
                                  _showNotice(context, 'Tentang Aplikasi'),
                            ),
                            const Divider(height: 1, color: AdminColors.border),
                            _buildTile(
                              icon: Icons.privacy_tip_outlined,
                              title: 'Kebijakan Privasi',
                              onTap: () =>
                                  _showNotice(context, 'Kebijakan Privasi'),
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
    final color = isDestructive ? const Color(0xFFDC2626) : AdminColors.textDark;
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
}
