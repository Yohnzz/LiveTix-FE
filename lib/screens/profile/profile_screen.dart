import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../models/user_model.dart';
import '../../services/data_service.dart';
import '../../widgets/user_avatar.dart';
import '../auth/login_screen.dart';
import '../promoter/promoter_main_screen.dart';
import 'edit_profile_screen.dart';
import 'refund_payment_method_screen.dart';

class ProfileScreen extends StatefulWidget {
  final bool isGuest;
  final String userName;
  final String userEmail;
  final String userInitials;
  final VoidCallback? onLogout;

  const ProfileScreen({
    super.key,
    this.isGuest = false,
    this.userName = 'Guest',
    this.userEmail = '',
    this.userInitials = 'G',
    this.onLogout,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final DataService _dataService = DataService();
  bool get _isDarkMode => _dataService.isDarkModeNotifier.value;
  late String _displayName;

  @override
  void initState() {
    super.initState();
    _displayName = widget.userName;
    if (!widget.isGuest) {
      _dataService.ensureSessionForLoggedInView(
        name: widget.userName,
        email: widget.userEmail,
      );
    }
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userName != widget.userName) {
      _displayName = widget.userName;
    }
  }

  Color get _bgColor => _isDarkMode ? const Color(0xFF0F172A) : Colors.white;
  Color get _cardColor => _isDarkMode ? const Color(0xFF1E293B) : Colors.white;
  Color get _borderColor => _isDarkMode ? const Color(0xFF334155) : AppColors.border;
  Color get _titleColor => _isDarkMode ? const Color(0xFFF8FAFC) : AppColors.textDark;
  Color get _subtitleColor => _isDarkMode ? const Color(0xFFCBD5E1) : AppColors.textGrey;
  Color get _iconBoxColor => _isDarkMode ? const Color(0xFF334155) : const Color(0xFFF2F4F7);

  void _goToLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _openEditProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(isDarkMode: _isDarkMode),
      ),
    );
  }

  void _showInfoSheet({required String title, required String body}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _titleColor,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                body,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: _subtitleColor,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Tutup'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewTop = MediaQuery.of(context).viewPadding.top;
    final topSpacing = viewTop > 0 ? viewTop + 16 : 38.0;

    if (widget.isGuest) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SingleChildScrollView(
          padding: EdgeInsets.only(left: 20, right: 20, top: topSpacing, bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                'Masuk ke akun untuk mengakses tiket dan pengaturan profil',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textGrey,
                ),
              ),
              const SizedBox(height: 22),

              // Kartu Guest + Tombol Masuk ke Akun saja tanpa menu user terautentikasi
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        GuestAvatarIcon(size: 54),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Guest',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textDark,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Belum masuk akun',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textGrey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
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
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Tampilan lengkap khusus User yang sudah login
    return Scaffold(
      backgroundColor: _bgColor,
      body: SingleChildScrollView(
        padding: EdgeInsets.only(left: 20, right: 20, top: topSpacing, bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Akun',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: _titleColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Kelola profil & preferensimu',
              style: TextStyle(
                fontSize: 13,
                color: _subtitleColor,
              ),
            ),
            const SizedBox(height: 12),
            _buildMenuItem(
              icon: Icons.campaign_outlined,
              title: 'Portal Produser / Pengelola Konser',
              iconColor: AppColors.accent,
              textColor: AppColors.accent,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PromoterMainScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            _buildLoggedInProfileCard(),
            const SizedBox(height: 14),

            _buildStatsCard(),
            const SizedBox(height: 24),

            Text(
              'AKUN',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _subtitleColor,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 8),
            _buildMenuItem(
              icon: Icons.person_outline_rounded,
              title: 'Edit profil',
              onTap: _openEditProfile,
            ),
            _buildMenuItem(
              icon: Icons.credit_card_outlined,
              title: 'Metode pembayaran',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RefundPaymentMethodScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            Text(
              'PREFERENSI',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _subtitleColor,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 8),
            _buildPreferenceSwitchItem(
              icon: Icons.nightlight_round_outlined,
              title: 'Mode tampilan',
              statusText: _isDarkMode ? 'Dark' : 'Light',
              value: _isDarkMode,
              onChanged: (val) {
                _dataService.setDarkMode(val);
                setState(() {});
              },
            ),
            const SizedBox(height: 20),

            Text(
              'LAINNYA',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _subtitleColor,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 8),
            _buildMenuItem(
              icon: Icons.help_outline_rounded,
              title: 'Pusat bantuan',
              onTap: () => _showInfoSheet(
                title: 'Pusat Bantuan LiveTix',
                body: 'Jika mengalami kendala pemesanan e-tiket atau pengembalian dana konser yang dibatalkan, hubungi tim dukungan resmi di support@livetix.id.',
              ),
            ),
            _buildMenuItem(
              icon: Icons.description_outlined,
              title: 'Syarat & ketentuan',
              onTap: () => _showInfoSheet(
                title: 'Syarat & Ketentuan',
                body: '1. Maksimal pembelian 4 tiket per akun dalam satu transaksi.\n2. Satu QR Code tiket berlaku sesuai jumlah tiket yang dibeli (maksimal 4 kali scan di gate) dan dapat dibagikan ke teman.\n3. Pengembalian dana penuh berlaku apabila konser dibatalkan penyelenggara.',
              ),
            ),
            _buildMenuItem(
              icon: Icons.shield_outlined,
              title: 'Kebijakan privasi',
              onTap: () => _showInfoSheet(
                title: 'Kebijakan Privasi',
                body: 'Data nama, email, dan nomor telepon pemesan hanya digunakan untuk penerbitan tiket resmi serta verifikasi identitas di lokasi acara.',
              ),
            ),
            const SizedBox(height: 12),

            _buildMenuItem(
              icon: Icons.logout_rounded,
              title: 'Keluar dari akun',
              iconColor: const Color(0xFFB91C1C),
              textColor: _isDarkMode ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: _cardColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: Text(
                      'Keluar Akun',
                      style: TextStyle(fontWeight: FontWeight.bold, color: _titleColor),
                    ),
                    content: Text(
                      'Apakah kamu yakin ingin keluar dan beralih ke mode tamu?',
                      style: TextStyle(color: _subtitleColor),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text('Batal', style: TextStyle(color: _subtitleColor)),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          widget.onLogout?.call();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFB91C1C),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Keluar'),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildLoggedInProfileCard() {
    return ValueListenableBuilder<UserModel?>(
      valueListenable: _dataService.currentUserNotifier,
      builder: (context, activeUser, _) {
        final effectiveName = activeUser?.name ?? _displayName;
        final effectiveEmail =
            (activeUser?.email.isNotEmpty ?? false) ? activeUser!.email : widget.userEmail;
        final userId = activeUser?.displayId ??
            UserModel.generateSixCharId(
              effectiveEmail.isNotEmpty ? effectiveEmail : effectiveName,
            );
        final initials = activeUser?.initials ??
            (effectiveName.trim().isNotEmpty
                ? effectiveName
                    .trim()
                    .split(RegExp(r'\s+'))
                    .take(2)
                    .map((e) => e[0].toUpperCase())
                    .join()
                : widget.userInitials);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _borderColor),
          ),
          child: Row(
            children: [
              UserAvatar(
                initials: initials,
                imageBytes: activeUser?.profileImageBytes,
                colorIndex: activeUser?.avatarColorIndex ?? -1,
                size: 54,
                fontSize: 16,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      effectiveName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _titleColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ID : $userId',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: _subtitleColor,
                      ),
                    ),
                    if (effectiveEmail.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        effectiveEmail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: _subtitleColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit profil',
                onPressed: _openEditProfile,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                style: IconButton.styleFrom(
                  backgroundColor: _iconBoxColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: _titleColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsCard() {
    final user = _dataService.currentUser;
    final tickets = '${user?.ticketsBought ?? 0}';
    final concerts = '${user?.concertsAttended ?? 0}';
    final reviews = '${user?.reviewsCount ?? 0}';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Expanded(child: _buildStatItem(tickets, 'Tiket dibeli')),
          Container(height: 32, width: 1, color: _borderColor),
          Expanded(child: _buildStatItem(concerts, 'Konser dihadiri')),
          Container(height: 32, width: 1, color: _borderColor),
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
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _titleColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: _subtitleColor,
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _iconBoxColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: iconColor ?? _titleColor,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: textColor ?? _titleColor,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: _subtitleColor,
                ),
              ],
            ),
          ),
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
              color: _iconBoxColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: _titleColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _titleColor,
              ),
            ),
          ),
          Text(
            statusText,
            style: TextStyle(fontSize: 13, color: _subtitleColor),
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
}
