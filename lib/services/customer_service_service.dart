import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide LocalStorage;
import '../utils/local_storage.dart';
import 'data_service.dart';
import 'promoter_data_service.dart';
import 'supabase_service.dart';

class CsMessageModel {
  final String id;
  final String threadId;
  final String senderId;
  final String senderName;
  final String senderEmail;
  final String senderRole; // 'Produser' | 'User' | 'Gatecrew' | 'Admin'
  final String receiverId;
  final String receiverName;
  final String receiverRole;
  final bool isFromAdmin;
  final String message;
  final DateTime createdAt;

  const CsMessageModel({
    required this.id,
    required this.threadId,
    required this.senderId,
    required this.senderName,
    required this.senderEmail,
    required this.senderRole,
    this.receiverId = '',
    this.receiverName = '',
    this.receiverRole = '',
    required this.isFromAdmin,
    required this.message,
    required this.createdAt,
  });

  factory CsMessageModel.fromJson(Map<String, dynamic> json) {
    final senderRole =
        (json['sender_role'] ?? json['senderRole'] ?? 'User').toString();
    final isAdmin = (json['is_admin_reply'] ??
                json['is_from_admin'] ??
                json['isFromAdmin']) ==
            true ||
        senderRole.trim().toLowerCase() == 'admin';

    return CsMessageModel(
      id: (json['id'] ?? '').toString(),
      threadId: (json['thread_id'] ?? json['threadId'] ?? '').toString(),
      senderId: (json['sender_id'] ?? json['senderId'] ?? '').toString(),
      senderName: (json['sender_name'] ?? json['senderName'] ?? 'Pengguna')
          .toString(),
      senderEmail:
          (json['sender_email'] ?? json['senderEmail'] ?? '').toString(),
      senderRole: senderRole,
      receiverId:
          (json['receiver_id'] ?? json['receiverId'] ?? '').toString(),
      receiverName:
          (json['receiver_name'] ?? json['receiverName'] ?? '').toString(),
      receiverRole:
          (json['receiver_role'] ?? json['receiverRole'] ?? '').toString(),
      isFromAdmin: isAdmin,
      message: (json['message'] ?? '').toString(),
      createdAt: DateTime.tryParse(
              (json['created_at'] ?? json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'thread_id': threadId,
        'sender_id': senderId,
        'sender_name': senderName,
        'sender_email': senderEmail,
        'sender_role': senderRole,
        'receiver_id': receiverId,
        'receiver_name': receiverName,
        'receiver_role': receiverRole,
        'message': message,
        'created_at': createdAt.toIso8601String(),
        'is_admin_reply': isFromAdmin,
        'is_from_admin': isFromAdmin,
      };
}

class CsThreadModel {
  final String threadId;
  final String userId;
  final String userName;
  final String userEmail;
  final String userRole; // 'Produser' | 'User' | 'Gatecrew'
  final String subject;
  final List<CsMessageModel> messages;
  final DateTime updatedAt;
  final int unreadAdminCount;

  const CsThreadModel({
    required this.threadId,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.userRole,
    required this.subject,
    required this.messages,
    required this.updatedAt,
    this.unreadAdminCount = 0,
  });

  CsMessageModel? get lastMessage =>
      messages.isNotEmpty ? messages.last : null;

  CsThreadModel copyWith({
    String? userId,
    String? userName,
    String? userEmail,
    String? userRole,
    String? subject,
    List<CsMessageModel>? messages,
    DateTime? updatedAt,
    int? unreadAdminCount,
  }) {
    return CsThreadModel(
      threadId: threadId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      userRole: userRole ?? this.userRole,
      subject: subject ?? this.subject,
      messages: messages ?? this.messages,
      updatedAt: updatedAt ?? this.updatedAt,
      unreadAdminCount: unreadAdminCount ?? this.unreadAdminCount,
    );
  }

  factory CsThreadModel.fromJson(Map<String, dynamic> json) {
    final rawMsgs = json['messages'] as List<dynamic>? ?? const [];
    final msgs = rawMsgs
        .whereType<Map<String, dynamic>>()
        .map(CsMessageModel.fromJson)
        .toList();
    return CsThreadModel(
      threadId: (json['thread_id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      userName: (json['user_name'] ?? 'Pengguna').toString(),
      userEmail: (json['user_email'] ?? '').toString(),
      userRole: (json['user_role'] ?? 'User').toString(),
      subject: (json['subject'] ?? 'Bantuan LiveTix').toString(),
      messages: msgs,
      updatedAt:
          DateTime.tryParse((json['updated_at'] ?? '').toString()) ??
              DateTime.now(),
      unreadAdminCount: (json['unread_admin_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'thread_id': threadId,
        'user_id': userId,
        'user_name': userName,
        'user_email': userEmail,
        'user_role': userRole,
        'subject': subject,
        'messages': messages.map((m) => m.toJson()).toList(),
        'updated_at': updatedAt.toIso8601String(),
        'unread_admin_count': unreadAdminCount,
      };
}

class CustomerServiceService extends ChangeNotifier {
  static final CustomerServiceService _instance =
      CustomerServiceService._internal();
  factory CustomerServiceService() => _instance;

  static const String _storageKey = 'livetix_cs_threads_v2';

  final List<CsThreadModel> _threads = [];
  bool _initialized = false;
  RealtimeChannel? _csRealtimeChannel;
  bool _isRealtimeSubscribed = false;

  CustomerServiceService._internal() {
    _loadInitialThreads();
  }

  /// Membuka listener Supabase Realtime pada tabel `cs_messages`.
  void startRealtimeSubscription() {
    if (!SupabaseService.isInitialized || _isRealtimeSubscribed) return;
    _isRealtimeSubscribed = true;
    try {
      _csRealtimeChannel = SupabaseService.client
          .channel('livetix_cs_messages_live')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'cs_messages',
            callback: (payload) {
              final row = payload.newRecord;
              if (row.isNotEmpty) {
                _ingestRealtimeRow(row);
              } else {
                fetchFromSupabase();
              }
            },
          )
          .subscribe();
    } catch (e) {
      _isRealtimeSubscribed = false;
      debugPrint('CustomerServiceService.startRealtimeSubscription error: $e');
    }
  }

  void stopRealtimeSubscription() {
    if (_csRealtimeChannel != null && SupabaseService.isInitialized) {
      SupabaseService.client.removeChannel(_csRealtimeChannel!);
    }
    _csRealtimeChannel = null;
    _isRealtimeSubscribed = false;
  }

  String _normalizeThreadRole(String rawRole, String threadId) {
    final lower = rawRole.trim().toLowerCase();
    final tidLower = threadId.trim().toLowerCase();
    if (lower == 'produser' ||
        lower == 'promoter' ||
        tidLower.startsWith('thread-produser-') ||
        tidLower.startsWith('thread-promoter-')) {
      return 'Produser';
    }
    if (lower == 'gatecrew' || tidLower.startsWith('thread-gatecrew-')) {
      return 'Gatecrew';
    }
    return 'User';
  }

  String _extractEmailFromThreadId(String tid) {
    final lower = tid.toLowerCase();
    for (final prefix in [
      'thread-produser-',
      'thread-promoter-',
      'thread-user-',
      'thread-gatecrew-',
    ]) {
      if (lower.startsWith(prefix)) {
        return tid.substring(prefix.length).trim();
      }
    }
    return '';
  }

  Map<String, String> _extractThreadMeta(
    Map<String, dynamic> raw,
    CsMessageModel msg,
  ) {
    if (!msg.isFromAdmin) {
      final rawRole = (raw['thread_user_role'] ?? msg.senderRole).toString();
      return {
        'userId': msg.senderId.isNotEmpty
            ? msg.senderId
            : (raw['thread_user_id'] ?? msg.senderEmail).toString(),
        'userName': msg.senderName.isNotEmpty
            ? msg.senderName
            : (raw['thread_user_name'] ?? 'Pengguna LiveTix').toString(),
        'userEmail': msg.senderEmail.isNotEmpty
            ? msg.senderEmail
            : (raw['thread_user_email'] ?? _extractEmailFromThreadId(msg.threadId))
                .toString(),
        'userRole': _normalizeThreadRole(rawRole, msg.threadId),
      };
    }

    final fallbackEmail = _extractEmailFromThreadId(msg.threadId);
    final rawThreadRole = (raw['thread_user_role'] ?? msg.receiverRole).toString();
    final resolvedName =
        (raw['thread_user_name'] ?? msg.receiverName).toString().trim();
    final resolvedEmail =
        (raw['thread_user_email'] ?? fallbackEmail).toString().trim();
    final resolvedId =
        (raw['thread_user_id'] ?? msg.receiverId).toString().trim();

    return {
      'userId': resolvedId.isNotEmpty
          ? resolvedId
          : (resolvedEmail.isNotEmpty ? resolvedEmail : msg.threadId),
      'userName': resolvedName.isNotEmpty
          ? resolvedName
          : (resolvedEmail.isNotEmpty ? resolvedEmail : 'Pengguna LiveTix'),
      'userEmail': resolvedEmail,
      'userRole': _normalizeThreadRole(rawThreadRole, msg.threadId),
    };
  }

  void _ingestRealtimeRow(Map<String, dynamic> raw) {
    final msg = CsMessageModel.fromJson(raw);
    if (msg.id.isEmpty || msg.threadId.isEmpty) return;

    final meta = _extractThreadMeta(raw, msg);
    final existingIdx = _threads.indexWhere((t) => t.threadId == msg.threadId);

    if (existingIdx != -1) {
      final existing = _threads[existingIdx];
      final alreadyExists = existing.messages.any((m) => m.id == msg.id);
      final updatedMessages = alreadyExists
          ? existing.messages.map((m) => m.id == msg.id ? msg : m).toList()
          : ([...existing.messages, msg]
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt)));
      final nextUnread = msg.isFromAdmin
          ? 0
          : (alreadyExists
              ? existing.unreadAdminCount
              : existing.unreadAdminCount + 1);
      _threads[existingIdx] = existing.copyWith(
        userId: existing.userId.isEmpty ? meta['userId'] : existing.userId,
        userName: !msg.isFromAdmin && meta['userName']!.isNotEmpty
            ? meta['userName']
            : existing.userName,
        userEmail: !msg.isFromAdmin && meta['userEmail']!.isNotEmpty
            ? meta['userEmail']
            : existing.userEmail,
        userRole: _normalizeThreadRole(
          meta['userRole']?.isNotEmpty == true
              ? meta['userRole']!
              : existing.userRole,
          msg.threadId,
        ),
        messages: updatedMessages,
        updatedAt: updatedMessages.isNotEmpty
            ? updatedMessages.last.createdAt
            : existing.updatedAt,
        unreadAdminCount: nextUnread,
      );
    } else {
      final role = meta['userRole'] ?? 'User';
      _threads.insert(
        0,
        CsThreadModel(
          threadId: msg.threadId,
          userId: meta['userId'] ?? msg.threadId,
          userName: meta['userName'] ?? 'Pengguna LiveTix',
          userEmail: meta['userEmail'] ?? '',
          userRole: role,
          subject: role == 'Produser'
              ? 'Bantuan Produser & Event'
              : 'Bantuan Pengguna LiveTix',
          messages: [msg],
          updatedAt: msg.createdAt,
          unreadAdminCount: msg.isFromAdmin ? 0 : 1,
        ),
      );
    }

    _threads.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    _persistThreads();
    notifyListeners();
  }

  List<CsThreadModel> get threads => List.unmodifiable(_threads);

  List<CsThreadModel> threadsByRole(String roleFilter) {
    final normalized = roleFilter.trim().toLowerCase();
    final filtered = _threads.where((t) {
      final r = t.userRole.toLowerCase();
      if (normalized == 'produser' || normalized == 'promoter') {
        return r == 'produser' || r == 'promoter';
      }
      if (normalized == 'user') {
        return r == 'user' || r == 'gatecrew';
      }
      return true;
    }).toList();
    filtered.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return filtered;
  }

  int unreadCountForRole(String roleFilter) {
    return threadsByRole(roleFilter)
        .fold<int>(0, (sum, t) => sum + t.unreadAdminCount);
  }

  int get totalUnreadAdminCount =>
      _threads.fold<int>(0, (sum, t) => sum + t.unreadAdminCount);

  void _loadInitialThreads() {
    if (_initialized) return;
    _initialized = true;

    final saved = LocalStorage.getItem(_storageKey);
    if (saved != null && saved.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(saved) as List<dynamic>;
        _threads
          ..clear()
          ..addAll(
            decoded
                .whereType<Map<String, dynamic>>()
                .map(CsThreadModel.fromJson),
          );
      } catch (_) {}
    }

    if (_threads.isEmpty) {
      final now = DateTime.now();
      _threads.addAll([
        CsThreadModel(
          threadId: 'thread-produser-produser@livetix.com',
          userId: 'b0000000-0000-0000-0000-000000000002',
          userName: 'Soundwave Entertainment',
          userEmail: 'produser@livetix.com',
          userRole: 'Produser',
          subject: 'Verifikasi Konser & Dokumen Legalitas',
          updatedAt: now.subtract(const Duration(minutes: 15)),
          unreadAdminCount: 1,
          messages: [
            CsMessageModel(
              id: 'msg-init-1',
              threadId: 'thread-produser-produser@livetix.com',
              senderId: 'admin',
              senderName: 'Tim Support LiveTix',
              senderEmail: 'admin@livetix.com',
              senderRole: 'Admin',
              isFromAdmin: true,
              message:
                  'Halo Soundwave Entertainment! Ada yang bisa kami bantu terkait pengajuan konser atau pencairan dana?',
              createdAt: now.subtract(const Duration(minutes: 25)),
            ),
            CsMessageModel(
              id: 'msg-init-2',
              threadId: 'thread-produser-produser@livetix.com',
              senderId: 'b0000000-0000-0000-0000-000000000002',
              senderName: 'Soundwave Entertainment',
              senderEmail: 'produser@livetix.com',
              senderRole: 'Produser',
              isFromAdmin: false,
              message:
                  'Halo Admin, mohon bantuannya untuk pengecekan dokumen pengajuan konser terbaru kami.',
              createdAt: now.subtract(const Duration(minutes: 15)),
            ),
          ],
        ),
        CsThreadModel(
          threadId: 'thread-user-user@livetix.com',
          userId: 'c0000000-0000-0000-0000-000000000003',
          userName: 'Budi Santoso',
          userEmail: 'user@livetix.com',
          userRole: 'User',
          subject: 'Pertanyaan Pembelian E-Tiket',
          updatedAt: now.subtract(const Duration(hours: 1)),
          unreadAdminCount: 1,
          messages: [
            CsMessageModel(
              id: 'msg-init-3',
              threadId: 'thread-user-user@livetix.com',
              senderId: 'admin',
              senderName: 'Tim Support LiveTix',
              senderEmail: 'admin@livetix.com',
              senderRole: 'Admin',
              isFromAdmin: true,
              message:
                  'Halo! Selamat datang di Layanan Bantuan LiveTix. Silakan sampaikan kendala tiket Anda.',
              createdAt: now.subtract(const Duration(hours: 1, minutes: 10)),
            ),
            CsMessageModel(
              id: 'msg-init-4',
              threadId: 'thread-user-user@livetix.com',
              senderId: 'c0000000-0000-0000-0000-000000000003',
              senderName: 'Budi Santoso',
              senderEmail: 'user@livetix.com',
              senderRole: 'User',
              isFromAdmin: false,
              message:
                  'Halo kak, apakah e-tiket VIP saya bisa langsung di-scan di Gate A saat hari konser?',
              createdAt: now.subtract(const Duration(hours: 1)),
            ),
          ],
        ),
      ]);
      _persistThreads();
    }

    if (SupabaseService.isInitialized) {
      fetchFromSupabase();
    }
  }

  void _persistThreads() {
    try {
      LocalStorage.setItem(
        _storageKey,
        jsonEncode(_threads.map((t) => t.toJson()).toList()),
      );
    } catch (_) {}
  }

  Future<void> fetchFromSupabase() async {
    if (!SupabaseService.isInitialized) return;
    startRealtimeSubscription();
    try {
      final rows = await SupabaseService.client
          .from('cs_messages')
          .select()
          .order('created_at', ascending: true);

      if (rows.isEmpty) return;

      final Map<String, List<CsMessageModel>> grouped = {};
      final Map<String, Map<String, String>> metaByThread = {};

      for (final raw in rows) {
        final msg = CsMessageModel.fromJson(raw);
        if (msg.threadId.isEmpty) continue;
        grouped.putIfAbsent(msg.threadId, () => []).add(msg);
        final extracted = _extractThreadMeta(raw, msg);
        if (!msg.isFromAdmin) {
          metaByThread[msg.threadId] = extracted;
        } else {
          metaByThread.putIfAbsent(msg.threadId, () => extracted);
        }
      }

      for (final entry in grouped.entries) {
        final tid = entry.key;
        final msgs = entry.value;
        final meta = metaByThread[tid] ?? const {};
        final existingIdx = _threads.indexWhere((t) => t.threadId == tid);
        final unreadCount = msgs.isNotEmpty && !msgs.last.isFromAdmin ? 1 : 0;

        if (existingIdx != -1) {
          final existing = _threads[existingIdx];
          // Merge messages by id
          final mergedMap = <String, CsMessageModel>{
            for (final m in existing.messages) m.id: m,
            for (final m in msgs) m.id: m,
          };
          final mergedList = mergedMap.values.toList()
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
          _threads[existingIdx] = existing.copyWith(
            userName: meta['userName']?.isNotEmpty == true
                ? meta['userName']
                : existing.userName,
            userEmail: meta['userEmail']?.isNotEmpty == true
                ? meta['userEmail']
                : existing.userEmail,
            userRole: meta['userRole']?.isNotEmpty == true
                ? meta['userRole']
                : existing.userRole,
            messages: mergedList,
            updatedAt: mergedList.isNotEmpty
                ? mergedList.last.createdAt
                : existing.updatedAt,
            unreadAdminCount: unreadCount,
          );
        } else {
          _threads.add(
            CsThreadModel(
              threadId: tid,
              userId: meta['userId'] ?? tid,
              userName: meta['userName'] ?? 'Pengguna LiveTix',
              userEmail: meta['userEmail'] ?? '',
              userRole: meta['userRole'] ?? 'User',
              subject: (meta['userRole'] == 'Produser')
                  ? 'Bantuan Produser & Event'
                  : 'Bantuan Pengguna LiveTix',
              messages: msgs,
              updatedAt:
                  msgs.isNotEmpty ? msgs.last.createdAt : DateTime.now(),
              unreadAdminCount: unreadCount,
            ),
          );
        }
      }

      _persistThreads();
      notifyListeners();
    } catch (e) {
      debugPrint('CustomerServiceService.fetchFromSupabase error: $e');
    }
  }

  /// Mendapatkan atau membuat thread untuk akun yang sedang login (User / Produser / Gatecrew).
  CsThreadModel ensureThreadForAccount({
    String? accountId,
    String? accountName,
    String? accountEmail,
    required String role, // 'Produser' | 'User' | 'Gatecrew'
    String? initialTopic,
  }) {
    final currentUser = DataService().currentUser;
    final resolvedRole = role.trim().isEmpty ? 'User' : role.trim();
    final isProducer = resolvedRole.toLowerCase() == 'produser' ||
        resolvedRole.toLowerCase() == 'promoter';

    final resolvedEmail = (accountEmail?.trim().isNotEmpty == true)
        ? accountEmail!.trim().toLowerCase()
        : (currentUser?.email.trim().isNotEmpty == true
            ? currentUser!.email.trim().toLowerCase()
            : (isProducer ? 'produser@livetix.com' : 'user@livetix.com'));

    final resolvedName = (accountName?.trim().isNotEmpty == true)
        ? accountName!.trim()
        : (isProducer
            ? PromoterDataService().promoterName
            : (currentUser?.name.trim().isNotEmpty == true
                ? currentUser!.name.trim()
                : 'Pengguna LiveTix'));

    final resolvedId = (accountId?.trim().isNotEmpty == true)
        ? accountId!.trim()
        : (currentUser?.id.trim().isNotEmpty == true
            ? currentUser!.id.trim()
            : resolvedEmail);

    final threadId =
        'thread-${isProducer ? 'produser' : 'user'}-$resolvedEmail';

    final existingIdx = _threads.indexWhere((t) => t.threadId == threadId);
    if (existingIdx != -1) {
      final updated = _threads[existingIdx].copyWith(
        userName: resolvedName,
        userEmail: resolvedEmail,
        userRole: isProducer ? 'Produser' : 'User',
        subject: initialTopic ?? _threads[existingIdx].subject,
      );
      _threads[existingIdx] = updated;
      return updated;
    }

    final now = DateTime.now();
    final welcomeMsg = CsMessageModel(
      id: 'msg-welcome-${now.millisecondsSinceEpoch}',
      threadId: threadId,
      senderId: 'admin',
      senderName: 'Tim Support LiveTix',
      senderEmail: 'admin@livetix.com',
      senderRole: 'Admin',
      isFromAdmin: true,
      message: isProducer
          ? 'Halo $resolvedName! Selamat datang di Layanan Customer Service Produser LiveTix. Silakan tulis pertanyaan atau kendala Anda, Admin kami akan segera membalas di sini.'
          : 'Halo $resolvedName! Selamat datang di Layanan Customer Service LiveTix. Ada yang bisa kami bantu hari ini?',
      createdAt: now,
    );

    final newThread = CsThreadModel(
      threadId: threadId,
      userId: resolvedId,
      userName: resolvedName,
      userEmail: resolvedEmail,
      userRole: isProducer ? 'Produser' : 'User',
      subject: initialTopic ??
          (isProducer ? 'Bantuan Produser & Event' : 'Bantuan Pengguna LiveTix'),
      messages: [welcomeMsg],
      updatedAt: now,
      unreadAdminCount: 0,
    );

    _threads.insert(0, newThread);
    _persistThreads();
    notifyListeners();
    return newThread;
  }

  CsThreadModel? getThreadById(String threadId) {
    for (final t in _threads) {
      if (t.threadId == threadId) return t;
    }
    return null;
  }

  void markThreadReadByAdmin(String threadId) {
    final idx = _threads.indexWhere((t) => t.threadId == threadId);
    if (idx == -1) return;
    if (_threads[idx].unreadAdminCount == 0) return;
    _threads[idx] = _threads[idx].copyWith(unreadAdminCount: 0);
    _persistThreads();
    notifyListeners();
  }

  Future<void> sendMessage({
    required String threadId,
    required String text,
    required bool isFromAdmin,
    String? senderName,
    String? senderEmail,
    String? senderRole,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final idx = _threads.indexWhere((t) => t.threadId == threadId);
    CsThreadModel target;
    if (idx == -1) {
      target = ensureThreadForAccount(
        accountName: senderName,
        accountEmail: senderEmail,
        role: senderRole ?? 'User',
      );
    } else {
      target = _threads[idx];
    }

    final currentUser = DataService().currentUser;
    final now = DateTime.now();
    final msg = CsMessageModel(
      id: 'cs-${now.microsecondsSinceEpoch}',
      threadId: target.threadId,
      senderId: isFromAdmin
          ? (currentUser?.id.trim().isNotEmpty == true
              ? currentUser!.id.trim()
              : 'admin')
          : target.userId,
      senderName: isFromAdmin
          ? (senderName?.trim().isNotEmpty == true
              ? senderName!.trim()
              : (currentUser?.name.trim().isNotEmpty == true
                  ? currentUser!.name.trim()
                  : 'Admin LiveTix'))
          : (senderName ?? target.userName),
      senderEmail: isFromAdmin
          ? (senderEmail?.trim().isNotEmpty == true
              ? senderEmail!.trim()
              : (currentUser?.email.trim().isNotEmpty == true
                  ? currentUser!.email.trim()
                  : 'admin@livetix.com'))
          : (senderEmail ?? target.userEmail),
      senderRole: isFromAdmin ? 'Admin' : (senderRole ?? target.userRole),
      receiverId: isFromAdmin ? target.userId : 'admin',
      receiverName: isFromAdmin ? target.userName : 'Admin LiveTix',
      receiverRole: isFromAdmin ? target.userRole : 'Admin',
      isFromAdmin: isFromAdmin,
      message: trimmed,
      createdAt: now,
    );

    final updatedMessages = [...target.messages, msg];
    final updatedThread = target.copyWith(
      messages: updatedMessages,
      updatedAt: now,
      unreadAdminCount: isFromAdmin ? 0 : target.unreadAdminCount + 1,
    );

    final finalIdx =
        _threads.indexWhere((t) => t.threadId == updatedThread.threadId);
    if (finalIdx != -1) {
      _threads[finalIdx] = updatedThread;
    } else {
      _threads.insert(0, updatedThread);
    }

    _persistThreads();
    notifyListeners();

    if (SupabaseService.isInitialized) {
      startRealtimeSubscription();
      final corePayload = <String, dynamic>{
        'id': msg.id,
        'thread_id': msg.threadId,
        'sender_name': msg.senderName,
        'sender_email': msg.senderEmail,
        'sender_role': msg.senderRole,
        'message': msg.message,
        'is_admin_reply': msg.isFromAdmin,
        'created_at': msg.createdAt.toIso8601String(),
      };
      final richPayload = <String, dynamic>{
        ...corePayload,
        'is_from_admin': msg.isFromAdmin,
        'sender_id': msg.senderId,
        'receiver_id': msg.receiverId,
        'receiver_name': msg.receiverName,
        'receiver_role': msg.receiverRole,
        'thread_user_id': target.userId,
        'thread_user_name': target.userName,
        'thread_user_email': target.userEmail,
        'thread_user_role': target.userRole,
      };
      await _upsertCsMessageWithFallback(richPayload, corePayload);
    }
  }

  Future<void> _upsertCsMessageWithFallback(
    Map<String, dynamic> richPayload,
    Map<String, dynamic> corePayload,
  ) async {
    final mutable = Map<String, dynamic>.from(richPayload);
    // Coba kirim payload lengkap; jika schema DB belum termigrasi (PGRST204),
    // buang kolom yang belum dikenal satu per satu lalu fallback ke payload inti.
    for (int attempt = 0; attempt < 8; attempt++) {
      try {
        await SupabaseService.client.from('cs_messages').upsert(mutable);
        return;
      } on PostgrestException catch (e) {
        if (e.code == 'PGRST204' ||
            e.message.toLowerCase().contains('schema cache')) {
          final match = RegExp(r"'([a-zA-Z0-9_]+)' column").firstMatch(e.message);
          final missingCol = match?.group(1);
          if (missingCol != null &&
              mutable.containsKey(missingCol) &&
              !corePayload.containsKey(missingCol)) {
            mutable.remove(missingCol);
            continue;
          }
          break;
        }
        debugPrint('CustomerServiceService.sendMessage Supabase error: $e');
        return;
      } catch (e) {
        debugPrint('CustomerServiceService.sendMessage Supabase error: $e');
        return;
      }
    }

    try {
      await SupabaseService.client.from('cs_messages').upsert(corePayload);
    } catch (e) {
      debugPrint('CustomerServiceService.sendMessage fallback error: $e');
    }
  }
}

