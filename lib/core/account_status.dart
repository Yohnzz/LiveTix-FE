import 'package:flutter/material.dart';

/// Pemetaan terpusat status akun (kolom `approval_status` di database).
///
/// Ini satu-satunya sumber label, warna, dan ikon status akun, baik untuk
/// Produser maupun User. Jangan menulis label/warna status di halaman lain.
///
/// Nilai database final: `pending`, `approved`, `rejected`, `nonaktif`.
enum AccountStatus {
  pending('pending', 'Menunggu', 'Menunggu persetujuan'),
  approved('approved', 'Disetujui', 'Disetujui'),
  rejected('rejected', 'Ditolak', 'Ditolak'),
  nonaktif('nonaktif', 'Nonaktif', 'Dinonaktifkan'),
  cancelled('cancelled', 'Dibatalkan', 'Dibatalkan');

  const AccountStatus(this.value, this.label, this.description);

  /// Nilai yang disimpan di kolom `approval_status`.
  final String value;

  /// Label pendek baku untuk badge, chip, dan tab.
  final String label;

  /// Kalimat lengkap untuk teks penjelasan.
  final String description;

  /// Mengubah nilai database menjadi status. Nilai lama tetap dikenali supaya
  /// data sebelum migrasi tidak salah tampil.
  ///
  /// Nilai kosong/tak dikenal selalu jatuh ke [pending] — bukan [rejected] —
  /// agar akun tidak pernah tampil "Ditolak" hanya karena data tidak lengkap.
  static AccountStatus fromValue(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'approved':
      case 'disetujui':
        return AccountStatus.approved;
      case 'rejected':
      case 'ditolak':
        return AccountStatus.rejected;
      case 'cancelled':
      case 'canceled':
      case 'dibatalkan':
      case 'batal':
        return AccountStatus.cancelled;
      case 'nonaktif':
      case 'deactivated':
      case 'inactive':
        return AccountStatus.nonaktif;
      case 'pending':
      case 'pending_create':
      case 'unverified':
        return AccountStatus.pending;
      default:
        return AccountStatus.pending;
    }
  }

  /// Status aktif yang boleh memakai fitur akun.
  bool get isActive => this == AccountStatus.approved;

  /// Status yang memblokir seluruh fitur Produser dan User.
  bool get isBlocked =>
      this == AccountStatus.rejected || this == AccountStatus.nonaktif;

  /// Apakah akun boleh login dan memakai fitur.
  bool get canUseApp => this == AccountStatus.approved;

  /// Label pendek untuk chip/tab yang ruangnya terbatas.
  String get shortLabel => label;

  /// Label status untuk akun User biasa. Akun User yang `approved` lazim
  /// disebut "Aktif"; status lain memakai label baku.
  String get userLabel => this == AccountStatus.approved ? 'Aktif' : label;

  /// Ikon status.
  IconData get icon => switch (this) {
        AccountStatus.pending => Icons.hourglass_top_rounded,
        AccountStatus.approved => Icons.verified_rounded,
        AccountStatus.rejected => Icons.cancel_rounded,
        AccountStatus.nonaktif => Icons.block_rounded,
        AccountStatus.cancelled => Icons.event_busy_rounded,
      };

  /// Warna teks/ikon status.
  Color get color => switch (this) {
        AccountStatus.pending => const Color(0xFFB45309),
        AccountStatus.approved => const Color(0xFF15803D),
        AccountStatus.rejected => const Color(0xFFB91C1C),
        AccountStatus.nonaktif => const Color(0xFF475467),
        AccountStatus.cancelled => const Color(0xFFD92D20),
      };

  /// Warna latar chip status.
  Color get backgroundColor => switch (this) {
        AccountStatus.pending => const Color(0xFFFEF3C7),
        AccountStatus.approved => const Color(0xFFDCFCE7),
        AccountStatus.rejected => const Color(0xFFFEE2E2),
        AccountStatus.nonaktif => const Color(0xFFEAECF0),
        AccountStatus.cancelled => const Color(0xFFFEE4E2),
      };

  /// Alasan yang harus ditampilkan, sesuai status.
  ///
  /// Alasan hanya dibaca dari kolom yang sesuai: `rejection_reason` untuk
  /// [rejected], `deactivation_reason` untuk [nonaktif]. Status lain tidak
  /// pernah menampilkan alasan.
  String? reasonFrom({
    String? rejectionReason,
    String? deactivationReason,
  }) {
    final reason = switch (this) {
      AccountStatus.rejected => rejectionReason,
      AccountStatus.nonaktif => deactivationReason,
      _ => null,
    };
    final trimmed = reason?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  /// Pesan layar blokir akun untuk User.
  String get blockedTitle => switch (this) {
        AccountStatus.nonaktif => 'Akun Anda dinonaktifkan',
        AccountStatus.rejected => 'Akun Anda ditolak',
        _ => 'Akun Anda belum aktif',
      };
}
