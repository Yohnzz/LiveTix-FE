import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_notification_model.dart';
import 'supabase_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } on FirebaseException catch (error) {
    debugPrint('FCM background init gagal: $error');
  }
}

enum NotificationLoadState { idle, loading, ready, error }

class NotificationService {
  NotificationService._();

  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;

  static const String _androidChannelId = 'livetix_notifications';
  static const String _androidChannelName = 'Notifikasi LiveTix';

  final ValueNotifier<List<AppNotificationModel>> notificationsNotifier =
      ValueNotifier<List<AppNotificationModel>>(const []);
  final ValueNotifier<NotificationLoadState> loadState =
      ValueNotifier<NotificationLoadState>(NotificationLoadState.idle);
  final ValueNotifier<String?> loadError = ValueNotifier<String?>(null);

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  RealtimeChannel? _realtimeChannel;
  String? _registeredUserId;
  String? _registeredToken;
  bool _initialized = false;
  bool _firebaseReady = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    if (SupabaseService.isInitialized) {
      _authSubscription =
          SupabaseService.client.auth.onAuthStateChange.listen((state) {
        unawaited(_onAuthChanged(state.session?.user.id));
      });
      await _onAuthChanged(SupabaseService.client.auth.currentUser?.id);
    }

    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      debugPrint('FCM dinonaktifkan: platform ini belum dikonfigurasi.');
      return;
    }

    try {
      await Firebase.initializeApp();
      _firebaseReady = true;
      FirebaseMessaging.onBackgroundMessage(
        firebaseMessagingBackgroundHandler,
      );
      await _initializeLocalNotifications();
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );
      _foregroundSubscription =
          FirebaseMessaging.onMessage.listen(_showForegroundNotification);
      _openedSubscription =
          FirebaseMessaging.onMessageOpenedApp.listen((_) => load());
      final userId = _registeredUserId;
      if (userId != null) await _registerCurrentDevice(userId);
    } on FirebaseException catch (error) {
      debugPrint(
        'FCM belum siap. Tambahkan konfigurasi Firebase platform: $error',
      );
    } catch (error) {
      debugPrint('NotificationService.initialize gagal: $error');
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _localNotifications.initialize(initializationSettings);
    const channel = AndroidNotificationChannel(
      _androidChannelId,
      _androidChannelName,
      description: 'Pemberitahuan transaksi dan aktivitas LiveTix.',
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _onAuthChanged(String? userId) async {
    if (userId == _registeredUserId) {
      if (userId != null) await load();
      return;
    }

    await _removeRealtimeChannel();
    await _removeRegisteredToken();
    _registeredUserId = userId;
    notificationsNotifier.value = const [];

    if (userId == null) {
      loadState.value = NotificationLoadState.ready;
      return;
    }

    await load();
    if (_firebaseReady) await _registerCurrentDevice(userId);
    _startRealtimeSubscription(userId);
  }

  Future<void> _registerCurrentDevice(String userId) async {
    try {
      final messaging = FirebaseMessaging.instance;
      final permission = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (permission.authorizationStatus != AuthorizationStatus.authorized &&
          permission.authorizationStatus != AuthorizationStatus.provisional) {
        debugPrint('Izin notifikasi FCM tidak diberikan oleh pengguna.');
        return;
      }

      if (defaultTargetPlatform == TargetPlatform.android) {
        await _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }

      try {
        _tokenSubscription ??= messaging.onRegistered.listen((token) {
          final currentUserId = _registeredUserId;
          if (currentUserId != null) {
            unawaited(_saveToken(currentUserId, token));
          }
        });
        await messaging.register();
      } catch (registerError) {
        debugPrint('[FCM] register() memerlukan full rebuild APK atau fallback getToken: $registerError');
        // Fallback untuk perangkat atau SDK yang memakai token FCM tradisional
        try {
          // ignore: deprecated_member_use
          final fallbackToken = await messaging.getToken();
          if (fallbackToken != null && fallbackToken.isNotEmpty) {
            unawaited(_saveToken(userId, fallbackToken));
          }
          // ignore: deprecated_member_use
          _tokenSubscription ??= messaging.onTokenRefresh.listen((token) {
            final currentUserId = _registeredUserId;
            if (currentUserId != null) {
              unawaited(_saveToken(currentUserId, token));
            }
          });
        } catch (tokenError) {
          debugPrint('[FCM] Fallback getToken gagal: $tokenError');
        }
      }
    } catch (error) {
      debugPrint('Gagal meminta izin atau mengambil token FCM: $error');
    }
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _tokenSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
    await _removeRealtimeChannel();
    _initialized = false;
  }

  Future<void> _saveToken(String userId, String token) async {
    if (!SupabaseService.isInitialized) return;
    try {
      await SupabaseService.client.from('user_fcm_tokens').upsert(
        {
          'user_id': userId,
          'fcm_token': token,
          'platform':
              defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'fcm_token',
      );
      _registeredToken = token;
      debugPrint('====================================================');
      debugPrint('[FCM] FCM Token perangkat Anda berhasil didapatkan:');
      debugPrint(token);
      debugPrint('====================================================');
    } catch (error) {
      debugPrint('Gagal menyimpan token FCM ke Supabase: $error');
    }
  }

  Future<void> _removeRegisteredToken() async {
    final userId = _registeredUserId;
    final token = _registeredToken;
    if (userId == null || token == null || !SupabaseService.isInitialized) {
      return;
    }
    try {
      await SupabaseService.client
          .from('user_fcm_tokens')
          .delete()
          .eq('user_id', userId)
          .eq('fcm_token', token);
    } catch (error) {
      debugPrint('Gagal melepas token FCM saat logout: $error');
    } finally {
      _registeredToken = null;
    }
  }

  Future<void> unregisterCurrentDevice() async {
    await _removeRegisteredToken();
    await _removeRealtimeChannel();
    if (_firebaseReady) {
      try {
        await FirebaseMessaging.instance.unregister();
      } catch (error) {
        try {
          // ignore: deprecated_member_use
          await FirebaseMessaging.instance.deleteToken();
        } catch (_) {}
      }
    }
    _registeredUserId = null;
    notificationsNotifier.value = const [];
    loadState.value = NotificationLoadState.ready;
  }

  Future<void> load() async {
    if (!SupabaseService.isInitialized) {
      notificationsNotifier.value = const [];
      loadState.value = NotificationLoadState.ready;
      return;
    }

    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      notificationsNotifier.value = const [];
      loadState.value = NotificationLoadState.ready;
      return;
    }

    loadState.value = NotificationLoadState.loading;
    loadError.value = null;
    try {
      final rows = await SupabaseService.client
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(100);
      if (SupabaseService.client.auth.currentUser?.id != userId) return;
      notificationsNotifier.value = rows
          .whereType<Map<String, dynamic>>()
          .where((row) {
            final dedupe = (row['dedupe_key'] ?? '').toString();
            final title = (row['title'] ?? '').toString().toLowerCase();
            final isProducerSaleNotif = dedupe.contains(':paid:producer') ||
                title.contains('tiket konser terjual');
            return !isProducerSaleNotif;
          })
          .map(AppNotificationModel.fromJson)
          .toList(growable: false);
      loadState.value = NotificationLoadState.ready;
    } catch (error) {
      loadError.value = error.toString();
      loadState.value = NotificationLoadState.error;
      debugPrint('Gagal memuat notifikasi Supabase: $error');
    }
  }

  Future<void> markAsRead(String id) async {
    final index =
        notificationsNotifier.value.indexWhere((item) => item.id == id);
    if (index < 0 || !notificationsNotifier.value[index].isUnread) return;

    final previous = notificationsNotifier.value;
    final updated = List<AppNotificationModel>.from(previous);
    updated[index] = updated[index].copyWith(isRead: true);
    notificationsNotifier.value = updated;

    if (!SupabaseService.isInitialized) return;
    try {
      await SupabaseService.client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', id)
          .eq('user_id', SupabaseService.client.auth.currentUser?.id ?? '');
    } catch (error) {
      notificationsNotifier.value = previous;
      debugPrint('Gagal memperbarui status notifikasi: $error');
      rethrow;
    }
  }

  void _startRealtimeSubscription(String userId) {
    if (!SupabaseService.isInitialized) return;
    _realtimeChannel = SupabaseService.client
        .channel('notifications:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          callback: (_) => unawaited(load()),
        )
        .subscribe();
  }

  Future<void> _removeRealtimeChannel() async {
    final channel = _realtimeChannel;
    if (channel == null || !SupabaseService.isInitialized) return;
    _realtimeChannel = null;
    await SupabaseService.client.removeChannel(channel);
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final title =
        message.notification?.title ?? message.data['title']?.toString();
    final body = message.notification?.body ?? message.data['body']?.toString();
    if (title == null || body == null || title.isEmpty || body.isEmpty) return;

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannelId,
          _androidChannelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  // Method untuk menampilkan notifikasi dengan sound kustom (akan digunakan saat file suara siap)
  // Saat file MP3 ditempatkan di android/app/src/main/res/raw/ dan iOS folder,
  // bisa digunakan dengan: sound: RawResourceAndroidNotificationSound('nama_file')
  // Future<void> _showNotificationWithSound(...) async { ... }

  // Method baru untuk notifikasi Customer Service
  // Method baru untuk notifikasi Customer Service
  Future<void> sendCustomerServiceNotification({
    required String message,
  }) async {
    const title = 'Notifikasi Customer Service';
    final body = message;

    try {
      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _androidChannelId,
            _androidChannelName,
            importance: Importance.high,
            priority: Priority.high,
            ), 
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (_) {}

    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId != null && SupabaseService.isInitialized) {
      try {
        await SupabaseService.client.from('notifications').insert({
          'user_id': userId,
          'title': title,
          'body': body,
          'type': 'CUSTOMER_SERVICE',
          'data': {
            'message': message,
          },
          'is_read': false,
        });
        unawaited(load());
      } catch (e) {
        debugPrint('Gagal mencatat notifikasi customer service ke database: $e');
      }
    }
  }

  // Method baru untuk notifikasi konser baru
  Future<void> sendNewConcertNotification({
    required String concertTitle,
  }) async {
    const title = 'Konser Baru Tersedia';
    final body = 'Tersedia konser baru: $concertTitle';

    try {
      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _androidChannelId,
            _androidChannelName,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (_) {}

    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId != null && SupabaseService.isInitialized) {
      try {
        await SupabaseService.client.from('notifications').insert({
          'user_id': userId,
          'title': title,
          'body': body,
          'type': 'NEW_CONCERT',
          'data': {
            'concert_title': concertTitle,
          },
          'is_read': false,
        });
        unawaited(load());
      } catch (e) {
        debugPrint('Gagal mencatat notifikasi konser baru ke database: $e');
      }
    }
  }

  /// Mengirim notifikasi lokal dan menyimpan ke tabel notifications di Supabase
  /// saat ada pesanan pembayaran tiket yang masih berstatus menunggu (pending).
  Future<void> sendPaymentPendingNotification({
    required String orderId,
    required String concertTitle,
    required int amount,
    required DateTime expiresAt,
  }) async {
    final remainingMinutes = expiresAt.difference(DateTime.now()).inMinutes;
    final minsText =
        remainingMinutes > 0 ? '$remainingMinutes menit' : 'beberapa saat';
    const title = 'Selesaikan Pembayaran Tiket!';
    final body =
        'Pesanan tiket $concertTitle masih menunggu pembayaran. Selesaikan sebelum batas waktu berakhir ($minsText).';

    try {
      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _androidChannelId,
            _androidChannelName,
            importance: Importance.high,
            priority: Priority.high,
            sound: RawResourceAndroidNotificationSound('hmmm'),
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (_) {}

    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId != null && SupabaseService.isInitialized) {
      try {
        await SupabaseService.client.from('notifications').insert({
          'user_id': userId,
          'title': title,
          'body': body,
          'type': 'PAYMENT_PENDING',
          'data': {
            'order_id': orderId,
            'concert_title': concertTitle,
            'amount': amount,
            'expires_at': expiresAt.toIso8601String(),
          },
          'is_read': false,
        });
        unawaited(load());
      } catch (e) {
        debugPrint('Gagal mencatat notifikasi pending payment ke database: $e');
      }
    }
  }
}
