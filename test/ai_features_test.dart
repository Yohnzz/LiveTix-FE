import 'package:flutter_test/flutter_test.dart';
import 'package:livetix/services/ai_customer_service.dart';
import 'package:livetix/services/ai_backend_service.dart';

void main() {
  group('AiCustomerService User Redirection & Troubleshooting Tests', () {
    final cs = AiCustomerService();

    test('User asking concert info in CS is redirected to Jelajah', () async {
      final reply = await cs.generateCustomerServiceReply(
        userMessage: 'Ada konser apa aja ya min?',
        role: 'User',
      );
      expect(reply.toLowerCase(), contains('jelajah'));
      expect(reply.toLowerCase(), contains('bantuan kendala'));
    });

    test('User asking artist lineup in CS is redirected to Jelajah', () async {
      final reply = await cs.generateCustomerServiceReply(
        userMessage: 'Siapa artis yang tampil di konser tulus?',
        role: 'User',
      );
      expect(reply.toLowerCase(), contains('jelajah'));
    });

    test('User asking concert recommendation in CS is redirected to Jelajah', () async {
      final reply = await cs.generateCustomerServiceReply(
        userMessage: 'Rekomendasi konser pop dong',
        role: 'User',
      );
      expect(reply.toLowerCase(), contains('jelajah'));
    });

    test('User asking troubleshooting (payment issue) receives support steps', () async {
      final reply = await cs.generateCustomerServiceReply(
        userMessage: 'Saya sudah bayar qris tapi tiket belum muncul',
        role: 'User',
      );
      expect(reply.toLowerCase(), contains('tiket'));
      expect(reply.toLowerCase(), contains('order id'));
    });

    test('User asking QR scan troubleshooting receives guide', () async {
      final reply = await cs.generateCustomerServiceReply(
        userMessage: 'Bagaimana cara scan QR tiket di gate?',
        role: 'User',
      );
      expect(reply.toLowerCase(), contains('tiket saya'));
      expect(reply.toLowerCase(), contains('qr'));
    });
  });

  group('AiBackendService Model & Parsing Tests', () {
    test('AiFilterModel parses fields properly and generates badges', () {
      const filter = AiFilterModel(
        genre: 'Rock',
        year: 2027,
        location: 'Malang',
        keyword: 'Slank',
        maxPrice: 150000,
      );
      expect(filter.hasActiveFilter, isTrue);
      expect(filter.filterBadges.length, 5);
      expect(filter.filterBadges, contains('Tema: Rock'));
      expect(filter.filterBadges, contains('Tahun: 2027'));
      expect(filter.filterBadges, contains('Lokasi: Malang'));
      expect(filter.filterBadges, contains('Artis: "Slank"'));
    });

    test('AiSearchResponse fallback guarantees data output', () async {
      final service = AiBackendService();
      // Searching query that tests fallback local logic
      final res = await service.searchConcerts('konser rock');
      expect(res.success, isTrue);
      expect(res.message, isNotEmpty);
    });
  });
}
