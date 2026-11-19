class AppNotificationModel {
  final String id;
  final String title;
  final String body;
  final String category;
  final String? targetId;
  final String? targetKind;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final bool isRead;

  const AppNotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.createdAt,
    required this.isRead,
    this.data = const {},
    this.targetId,
    this.targetKind,
  });

  bool get isUnread => !isRead;
  String? get action => data['action']?.toString();

  String get timeAgo {
    final elapsed = DateTime.now().difference(createdAt);
    if (elapsed.inMinutes < 1) return 'Baru saja';
    if (elapsed.inHours < 1) return '${elapsed.inMinutes} menit lalu';
    if (elapsed.inDays < 1) return '${elapsed.inHours} jam lalu';
    if (elapsed.inDays < 7) return '${elapsed.inDays} hari lalu';
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }

  factory AppNotificationModel.fromJson(Map<String, dynamic> json) {
    return AppNotificationModel(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      category: (json['category'] ?? 'general').toString(),
      targetId: json['target_id']?.toString(),
      targetKind: json['target_kind']?.toString(),
      data: json['data'] is Map
          ? Map<String, dynamic>.from(json['data'] as Map)
          : const {},
      createdAt:
          DateTime.tryParse((json['created_at'] ?? '').toString())?.toLocal() ??
              DateTime.now(),
      isRead: json['is_read'] == true,
    );
  }

  AppNotificationModel copyWith({bool? isRead}) {
    return AppNotificationModel(
      id: id,
      title: title,
      body: body,
      category: category,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      data: data,
      targetId: targetId,
      targetKind: targetKind,
    );
  }
}
