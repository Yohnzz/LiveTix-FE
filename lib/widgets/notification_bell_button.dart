import 'package:flutter/material.dart';

import '../models/app_notification_model.dart';
import '../screens/common/notification_center_screen.dart';
import '../services/notification_service.dart';

class NotificationBellButton extends StatelessWidget {
  const NotificationBellButton({
    super.key,
    this.color,
  });

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final service = NotificationService();
    return ValueListenableBuilder<List<AppNotificationModel>>(
      valueListenable: service.notificationsNotifier,
      builder: (context, notifications, _) {
        final unreadCount =
            notifications.where((notification) => notification.isUnread).length;
        return IconButton(
          tooltip: unreadCount == 0
              ? 'Notifikasi'
              : 'Notifikasi, $unreadCount belum dibaca',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const NotificationCenterScreen(),
              ),
            );
          },
          icon: Badge(
            isLabelVisible: unreadCount > 0,
            label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
            child: Icon(Icons.notifications_outlined, color: color),
          ),
        );
      },
    );
  }
}
