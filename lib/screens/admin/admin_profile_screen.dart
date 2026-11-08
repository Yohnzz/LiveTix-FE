import 'package:flutter/material.dart';
import '../../models/approval_models.dart';
import '../../services/admin_service.dart';
import '../../services/customer_service_service.dart';
import '../../services/data_service.dart';
import '../home/home_screen.dart';
import '../promoter/producer_customer_service_screen.dart';
import 'admin_notification_screen.dart';
import 'admin_shell.dart';
import 'widgets/admin_theme.dart';
import 'widgets/admin_widgets.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
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

  @override
  Widget build(BuildContext context) {
    final adminService = AdminService();
    final csService = CustomerServiceService();

    return ListenableBuilder(
      listenable: Listenable.merge([
        DataService().currentUserNotifier,
        DataService().isDarkModeNotifier,
        adminService.producersNotifier,
        adminService.concertsNotifier,
        adminService.notificationsNotifier,
        csService,
      ]),
      builder: (context, _) {
        final user = DataService().currentUser;
        final email = (user?.email.isNotEmpty == true)
            ? user!.email
            : 'admin@livetix.com';
        final name =
            (user?.name.isNotEmpty == true) ? user!.name : 'Super Admin';
        final initials = ApprovalFormat.initialsOf(name);
        final isDark = DataService().isDarkModeNotifier.value;

        final approvedProducers = adminService.producersNotifier.value
            .where((p) => p.approvalStatus == ApprovalStatus.approved)
            .length;
        final approvedConcerts = adminService.concertsNotifier.value
            .where((c) => c.approvalStatus == ApprovalStatus.approved)
            .length;
        final totalApproved = approvedProducers + approvedConcerts;
        final pendingTotal = adminService.pendingTotal;
        final unreadNotif = adminService.unreadNotificationCount;
        final unreadCs = csService.totalUnreadAdminCount;

        final textSec = AdminColors.textSecondaryOf(context);
        final border = AdminColors.borderOf(context);
        final accent = AdminColors.accentOf(context);

        return MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.35,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              // 1. Header seragam dengan Beranda Admin
              AdminHeader(
                eyebrow: 'ADMINISTRATOR UTAMA',
                title: name,
                subtitle: email,
                trailing: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.28),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 2. Kartu Ringkasan Approval Admin
                    Row(
                      children: [
                        Expanded(
                          child: AdminCard(
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 14,
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '$pendingTotal',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: accent,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Antrean Menunggu',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: textSec,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AdminCard(
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 14,
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '$totalApproved',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF15803D),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Total Disetujui',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: textSec,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // 3. Grup PENGATURAN & LAYANAN (Hanya Notifikasi, Tema, dan Customer Service)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 10),
                      child: Text(
                        'PENGATURAN & LAYANAN',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: textSec,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    AdminCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          // Menu 1: Notifikasi
                          _ProfileMenuRow(
                            icon: Icons.notifications_outlined,
                            iconBgColor: const Color(0xFFFEF3C7),
                            iconColor: const Color(0xFFD97706),
                            title: 'Notifikasi',
                            subtitle: unreadNotif > 0
                                ? '$unreadNotif notifikasi belum dibaca'
                                : 'Pantau pengajuan produser, konser, dan gatecrew',
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (unreadNotif > 0)
                                  Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEF4444),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      '$unreadNotif',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: textSec,
                                  size: 20,
                                ),
                              ],
                            ),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      const AdminNotificationScreen(),
                                ),
                              );
                            },
                          ),
                          Divider(height: 1, color: border),

                          // Menu 2: Mode Tampilan / Tema (Langsung bekerja mengubah tema seluruh aplikasi & Admin)
                          _ProfileMenuRow(
                            icon: isDark
                                ? Icons.dark_mode_rounded
                                : Icons.light_mode_rounded,
                            iconBgColor: const Color(0xFFF3E8FF),
                            iconColor: const Color(0xFF7C3AED),
                            title: 'Mode Tampilan',
                            subtitle: isDark ? 'Tema Gelap Aktif' : 'Tema Terang Aktif',
                            trailing: Switch(
                              key: const Key('admin_theme_switch'),
                              value: isDark,
                              activeThumbColor: Colors.white,
                              activeTrackColor: accent,
                              onChanged: (val) {
                                DataService().setDarkMode(val);
                                ScaffoldMessenger.of(context)
                                  ..hideCurrentSnackBar()
                                  ..showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        val
                                            ? 'Mode tampilan diubah ke Tema Gelap'
                                            : 'Mode tampilan diubah ke Tema Terang',
                                      ),
                                      duration: const Duration(seconds: 1),
                                    ),
                                  );
                              },
                            ),
                            onTap: () {
                              final next = !isDark;
                              DataService().setDarkMode(next);
                            },
                          ),
                          Divider(height: 1, color: border),

                          // Menu 3: Customer Service (Pengelompokan Chat Produser & User)
                          _ProfileMenuRow(
                            icon: Icons.support_agent_rounded,
                            iconBgColor: const Color(0xFFDBEAFE),
                            iconColor: const Color(0xFF1D4ED8),
                            title: 'Customer Service',
                            subtitle:
                                'Kelola pesan masuk dari Produser dan User',
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (unreadCs > 0)
                                  Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEF4444),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      '$unreadCs baru',
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: textSec,
                                  size: 20,
                                ),
                              ],
                            ),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      const ProducerCustomerServiceScreen(
                                    isAdminInbox: true,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 4. Tombol Keluar dari Akun
                    AdminCard(
                      onTap: () => _logout(context),
                      borderColor: const Color(0xFFFECACA),
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 16,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.logout_rounded,
                            color: AdminColors.danger,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Keluar dari akun',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? const Color(0xFFF87171)
                                  : AdminColors.danger,
                            ),
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
}

class _ProfileMenuRow extends StatelessWidget {
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  const _ProfileMenuRow({
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textPri = AdminColors.textPrimaryOf(context);
    final textSec = AdminColors.textSecondaryOf(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: textPri,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        color: textSec,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
