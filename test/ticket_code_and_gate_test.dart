import 'package:flutter_test/flutter_test.dart';
import 'package:livetix/models/concert_model.dart';
import 'package:livetix/models/ticket_order_model.dart';
import 'package:livetix/utils/ticket_code_generator.dart';

void main() {
  group('TicketCodeGenerator Tests', () {
    test('generateSecureTicketCode formats correctly: LTX_NIK_username_tanggalbeli_kodeunik', () {
      final code = TicketCodeGenerator.generateSecureTicketCode(
        nik: '3507123456789012',
        customerName: 'Budi Santoso',
        purchaseDate: DateTime(2026, 11, 20),
        orderId: 'ORD-987654',
      );

      expect(code.startsWith('LTX_3507123456789012_budisantoso_20261120_'), isTrue);
      final parts = code.split('_');
      expect(parts.length, 5);
      expect(parts[0], 'LTX');
      expect(parts[1], '3507123456789012');
      expect(parts[2], 'budisantoso');
      expect(parts[3], '20261120');
      expect(parts[4].length, greaterThanOrEqualTo(6));
    });

    test('generateSecureTicketCode handles null NIK and special characters in name', () {
      final code = TicketCodeGenerator.generateSecureTicketCode(
        nik: null,
        customerName: 'Siti & Co. #1',
        purchaseDate: DateTime(2026, 5, 10),
        orderId: 'ORD-123456',
      );

      final parts = code.split('_');
      expect(parts.length, 5);
      expect(parts[0], 'LTX');
      expect(parts[1].length, 16);
      expect(parts[2], 'sitico1');
      expect(parts[3], '20260510');
    });

    test('resolveGateForTier matches category keywords with producer gates', () {
      final producerGates = [
        'Gate 1 (VIP & VVIP)',
        'Gate 2 (Festival)',
        'Gate 3 (Tribun & Reguler)',
      ];

      // VIP should match Gate 1
      expect(
        TicketCodeGenerator.resolveGateForTier(
          gates: producerGates,
          tierName: 'VIP Exclusive',
        ),
        'Gate 1 (VIP & VVIP)',
      );

      // Festival should match Gate 2
      expect(
        TicketCodeGenerator.resolveGateForTier(
          gates: producerGates,
          tierName: 'Early Bird Festival A',
        ),
        'Gate 2 (Festival)',
      );

      // Tribun should match Gate 3
      expect(
        TicketCodeGenerator.resolveGateForTier(
          gates: producerGates,
          tierName: 'Tribun Barat',
        ),
        'Gate 3 (Tribun & Reguler)',
      );

      // Reguler should match Gate 3
      expect(
        TicketCodeGenerator.resolveGateForTier(
          gates: producerGates,
          tierName: 'Reguler Presale',
        ),
        'Gate 3 (Tribun & Reguler)',
      );

      // Unknown tier falls back to first gate
      expect(
        TicketCodeGenerator.resolveGateForTier(
          gates: producerGates,
          tierName: 'Special Pass',
        ),
        'Gate 1 (VIP & VVIP)',
      );

      // Empty gates list falls back to Gate A
      expect(
        TicketCodeGenerator.resolveGateForTier(
          gates: [],
          tierName: 'VIP',
        ),
        'Gate A',
      );
    });
  });

  group('ConcertModel and UserTicketModel Integration', () {
    test('ConcertModel parses gates correctly from JSON and serializes', () {
      final json = {
        'id': 'c-1',
        'title': 'Soundrenaline 2026',
        'date': '20 Nov 2026',
        'venue': 'GBK',
        'price': 500000,
        'category': 'Rock',
        'gates': ['Gate A (VIP)', 'Gate B (Festival)'],
      };

      final concert = ConcertModel.fromJson(json);
      expect(concert.gates, ['Gate A (VIP)', 'Gate B (Festival)']);
      expect(concert.toJson()['gates'], ['Gate A (VIP)', 'Gate B (Festival)']);
    });

    test('UserTicketModel stores and serializes buyer identity', () {
      const ticket = UserTicketModel(
        id: 't-100',
        bookingCode: 'LTX_3507123456789012_mario_20261120_987XYZ',
        concertTitle: 'Konser Musik',
        concertSubtitle: '20 Nov 2026 · GBK',
        category: 'VIP',
        date: '20 Nov 2026',
        time: '19.00 WIB',
        gate: 'Gate A (VIP)',
        block: 'VIP-01',
        venue: 'GBK',
        quantity: 2,
        totalPrice: 1000000,
        buyerName: 'Mario Pranata',
        buyerEmail: 'mario@example.com',
        buyerNik: '3507123456789012',
      );

      expect(ticket.buyerName, 'Mario Pranata');
      expect(ticket.buyerEmail, 'mario@example.com');
      expect(ticket.buyerNik, '3507123456789012');

      final serialized = ticket.toJson();
      expect(serialized['buyerName'], 'Mario Pranata');
      expect(serialized['buyerEmail'], 'mario@example.com');
      expect(serialized['buyerNik'], '3507123456789012');

      final deserialized = UserTicketModel.fromJson(serialized);
      expect(deserialized.buyerName, 'Mario Pranata');
      expect(deserialized.buyerEmail, 'mario@example.com');
      expect(deserialized.buyerNik, '3507123456789012');
    });
  });
}
