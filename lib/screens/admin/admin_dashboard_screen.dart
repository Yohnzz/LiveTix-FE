import 'package:flutter/material.dart';
import '../../models/approval_models.dart';
import '../../services/admin_service.dart';
import '../../services/data_service.dart';
import 'admin_concert_detail_screen.dart';
import 'admin_notification_screen.dart';
import 'admin_producer_detail_screen.dart';
import 'admin_refund_monitoring_screen.dart';
import 'admin_shell.dart';
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
                _DashboardHeader(
                  firstName: firstName,
                  initials: user?.initials ?? 'AD',
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

class _DashboardHeader extends StatelessWidget {
  final String firstName;
  final String initials;

  const _DashboardHeader({
    required this.firstName,
    required this.initials,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: AdminColors.gradient,
          borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3B1478).withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(24)),
          child: Stack(
            children: [
              // Lingkaran dekoratif halus agar tampilan header bernuansa dinamis & tidak kaku
              Positioned(
                top: -35,
                right: -25,
                child: IgnorePointer(
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -40,
                left: 15,
                child: IgnorePointer(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(20, top + 18, 20, 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Status badge pill dengan indikator online aktif
                          Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.22),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF4ADE80),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Flexible(
                                  child: Text(
                                    'Dashboard Utama',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Semantics(
                            header: true,
                            child: Text(
                              'Halo, $firstName',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.3,
                                height: 1.25,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _NotificationButton(),
                        const SizedBox(width: 8),
                        _HeaderAvatar(initials: initials),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.28),
              width: 1,
            ),
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
                  size: 21,
                ),
              ),
              if (unread > 0)
                Positioned(
                  top: 7,
                  right: 7,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 1.5,
                      ),
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
      button: true,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: () => AdminNavigation.tab.value = 3,
          customBorder: const CircleBorder(),
          child: Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AdminColors.amberAvatar,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.9),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ExcludeSemantics(
              child: Text(
                initials,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AdminColors.textDark,
                ),
              ),
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
    final textPri = AdminColors.textPrimaryOf(context);
    final textSec = AdminColors.textSecondaryOf(context);
    final accent = AdminColors.accentOf(context);

    return RefreshIndicator(
      color: accent,
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
                    valueColor: AdminColors.magentaOf(context),
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
                    color: AdminColors.warningBgOf(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.currency_exchange_rounded,
                    color: AdminColors.isDark(context)
                        ? const Color(0xFFFBBF24)
                        : const Color(0xFFD97706),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Monitoring Refund',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: textPri,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Pantau pengembalian dana konser dibatalkan',
                        style: TextStyle(
                          fontSize: 12,
                          color: textSec,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: textSec,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const AdminSectionTitle('Approval Terbaru'),
          if (recent.isEmpty)
            AdminCard(
              child: Text(
                'Tidak ada pengajuan yang menunggu.',
                style: TextStyle(fontSize: 13, color: textSec),
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
  final Color? valueColor;

  const _StatCard({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final textPri = AdminColors.textPrimaryOf(context);
    final textSec = AdminColors.textSecondaryOf(context);
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
              style: TextStyle(fontSize: 12, color: textSec),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: valueColor ?? textPri,
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
    final textPri = AdminColors.textPrimaryOf(context);
    final textSec = AdminColors.textSecondaryOf(context);
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
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: textPri,
                      ),
                    ),
                    const StatusBadge(status: ApprovalStatus.pending),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.subtitle,
                  style: TextStyle(fontSize: 12, color: textSec),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: textSec),
        ],
      ),
    );
  }
}
