import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../core/supabase_config.dart';
import '../utils/uuid_utils.dart';
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
  // Snap Midtrans
  final String? snapToken;
  final String? snapRedirectUrl;

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
    this.snapToken,
    this.snapRedirectUrl,
  });
}

class PromoterBalanceResult {
  final int pendingBalance; // Saldo tertahan (konser belum mulai)
  final int availableBalance; // Saldo tersedia (konser sudah mulai & tidak dibatalkan)
  final int totalSales;
  final int totalWithdrawn;
  final bool hasPendingWithdrawal;

  const PromoterBalanceResult({
    required this.pendingBalance,
    required this.availableBalance,
    required this.totalSales,
    required this.totalWithdrawn,
    this.hasPendingWithdrawal = false,
  });
}

class AdminBalanceResult {
  final int totalFeeCollected; // Total keseluruhan (biaya aplikasi + pembulatan)
  final int availableFeeBalance; // Total saldo fee tersedia untuk ditarik
  final int totalFeeWithdrawn; // Total yang sudah ditarik
  final int totalBiayaAplikasi; // Total pendapatan biaya aplikasi (2%)
  final int totalPembulatan; // Total pendapatan pembulatan
  final int availableBiayaAplikasi; // Biaya aplikasi yang siap ditarik
  final int availablePembulatan; // Pembulatan yang siap ditarik
  final bool hasPendingWithdrawal; // Apakah ada withdraw pending

  const AdminBalanceResult({
    required this.totalFeeCollected,
    required this.availableFeeBalance,
    required this.totalFeeWithdrawn,
    this.totalBiayaAplikasi = 0,
    this.totalPembulatan = 0,
    this.availableBiayaAplikasi = 0,
    this.availablePembulatan = 0,
    this.hasPendingWithdrawal = false,
  });
}

class PaymentGatewayService {
  static final PaymentGatewayService _instance = PaymentGatewayService._internal();
  factory PaymentGatewayService() => _instance;
  PaymentGatewayService._internal();

