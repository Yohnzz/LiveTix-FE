import 'dart:convert';
import 'package:flutter/foundation.dart';
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
    required this.isFromAdmin,
    required this.message,
    required this.createdAt,
  });

  factory CsMessageModel.fromJson(Map<String, dynamic> json) {
    return CsMessageModel(
      id: (json['id'] ?? '').toString(),
      threadId: (json['thread_id'] ?? json['threadId'] ?? '').toString(),
      senderId: (json['sender_id'] ?? json['senderId'] ?? '').toString(),
      senderName: (json['sender_name'] ?? json['senderName'] ?? 'Pengguna')
          .toString(),
      senderEmail:
          (json['sender_email'] ?? json['senderEmail'] ?? '').toString(),
      senderRole:
          (json['sender_role'] ?? json['senderRole'] ?? 'User').toString(),
      isFromAdmin: (json['is_from_admin'] ?? json['isFromAdmin'] ?? false) == true,
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
        'is_from_admin': isFromAdmin,
        'message': message,
        'created_at': createdAt.toIso8601String(),
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
      userId: userId,
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

  CustomerServiceService._internal() {
    _loadInitialThreads();
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
        if (!msg.isFromAdmin) {
          metaByThread[msg.threadId] = {
            'userId': msg.senderId,
            'userName': msg.senderName,
            'userEmail': msg.senderEmail,
            'userRole': msg.senderRole,
          };
        } else {
          metaByThread.putIfAbsent(msg.threadId, () => {
                'userId': (raw['thread_user_id'] ?? msg.senderId).toString(),
                'userName':
                    (raw['thread_user_name'] ?? 'Pengguna LiveTix').toString(),
                'userEmail': (raw['thread_user_email'] ?? '').toString(),
                'userRole': (raw['thread_user_role'] ?? 'User').toString(),
              });
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

    final now = DateTime.now();
    final msg = CsMessageModel(
      id: 'cs-${now.microsecondsSinceEpoch}',
      threadId: target.threadId,
      senderId: isFromAdmin ? 'admin' : target.userId,
      senderName:
          isFromAdmin ? 'Admin LiveTix' : (senderName ?? target.userName),
      senderEmail:
          isFromAdmin ? 'admin@livetix.com' : (senderEmail ?? target.userEmail),
      senderRole: isFromAdmin ? 'Admin' : (senderRole ?? target.userRole),
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
      try {
        await SupabaseService.client.from('cs_messages').upsert(msg.toJson());
      } catch (e) {
        debugPrint('CustomerServiceService.sendMessage Supabase error: $e');
      }
    }
  }
}

