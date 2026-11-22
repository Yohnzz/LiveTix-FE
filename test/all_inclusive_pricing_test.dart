import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livetix/models/concert_model.dart';
import 'package:livetix/models/ticket_order_model.dart';

void main() {
  group('All-Inclusive Pricing & Nett Ticket Pricing Tests', () {
    test('calculateUnitAllInclusivePrice: 50.000 base -> 56.000 all-in', () {
      final allIn = TransactionPricing.calculateUnitAllInclusivePrice(50000);
      expect(allIn, 56000);
    });

    test('calculateUnitAllInclusivePrice: 65.500 base -> 74.000 all-in (pembulatan)', () {
      // 65.500 + 6.550 (10%) + 1.310 (2%) = 73.360 -> dibulatkan ke atas per 1.000 = 74.000
      final allIn = TransactionPricing.calculateUnitAllInclusivePrice(65500);
      expect(allIn, 74000);
    });

    test('TransactionPricing: 1 tiket kelipatan konsisten dan invarian 100% terjaga', () {
      final p = TransactionPricing.calculate(50000, 1);
      expect(p.totalPay, 56000);
      expect(p.allInclusiveUnitPrice, 56000);
      expect(p.ticketPrice, 50000);
      expect(p.entertainmentTax, 5000);
      expect(p.applicationFee, 1000);
      expect(p.rounding, 0);
      expect(p.producerShare, 55000);
      expect(p.adminShare, 1000);
      expect(p.producerShare + p.adminShare, p.totalPay);
    });

    test('TransactionPricing: 2 tiket tepat 2x lipat dari harga per tiket (tanpa penambahan acak)', () {
      final p = TransactionPricing.calculate(50000, 2);
      expect(p.totalPay, 112000);
      expect(p.allInclusiveUnitPrice, 56000);
      expect(p.ticketPrice, 100000);
      expect(p.entertainmentTax, 10000);
      expect(p.applicationFee, 2000);
      expect(p.producerShare, 110000);
      expect(p.adminShare, 2000);
      expect(p.producerShare + p.adminShare, p.totalPay);
    });

    test('TicketTierModel: formattedPrice menampilkan harga all-inclusive', () {
      const tier = TicketTierModel(
        id: 'tier-1',
        name: 'VIP Regular',
        description: 'VIP Area',
        price: 50000,
      );
      expect(tier.allInclusivePrice, 56000);
      expect(tier.formattedPrice, 'Rp56.000');
      expect(tier.formattedBasePrice, 'Rp50.000');
    });

    test('ConcertModel: formattedPrice menampilkan harga terendah all-inclusive', () {
      const concert = ConcertModel(
        id: 'c-1',
        title: 'Soundwave Fest 2026',
        subtitle: 'Malang',
        date: '2026-11-25',
        time: '19:00',
        venue: 'Stadion Gajayana',
        price: 50000,
        category: 'Pop',
        tag: 'Trending',
        badgeColor: Color(0xFF1B2A8C),
        iconBgColor: Color(0xFF1B2A8C),
        iconColor: Color(0xFF1B2A8C),
        ticketTiers: [
          TicketTierModel(
            id: 't-1',
            name: 'Regular',
            description: 'Regular',
            price: 50000,
          ),
          TicketTierModel(
            id: 't-2',
            name: 'VIP',
            description: 'VIP',
            price: 100000,
          ),
        ],
      );
      // Tier terendah 50.000 -> all-in 56.000
      expect(concert.allInclusivePrice, 56000);
      expect(concert.formattedPrice, 'Rp56.000');
    });
  });
}
