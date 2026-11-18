// lib/services/ticket_validator_service.dart
// FASE 4 - Layanan validasi QR tiket melalui Edge Function validate-ticket
// Flutter hanya memanggil server; HMAC_TICKET_SECRET tidak pernah ada di client.

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/supabase_config.dart';
import 'supabase_service.dart';

class TicketValidationResult {
  final bool valid;
  final String? ticketId;
  final String? reason;       // null jika valid
  final String? tierName;
  final int scansUsed;
  final int scanQuota;
  final int scansLeft;
  final String? issuedAt;
  final String? error;

  const TicketValidationResult({
    required this.valid,
    this.ticketId,
    this.reason,
    this.tierName,
    this.scansUsed = 0,
    this.scanQuota = 1,
    this.scansLeft = 0,
    this.issuedAt,
    this.error,
  });

  String get reasonLabel {
    switch (reason) {
      case 'TICKET_NOT_FOUND':
        return 'Tiket tidak ditemukan dalam sistem';
      case 'CODE_MISMATCH':
        return 'Kode tiket tidak cocok (kemungkinan QR palsu)';
      case 'SIGNATURE_INVALID':
        return 'Tanda tangan QR tidak valid — tiket mungkin dipalsukan';
      case 'TICKET_CANCELLED':
        return 'Tiket sudah dibatalkan atau direfund';
      case 'SCAN_QUOTA_EXCEEDED':
        return 'Tiket sudah dipakai semua ($scanQuota dari $scanQuota scan)';
      default:
        return reason ?? error ?? 'Validasi gagal';
    }
  }

  factory TicketValidationResult.fromJson(Map<String, dynamic> json) {
    return TicketValidationResult(
      valid: json['valid'] == true,
      ticketId: json['ticket_id']?.toString(),
      reason: json['reason']?.toString(),
      tierName: json['tier_name']?.toString(),
      scansUsed: (json['scans_used'] as num?)?.toInt() ?? 0,
      scanQuota: (json['scan_quota'] as num?)?.toInt() ?? 1,
      scansLeft: (json['scans_left'] as num?)?.toInt() ?? 0,
      issuedAt: json['issued_at']?.toString(),
      error: json['error']?.toString(),
    );
  }
}

class TicketValidatorService {
  static final TicketValidatorService _instance =
      TicketValidatorService._internal();
  factory TicketValidatorService() => _instance;
  TicketValidatorService._internal();

  /// Validasi payload QR tiket melalui Edge Function validate-ticket.
  /// [qrPayload] = string yang di-scan dari QR Code (format: ticket_id.kode_tiket.signature)
  /// [gateUserId] = ID user petugas gate yang melakukan scan (optional)
  Future<TicketValidationResult> validateQrPayload({
    required String qrPayload,
    String? gateUserId,
  }) async {
    if (!SupabaseService.isInitialized) {
      return const TicketValidationResult(
        valid: false,
        error: 'Koneksi server tidak tersedia',
      );
    }

    final uri = Uri.parse(
      '${SupabaseConfig.url}/functions/v1/validate-ticket',
    );

    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'apikey': SupabaseConfig.anonKey,
              'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
            },
            body: jsonEncode({
              'qrPayload': qrPayload.trim(),
              if (gateUserId != null) 'gateUserId': gateUserId,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return TicketValidationResult.fromJson(data);
    } catch (e) {
      return TicketValidationResult(
        valid: false,
        error: 'Gagal terhubung ke server: $e',
      );
    }
  }

  /// Ambil payload QR tiket dari database via RPC get_ticket_qr_payload.
  /// Dipanggil saat user membuka modal tiket aktif untuk mendapatkan QR terbaru.
  Future<String?> fetchTicketQrPayload(String ticketId) async {
    if (!SupabaseService.isInitialized) return null;
    try {
      final result = await SupabaseService.client
          .rpc('get_ticket_qr_payload', params: {'p_ticket_id': ticketId});
      if (result == null) return null;
      final data = result as Map<String, dynamic>;
      if (data['error'] != null) return null;
      final payload = data['qr_payload']?.toString() ?? '';
      return payload.isNotEmpty ? payload : null;
    } catch (e) {
      return null;
    }
  }
}
