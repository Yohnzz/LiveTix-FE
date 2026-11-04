import 'package:flutter/foundation.dart';

/// Status hasil pemindaian tiket di gate
enum GateScanStatus {
  valid,
  alreadyUsed,
  wrongGate,
  refunded,
  invalid,
}

/// Model data Gate tugas kru lapangan
class GateModel {
  final String id;
  final String concertId;
  final String concertTitle;
  final String concertDate;
  final String concertVenue;
  final String name; // contoh: 'Gate B'
  final String category; // contoh: 'Festival'
  final String openTime; // contoh: '17.00 WIB'
  final bool isOpen;
  final String doorNumber; // contoh: 'FEST-04'
  final int totalExpected; // contoh: 3000
  final int totalCheckedIn; // contoh: 1420
  final String assignedCrewId; // ID kru bertugas
  final String assignedCrewName; // Nama kru bertugas
  final String? bannerImageUrl;
  final Uint8List? bannerImageBytes;

  const GateModel({
    required this.id,
    required this.concertId,
    required this.concertTitle,
    required this.concertDate,
    required this.concertVenue,
    required this.name,
    required this.category,
    this.openTime = '17.00 WIB',
    this.isOpen = true,
    this.doorNumber = 'FEST-04',
    this.totalExpected = 3000,
    this.totalCheckedIn = 1420,
    this.assignedCrewId = '300001',
    this.assignedCrewName = 'Budi Santoso',
    this.bannerImageUrl,
    this.bannerImageBytes,
  });

  /// Persentase kehadiran penonton di gate ini (0 - 100)
  int get attendancePercentage {
    if (totalExpected <= 0) return 0;
    final pct = ((totalCheckedIn / totalExpected) * 100).round();
    return pct > 100 ? 100 : pct;
  }

  /// Rasio progres kehadiran untuk progress bar (0.0 - 1.0)
  double get attendanceRatio {
    if (totalExpected <= 0) return 0.0;
    final r = totalCheckedIn / totalExpected;
    return r > 1.0 ? 1.0 : (r < 0.0 ? 0.0 : r);
  }

  /// Label lengkap gate tugas (contoh: 'GATE B - FESTIVAL')
  String get fullTitle => '${name.toUpperCase()} - ${category.toUpperCase()}';

  GateModel copyWith({
    String? id,
    String? concertId,
    String? concertTitle,
    String? concertDate,
    String? concertVenue,
    String? name,
    String? category,
    String? openTime,
    bool? isOpen,
    String? doorNumber,
    int? totalExpected,
    int? totalCheckedIn,
    String? assignedCrewId,
    String? assignedCrewName,
    String? bannerImageUrl,
    Uint8List? bannerImageBytes,
  }) {
    return GateModel(
      id: id ?? this.id,
      concertId: concertId ?? this.concertId,
      concertTitle: concertTitle ?? this.concertTitle,
      concertDate: concertDate ?? this.concertDate,
      concertVenue: concertVenue ?? this.concertVenue,
      name: name ?? this.name,
      category: category ?? this.category,
      openTime: openTime ?? this.openTime,
      isOpen: isOpen ?? this.isOpen,
      doorNumber: doorNumber ?? this.doorNumber,
      totalExpected: totalExpected ?? this.totalExpected,
      totalCheckedIn: totalCheckedIn ?? this.totalCheckedIn,
      assignedCrewId: assignedCrewId ?? this.assignedCrewId,
      assignedCrewName: assignedCrewName ?? this.assignedCrewName,
      bannerImageUrl: bannerImageUrl ?? this.bannerImageUrl,
      bannerImageBytes: bannerImageBytes ?? this.bannerImageBytes,
    );
  }
}

/// Riwayat pemindaian tiket di gate
class GateScanRecord {
  final String id;
  final String ticketCode;
  final String attendeeName;
  final String category;
  final int quantity;
  final String gateId;
  final String gateName;
  final String doorNumber;
  final DateTime scannedAt;
  final GateScanStatus status;
  final String? message;
  final String? previousScanInfo; // e.g. '17:15 WIB · Gate A oleh Petugas Budi'
  final String? targetGate; // e.g. 'Gate VIP · sisi barat'
  final String? eventTitle; // e.g. 'Soundwave Fest 2026'
  final String? nik; // e.g. 'NIK 3573 **** **** 0012'
  final String? bookingCode; // e.g. 'SWF-8891-2A'

  const GateScanRecord({
    required this.id,
    required this.ticketCode,
    required this.attendeeName,
    required this.category,
    this.quantity = 1,
    required this.gateId,
    required this.gateName,
    required this.doorNumber,
    required this.scannedAt,
    required this.status,
    this.message,
    this.previousScanInfo,
    this.targetGate,
    this.eventTitle,
    this.nik,
    this.bookingCode,
  });

  /// Format waktu scan singkat: '17:45:12 WIB'
  String get formattedTime {
    final h = scannedAt.hour.toString().padLeft(2, '0');
    final m = scannedAt.minute.toString().padLeft(2, '0');
    final s = scannedAt.second.toString().padLeft(2, '0');
    return '$h:$m:$s WIB';
  }

  /// Format jam dan menit: '17:45 WIB'
  String get shortTime {
    final h = scannedAt.hour.toString().padLeft(2, '0');
    final m = scannedAt.minute.toString().padLeft(2, '0');
    return '$h:$m WIB';
  }
}
