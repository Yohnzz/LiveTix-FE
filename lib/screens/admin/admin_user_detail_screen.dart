import 'package:flutter/material.dart';
import '../../models/approval_models.dart';
import '../../services/admin_service.dart';
import 'widgets/admin_theme.dart';
import 'widgets/admin_widgets.dart';

/// Layar Detail Pengguna (Image 5): Menampilkan profil, metrik tiket & konser,
/// info akun, status aktif, riwayat transaksi, dan aksi nonaktifkan akun.
class AdminUserDetailScreen extends StatelessWidget {
  final String userId;

  const AdminUserDetailScreen({super.key, required this.userId});

  Future<void> _toggleStatus(BuildContext context, ManagedUserModel user) async {
    final willDeactivate = user.isActive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          willDeactivate ? 'Nonaktifkan Akun?' : 'Aktifkan Akun?',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: Text(
          willDeactivate
              ? 'Pengguna ${user.name} tidak akan dapat login atau bertransaksi selama akun dinonaktifkan.'
              : 'Akun ${user.name} akan diaktifkan kembali.',
          style: const TextStyle(fontSize: 14),
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
              backgroundColor:
                  willDeactivate ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
            ),
            child: Text(willDeactivate ? 'Nonaktifkan' : 'Aktifkan'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      AdminService().toggleUserActive(user.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            willDeactivate
                ? 'Akun ${user.name} berhasil dinonaktifkan'
                : 'Akun ${user.name} berhasil diaktifkan',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = AdminService();
    return AdminScope(
      child: ListenableBuilder(
        listenable: service.usersNotifier,
        builder: (context, _) {
          final user = service.userById(userId);
          return Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            body: Column(
              children: [
                AdminHeader(
                  title: 'Detail Pengguna',
                  onBack: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: user == null
                      ? const AdminMessageState(
                          icon: Icons.person_off_outlined,
                          title: 'Pengguna tidak ditemukan',
                          message: 'Data pengguna ini sudah tidak tersedia.',
                        )
                      : _buildBody(context, user),
                ),
              ],
            ),
            bottomNavigationBar: user != null ? _buildBottomBar(context, user) : null,
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, ManagedUserModel user) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.35,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          // 1. Kartu Profil & Metrik Pengguna
          AdminCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Avatar Bulat Besar
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: _avatarBg(user.role),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    user.initials,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: _avatarTextColor(user.role),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  user.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AdminColors.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _badgeBg(user.role),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    user.role,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _badgeTextColor(user.role),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 16),
                // 3 Kolom Metrik
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            '${user.ticketsBought}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AdminColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Tiket Dibeli',
                            style: TextStyle(
                              fontSize: 12,
                              color: AdminColors.textGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(height: 32, width: 1, color: const Color(0xFFE2E8F0)),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            '${user.concertsAttended}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AdminColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Konser Dihadiri',
                            style: TextStyle(
                              fontSize: 12,
                              color: AdminColors.textGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(height: 32, width: 1, color: const Color(0xFFE2E8F0)),
                    Expanded(
                      child: Column(
                        children: [
                          Icon(
                            user.hasFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 22,
                            color: user.hasFavorite
                                ? const Color(0xFFEC4899)
                                : AdminColors.textGrey,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Favorit',
                            style: TextStyle(
                              fontSize: 12,
                              color: AdminColors.textGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 2. Kartu Informasi Akun
          AdminCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              children: [
                _buildInfoRow('Nomor HP', user.phone),
                const Divider(height: 1, color: AdminColors.border),
                _buildInfoRow('Bergabung Sejak', user.joinedAt),
                const Divider(height: 1, color: AdminColors.border),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 120,
                        child: Text(
                          'Status Akun',
                          style: TextStyle(fontSize: 13, color: AdminColors.textGrey),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: user.isActive
                                  ? const Color(0xFFECFDF5)
                                  : const Color(0xFFFEF2F2),
                              border: Border.all(
                                color: user.isActive
                                    ? const Color(0xFFA7F3D0)
                                    : const Color(0xFFFECACA),
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: user.isActive
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFEF4444),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  user.isActive ? 'Aktif' : 'Nonaktif',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: user.isActive
                                        ? const Color(0xFF059669)
                                        : const Color(0xFFDC2626),
                                  ),
                                ),
                              ],
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

          const SizedBox(height: 20),

          // 3. Riwayat Transaksi
          const AdminSectionTitle('Riwayat Transaksi'),
          if (user.transactions.isEmpty)
            const AdminCard(
              child: Text(
                'Belum ada transaksi.',
                style: TextStyle(fontSize: 13, color: AdminColors.textGrey),
              ),
            )
          else
            ...user.transactions.map(
              (tx) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AdminCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tx.title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AdminColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${tx.invoice} · ${ApprovalFormat.rupiah(tx.amount)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AdminColors.textGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          tx.status,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: AdminColors.textGrey),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AdminColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, ManagedUserModel user) {
    final willDeactivate = user.isActive;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: SizedBox(
          height: 48,
          child: OutlinedButton(
            onPressed: () => _toggleStatus(context, user),
            style: OutlinedButton.styleFrom(
              backgroundColor: willDeactivate
                  ? const Color(0xFFFEE2E2)
                  : const Color(0xFFDCFCE7),
              foregroundColor: willDeactivate
                  ? const Color(0xFFDC2626)
                  : const Color(0xFF16A34A),
              side: BorderSide(
                color: willDeactivate
                    ? const Color(0xFFFECDD3)
                    : const Color(0xFFBBF7D0),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              willDeactivate ? 'Nonaktifkan Akun' : 'Aktifkan Akun',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }

  static Color _avatarBg(String role) {
    switch (role.toLowerCase()) {
      case 'produser':
        return const Color(0xFFF3E8FF);
      case 'admin':
        return const Color(0xFFEFF6FF);
      default:
        return const Color(0xFFEFF6FF);
    }
  }

  static Color _avatarTextColor(String role) {
    switch (role.toLowerCase()) {
      case 'produser':
        return const Color(0xFF7C3AED);
      case 'admin':
        return const Color(0xFF1E3A8A);
      default:
        return const Color(0xFF2563EB);
    }
  }

  static Color _badgeBg(String role) {
    switch (role.toLowerCase()) {
      case 'produser':
        return const Color(0xFFF3E8FF);
      case 'admin':
        return const Color(0xFFEFF6FF);
      default:
        return const Color(0xFFEFF6FF);
    }
  }

  static Color _badgeTextColor(String role) {
    switch (role.toLowerCase()) {
      case 'produser':
        return const Color(0xFF7C3AED);
      case 'admin':
        return const Color(0xFF1E3A8A);
      default:
        return const Color(0xFF2563EB);
    }
  }
}
