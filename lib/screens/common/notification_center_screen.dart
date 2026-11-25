import 'package:flutter/material.dart';

import '../../models/app_notification_model.dart';
import '../../models/ticket_order_model.dart';
import '../../screens/refund/cancelled_ticket_detail_screen.dart';
import '../../services/data_service.dart';
import '../../services/notification_service.dart';

class NotificationCenterScreen extends StatelessWidget {
  const NotificationCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = NotificationService();
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi'),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                final unread = service.notificationsNotifier.value
                    .where((notification) => notification.isUnread)
                    .toList(growable: false);
                for (final notification in unread) {
                  await service.markAsRead(notification.id);
                }
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Gagal memperbarui notifikasi: $error'),
                    ),
                  );
                }
              }
            },
            child: const Text('Tandai dibaca'),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: service.loadState,
        builder: (context, _) {
          if (service.loadState.value == NotificationLoadState.loading &&
              service.notificationsNotifier.value.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (service.loadState.value == NotificationLoadState.error &&
              service.notificationsNotifier.value.isEmpty) {
            return _MessageState(
              message: 'Notifikasi gagal dimuat.',
              actionLabel: 'Coba lagi',
              onPressed: service.load,
            );
          }

          return RefreshIndicator(
            onRefresh: service.load,
            child: ListenableBuilder(
              listenable: service.notificationsNotifier,
              builder: (context, _) {
                final notifications = service.notificationsNotifier.value;
                if (notifications.isEmpty) {
                  return const _MessageState(
                    message: 'Belum ada notifikasi.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: notifications.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    return _NotificationCard(
                      notification: notification,
                      accentColor: colors.primary,
                      onTap: () => _handleNotificationTap(context, notification),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

Future<void> _handleNotificationTap(
  BuildContext context,
  AppNotificationModel notification,
) async {
  try {
    await NotificationService().markAsRead(notification.id);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memperbarui notifikasi: $error')),
      );
    }
    return;
  }

  // Redirect berdasarkan targetKind dan targetId
  if (notification.targetId == null || notification.targetId!.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notifikasi tidak memiliki target')),
      );
    }
    return;
  }

  // Handle different notification types based on targetKind
  if (notification.targetKind == 'concert') {
    // Notifikasi konser baru - arahkan ke detail konser
    if (!context.mounted) return;
    // TODO: Implementasikan redirect ke ConcertDetailScreen
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fitur detail konser akan segera tersedia')),
      );
    }
    return;
  }

  if (notification.targetKind == 'ticket') {
    // Notifikasi terkait tiket
    if (notification.action == 'payment_expired') {
      // Pembayaran kedaluwarsa - arahkan ke halaman pembayaran
      if (!context.mounted) return;
      // TODO: Implementasikan redirect ke pembayaran gagal screen
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fitur pembayaran akan segera tersedia')),
        );
      }
      return;
    }

    if (notification.action == 'request_refund') {
      // Permintaan refund - arahkan ke detail tiket refund
      final tickets = await _fetchTicketsIfNeeded(context);
      final ticketIndex =
          tickets.indexWhere((ticket) => ticket.id == notification.targetId);
      if (ticketIndex < 0 || !context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CancelledTicketDetailScreen(ticket: tickets[ticketIndex]),
        ),
      );
      return;
    }

    // Notifikasi tiket lainnya - arahkan ke detail tiket
    final tickets = await _fetchTicketsIfNeeded(context);
    final ticketIndex =
        tickets.indexWhere((ticket) => ticket.id == notification.targetId);
    if (ticketIndex < 0 || !context.mounted) return;
    // TODO: Implementasikan redirect ke detail tiket aktif
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fitur detail tiket akan segera tersedia')),
      );
    }
    return;
  }

  if (notification.targetKind == 'producer') {
    // Notifikasi produsen - arahkan ke detail produsen
    if (!context.mounted) return;
    // TODO: Implementasikan redirect ke detail produsen
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fitur detail produsen akan segera tersedia')),
      );
    }
    return;
  }

  // Fallback: tampilkan snack bar dan tidak redirect
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Aksi notifikasi tidak didukung')),
    );
  }
}

Future<List<UserTicketModel>> _fetchTicketsIfNeeded(BuildContext context) async {
  if (!context.mounted) return [];
  await DataService().fetchUserTicketsFromSupabase();
  return DataService().userTicketsNotifier.value;
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.accentColor,
    required this.onTap,
  });

  final AppNotificationModel notification;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                notification.isUnread
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_none_outlined,
                color: notification.isUnread
                    ? accentColor
                    : textColor.withValues(alpha: 0.55),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: TextStyle(
                        fontWeight: notification.isUnread
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(notification.body),
                    const SizedBox(height: 8),
                    Text(
                      notification.timeAgo,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (notification.action == 'request_refund') ...[
                      const SizedBox(height: 8),
                      Text(
                        'Ajukan refund',
                        style: TextStyle(
                          color: accentColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (notification.isUnread)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 6),
                  child: CircleAvatar(
                    radius: 4,
                    backgroundColor: accentColor,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.message,
    this.actionLabel,
    this.onPressed,
  });

  final String message;
  final String? actionLabel;
  final Future<void> Function()? onPressed;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Center(child: Text(message)),
        if (actionLabel != null && onPressed != null)
          Center(
            child: TextButton(
              onPressed: () => onPressed!(),
              child: Text(actionLabel!),
            ),
          ),
      ],
    );
  }
}