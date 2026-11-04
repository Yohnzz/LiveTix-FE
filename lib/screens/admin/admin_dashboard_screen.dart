import 'package:flutter/material.dart';
import '../../models/approval_models.dart';
import '../../services/admin_service.dart';
import '../../services/data_service.dart';
import 'admin_concert_detail_screen.dart';
import 'admin_notification_screen.dart';
import 'admin_producer_detail_screen.dart';
import 'admin_refund_monitoring_screen.dart';
import 'widgets/admin_theme.dart';
import 'widgets/admin_widgets.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = AdminService();
    return ValueListenableBuilder<AdminLoadState>(
      valueListenable: service.loadState,
      builder: (context, state, _) {
        return ListenableBuilder(
          listenable: Listenable.merge([
            service.producersNotifier,
            service.concertsNotifier,
            service.statsNotifier,
            DataService().currentUserNotifier,
          ]),
          builder: (context, _) {
            final user = DataService().currentUser;
            final firstName =
                (user?.name ?? 'Admin').trim().split(RegExp(r'\s+')).first;
            return Column(
              children: [
                AdminHeader(
                  eyebrow: 'Dashboard Utama',
                  title: 'Halo, $firstName',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _NotificationButton(),
                      const SizedBox(width: 8),
                      _HeaderAvatar(initials: user?.initials ?? 'AD'),
                    ],
                  ),
                ),
                Expanded(child: _body(context, service, state)),
              ],
            );
          },
        );
      },
    );
  }

  Widget _body(
      BuildContext context, AdminService service, AdminLoadState state) {
    switch (state) {
      case AdminLoadState.loading:
        return const AdminLoadingState();
      case AdminLoadState.error:
        return AdminMessageState(
          icon: Icons.cloud_off_rounded,
          title: 'Data belum bisa dimuat',
          message: 'Periksa koneksi lalu coba lagi.',
          actionLabel: 'Coba lagi',
          onAction: () => service.load(force: true),
        );
      case AdminLoadState.ready:
        return _ReadyBody(service: service);
    }
  }
}

class _NotificationButton extends StatelessWidget {
  const _NotificationButton();

  @override
  Widget build(BuildContext context) {
    final service = AdminService();
    return ListenableBuilder(
      listenable: service.notificationsNotifier,
      builder: (context, _) {
        final unread = service.unreadNotificationCount;
        return Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.22),
            shape: BoxShape.circle,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AdminNotificationScreen(),
                  ),
                ),
                tooltip: 'Notifikasi',
                padding: EdgeInsets.zero,
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              if (unread > 0)
                Positioned(
                  top: 9,
                  right: 9,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _HeaderAvatar extends StatelessWidget {
  final String initials;

  const _HeaderAvatar({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Akun Super Admin',
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AdminColors.amberAvatar,
          shape: BoxShape.circle,
        ),
        child: ExcludeSemantics(
          child: Text(
            initials,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AdminColors.textDark,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReadyBody extends StatelessWidget {
  final AdminService service;

  const _ReadyBody({required this.service});

  @override
  Widget build(BuildContext context) {
    final stats = service.statsNotifier.value;
    final recent = service.recentPending();
    return RefreshIndicator(
      color: AdminColors.navy,
      onRefresh: () => service.load(force: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Total Pengguna',
                    value: ApprovalFormat.thousands(stats.totalUsers),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Produser Aktif',
                    value: ApprovalFormat.thousands(stats.activeProducers),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Konser Aktif',
                    value: ApprovalFormat.thousands(stats.activeConcerts),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Menunggu Approval',
                    value: ApprovalFormat.thousands(service.pendingTotal),
                    valueColor: AdminColors.magenta,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Akses Cepat ke Monitoring Refund (Image 2)
          AdminCard(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AdminRefundMonitoringScreen(),
                ),
              );
            },
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.currency_exchange_rounded,
                    color: Color(0xFFD97706),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Monitoring Refund',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AdminColors.textDark,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Pantau pengembalian dana konser dibatalkan',
                        style: TextStyle(
                          fontSize: 12,
                          color: AdminColors.textGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AdminColors.textGrey,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const AdminSectionTitle('Approval Terbaru'),
          if (recent.isEmpty)
            const AdminCard(
              child: Text(
                'Tidak ada pengajuan yang menunggu.',
                style: TextStyle(fontSize: 13, color: AdminColors.textGrey),
              ),
            )
          else
            for (final item in recent)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _QueueCard(item: item),
              ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _StatCard({
    required this.label,
    required this.value,
    this.valueColor = AdminColors.textDark,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: AdminCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: AdminColors.textGrey),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: valueColor,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QueueCard extends StatelessWidget {
  final ApprovalQueueItem item;

  const _QueueCard({required this.item});

  void _open(BuildContext context) {
    final Widget screen = item.kind == ApprovalKind.producer
        ? AdminProducerDetailScreen(producerId: item.id)
        : AdminConcertDetailScreen(concertId: item.id);
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      onTap: () => _open(context),
      semanticLabel: '${item.title}, ${item.subtitle}, menunggu',
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const StatusBadge(status: ApprovalStatus.pending),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.subtitle,
                  style: const TextStyle(
                      fontSize: 12, color: AdminColors.textGrey),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AdminColors.textGrey),
        ],
      ),
    );
  }
}
