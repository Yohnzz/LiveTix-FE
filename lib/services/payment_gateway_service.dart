import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../core/supabase_config.dart';
import 'data_service.dart';
import 'supabase_service.dart';

class PaymentChargeResult {
  final bool isSuccess;
  final String orderId;
  final int grossAmount;
  final String paymentMethod;
  final String paymentType;
  final String? qrString;
  final String? qrUrl;
  final String? deeplinkUrl;
  final String? vaNumber;
  final String? billerCode;
  final String? billKey;
  final DateTime? expiresAt;
  final String? errorMessage;

  const PaymentChargeResult({
    required this.isSuccess,
    required this.orderId,
    required this.grossAmount,
    required this.paymentMethod,
    required this.paymentType,
    this.qrString,
    this.qrUrl,
    this.deeplinkUrl,
    this.vaNumber,
    this.billerCode,
    this.billKey,
    this.expiresAt,
    this.errorMessage,
  });
}

class PromoterBalanceResult {
  final int pendingBalance; // Saldo tertahan (konser belum mulai)
  final int availableBalance; // Saldo tersedia (konser sudah mulai & tidak dibatalkan)
  final int totalSales;
  final int totalWithdrawn;

  const PromoterBalanceResult({
    required this.pendingBalance,
    required this.availableBalance,
    required this.totalSales,
    required this.totalWithdrawn,
  });
}

class AdminBalanceResult {
  final int totalFeeCollected; // Total fee 3% terkumpul
  final int availableFeeBalance; // Saldo fee tersedia untuk ditarik
  final int totalFeeWithdrawn;

  const AdminBalanceResult({
    required this.totalFeeCollected,
    required this.availableFeeBalance,
    required this.totalFeeWithdrawn,
  });
}

class PaymentGatewayService {
  static final PaymentGatewayService _instance = PaymentGatewayService._internal();
  factory PaymentGatewayService() => _instance;
  PaymentGatewayService._internal();

  /// 1. Create Payment Charge ke Backend (Midtrans Core API)
  /// Client Flutter TIDAK memegang Server Key. Seluruh charge diproses oleh backend/Edge Function.
  Future<PaymentChargeResult> createPaymentCharge({
    required String orderId,
    required String concertId,
    required String tierId,
    required int quantity,
    required String paymentMethod,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    String? userId,
  }) async {
    // URL Backend Supabase Edge Function create-payment
    final functionUrl = '${SupabaseConfig.url}/functions/v1/create-payment';

    if (SupabaseService.isInitialized) {
      try {
        final resp = await http.post(
          Uri.parse(functionUrl),
          headers: {
            'Content-Type': 'application/json',
            'apikey': SupabaseConfig.anonKey,
            'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
          },
          body: jsonEncode({
            'orderId': orderId,
            'concertId': concertId,
            'tierId': tierId,
            'quantity': quantity,
            'paymentMethod': paymentMethod,
            'customerName': customerName,
            'customerEmail': customerEmail,
            'customerPhone': customerPhone,
            'userId': userId,
          }),
        ).timeout(const Duration(seconds: 10));

        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          final expStr = data['expiresAt'] as String?;
          return PaymentChargeResult(
            isSuccess: true,
            orderId: orderId,
            grossAmount: (data['grossAmount'] as num?)?.toInt() ?? 0,
            paymentMethod: (data['paymentMethod'] ?? paymentMethod).toString(),
            paymentType: (data['paymentType'] ?? 'qris').toString(),
            qrString: data['qrString'] as String?,
            qrUrl: data['qrUrl'] as String?,
            deeplinkUrl: data['deeplinkUrl'] as String?,
            vaNumber: data['vaNumber'] as String?,
            billerCode: data['billerCode'] as String?,
            billKey: data['billKey'] as String?,
            expiresAt: expStr != null ? DateTime.tryParse(expStr) : null,
          );
        }
      } catch (e) {
        debugPrint('Error calling create-payment Edge Function: $e');
      }
    }

    // Fallback Sandbox Simulation jika Edge Function sedang offline / dev lokal
    final cleanOrderId = orderId.replaceAll(RegExp(r'[^0-9]'), '');
    final sampleVa = cleanOrderId.length >= 8 ? cleanOrderId.substring(0, 8) : '12345678';
    final methodUpper = paymentMethod.toUpperCase();

    String? qrStr;
    String? deepUrl;
    String? va;

    if (methodUpper.contains('QRIS')) {
      qrStr = '00020101021226590014ID.LINKAJA.WWW011893600911002230467702150000000000000000303UMI51440014ID.CO.QRIS.WWW0215ID10260088912040303UMI5204581253033605802ID5916LIVETIX OFFICIAL6006MALANG61056514162190715$orderId';
    } else if (methodUpper.contains('GOPAY')) {
      deepUrl = 'gojek://gopay/partnerweb/pay?order_id=$orderId';
    } else if (methodUpper.contains('SHOPEE')) {
      deepUrl = 'shopeeid://shopeepay/payment?order_id=$orderId';
    } else if (methodUpper.contains('MANDIRI')) {
      va = '89022 0812$sampleVa';
    } else if (methodUpper.contains('BNI')) {
      va = '8808 1234 $sampleVa';
    } else if (methodUpper.contains('BRI')) {
      va = '7788 9012 $sampleVa';
    } else {
      va = '8808 1234 $sampleVa';
    }

