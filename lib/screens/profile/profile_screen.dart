import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  final bool isGuest;
  final String userName;
  final String userEmail;
  final String userInitials;
  final VoidCallback? onLogout;

  const ProfileScreen({
    super.key,
    this.isGuest = false,
    this.userName = 'Rafi Firmansyah',
    this.userEmail = 'rafi@email.com',
    this.userInitials = 'RF',
    this.onLogout,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isDarkMode = false;

  void _goToLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _onRestrictedTap(String featureName) {
    if (widget.isGuest) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Akses Dibatasi',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          content: Text(
            'Silakan masuk dengan akun LiveTix untuk mengakses fitur $featureName.',
            style: const TextStyle(fontSize: 13.5, color: AppColors.textGrey, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal', style: TextStyle(color: AppColors.textGrey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _goToLogin();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Masuk Sekarang'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Akun
              const Text(
                'Akun',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Kelola profil & preferensimu',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textGrey,
                ),
              ),
              const SizedBox(height: 20),

              // Kartu Profil Utama
              _buildProfileCard(),
              const SizedBox(height: 14),

              // Jika Guest: Tombol Cepat Masuk Akun di bawah kartu profil
              if (widget.isGuest) ...[
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: _goToLogin,
                    icon: const Icon(Icons.login_rounded, size: 20),
                    label: const Text(
                      'Masuk ke Akun',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Kartu Statistik (Tiket dibeli, Konser dihadiri, Ulasan)
              _buildStatsCard(),
              const SizedBox(height: 24),

              // Grup AKUN
              const Text(
                'AKUN',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textGrey,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              _buildMenuItem(
                icon: Icons.person_outline_rounded,
                title: 'Edit profil',
                onTap: () => _onRestrictedTap('Edit Profil'),
              ),
              _buildMenuItem(
                icon: Icons.credit_card_outlined,
                title: 'Metode pembayaran',
                onTap: () => _onRestrictedTap('Metode Pembayaran'),
              ),
              _buildMenuItem(
                icon: Icons.notifications_none_rounded,
                title: 'Notifikasi',
                onTap: () => _onRestrictedTap('Notifikasi'),
              ),
              const SizedBox(height: 20),

              // Grup PREFERENSI
              const Text(
                'PREFERENSI',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textGrey,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              _buildPreferenceSwitchItem(
                icon: Icons.nightlight_round_outlined,
                title: 'Mode tampilan',
                statusText: _isDarkMode ? 'Dark' : 'Light',
                value: _isDarkMode,
                onChanged: (val) => setState(() => _isDarkMode = val),
              ),
              _buildPreferenceTextItem(
                icon: Icons.language_rounded,
                title: 'Bahasa',
                valueText: 'Indonesia',
              ),
              const SizedBox(height: 20),

              // Grup LAINNYA
              const Text(
                'LAINNYA',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textGrey,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              _buildMenuItem(
                icon: Icons.help_outline_rounded,
                title: 'Pusat bantuan',
                onTap: () {},
              ),
              _buildMenuItem(
                icon: Icons.description_outlined,
                title: 'Syarat & ketentuan',
                onTap: () {},
              ),
              _buildMenuItem(
                icon: Icons.shield_outlined,
                title: 'Kebijakan privasi',
                onTap: () {},
              ),

              // Tombol Logout jika sedang mode User
              if (!widget.isGuest) ...[
                const SizedBox(height: 12),
                _buildMenuItem(
                  icon: Icons.logout_rounded,
                  title: 'Keluar dari akun',
                  iconColor: Colors.redAccent,
                  textColor: Colors.redAccent,
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: const Text('Keluar Akun', style: TextStyle(fontWeight: FontWeight.bold)),
                        content: const Text('Apakah kamu yakin ingin keluar dan beralih ke mode tamu?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Batal', style: TextStyle(color: AppColors.textGrey)),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              if (widget.onLogout != null) {
                                widget.onLogout!();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Keluar'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Avatar Bulat
          Container(
            width: 54,
            height: 54,
            decoration: const BoxDecoration(
              color: AppColors.avatarBg,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                widget.isGuest ? '' : widget.userInitials,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.avatarText,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Nama & Email / Guest
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.isGuest ? 'Guest' : widget.userName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                if (!widget.isGuest) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.userEmail,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textGrey,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Tombol Edit
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F4F7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.edit_outlined,
              size: 18,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    final tickets = widget.isGuest ? '0' : '12';
    final concerts = widget.isGuest ? '0' : '9';
    final reviews = widget.isGuest ? '0' : '4';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(child: _buildStatItem(tickets, 'Tiket dibeli')),
          Container(height: 32, width: 1, color: AppColors.border),
          Expanded(child: _buildStatItem(concerts, 'Konser dihadiri')),
          Container(height: 32, width: 1, color: AppColors.border),
          Expanded(child: _buildStatItem(reviews, 'Ulasan')),
        ],
      ),
    );
  }

  Widget _buildStatItem(String count, String label) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textGrey,
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
    Color? textColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF2F4F7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 20,
                color: iconColor ?? AppColors.textDark,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: textColor ?? AppColors.textDark,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.textGrey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferenceSwitchItem({
    required IconData icon,
    required String title,
    required String statusText,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F4F7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: AppColors.textDark),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textDark,
              ),
            ),
          ),
          Text(
            statusText,
            style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
          ),
          const SizedBox(width: 8),
          Switch(
            value: value,
            activeThumbColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildPreferenceTextItem({
    required IconData icon,
    required String title,
    required String valueText,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F4F7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: AppColors.textDark),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textDark,
              ),
            ),
          ),
          Text(
            valueText,
            style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
          ),
        ],
      ),
    );
  }
}
