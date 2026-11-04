import 'dart:typed_data';

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
  final int avatarColorIndex;
  final bool hasAcceptedAgreement;

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
    this.avatarColorIndex = -1,
    this.hasAcceptedAgreement = true,
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
    bool clearProfileImage = false,
    int? avatarColorIndex,
    bool? hasAcceptedAgreement,
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
      profileImageBytes:
          clearProfileImage ? null : (profileImageBytes ?? this.profileImageBytes),
      avatarColorIndex: avatarColorIndex ?? this.avatarColorIndex,
      hasAcceptedAgreement: hasAcceptedAgreement ?? this.hasAcceptedAgreement,
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
}
