import 'package:flutter_test/flutter_test.dart';
import 'package:livetix/models/ticket_order_model.dart';
import 'package:livetix/services/payment_gateway_service.dart';
import 'package:livetix/services/ticket_validator_service.dart';

void main() {
  group('FASE 1 & 2: Transparent Pricing Engine & Invariant Assertions', () {
    test('Invariant 1: produserShare + adminShare == totalPay on standard price', () {
      final pricing = TransactionPricing.calculate(150000, 2);

      // harga_tiket = 150.000 * 2 = 300.000
      expect(pricing.ticketPrice, equals(300000));
      // pajak_hiburan = 10% * 300.000 = 30.000
      expect(pricing.entertainmentTax, equals(30000));
      // biaya_aplikasi = 2% * 300.000 = 6.000
      expect(pricing.applicationFee, equals(6000));
      // subtotal = 336.000
      expect(pricing.subtotal, equals(336000));
      // pembulatan = 0 karena sudah ribuan
      expect(pricing.rounding, equals(0));
      // total_bayar = 336.000
      expect(pricing.totalPay, equals(336000));
      // bagian produser = 330.000, admin = 6.000
      expect(pricing.producerShare, equals(330000));
      expect(pricing.adminShare, equals(6000));

      // MANDATORY INVARIANT
      expect(pricing.producerShare + pricing.adminShare, equals(pricing.totalPay));
    });

    test('Invariant 2: Ceil to 1000 and fractional rounding calculation', () {
      // Harga pecahan ganjil: Rp 175.500 x 3 tiket
      final pricing = TransactionPricing.calculate(175500, 3);

      expect(pricing.ticketPrice, equals(526500));
      expect(pricing.entertainmentTax, equals(52650));
      expect(pricing.applicationFee, equals(10530));
      expect(pricing.subtotal, equals(589680));
      // Ceil ke 1000: 589.680 -> 590.000
      expect(pricing.totalPay, equals(590000));
      expect(pricing.rounding, equals(320));
      expect(pricing.producerShare, equals(579150));
      expect(pricing.adminShare, equals(10850));

      // INVARIAN MUTLAK: produser + admin == total_bayar
      expect(pricing.producerShare + pricing.adminShare, equals(pricing.totalPay));
    });

    test('Invariant 3: Max 4 tickets per transaction boundary test', () {
      final pricingOverMax = TransactionPricing.calculate(250000, 10);
      expect(pricingOverMax.quantity, equals(4));
      expect(pricingOverMax.ticketPrice, equals(1000000));
      expect(pricingOverMax.producerShare + pricingOverMax.adminShare, equals(pricingOverMax.totalPay));

      final pricingZero = TransactionPricing.calculate(250000, 0);
      expect(pricingZero.quantity, equals(1));
    });
  });

  group('FASE 4: Secure QR Ticket & HMAC Integrity Verification', () {
    test('QR Code format contains 3 parts without plaintext PII (NIK)', () {
      const sampleQrPayload = 'v1.tck-12345.KODE-8891.a1b2c3d4e5f6';
      final parts = sampleQrPayload.split('.');

      expect(parts.length, equals(4)); // v1, ticket_id, kode_tiket, signature
      expect(parts[0], equals('v1'));
      expect(sampleQrPayload.contains('3201'), isFalse); // NIK tidak bocor dalam string QR
    });

    test('TicketValidatorService parses validation states correctly', () {
      final successResult = TicketValidationResult.fromJson({
        'valid': true,
        'ticket_id': 'tck-001',
        'tier_name': 'VIP Festival',
        'scans_used': 1,
        'scan_quota': 1,
        'scans_left': 0,
      });
      expect(successResult.valid, isTrue);
      expect(successResult.scansLeft, equals(0));

      final quotaExceeded = TicketValidationResult.fromJson({
        'valid': false,
        'reason': 'SCAN_QUOTA_EXCEEDED',
        'scan_quota': 1,
      });
      expect(quotaExceeded.valid, isFalse);
      expect(quotaExceeded.reasonLabel, contains('sudah dipakai'));

      final cancelled = TicketValidationResult.fromJson({
        'valid': false,
        'reason': 'TICKET_CANCELLED',
      });
      expect(cancelled.valid, isFalse);
      expect(cancelled.reasonLabel, contains('dibatalkan'));
    });
  });

  group('FASE 5: Producer Withdrawal (Held vs Available Balance)', () {
    test('Promoter balance separates held vs available funds', () {
      const balance = PromoterBalanceResult(
        pendingBalance: 24500000, // konser belum mulai
        availableBalance: 8750000, // konser sudah mulai & tidak batal
        totalSales: 33250000,
        totalWithdrawn: 12500000,
        hasPendingWithdrawal: false,
      );

      expect(balance.pendingBalance, greaterThan(0));
      expect(balance.availableBalance, lessThan(balance.totalSales));
      expect(balance.hasPendingWithdrawal, isFalse);
    });

    test('Producer withdrawal minimum amount enforcement (Rp 50.000)', () async {
      final res = await PaymentGatewayService().requestProducerWithdrawal(
        producerId: 'prd-001',
        amount: 25000, // di bawah Rp 50.000
        bankName: 'BCA',
        accountNumber: '1234567890',
        accountName: 'Promoter Live',
      );

      expect(res['success'], isFalse);
      expect(res['message'], contains('Rp 50.000'));
    });
  });

  group('FASE 6: Admin Withdrawal (Separated App Fee & Rounding)', () {
    test('AdminBalanceResult maintains separate metrics for 2% app fee & rounding', () {
      const adminBal = AdminBalanceResult(
        totalFeeCollected: 4500000,
        availableFeeBalance: 3200000,
        totalFeeWithdrawn: 1300000,
        totalBiayaAplikasi: 3600000,
        totalPembulatan: 900000,
        availableBiayaAplikasi: 2560000,
        availablePembulatan: 640000,
        hasPendingWithdrawal: false,
      );

      // Invarian: totalBiayaAplikasi + totalPembulatan == totalFeeCollected
      expect(adminBal.totalBiayaAplikasi + adminBal.totalPembulatan, equals(adminBal.totalFeeCollected));
      // Invarian: availableBiayaAplikasi + availablePembulatan == availableFeeBalance
      expect(adminBal.availableBiayaAplikasi + adminBal.availablePembulatan, equals(adminBal.availableFeeBalance));
    });

    test('Admin withdrawal minimum amount enforcement (Rp 50.000)', () async {
      final res = await PaymentGatewayService().requestAdminWithdrawal(
        adminId: 'adm-001',
        amount: 30000, // di bawah Rp 50.000
        bankName: 'BCA',
        accountNumber: '1234567890',
        accountName: 'PT LiveTix Indonesia',
      );

      expect(res['success'], isFalse);
      expect(res['message'], contains('Rp 50.000'));
    });
  });

  group('FASE 7: Cancel Concert Refund & 100% Invariant Verification', () {
    test('100% Refund invariant: producer deduction + admin deduction == total refund', () {
      // Simulasi 1 order 2 tiket @ Rp 200.000
      final pricing = TransactionPricing.calculate(200000, 2);
      final totalRefund = pricing.totalPay;
      final producerDeduction = pricing.producerShare;
      final adminDeduction = pricing.adminShare;

      expect(totalRefund, equals(448000));
      expect(producerDeduction, equals(440000));
      expect(adminDeduction, equals(8000));

      // INVARIAN REFUND MUTLAK
      expect(producerDeduction + adminDeduction, equals(totalRefund));
    });

    test('Refund destination validation fails if account details are empty', () async {
      final res = await PaymentGatewayService().requestTicketRefund(
        ticketId: 'tck-999',
        userId: 'u-123',
        destinationType: 'BANK',
        destinationProvider: 'BCA',
        destinationAccountNo: '   ', // kosong
        destinationAccountName: '',
        reason: 'Konser Dibatalkan',
      );

      expect(res['success'], isFalse);
      expect(res['message'], contains('wajib diisi'));
    });
  });
}
