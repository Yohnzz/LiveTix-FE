import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide LocalStorage;

import 'data_service.dart';
import '../utils/local_storage.dart';
import 'promoter_data_service.dart';
import 'supabase_service.dart';

/// Informasi akun Google yang berasal dari sesi Supabase Auth.
class GoogleAccountInfo {
  const GoogleAccountInfo({
    required this.userId,
    required this.googleId,
    required this.name,
    required this.email,
    required this.avatarUrl,
    required this.emailVerified,
  });

  final String userId;
  final String googleId;
  final String name;
  final String email;
  final String? avatarUrl;
  final bool emailVerified;

  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts.isNotEmpty ? parts[0][0].toUpperCase() : 'G';
  }
}

class GoogleProfileSyncResult {
  const GoogleProfileSyncResult({
    required this.success,
    this.account,
    this.needsRoleSelection = false,
    this.errorMessage,
  });

  final bool success;
  final GoogleAccountInfo? account;
  final bool needsRoleSelection;
  final String? errorMessage;
}

class GoogleRoleSelectionResult {
  const GoogleRoleSelectionResult({
    required this.success,
    this.role,
    this.errorMessage,
  });

  final bool success;
  final String? role;
  final String? errorMessage;
}

class GoogleBindResult {
  const GoogleBindResult({
    required this.success,
    this.googleEmail,
    this.errorMessage,
  });

  final bool success;
  final String? googleEmail;
  final String? errorMessage;
}

/// Autentikasi Google melalui Supabase Auth.
///
/// Satu akun Supabase (UUID auth.users) dipakai untuk seluruh alur: login,
/// sinkronisasi profil, pemilihan role, dan verifikasi User/Produser. Tidak ada
/// pembuatan akun terpisah di sisi aplikasi.
class GoogleAuthService {
  GoogleAuthService._();
  static final GoogleAuthService _instance = GoogleAuthService._();
  factory GoogleAuthService() => _instance;

  static const String _mobileRedirectUrl = 'io.livetix.app://login-callback';

  /// Alamat kembali setelah Google mengautentikasi pengguna.
  ///
  /// Web memakai origin aplikasi (Supabase memproses sesi dari URL). Perangkat
  /// native memakai deep link yang harus didaftarkan di Supabase Auth.
  static String get redirectUrl {
    if (dotenv.isInitialized) {
      final fromEnv = dotenv.env['AUTH_REDIRECT_URL'];
      if (fromEnv != null && fromEnv.trim().isNotEmpty) return fromEnv.trim();
    }
    if (kIsWeb) return Uri.base.origin;
    return _mobileRedirectUrl;
  }

  User? get _authUser {
    if (!SupabaseService.isInitialized) return null;
    return SupabaseService.client.auth.currentUser;
  }

