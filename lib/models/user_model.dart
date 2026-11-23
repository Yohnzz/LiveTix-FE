import 'dart:convert';
import 'dart:typed_data';

import '../core/account_status.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String password;
  final String role; // 'User' | 'Produser' | 'Admin'
  final int ticketsBought;
  final int concertsAttended;
  final int reviewsCount;
  final Uint8List? profileImageBytes;
  final String? avatarUrl;
  final int avatarColorIndex;
  final bool hasAcceptedAgreement;
  final String nik;
  final bool isVerified;
  final AccountStatus accountStatus;
  final String? deactivationReason;

  /// ID identitas Google (provider_id/sub). Kosong untuk akun non-Google.
  final String googleId;

  /// Email akun Google yang tertaut (bisa berbeda dari email pendaftaran manual).
  final String googleEmail;

  /// Status persetujuan role: kosong = role belum dipilih, `pending`,
  /// `approved`, atau `rejected`.
  final String roleVerificationStatus;

  /// Akun yang dinonaktifkan/ditolak tidak boleh memakai fitur apa pun.
  bool get isBlocked => accountStatus.isBlocked;

  /// Akun yang masuk melalui Google OAuth.
  bool get isGoogleAccount => googleId.trim().isNotEmpty;

  /// Pengguna sudah menentukan role User/Produser (bukan dugaan otomatis).
  bool get hasSelectedRole => roleVerificationStatus.trim().isNotEmpty;

  bool get isIdentityVerified {
    final normalizedRole = role.trim().toLowerCase();
    if (normalizedRole == 'user') {
      final cleanNik = nik.replaceAll(RegExp(r'[^0-9]'), '');
      return isVerified && cleanNik.length >= 16 && name.trim().isNotEmpty;
    }
    return isVerified;
  }

  const UserModel({
    this.id = '123456',
    required this.name,
    required this.email,
    required this.phone,
    required this.password,
    this.role = 'User',
    this.ticketsBought = 12,
    this.concertsAttended = 9,
    this.reviewsCount = 4,
    this.profileImageBytes,
    this.avatarUrl,
    this.avatarColorIndex = -1,
    this.hasAcceptedAgreement = true,
    this.nik = '',
    this.isVerified = false,
    this.accountStatus = AccountStatus.approved,
    this.deactivationReason,
    this.googleId = '',
    this.googleEmail = '',
    this.roleVerificationStatus = '',
  });

  /// Menjamin ID pengguna selalu tepat 6 karakter alfanumerik/angka.
  String get displayId => normalizeSixCharId(id);

  static String normalizeSixCharId(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    if (cleaned.isEmpty) return '123456';
    if (cleaned.length >= 6) return cleaned.substring(0, 6);
    return cleaned.padLeft(6, '0');
  }

  /// Menghasilkan ID 6 digit deterministik untuk akun baru pada sesi lokal.
  static String generateSixCharId(String seed) {
    final trimmed = seed.trim().toLowerCase();
    if (trimmed.isEmpty) return '123456';
    int hash = 17;
    for (final unit in trimmed.codeUnits) {
      hash = ((hash * 31) + unit) & 0x7fffffff;
    }
    final sixDigit = 100000 + (hash % 900000);
    return sixDigit.toString();
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? password,
    String? role,
    int? ticketsBought,
    int? concertsAttended,
    int? reviewsCount,
    Uint8List? profileImageBytes,
    String? avatarUrl,
    bool clearProfileImage = false,
    int? avatarColorIndex,
    bool? hasAcceptedAgreement,
    String? nik,
    bool? isVerified,
    AccountStatus? accountStatus,
    String? deactivationReason,
    bool clearDeactivationReason = false,
    String? googleId,
    String? googleEmail,
    String? roleVerificationStatus,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      password: password ?? this.password,
      role: role ?? this.role,
      ticketsBought: ticketsBought ?? this.ticketsBought,
      concertsAttended: concertsAttended ?? this.concertsAttended,
      reviewsCount: reviewsCount ?? this.reviewsCount,
      profileImageBytes: clearProfileImage
          ? null
          : (profileImageBytes ?? this.profileImageBytes),
      avatarUrl: avatarUrl ?? this.avatarUrl,
      avatarColorIndex: avatarColorIndex ?? this.avatarColorIndex,
      hasAcceptedAgreement: hasAcceptedAgreement ?? this.hasAcceptedAgreement,
      nik: nik ?? this.nik,
      isVerified: isVerified ?? this.isVerified,
      accountStatus: accountStatus ?? this.accountStatus,
      deactivationReason: clearDeactivationReason
          ? null
          : (deactivationReason ?? this.deactivationReason),
      googleId: googleId ?? this.googleId,
      googleEmail: googleEmail ?? this.googleEmail,
      roleVerificationStatus:
          roleVerificationStatus ?? this.roleVerificationStatus,
    );
  }

  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts.isNotEmpty ? parts[0][0].toUpperCase() : 'U';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'url_foto': avatarUrl,
      'avatar_url': avatarUrl,
      'avatarUrl': avatarUrl,
      'avatarColorIndex': avatarColorIndex,
      'ticketsBought': ticketsBought,
      'concertsAttended': concertsAttended,
      'reviewsCount': reviewsCount,
      'hasAcceptedAgreement': hasAcceptedAgreement,
      'nik': nik,
      'isVerified': isVerified,
      'is_verified': isVerified,
      'approval_status': accountStatus.value,
      'deactivation_reason': deactivationReason,
      'google_id': googleId,
      'google_email': googleEmail,
      'role_verification_status': roleVerificationStatus,
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final avatar = (json['url_foto'] ?? json['avatarUrl'] ?? json['avatar_url'])
        as String?;
    Uint8List? bytes;
    if (avatar != null && avatar.startsWith('data:image')) {
      try {
        final commaIdx = avatar.indexOf(',');
        if (commaIdx != -1) {
          bytes = base64Decode(avatar.substring(commaIdx + 1));
        }
      } catch (_) {}
    }

    final roleStr = (json['role'] as String?) ?? 'User';
    final rawNik = (json['nik'] as String?) ?? '';
    final cleanNik = rawNik.replaceAll(RegExp(r'[^0-9]'), '');
    final rawVerified = (json['is_verified'] as bool?) ??
        (json['isVerified'] as bool?) ??
        false;
    final statusStr =
        (json['verification_status'] ?? json['approval_status'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
    final isUserRole = roleStr.trim().toLowerCase() == 'user';
    final resolvedVerified = isUserRole
        ? ((rawVerified || statusStr == 'approved') && cleanNik.length >= 16)
        : (rawVerified || statusStr == 'approved');

    return UserModel(
      id: (json['id'] as String?) ?? '123456',
      name: (json['name'] as String?) ?? (json['full_name'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      phone: (json['phone'] as String?) ?? '',
      password: '',
      role: roleStr,
      avatarUrl: avatar,
      profileImageBytes: bytes,
      ticketsBought: (json['ticketsBought'] as num?)?.toInt() ?? 0,
      concertsAttended: (json['concertsAttended'] as num?)?.toInt() ?? 0,
      reviewsCount: (json['reviewsCount'] as num?)?.toInt() ?? 0,
      avatarColorIndex: (json['avatarColorIndex'] as num?)?.toInt() ?? -1,
      hasAcceptedAgreement: (json['hasAcceptedAgreement'] as bool?) ?? true,
      nik: rawNik,
      isVerified: resolvedVerified,
      accountStatus: json['approval_status'] != null
          ? AccountStatus.fromValue(json['approval_status'] as String?)
          : AccountStatus.approved,
      deactivationReason: json['deactivation_reason'] as String?,
      googleId: (json['google_id'] as String?) ?? '',
      googleEmail: (json['google_email'] as String?) ?? '',
      roleVerificationStatus:
          (json['role_verification_status'] as String?) ?? '',
    );
  }
}