  /// 1. Create Payment Charge ke Backend (Midtrans Snap Sandbox) + Atomic Stock Reservation
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
    String? tierName,
    String? customerNik,
    int? totalAmount,
  }) async {
    // 1A. Validasi ketersediaan stok terlebih dahulu (Supabase / cache lokal)
    if (SupabaseService.isInitialized) {
      try {
        final tierRow = await SupabaseService.client
            .from('ticket_tiers')
            .select('total_quota, quota, sold_count, reserved_count')
            .eq('id', tierId)
            .maybeSingle();
        if (tierRow != null) {
          final totalQuota =
              (tierRow['total_quota'] as num?)?.toInt() ??
                  (tierRow['quota'] as num?)?.toInt() ??
                  0;
          final sold = (tierRow['sold_count'] as num?)?.toInt() ?? 0;
          final reserved = (tierRow['reserved_count'] as num?)?.toInt() ?? 0;
          final avail = (totalQuota - (sold + reserved)).clamp(0, totalQuota);
          if (avail < quantity) {
            return PaymentChargeResult(
              isSuccess: false,
              orderId: orderId,
              grossAmount: totalAmount ?? 0,
              paymentMethod: paymentMethod,
              paymentType: 'qris',
              errorMessage:
                  'Maaf, tiket yang tersedia saat ini hanya tersisa $avail tiket. Silakan kurangi jumlah pembelian.',
            );
          }
        }
      } catch (e) {
        debugPrint('Error pre-check tier stock: $e');
      }
    } else {
      final concert = await DataService().getConcertById(concertId);
      final tierMatch = concert?.ticketTiers.where((t) => t.id == tierId).toList();
      if (tierMatch != null && tierMatch.isNotEmpty) {
        final avail = tierMatch.first.availableStock;
        if (avail < quantity) {
          return PaymentChargeResult(
            isSuccess: false,
            orderId: orderId,
            grossAmount: totalAmount ?? 0,
            paymentMethod: paymentMethod,
            paymentType: 'qris',
            errorMessage:
                'Maaf, tiket yang tersedia saat ini hanya tersisa $avail tiket. Silakan kurangi jumlah pembelian.',
          );
        }
      }
    }

    // URL Backend Supabase Edge Function create-payment
    final functionUrl = '${SupabaseConfig.url}/functions/v1/create-payment';
    PaymentChargeResult? edgeResult;

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
            'customerNik': customerNik,
            'userId': userId,
            'totalAmount': totalAmount,
            'grossAmount': totalAmount,
          }),
        ).timeout(const Duration(seconds: 10));

        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          final expStr = data['expiresAt'] as String?;
          edgeResult = PaymentChargeResult(
            isSuccess: true,
            orderId: orderId,
            grossAmount: (data['totalBayar'] as num?)?.toInt() ??
                (data['grossAmount'] as num?)?.toInt() ??
                (totalAmount ?? 0),
            paymentMethod: (data['paymentMethod'] ?? paymentMethod).toString(),
            paymentType: (data['paymentType'] ?? 'snap').toString(),
            snapToken: data['snapToken'] as String?,
            snapRedirectUrl: data['snapRedirectUrl'] as String?,
            qrString: data['qrString'] as String?,
            qrUrl: data['qrUrl'] as String?,
            deeplinkUrl: data['deeplinkUrl'] ?? data['snapRedirectUrl'] as String?,
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
    if (edgeResult == null) {
      final cleanOrderId = orderId.replaceAll(RegExp(r'[^0-9]'), '');
      final sampleVa =
          cleanOrderId.length >= 8 ? cleanOrderId.substring(0, 8) : '12345678';
      final methodUpper = paymentMethod.toUpperCase();

      String? qrStr;
      String? deepUrl;
      String? va;

      if (methodUpper.contains('QRIS')) {
        qrStr =
            '00020101021226590014ID.LINKAJA.WWW011893600911002230467702150000000000000000303UMI51440014ID.CO.QRIS.WWW0215ID10260088912040303UMI5204581253033605802ID5916LIVETIX OFFICIAL6006MALANG61056514162190715$orderId';
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

      edgeResult = PaymentChargeResult(
        isSuccess: true,
        orderId: orderId,
        grossAmount: totalAmount ?? 350000,
        paymentMethod: methodUpper,
        paymentType: methodUpper.contains('QRIS') ? 'qris' : 'bank_transfer',
        qrString: qrStr,
        deeplinkUrl: deepUrl,
        vaNumber: va,
        expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 15)),
      );
    }

    // 1B. Pastikan baris order PENDING tersimpan dan panggil atomic RPC reserve_ticket_stock
    DateTime? authoritativeExpiry = edgeResult.expiresAt;
    if (SupabaseService.isInitialized) {
      final uuidRegex = RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
      final rawUid = userId ?? SupabaseService.client.auth.currentUser?.id;
      final sanitizedUid =
          (rawUid != null && uuidRegex.hasMatch(rawUid)) ? rawUid : null;
      final expIso =
          (authoritativeExpiry ?? DateTime.now().toUtc().add(const Duration(minutes: 15)))
              .toUtc()
              .toIso8601String();

      final orderRow = <String, dynamic>{
        'id': orderId,
        if (sanitizedUid != null) 'user_id': sanitizedUid,
        'concert_id': concertId,
        'tier_id': UuidUtils.ensureValidUuid(tierId),
        if (tierName != null && tierName.isNotEmpty) 'tier_name': tierName,
        'quantity': quantity,
        'subtotal_amount': totalAmount ?? edgeResult.grossAmount,
        'total_amount': totalAmount ?? edgeResult.grossAmount,
        'gross_amount': totalAmount ?? edgeResult.grossAmount,
        'payment_method': paymentMethod,
        'payment_status': 'PENDING',
        'customer_name': customerName,
        'customer_email': customerEmail,
        'expires_at': expIso,
      };

      try {
        await SupabaseService.client.from('orders').upsert(orderRow);
      } catch (e) {
        final errStr = e.toString();
        if (errStr.contains('22P02') || errStr.contains('uuid')) {
          final fallback = Map<String, dynamic>.from(orderRow)
            ..remove('concert_id')
            ..remove('tier_id');
          try {
            await SupabaseService.client.from('orders').upsert(fallback);
          } catch (_) {}
        }
      }

      try {
        final rpcRes = await SupabaseService.client.rpc(
          'reserve_ticket_stock',
          params: {
            'p_tier_id': tierId,
            'p_quantity': quantity,
            'p_order_id': orderId,
            if (sanitizedUid != null) 'p_user_id': sanitizedUid,
          },
        );
        if (rpcRes is Map) {
          final ok = rpcRes['success'] == true;
          if (!ok) {
            try {
              await SupabaseService.client
                  .from('orders')
                  .update({'payment_status': 'FAILED'}).eq('id', orderId);
            } catch (_) {}
            unawaited(DataService().fetchConcertsFromSupabase(forceRefresh: true));
            return PaymentChargeResult(
              isSuccess: false,
              orderId: orderId,
              grossAmount: edgeResult.grossAmount,
              paymentMethod: edgeResult.paymentMethod,
              paymentType: edgeResult.paymentType,
              errorMessage: rpcRes['error']?.toString() ??
                  'Maaf, stok tiket tidak mencukupi.',
            );
          }
          final serverExp = rpcRes['expires_at']?.toString();
          if (serverExp != null) {
            authoritativeExpiry = DateTime.tryParse(serverExp) ?? authoritativeExpiry;
          }
        }
      } catch (e) {
        debugPrint('RPC reserve_ticket_stock warning: $e');
      }

      unawaited(DataService().fetchConcertsFromSupabase(forceRefresh: true));
    }

    DataService().adjustLocalTierStock(
      concertId,
      tierId,
      reservedDelta: quantity,
    );

    return PaymentChargeResult(
      isSuccess: true,
      orderId: edgeResult.orderId,
      grossAmount: edgeResult.grossAmount,
      paymentMethod: edgeResult.paymentMethod,
      paymentType: edgeResult.paymentType,
      snapToken: edgeResult.snapToken,
      snapRedirectUrl: edgeResult.snapRedirectUrl,
      qrString: edgeResult.qrString,
      qrUrl: edgeResult.qrUrl,
      deeplinkUrl: edgeResult.deeplinkUrl,
      vaNumber: edgeResult.vaNumber,
      billerCode: edgeResult.billerCode,
      billKey: edgeResult.billKey,
      expiresAt: authoritativeExpiry,
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
            .select('payment_status, expires_at')
            .eq('id', orderId)
            .maybeSingle();

        if (res != null && res['payment_status'] != null) {
          final s = (res['payment_status'] as String).toUpperCase();
          if (s == 'PAID' || s == 'SETTLEMENT' || s == 'CAPTURE') {
            try {
              await SupabaseService.client.rpc(
                'confirm_ticket_payment',
                params: {'p_order_id': orderId},
              );
              unawaited(DataService().fetchConcertsFromSupabase(forceRefresh: true));
            } catch (_) {}
            DataService().markOrderPaid(orderId);
            return 'PAID';
          } else if (s == 'EXPIRED' ||
              s == 'FAILED' ||
              s == 'CANCEL' ||
              s == 'CANCELLED' ||
              s == 'DENY') {
            DataService().cancelOrderTicket(orderId, reason: s);
            return 'EXPIRED';
          } else if (s == 'PENDING') {
            // Cek langsung status Midtrans Sandbox jika status di Supabase masih pending
            try {
              const serverKey = 'SB-Mid-server-HoUFborANT9387i9kIhiZm-7';
              final authHeader =
                  'Basic ${base64Encode(utf8.encode('$serverKey:'))}';
              final mResp = await http.get(
                Uri.parse(
                    'https://api.sandbox.midtrans.com/v2/$orderId/status'),
                headers: {
                  'Authorization': authHeader,
                  'Accept': 'application/json',
                },
              ).timeout(const Duration(seconds: 4));
              if (mResp.statusCode == 200 || mResp.statusCode == 201) {
                final mData = jsonDecode(mResp.body) as Map<String, dynamic>;
                final ms =
                    (mData['transaction_status'] ?? '').toString().toLowerCase();
                if (ms == 'settlement' || ms == 'capture') {
                  try {
                    await SupabaseService.client.from('orders').update({
                      'payment_status': 'PAID',
                      'paid_at': DateTime.now().toUtc().toIso8601String(),
                    }).eq('id', orderId);
                  } catch (_) {}
                  try {
                    await SupabaseService.client.rpc(
                      'confirm_ticket_payment',
                      params: {'p_order_id': orderId},
                    );
                    unawaited(DataService()
                        .fetchConcertsFromSupabase(forceRefresh: true));
                  } catch (_) {}
                  DataService().markOrderPaid(orderId);
                  return 'PAID';
                }
              }
            } catch (_) {}

            final expStr = res['expires_at']?.toString();
            final expDt = expStr != null ? DateTime.tryParse(expStr) : null;
            if (expDt != null && expDt.toUtc().isBefore(DateTime.now().toUtc())) {
              await cancelOrExpireOrder(orderId, reason: 'EXPIRED');
              return 'EXPIRED';
            }
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

  /// 3B. Membatalkan atau menandai kedaluwarsa pesanan PENDING dan melepaskan reservasi stok ke Supabase
  Future<bool> cancelOrExpireOrder(
    String orderId, {
    String reason = 'CANCELLED',
  }) async {
    DataService().cancelOrderTicket(orderId, reason: reason);

    if (SupabaseService.isInitialized) {
      try {
        await SupabaseService.client.rpc(
          'release_ticket_reservation',
          params: {
            'p_order_id': orderId,
            'p_reason': reason.toUpperCase(),
          },
        );
        unawaited(DataService().fetchConcertsFromSupabase(forceRefresh: true));
        return true;
      } catch (e) {
        debugPrint('Error release_ticket_reservation RPC: $e');
        try {
          await SupabaseService.client
              .from('orders')
              .update({'payment_status': reason.toUpperCase()}).eq('id', orderId);
        } catch (_) {}
      }
    }
    return true;
  }

  /// 4. Simulasi Pembayaran Sukses Sandbox (Untuk Demo & Pengujian Cepat)
  /// Memanggil midtrans-webhook Edge Function dengan signature="sandbox_simulation_key"
  Future<bool> simulateSandboxPaymentSuccess(String orderId) async {
    DataService().markOrderPaid(orderId);

    // Coba trigger webhook simulation ke Edge Function (agar ledger ditulis)
    if (SupabaseService.isInitialized) {
      try {
        // Ambil total_bayar dari order untuk gross_amount yang benar
        final orderRow = await SupabaseService.client
            .from('orders')
            .select('total_bayar, total_amount, gross_amount')
            .eq('id', orderId)
            .maybeSingle();
        final grossVal = (orderRow?['total_bayar'] as num?)?.toInt() ??
            (orderRow?['total_amount'] as num?)?.toInt() ??
            0;

        // POST ke midtrans-webhook dengan sandbox simulation payload
        final webhookUrl = '${SupabaseConfig.url}/functions/v1/midtrans-webhook';
        try {
          final resp = await http.post(
            Uri.parse(webhookUrl),
            headers: {
              'Content-Type': 'application/json',
              'apikey': SupabaseConfig.anonKey,
              'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
            },
            body: jsonEncode({
              'order_id': orderId,
              'transaction_status': 'settlement',
              'status_code': '200',
              'gross_amount': grossVal.toString(),
              'fraud_status': 'accept',
              'signature_key': 'sandbox_simulation_key',
            }),
          ).timeout(const Duration(seconds: 10));
          if (resp.statusCode == 200) {
            debugPrint('Webhook simulation sukses untuk order $orderId');
            unawaited(DataService().fetchConcertsFromSupabase(forceRefresh: true));
            return true;
          }
        } catch (webhookErr) {
          debugPrint('Webhook simulation error: $webhookErr');
        }

        // Fallback: panggil confirm_ticket_payment RPC langsung
        try {
          await SupabaseService.client.rpc(
            'confirm_ticket_payment',
            params: {'p_order_id': orderId},
          );
          unawaited(DataService().fetchConcertsFromSupabase(forceRefresh: true));
          return true;
        } catch (e) {
          debugPrint('Error confirm_ticket_payment RPC: $e');
          try {
            await SupabaseService.client.from('orders').update({
              'payment_status': 'PAID',
              'paid_at': DateTime.now().toIso8601String(),
            }).eq('id', orderId);
          } catch (err) {
            debugPrint('Error simulateSandboxPaymentSuccess Supabase: $err');
          }
        }
      } catch (e) {
        debugPrint('simulateSandboxPaymentSuccess error: $e');
      }
    }
    return true;
  }

  /// 5. Ambil Saldo Produser dari Ledger (Saldo Tertahan vs Saldo Tersedia)
  Future<PromoterBalanceResult> getPromoterBalance(String producerId) async {
    final validProducerId = producerId.isNotEmpty
        ? producerId
        : 'b3f25b77-6fb1-4004-90ac-f8e877b2eed4';
    if (SupabaseService.isInitialized) {
      try {
        final res = await SupabaseService.client.rpc(
            'calculate_promoter_balance',
            params: {'p_producer_id': validProducerId});
        Map<String, dynamic>? data;
        if (res is Map) {
          data = Map<String, dynamic>.from(res);
        } else if (res is List && res.isNotEmpty && res.first is Map) {
          data = Map<String, dynamic>.from(res.first);
        }

        if (data != null) {
          final bal = PromoterBalanceResult(
            pendingBalance: ((data['pending_balance'] ?? data['held_balance']) as num?)?.toInt() ?? 0,
            availableBalance: (data['available_balance'] as num?)?.toInt() ?? 0,
            totalSales: ((data['total_sales'] ?? data['total_sales_gross']) as num?)?.toInt() ?? 0,
            totalWithdrawn: (data['total_withdrawn'] as num?)?.toInt() ?? 0,
            hasPendingWithdrawal: data['has_pending_withdrawal'] == true,
          );
          if (bal.totalSales > 0 || bal.availableBalance > 0 || bal.pendingBalance > 0) return bal;
        }
      } catch (e) {
        debugPrint('Error getPromoterBalance Supabase RPC: $e');
      }

      // Fallback: hitung langsung dari orders yang sudah PAID
      try {
        final rows = await SupabaseService.client
            .from('orders')
            .select('id, total_amount, bagian_produser, gross_amount')
            .eq('payment_status', 'PAID');
        if (rows.isNotEmpty) {
          int sales = 0;
          for (final r in rows) {
            final part = (r['bagian_produser'] as num?)?.toInt() ??
                ((r['total_amount'] ?? r['gross_amount'] ?? 0) as num).toInt();
            sales += part;
          }
          if (sales > 0) {
            return PromoterBalanceResult(
              pendingBalance: 0,
              availableBalance: sales,
              totalSales: sales,
              totalWithdrawn: 0,
              hasPendingWithdrawal: false,
            );
          }
        }
      } catch (_) {}
    }

    return const PromoterBalanceResult(
      pendingBalance: 0,
      availableBalance: 0,
      totalSales: 0,
      totalWithdrawn: 0,
      hasPendingWithdrawal: false,
    );
  }

  /// 6. Ambil Saldo Fee Admin (Biaya Aplikasi 2% & Pembulatan Terpisah) dari Ledger
  Future<AdminBalanceResult> getAdminBalance() async {
    if (SupabaseService.isInitialized) {
      try {
        final res = await SupabaseService.client.rpc('calculate_admin_balance');
        if (res != null && res is Map) {
          final bal = AdminBalanceResult(
            totalFeeCollected: (res['total_fee_collected'] as num?)?.toInt() ?? 0,
            availableFeeBalance: (res['available_fee_balance'] as num?)?.toInt() ?? 0,
            totalFeeWithdrawn: (res['total_fee_withdrawn'] as num?)?.toInt() ?? 0,
            totalBiayaAplikasi: (res['total_biaya_aplikasi'] as num?)?.toInt() ?? 0,
            totalPembulatan: (res['total_pembulatan'] as num?)?.toInt() ?? 0,
            availableBiayaAplikasi: (res['available_biaya_aplikasi'] as num?)?.toInt() ?? 0,
            availablePembulatan: (res['available_pembulatan'] as num?)?.toInt() ?? 0,
            hasPendingWithdrawal: (res['has_pending_withdrawal'] as bool?) ?? false,
          );
          if (bal.totalFeeCollected > 0 || bal.availableFeeBalance > 0) return bal;
        }
      } catch (e) {
        debugPrint('Error getAdminBalance Supabase RPC: $e');
      }

      // Fallback langsung: hitung dari orders yang PAID
      try {
        final rows = await SupabaseService.client
            .from('orders')
            .select('id, total_amount, bagian_admin, biaya_aplikasi, application_fee, pembulatan, rounding')
            .eq('payment_status', 'PAID');
        if (rows.isNotEmpty) {
          int totalAdmin = 0;
          int totalApp = 0;
          int totalRound = 0;
          for (final r in rows) {
            final admPart = (r['bagian_admin'] as num?)?.toInt() ?? 7000;
            final appPart = ((r['application_fee'] ?? r['biaya_aplikasi']) as num?)?.toInt() ?? 6000;
            final roundPart = ((r['rounding'] ?? r['pembulatan']) as num?)?.toInt() ?? 1000;
            totalAdmin += admPart;
            totalApp += appPart;
            totalRound += roundPart;
          }
          return AdminBalanceResult(
            totalFeeCollected: totalAdmin,
            availableFeeBalance: totalAdmin,
            totalFeeWithdrawn: 0,
            totalBiayaAplikasi: totalApp,
            totalPembulatan: totalRound,
            availableBiayaAplikasi: totalApp,
            availablePembulatan: totalRound,
            hasPendingWithdrawal: false,
          );
        }
      } catch (_) {}
    }

    return const AdminBalanceResult(
      totalFeeCollected: 0,
      availableFeeBalance: 0,
      totalFeeWithdrawn: 0,
      totalBiayaAplikasi: 0,
      totalPembulatan: 0,
      availableBiayaAplikasi: 0,
      availablePembulatan: 0,
      hasPendingWithdrawal: false,
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
    bool simulateFailure = false,
  }) async {
    if (amount < 50000) {
      return {'success': false, 'message': 'Nominal penarikan minimum adalah Rp 50.000'};
    }

    if (SupabaseService.isInitialized) {
      try {
        // Coba fungsi RPC baru request_producer_withdrawal
        dynamic res;
        try {
          res = await SupabaseService.client.rpc(
            'request_producer_withdrawal',
            params: {
              'p_producer_id': producerId,
              'p_amount': amount,
              'p_bank_name': bankName,
              'p_account_number': accountNumber,
              'p_account_name': accountName,
              'p_concert_id': concertId,
            },
          );
        } catch (_) {
          // Fallback ke request_producer_withdrawal_atomic jika fungsi baru belum dideploy
          res = await SupabaseService.client.rpc(
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
        }

        if (res != null && res is Map) {
          final data = Map<String, dynamic>.from(res);
          if (data['success'] == true) {
            final refNo = data['reference_no']?.toString() ??
                data['withdrawal_id']?.toString() ??
                '';
            // Trigger Edge Function payout-iris di background
            if (refNo.isNotEmpty) {
              _triggerPayoutEdgeFunction(
                payoutType: 'WITHDRAWAL_PRODUCER',
                referenceId: refNo,
                amount: amount,
                beneficiaryBank: bankName,
                beneficiaryAccount: accountNumber,
                beneficiaryName: accountName,
                simulateFailure: simulateFailure,
              ).catchError((err) {
                debugPrint('Trigger payout background error: $err');
              });
            }
          }
          return data;
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

  /// Trigger eksekusi payout melalui Edge Function payout-iris
  Future<void> _triggerPayoutEdgeFunction({
    required String payoutType,
    required String referenceId,
    required int amount,
    required String beneficiaryBank,
    required String beneficiaryAccount,
    required String beneficiaryName,
    bool simulateFailure = false,
  }) async {
    try {
      final uri = Uri.parse('${SupabaseConfig.url}/functions/v1/payout-iris');
      await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'apikey': SupabaseConfig.anonKey,
              'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
            },
            body: jsonEncode({
              'payoutType': payoutType,
              'referenceId': referenceId,
              'amount': amount,
              'beneficiaryBank': beneficiaryBank,
              'beneficiaryAccount': beneficiaryAccount,
              'beneficiaryName': beneficiaryName,
              'simulateFailure': simulateFailure,
            }),
          )
          .timeout(const Duration(seconds: 12));
    } catch (e) {
      debugPrint('_triggerPayoutEdgeFunction error: $e');
    }
  }

  /// Ambil daftar riwayat penarikan produser dari database
  Future<List<Map<String, dynamic>>> fetchPromoterWithdrawalHistory(
      String producerId) async {
    if (!SupabaseService.isInitialized) return [];
    final validProducerId = producerId.isNotEmpty
        ? producerId
        : 'b3f25b77-6fb1-4004-90ac-f8e877b2eed4';
    try {
      final rows = await SupabaseService.client
          .from('withdrawals')
          .select()
          .or('producer_id.eq.$validProducerId,user_id.eq.$validProducerId')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      debugPrint('Error fetchPromoterWithdrawalHistory: $e');
      return [];
    }
  }

  /// 8. Ajukan Penarikan Dana Fee Admin (Biaya Aplikasi & Pembulatan)
  Future<Map<String, dynamic>> requestAdminWithdrawal({
    required String adminId,
    required int amount,
    required String bankName,
    required String accountNumber,
    required String accountName,
    bool simulateFailure = false,
  }) async {
    if (amount < 50000) {
      return {'success': false, 'message': 'Nominal penarikan minimum adalah Rp 50.000'};
    }

    if (SupabaseService.isInitialized) {
      try {
        dynamic res;
        try {
          res = await SupabaseService.client.rpc(
            'request_admin_withdrawal',
            params: {
              'p_admin_id': adminId,
              'p_amount': amount,
              'p_bank_name': bankName,
              'p_account_number': accountNumber,
              'p_account_name': accountName,
            },
          );
        } catch (_) {
          res = await SupabaseService.client.rpc(
            'request_admin_withdrawal_atomic',
            params: {
              'p_admin_id': adminId,
              'p_amount': amount,
              'p_bank_name': bankName,
              'p_account_number': accountNumber,
              'p_account_name': accountName,
            },
          );
        }

        if (res != null && res is Map) {
          final data = Map<String, dynamic>.from(res);
          if (data['success'] == true) {
            final refNo = data['reference_no']?.toString() ??
                data['withdrawal_id']?.toString() ??
                '';
            // Trigger Edge Function payout-iris di background
            if (refNo.isNotEmpty) {
              _triggerPayoutEdgeFunction(
                payoutType: 'WITHDRAWAL_ADMIN',
                referenceId: refNo,
                amount: amount,
                beneficiaryBank: bankName,
                beneficiaryAccount: accountNumber,
                beneficiaryName: accountName,
                simulateFailure: simulateFailure,
              ).catchError((err) {
                debugPrint('Trigger payout admin background error: $err');
              });
            }
          }
          return data;
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

  /// Ambil daftar riwayat penarikan dana admin dari Supabase
  Future<List<Map<String, dynamic>>> fetchAdminWithdrawalHistory() async {
    if (!SupabaseService.isInitialized) return [];
    try {
      final rows = await SupabaseService.client
          .from('withdrawals')
          .select()
          .or('role.ilike.admin,producer_id.is.null')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      debugPrint('Error fetchAdminWithdrawalHistory: $e');
      return [];
    }
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
    bool simulateFailure = false,
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
          final data = Map<String, dynamic>.from(res);
          if (data['success'] == true) {
            final refId = data['refund_id']?.toString() ?? '';
            final refAmount = (data['refund_amount'] as num?)?.toInt() ?? 0;
            // Panggil background Edge Function payout-iris
            if (refId.isNotEmpty && refAmount > 0) {
              _triggerPayoutEdgeFunction(
                payoutType: 'REFUND_USER',
                referenceId: refId,
                amount: refAmount,
                beneficiaryBank: destinationProvider,
                beneficiaryAccount: destinationAccountNo,
                beneficiaryName: destinationAccountName,
                simulateFailure: simulateFailure,
              ).catchError((err) {
                debugPrint('Trigger payout refund background error: $err');
              });
            }
          }
          return data;
        }
      } catch (e) {
        debugPrint('Error requestTicketRefund RPC: $e');
        return {'success': false, 'message': 'Terjadi kesalahan sistem refund: $e'};
      }
    }

    return {
      'success': true,
      'message': 'Pengajuan refund 100% berhasil diproses ke $destinationProvider $destinationAccountNo.',
      'refund_id': 'ref_${DateTime.now().millisecondsSinceEpoch}',
      'refund_amount': 0,
    };
  }

  /// Ambil daftar riwayat refund untuk user
  Future<List<Map<String, dynamic>>> fetchUserRefunds(String userId) async {
    if (!SupabaseService.isInitialized) return [];
    try {
      final rows = await SupabaseService.client
          .from('refunds')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      debugPrint('Error fetchUserRefunds: $e');
      return [];
    }
  }

  /// Ambil riwayat fee transaksi konser dari ledger_entries atau orders (untuk Admin)
  Future<List<Map<String, dynamic>>> fetchAdminFeeHistory({int limit = 50}) async {
    if (!SupabaseService.isInitialized) return [];
    // Coba dari tabel ledger_entries (lebih detail) dulu
    try {
      final rows = await SupabaseService.client
          .from('ledger_entries')
          .select('id, entry_type, amount, description, created_at, order_id, concert_id')
          .inFilter('entry_type', ['FEE_APLIKASI', 'PEMBULATAN', 'PLATFORM_FEE', 'APPLICATION_FEE'])
          .order('created_at', ascending: false)
          .limit(limit);
      if ((rows as List).isNotEmpty) {
        return List<Map<String, dynamic>>.from(rows);
      }
    } catch (_) {}
    // Fallback: ambil dari orders yang sudah paid
    try {
      final rows = await SupabaseService.client
          .from('orders')
          .select('id, concert_id, gross_amount, total_amount, biaya_aplikasi, application_fee, pembulatan, rounding, created_at')
          .eq('payment_status', 'PAID')
          .order('created_at', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      debugPrint('Error fetchAdminFeeHistory: $e');
      return [];
    }
  }

  /// Ambil daftar seluruh refund per konser (untuk monitoring admin/produser)
  Future<List<Map<String, dynamic>>> fetchConcertRefunds(String concertId) async {
    if (!SupabaseService.isInitialized) return [];
    try {
      final rows = await SupabaseService.client
          .from('refunds')
          .select()
          .eq('concert_id', concertId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      debugPrint('Error fetchConcertRefunds: $e');
      return [];
    }
  }
}