  /// Membuka halaman pemilihan akun Google. Di web halaman akan dialihkan
  /// kembali ke aplikasi dan sesi dipulihkan otomatis oleh Supabase.
  Future<void> signInWithGoogle() async {
    if (!SupabaseService.isInitialized) {
      throw const GoogleAuthException(
        'Layanan autentikasi belum siap. Periksa koneksi internet lalu coba lagi.',
      );
    }
    try {
      await SupabaseService.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectUrl,
        authScreenLaunchMode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.inAppBrowserView,
      );
    } on AuthException catch (e) {
      throw GoogleAuthException(_friendlyAuthError(e.message));
    } catch (e) {
      throw GoogleAuthException(
        'Login Google gagal dibuka. Periksa koneksi dan konfigurasi OAuth Supabase. ($e)',
      );
    }
  }

  /// Mengembalikan informasi akun Google dari sesi aktif, atau null bila sesi
  /// bukan berasal dari Google.
  GoogleAccountInfo? currentGoogleAccount() {
    final user = _authUser;
    if (user == null) return null;

    UserIdentity? googleIdentity;
    for (final identity in user.identities ?? const <UserIdentity>[]) {
      if (identity.provider == 'google') {
        googleIdentity = identity;
        break;
      }
    }

    final provider =
        (user.appMetadata['provider'] ?? user.userMetadata?['provider'] ?? '')
            .toString()
            .toLowerCase();
    if (googleIdentity == null && provider != 'google') return null;

    final identityData = googleIdentity?.identityData ?? const {};
    final meta = user.userMetadata ?? const {};
    final email = (identityData['email'] ?? user.email ?? '').toString().trim();
    final googleId = (identityData['sub'] ?? googleIdentity?.identityId ?? '')
        .toString()
        .trim();
    final name = _firstNonEmpty([
      identityData['full_name'],
      identityData['name'],
      meta['full_name'],
      meta['name'],
      email.isNotEmpty ? email.split('@').first : null,
      'Pengguna Google',
    ]);
    final avatarUrl = _firstNonEmpty([
      identityData['avatar_url'],
      identityData['picture'],
      meta['avatar_url'],
      meta['url_foto'],
    ]);
    final emailVerified = identityData['email_verified'] == true ||
        meta['email_verified'] == true ||
        user.emailConfirmedAt != null;

    return GoogleAccountInfo(
      userId: user.id,
      googleId: googleId,
      name: name,
      email: email,
      avatarUrl: avatarUrl,
      emailVerified: emailVerified,
    );
  }

  /// Menyinkronkan akun Google ke `public.profiles` secara idempotent.
  ///
  /// Login dianggap gagal bila profil tidak dapat dipastikan tersimpan, agar
  /// pengguna tidak diarahkan ke dashboard dengan data setengah jadi.
  Future<GoogleProfileSyncResult> syncSessionProfile() async {
    final account = currentGoogleAccount();
    if (account == null) {
      return const GoogleProfileSyncResult(
        success: false,
        errorMessage:
            'Sesi Google tidak ditemukan. Silakan masuk ulang dengan Google.',
      );
    }
    if (account.email.isEmpty) {
      return const GoogleProfileSyncResult(
        success: false,
        errorMessage:
            'Email akun Google tidak tersedia. Sesi tidak dapat disinkronkan.',
      );
    }
    if (!account.emailVerified) {
      return const GoogleProfileSyncResult(
        success: false,
        errorMessage:
            'Email Google belum terverifikasi. Gunakan akun Google dengan email yang sudah diverifikasi.',
      );
    }

    try {
      final existing = await SupabaseService.client
          .from('profiles')
          .select()
          .eq('id', account.userId)
          .maybeSingle();

      // VALIDASI PENTING: Periksa apakah akun Google (email atau googleId) sudah dipakai oleh akun lain di database
      final conflict = await SupabaseService.client
          .from('profiles')
          .select('id, email, google_id')
          .or('email.eq.${account.email},google_id.eq.${account.googleId}')
          .neq('id', account.userId)
          .maybeSingle();

      if (conflict != null) {
        try {
          await SupabaseService.client.auth.signOut();
        } catch (_) {}
        return const GoogleProfileSyncResult(
          success: false,
          errorMessage: 'Akun ini sudah terpakai, silakan gunakan akun lainnya.',
        );
      }

      final existingName = _firstNonEmpty([
        existing?['name'],
        existing?['full_name'],
      ]);
      final existingAvatar = _firstNonEmpty([
        existing?['url_foto'],
        existing?['avatar_url'],
      ]);
      final existingGoogleId = (existing?['google_id'] ?? '').toString().trim();
      final displayName = existingName.isNotEmpty ? existingName : account.name;
      final avatarUrl = existingAvatar.isNotEmpty
          ? existingAvatar
          : (account.avatarUrl ?? '');

      final payload = <String, dynamic>{
        'id': account.userId,
        'email': account.email,
        'name': displayName,
        'full_name': displayName,
        'avatar_url': avatarUrl,
        'google_id':
            account.googleId.isNotEmpty ? account.googleId : existingGoogleId,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (existing == null) {
        payload.addAll({
          'username':
              '${_slug(account.email.split('@').first)}_${account.userId.length >= 6 ? account.userId.substring(0, 6) : account.userId}',
          'role': 'User',
          'is_verified': false,
          'verification_status': 'unverified',
        });
      }

      await _upsertProfile(payload);

      // Pastikan baris profil benar-benar dapat dibaca sebelum lanjut.
      final saved = await SupabaseService.client
          .from('profiles')
          .select('id, role_verification_status')
          .eq('id', account.userId)
          .maybeSingle();
      if (saved == null || saved['id']?.toString() != account.userId) {
        return const GoogleProfileSyncResult(
          success: false,
          errorMessage:
              'Profil Google gagal dipastikan tersimpan. Silakan coba lagi.',
        );
      }

      // Metadata auth bersifat pelengkap; kegagalan di sini tidak membatalkan
      // login karena sumber kebenaran role/verifikasi adalah tabel profiles.
      try {
        await SupabaseService.client.auth.updateUser(
          UserAttributes(data: {
            'name': displayName,
            'full_name': displayName,
            'avatar_url': avatarUrl,
            if (account.googleId.isNotEmpty) 'google_id': account.googleId,
          }),
        );
      } catch (e) {
        debugPrint('GoogleAuthService metadata sync warning: $e');
      }

      await DataService().restoreSupabaseSession(force: true);

      final roleStatus =
          (saved['role_verification_status'] ?? '').toString().trim();
      return GoogleProfileSyncResult(
        success: true,
        account: account,
        needsRoleSelection: roleStatus.isEmpty,
      );
    } on GoogleAuthException catch (e) {
      return GoogleProfileSyncResult(
        success: false,
        errorMessage: e.message,
      );
    } on PostgrestException catch (e) {
      return GoogleProfileSyncResult(
        success: false,
        errorMessage: _friendlyPostgrestError(e),
      );
    } catch (e) {
      return GoogleProfileSyncResult(
        success: false,
        errorMessage:
            'Sinkronisasi profil Google gagal. Periksa koneksi lalu coba lagi. ($e)',
      );
    }
  }

  /// Menyimpan role yang dipilih pengguna. Perubahan role dilakukan oleh
  /// fungsi database `select_google_role` agar client tidak bisa mengganti role
  /// secara sembarangan.
  Future<GoogleRoleSelectionResult> selectRole(String role) async {
    final canonicalRole = switch (role.trim().toLowerCase()) {
      'user' => 'User',
      'produser' || 'producer' || 'promoter' => 'Produser',
      _ => null,
    };
    if (canonicalRole == null) {
      return const GoogleRoleSelectionResult(
        success: false,
        errorMessage: 'Pilih role User atau Produser terlebih dahulu.',
      );
    }

    final account = currentGoogleAccount();
    if (account == null) {
      return const GoogleRoleSelectionResult(
        success: false,
        errorMessage:
            'Sesi Google tidak ditemukan. Silakan masuk ulang dengan Google.',
      );
    }

    try {
      await SupabaseService.client.rpc(
        'select_google_role',
        params: {'p_role': canonicalRole},
      );

      await DataService().restoreSupabaseSession(force: true);
      final user = DataService().currentUser;
      if (user == null) {
        return const GoogleRoleSelectionResult(
          success: false,
          errorMessage:
              'Role tersimpan tetapi profil tidak dapat dimuat. Silakan masuk ulang.',
        );
      }
      if (user.role.trim().toLowerCase() != canonicalRole.toLowerCase() ||
          !user.hasSelectedRole) {
        return const GoogleRoleSelectionResult(
          success: false,
          errorMessage: 'Role belum berhasil tersimpan. Silakan coba lagi.',
        );
      }

      if (canonicalRole == 'Produser') {
        PromoterDataService().verificationStatusNotifier.value = 'unverified';
        PromoterDataService().isPinUnlockedThisSession = false;
        await PromoterDataService().loadProducerProfileFromSupabase(user.id);
      }

      return GoogleRoleSelectionResult(success: true, role: canonicalRole);
    } on PostgrestException catch (e) {
      return GoogleRoleSelectionResult(
        success: false,
        errorMessage: _friendlyPostgrestError(e, roleSelection: true),
      );
    } catch (e) {
      return GoogleRoleSelectionResult(
        success: false,
        errorMessage:
            'Gagal menyimpan role ke database. Periksa koneksi lalu coba lagi. ($e)',
      );
    }
  }

  /// Menautkan (bind) akun Google ke akun yang sedang login (User atau Produser).
  /// Memeriksa apakah akun Google sudah terpakai di database. Jika sudah ada,
  /// mengembalikan: "Akun ini sudah terpakai, silakan gunakan akun lainnya."

  /// Mengembalikan email akun Google yang ditautkan (bukan email pendaftaran manual).
  String? getBoundGoogleEmail() {
    final user = _authUser;
    if (user == null) return null;

    for (final identity in user.identities ?? const <UserIdentity>[]) {
      if (identity.provider == 'google') {
        final email = (identity.identityData?['email'] ?? '').toString().trim();
        if (email.isNotEmpty) return email;
      }
    }
    return null;
  }

  /// Mengembalikan nama akun Google yang ditautkan.
  String? getBoundGoogleName() {
    final user = _authUser;
    if (user == null) return null;

    for (final identity in user.identities ?? const <UserIdentity>[]) {
      if (identity.provider == 'google') {
        final name = _firstNonEmpty([
          identity.identityData?['full_name'],
          identity.identityData?['name'],
        ]);
        if (name.isNotEmpty) return name;
      }
    }
    return null;
  }

  Future<GoogleBindResult> linkGoogleAccount() async {
    if (!SupabaseService.isInitialized) {
      return const GoogleBindResult(
        success: false,
        errorMessage: 'Layanan autentikasi belum siap. Periksa koneksi internet.',
      );
    }
    final currentUser = _authUser;
    if (currentUser == null) {
      return const GoogleBindResult(
        success: false,
        errorMessage: 'Silakan masuk ke akun Anda terlebih dahulu.',
      );
    }

    try {
      final success = await SupabaseService.client.auth.linkIdentity(
        OAuthProvider.google,
        redirectTo: redirectUrl,
        authScreenLaunchMode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.inAppBrowserView,
      );

      if (!success) {
        return const GoogleBindResult(
          success: false,
          errorMessage: 'Proses penautan akun Google dibatalkan.',
        );
      }

      final updatedUser = SupabaseService.client.auth.currentUser;
      UserIdentity? googleIdentity;
      for (final identity in updatedUser?.identities ?? const <UserIdentity>[]) {
        if (identity.provider == 'google') {
          googleIdentity = identity;
          break;
        }
      }

      if (googleIdentity == null) {
        return const GoogleBindResult(
          success: false,
          errorMessage:
              'Identitas Google belum berhasil diperoleh. Silakan coba lagi.',
        );
      }

      final identityData = googleIdentity.identityData ?? const {};
      final googleEmail = (identityData['email'] ?? '').toString().trim();
      final googleId =
          (identityData['sub'] ?? googleIdentity.identityId).toString().trim();

      // VALIDASI: Cek apakah akun Google ini sudah terhubung ke akun LiveTix lain
      final conflict = await SupabaseService.client
          .from('profiles')
          .select('id, email, google_id')
          .or('email.eq.$googleEmail,google_id.eq.$googleId')
          .neq('id', currentUser.id)
          .maybeSingle();

      if (conflict != null) {
        try {
          await SupabaseService.client.auth.unlinkIdentity(googleIdentity);
        } catch (_) {}
        return const GoogleBindResult(
          success: false,
          errorMessage: 'Akun ini sudah terpakai, silakan gunakan akun lainnya.',
        );
      }

      // Update google_id & google_email di tabel profiles
      try {
        await SupabaseService.client.from('profiles').update({
          'google_id': googleId,
          'google_email': googleEmail,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', currentUser.id);
      } catch (_) {
        // Fallback bila kolom google_email belum ada di database
        await SupabaseService.client.from('profiles').update({
          'google_id': googleId,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', currentUser.id);
      }

      // Update langsung state lokal pengguna di memori dan storage
      final current = DataService().currentUser;
      if (current != null) {
        final boundUser = current.copyWith(
          googleId: googleId,
          googleEmail: googleEmail,
        );
        DataService().currentUserNotifier.value = boundUser;
        try {
          LocalStorage.setString(
            LocalStorage.savedUserKey,
            jsonEncode(boundUser.toJson()),
          );
        } catch (_) {}
      }

      await DataService().restoreSupabaseSession(force: true);

      return GoogleBindResult(
        success: true,
        googleEmail:
            googleEmail.isNotEmpty ? googleEmail : 'Akun Google Terhubung',
      );
    } on AuthException catch (e) {
      final lower = e.message.toLowerCase();
      if (lower.contains('already') ||
          lower.contains('exists') ||
          lower.contains('conflict') ||
          lower.contains('assigned')) {
        return const GoogleBindResult(
          success: false,
          errorMessage: 'Akun ini sudah terpakai, silakan gunakan akun lainnya.',
        );
      }
      return GoogleBindResult(
        success: false,
        errorMessage: _friendlyAuthError(e.message),
      );
    } catch (e) {
      final str = e.toString().toLowerCase();
      if (str.contains('already') ||
          str.contains('conflict') ||
          str.contains('terpakai')) {
        return const GoogleBindResult(
          success: false,
          errorMessage: 'Akun ini sudah terpakai, silakan gunakan akun lainnya.',
        );
      }
      return GoogleBindResult(
        success: false,
        errorMessage: 'Gagal menautkan akun Google: $e',
      );
    }
  }

  /// Melepas tautan (unbind) akun Google dari akun yang sedang login.
  Future<GoogleBindResult> unlinkGoogleAccount() async {
    final user = _authUser;
    if (user == null) {
      return const GoogleBindResult(
        success: false,
        errorMessage: 'Sesi akun tidak aktif.',
      );
    }

    UserIdentity? googleIdentity;
    for (final identity in user.identities ?? const <UserIdentity>[]) {
      if (identity.provider == 'google') {
        googleIdentity = identity;
        break;
      }
    }

    try {
      if (googleIdentity != null) {
        await SupabaseService.client.auth.unlinkIdentity(googleIdentity);
      }

      // 1. Kosongkan google_id & google_email pada database profiles
      try {
        await SupabaseService.client.from('profiles').update({
          'google_id': null,
          'google_email': null,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', user.id);
      } catch (_) {
        await SupabaseService.client.from('profiles').update({
          'google_id': null,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', user.id);
      }

      // 2. Bersihkan seketika pada state lokal aplikasi agar UI langsung berubah
      final current = DataService().currentUser;
      if (current != null) {
        final clearedUser = current.copyWith(
          googleId: '',
          googleEmail: '',
        );
        DataService().currentUserNotifier.value = clearedUser;
        try {
          LocalStorage.setString(
            LocalStorage.savedUserKey,
            jsonEncode(clearedUser.toJson()),
          );
        } catch (_) {}
      }

      // 3. Perbarui cache identitas Supabase Auth dari server
      try {
        await SupabaseService.client.auth.getUser();
      } catch (_) {}

      await DataService().restoreSupabaseSession(force: true);

      return const GoogleBindResult(success: true);
    } catch (e) {
      return GoogleBindResult(
        success: false,
        errorMessage: 'Gagal melepas tautan akun Google: $e',
      );
    }
  }

  /// Upsert profil dengan toleransi kolom opsional yang belum dimigrasikan.
  /// Kolom inti Google tidak boleh dilewati karena alur role bergantung padanya.
  Future<void> _upsertProfile(Map<String, dynamic> payload) async {
    final data = Map<String, dynamic>.from(payload);
    for (var attempt = 0; attempt < 10; attempt++) {
      try {
        await SupabaseService.client.from('profiles').upsert(data);
        return;
      } catch (e) {
        final missingColumn =
            RegExp(r"Could not find the '([^']+)' column").firstMatch('$e');
        final column = missingColumn?.group(1);
        if (column == null || !data.containsKey(column) || column == 'id') {
          rethrow;
        }
        if (column == 'google_id' || column == 'role_verification_status') {
          throw GoogleAuthException(
            'Migrasi database Google OAuth belum dijalankan (kolom $column belum tersedia). '
            'Jalankan migration 20261118_google_oauth_and_role_verification.sql lalu coba lagi.',
          );
        }
        data.remove(column);
      }
    }
    throw const GoogleAuthException(
      'Profil Google tidak dapat disimpan karena struktur tabel tidak sesuai.',
    );
  }

  static String _firstNonEmpty(List<Object?> values) {
    for (final value in values) {
      final text = (value ?? '').toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static String _slug(String value) {
    final slug = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return slug.isEmpty ? 'user' : slug;
  }

  static String _friendlyAuthError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('provider is not enabled') ||
        lower.contains('unsupported provider')) {
      return 'Login Google belum diaktifkan di Supabase Auth. Aktifkan provider Google lalu coba lagi.';
    }
    if (lower.contains('redirect') && lower.contains('not allowed')) {
      return 'Alamat callback Google belum diizinkan di Supabase Auth. Periksa Redirect URLs.';
    }
    return 'Login Google gagal: $message';
  }

  static String _friendlyPostgrestError(
    PostgrestException e, {
    bool roleSelection = false,
  }) {
    final message = e.message;
    final lower = message.toLowerCase();
    if (lower.contains('could not find the function') ||
        lower.contains('select_google_role')) {
      return 'Fungsi pemilihan role belum tersedia di database. Jalankan migration Google OAuth terlebih dahulu.';
    }
    if (lower.contains('could not find the') && lower.contains('column')) {
      return 'Struktur tabel profil belum lengkap. Jalankan migration Google OAuth terlebih dahulu. ($message)';
    }
    if (roleSelection) {
      return 'Role tidak dapat disimpan: $message';
    }
    return 'Operasi database gagal: $message';
  }
}

class GoogleAuthException implements Exception {
  const GoogleAuthException(this.message);
  final String message;

  @override
  String toString() => message;
}