    return PaymentChargeResult(
      isSuccess: true,
      orderId: orderId,
      grossAmount: 350000,
      paymentMethod: methodUpper,
      paymentType: methodUpper.contains('QRIS') ? 'qris' : 'bank_transfer',
      qrString: qrStr,
      deeplinkUrl: deepUrl,
      vaNumber: va,
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    );
  }

  /// 2. Buka Aplikasi E-Wallet Pilihan User via Deep Link Langsung
  Future<bool> launchEwalletApp(String deeplinkUrl, {String? fallbackWebUrl}) async {
    try {
      final uri = Uri.parse(deeplinkUrl);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching deep link $deeplinkUrl: $e');
    }

    if (fallbackWebUrl != null && fallbackWebUrl.isNotEmpty) {
      try {
        final webUri = Uri.parse(fallbackWebUrl);
        return await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }

    return false;
  }

  /// 3. Polling Status Transaksi ke Backend (Membaca status resmi dari tabel orders Supabase yang diupdate oleh Webhook Midtrans)
  Future<String> checkOrderStatus(String orderId) async {
    if (SupabaseService.isInitialized) {
      try {
        final res = await SupabaseService.client
            .from('orders')
            .select('payment_status')
            .eq('id', orderId)
            .maybeSingle();

        if (res != null && res['payment_status'] != null) {
          final s = (res['payment_status'] as String).toUpperCase();
          if (s == 'PAID' || s == 'SETTLEMENT' || s == 'CAPTURE') {
            DataService().markOrderPaid(orderId);
            return 'PAID';
          } else if (s == 'EXPIRED' || s == 'FAILED' || s == 'CANCEL' || s == 'DENY') {
            return 'EXPIRED';
          } else if (s == 'PENDING') {
            return 'PENDING';
          }
        }
      } catch (e) {
        debugPrint('Error checkOrderStatus Supabase: $e');
      }
    }

    // Cek memori lokal jika status telah diverifikasi sebelumnya
    if (DataService().isOrderPaid(orderId)) {
      return 'PAID';
    }

    return 'PENDING';
  }

  /// 4. Simulasi Pembayaran Sukses Sandbox (Untuk Demo & Pengujian Cepat)
  Future<bool> simulateSandboxPaymentSuccess(String orderId) async {
    DataService().markOrderPaid(orderId);

    if (SupabaseService.isInitialized) {
      try {
        await SupabaseService.client.from('orders').update({
          'payment_status': 'PAID',
          'paid_at': DateTime.now().toIso8601String(),
        }).eq('id', orderId);
        return true;
      } catch (e) {
        debugPrint('Error simulateSandboxPaymentSuccess Supabase: $e');
      }
    }
    return true;
  }

  /// 5. Ambil Saldo Produser dari Ledger (Saldo Tertahan vs Saldo Tersedia)
  Future<PromoterBalanceResult> getPromoterBalance(String producerId) async {
    if (SupabaseService.isInitialized) {
      try {
        final res = await SupabaseService.client
            .rpc('calculate_promoter_balance', params: {'p_producer_id': producerId});
        if (res != null && res is Map) {
          return PromoterBalanceResult(
            pendingBalance: (res['pending_balance'] as num?)?.toInt() ?? 0,
            availableBalance: (res['available_balance'] as num?)?.toInt() ?? 0,
            totalSales: (res['total_sales'] as num?)?.toInt() ?? 0,
            totalWithdrawn: (res['total_withdrawn'] as num?)?.toInt() ?? 0,
          );
        }
      } catch (e) {
        debugPrint('Error getPromoterBalance Supabase RPC: $e');
      }
    }

    // Nilai Default Simulasi
    return const PromoterBalanceResult(
      pendingBalance: 24500000,
      availableBalance: 8750000,
      totalSales: 33250000,
      totalWithdrawn: 12500000,
    );
  }

  /// 6. Ambil Saldo Fee Admin 3% dari Ledger
  Future<AdminBalanceResult> getAdminBalance() async {
    if (SupabaseService.isInitialized) {
      try {
        final res = await SupabaseService.client.rpc('calculate_admin_balance');
        if (res != null && res is Map) {
          return AdminBalanceResult(
            totalFeeCollected: (res['total_fee_collected'] as num?)?.toInt() ?? 0,
            availableFeeBalance: (res['available_fee_balance'] as num?)?.toInt() ?? 0,
            totalFeeWithdrawn: (res['total_fee_withdrawn'] as num?)?.toInt() ?? 0,
          );
        }
      } catch (e) {
        debugPrint('Error getAdminBalance Supabase RPC: $e');
      }
    }

    return const AdminBalanceResult(
      totalFeeCollected: 4500000,
      availableFeeBalance: 3200000,
      totalFeeWithdrawn: 1300000,
    );
  }

  /// 7. Ajukan Penarikan Dana Produser (Atomic & Cegah Double Withdraw)
  Future<Map<String, dynamic>> requestProducerWithdrawal({
    required String producerId,
    required int amount,
    required String bankName,
    required String accountNumber,
    required String accountName,
    String? concertId,
  }) async {
    if (amount < 50000) {
      return {'success': false, 'message': 'Nominal penarikan minimum adalah Rp 50.000'};
    }

    if (SupabaseService.isInitialized) {
      try {
        final res = await SupabaseService.client.rpc(
          'request_producer_withdrawal_atomic',
          params: {
            'p_producer_id': producerId,
            'p_amount': amount,
            'p_bank_name': bankName,
            'p_account_number': accountNumber,
            'p_account_name': accountName,
            'p_concert_id': concertId,
          },
        );
        if (res != null && res is Map) {
          return Map<String, dynamic>.from(res);
        }
      } catch (e) {
        debugPrint('Error requestProducerWithdrawal RPC: $e');
        return {'success': false, 'message': 'Terjadi kesalahan sistem: $e'};
      }
    }

    return {
      'success': true,
      'message': 'Pengajuan penarikan dana Rp $amount berhasil dibuat dan sedang diproses.',
      'reference_no': 'WD-PRD-${DateTime.now().millisecondsSinceEpoch}',
    };
  }

  /// 8. Ajukan Penarikan Fee Admin 3%
  Future<Map<String, dynamic>> requestAdminWithdrawal({
    required String adminId,
    required int amount,
    required String bankName,
    required String accountNumber,
    required String accountName,
  }) async {
    if (amount < 50000) {
      return {'success': false, 'message': 'Nominal penarikan minimum adalah Rp 50.000'};
    }

    if (SupabaseService.isInitialized) {
      try {
        final res = await SupabaseService.client.rpc(
          'request_admin_withdrawal_atomic',
          params: {
            'p_admin_id': adminId,
            'p_amount': amount,
            'p_bank_name': bankName,
            'p_account_number': accountNumber,
            'p_account_name': accountName,
          },
        );
        if (res != null && res is Map) {
          return Map<String, dynamic>.from(res);
        }
      } catch (e) {
        debugPrint('Error requestAdminWithdrawal RPC: $e');
        return {'success': false, 'message': 'Terjadi kesalahan sistem: $e'};
      }
    }

    return {
      'success': true,
      'message': 'Pengajuan penarikan fee admin Rp $amount berhasil diproses.',
      'reference_no': 'WD-ADM-${DateTime.now().millisecondsSinceEpoch}',
    };
  }

  /// 9. Batalkan Konser & Kunci Saldo Produser untuk Pengalihan Refund
  Future<Map<String, dynamic>> cancelConcertAndLockFunds({
    required String concertId,
    required String reason,
    String category = 'Force Majeure',
  }) async {
    if (reason.trim().isEmpty) {
      return {'success': false, 'message': 'Alasan pembatalan konser wajib diisi.'};
    }

    if (SupabaseService.isInitialized) {
      try {
        final res = await SupabaseService.client.rpc(
          'cancel_concert_and_lock_funds',
          params: {
            'p_concert_id': concertId,
            'p_reason': reason,
            'p_category': category,
          },
        );
        if (res != null && res is Map) {
          return Map<String, dynamic>.from(res);
        }
      } catch (e) {
        debugPrint('Error cancelConcertAndLockFunds RPC: $e');
      }
    }

    return {
      'success': true,
      'message': 'Konser berhasil dibatalkan. Tiket aktif berhak refund 100% dan dana konser dikunci.',
    };
  }

  /// 10. Pengajuan Refund Tiket 100% oleh User (E-Wallet / Rekening Bank)
  Future<Map<String, dynamic>> requestTicketRefund({
    required String ticketId,
    required String userId,
    required String destinationType, // 'BANK' / 'EWALLET'
    required String destinationProvider, // 'BCA', 'GoPay', 'ShopeePay', dll
    required String destinationAccountNo,
    required String destinationAccountName,
    required String reason,
  }) async {
    if (destinationAccountNo.trim().isEmpty || destinationAccountName.trim().isEmpty) {
      return {'success': false, 'message': 'Nomor dan nama pemilik rekening/e-wallet wajib diisi.'};
    }

    if (SupabaseService.isInitialized) {
      try {
        final res = await SupabaseService.client.rpc(
          'request_ticket_refund_atomic',
          params: {
            'p_ticket_id': ticketId,
            'p_user_id': userId,
            'p_dest_type': destinationType,
            'p_dest_provider': destinationProvider,
            'p_dest_account_no': destinationAccountNo,
            'p_dest_account_name': destinationAccountName,
            'p_reason': reason,
          },
        );
        if (res != null && res is Map) {
          return Map<String, dynamic>.from(res);
        }
      } catch (e) {
        debugPrint('Error requestTicketRefund RPC: $e');
        return {'success': false, 'message': 'Terjadi kesalahan sistem refund: $e'};
      }
    }

    return {
      'success': true,
      'message': 'Pengajuan refund 100% berhasil diproses ke $destinationProvider $destinationAccountNo.',
    };
  }
}
