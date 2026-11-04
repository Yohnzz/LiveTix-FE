import 'package:flutter/material.dart';
import '../../models/approval_models.dart';
import '../../services/admin_service.dart';
import 'admin_concert_detail_screen.dart';
import 'admin_producer_detail_screen.dart';
import 'widgets/admin_theme.dart';
import 'widgets/admin_widgets.dart';

enum _NotificationTab { all, approval, system }

/// Layar Notifikasi Super Admin (Image 3):
/// Aktivitas dan log sistem terbaru dengan filter tab Semua, Approval, dan Sistem.
class AdminNotificationScreen extends StatefulWidget {
  const AdminNotificationScreen({super.key});

  @override
  State<AdminNotificationScreen> createState() =>
      _AdminNotificationScreenState();
}

class _AdminNotificationScreenState extends State<AdminNotificationScreen> {
  final AdminService _service = AdminService();
  _NotificationTab _selectedTab = _NotificationTab.all;

  void _onNotificationTap(AdminNotificationModel notif) {
    _service.markNotificationAsRead(notif.id);

    if (notif.targetKind == ApprovalKind.producer &&
        notif.targetId != null &&
        notif.targetId!.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              AdminProducerDetailScreen(producerId: notif.targetId!),
        ),
      );
    } else if (notif.targetKind == ApprovalKind.concert &&
        notif.targetId != null &&
        notif.targetId!.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AdminConcertDetailScreen(concertId: notif.targetId!),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminScope(
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Column(
          children: [
            AdminHeader(
              title: 'Notifikasi',
              subtitle: 'Aktivitas dan log sistem terbaru',
              onBack: () => Navigator.of(context).pop(),
            ),
            ListenableBuilder(
              listenable: _service.notificationsNotifier,
              builder: (context, _) {
                final list = _service.notificationsNotifier.value;
                final allCount = list.length;

                return AdminTextTabs<_NotificationTab>(
                  items: [
                    AdminTabItem(
                      allCount > 0 ? 'Semua ($allCount)' : 'Semua',
                      _NotificationTab.all,
                    ),
                    const AdminTabItem('Approval', _NotificationTab.approval),
                    const AdminTabItem('Sistem', _NotificationTab.system),
                  ],
                  selected: _selectedTab,
                  onChanged: (tab) => setState(() => _selectedTab = tab),
                );
              },
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: _service.notificationsNotifier,
                builder: (context, _) {
                  final list = _service.notificationsNotifier.value;
                  final filtered = list.where((n) {
                    switch (_selectedTab) {
                      case _NotificationTab.all:
                        return true;
                      case _NotificationTab.approval:
                        return n.category == 'approval';
                      case _NotificationTab.system:
                        return n.category == 'system';
                    }
                  }).toList();

                  if (filtered.isEmpty) {
                    return const AdminMessageState(
                      icon: Icons.notifications_none_rounded,
                      title: 'Tidak ada notifikasi',
                      message: 'Semua aktivitas sistem terbaru akan muncul di sini.',
                    );
                  }

                  return MediaQuery.withClampedTextScaling(
                    maxScaleFactor: 1.35,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final notif = filtered[index];
                        return _buildNotificationCard(notif);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(AdminNotificationModel notif) {
    return AdminCard(
      onTap: () => _onNotificationTap(notif),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.domain_rounded,
              color: Color(0xFF1E3A8A),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        notif.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AdminColors.textDark,
                        ),
                      ),
                    ),
                    if (notif.isUnread) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF2563EB),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  notif.body,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF475467),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  notif.timeAgo,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AdminColors.textGrey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
