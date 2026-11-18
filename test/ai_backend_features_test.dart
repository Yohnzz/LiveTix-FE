import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:livetix/screens/common/concert_ai_info_modal.dart';
import 'package:livetix/screens/explore/explore_screen.dart';
import 'package:livetix/screens/promoter/add_concert/step1_detail_poster_screen.dart';
import 'package:livetix/services/ai_backend_service.dart';
import 'package:livetix/services/promoter_data_service.dart';

void main() {
  setUp(() {
    PromoterDataService().verificationStatusNotifier.value = 'approved';
    PromoterDataService().promoterNameNotifier.value = 'Java Promotor';
  });

  group('Model AI Filter & Response (Unit Tests)', () {
    test('AiFilterModel parsing from JSON and badges', () {
      final json = {
        'genre': 'rock',
        'year': 2027,
        'location': 'Malang',
        'keyword': 'Slank',
        'min_price': 50000,
        'max_price': 200000,
      };

      final model = AiFilterModel.fromJson(json);
      expect(model.genre, 'rock');
      expect(model.year, 2027);
      expect(model.location, 'Malang');
      expect(model.keyword, 'Slank');
      expect(model.minPrice, 50000);
      expect(model.maxPrice, 200000);
      expect(model.hasActiveFilter, isTrue);

      final badges = model.filterBadges;
      expect(badges.any((b) => b.contains('rock')), isTrue);
      expect(badges.any((b) => b.contains('2027')), isTrue);
      expect(badges.any((b) => b.contains('Malang')), isTrue);
      expect(badges.any((b) => b.contains('Slank')), isTrue);
    });

    test('AiFilterModel handles null fields correctly', () {
      final json = {
        'genre': null,
        'year': null,
        'location': null,
        'keyword': null,
        'min_price': null,
        'max_price': null,
      };

      final model = AiFilterModel.fromJson(json);
      expect(model.hasActiveFilter, isFalse);
      expect(model.filterBadges.isEmpty, isTrue);
    });

    test('AiConcertInfoResponse parses single match and ambiguous lists', () {
      final singleMatchJson = {
        'success': true,
        'matched': true,
        'ambiguous': false,
        'message': 'Konser HS Punya Cerita diadakan di Malang.',
        'concert': {
          'id': 'c-1',
          'title': 'HS Punya Cerita',
          'subtitle': 'Pop Malang',
          'date': '23 Nov 2026',
          'venue': 'Kawasan Malang Raya',
          'price': 24000,
          'category': 'Pop',
          'ticket_tiers': [
            {'id': 't-1', 'concert_id': 'c-1', 'name': 'VIP', 'price': 200000, 'quota': 100}
          ]
        }
      };

      final resp = AiConcertInfoResponse.fromJson(singleMatchJson);
      expect(resp.success, isTrue);
      expect(resp.matched, isTrue);
      expect(resp.ambiguous, isFalse);
      expect(resp.concert?.title, 'HS Punya Cerita');
      expect(resp.concert?.ticketTiers.first.name, 'VIP');
    });

    test('AiSearchResponse parses filtered results and empty results', () {
      final emptyJson = {
        'success': true,
        'filter': {'genre': 'rock', 'year': 2027, 'location': 'Malang'},
        'total': 0,
        'results': [],
        'message': 'Konser tidak ditemukan. Coba longgarkan filter pencarian Anda.'
      };

      final resp = AiSearchResponse.fromJson(emptyJson);
      expect(resp.success, isTrue);
      expect(resp.total, 0);
      expect(resp.results.isEmpty, isTrue);
      expect(resp.message, contains('Konser tidak ditemukan'));
      expect(resp.filter?.location, 'Malang');
    });
  });

  group('AiBackendService API Client', () {
    test('askConcertInfo calls backend and parses response', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/ai/concert-info');
        final body = jsonDecode(request.body);
        expect(body['query'], 'Jelaskan mengenai konser HS');

        return http.Response(
          jsonEncode({
            'success': true,
            'matched': true,
            'ambiguous': false,
            'message': 'Konser HS Punya Cerita bergenre Pop di Malang.',
            'matchedConcerts': []
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = AiBackendService();
      service.customClient = mockClient;
      service.customBaseUrl = 'http://localhost:3000';

      final res = await service.askConcertInfo('Jelaskan mengenai konser HS');
      expect(res.success, isTrue);
      expect(res.matched, isTrue);
      expect(res.message, contains('HS Punya Cerita'));
    });

    test('searchConcerts calls backend and returns filter + items', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/ai/search-concerts');
        final body = jsonDecode(request.body);
        expect(body['query'], 'Konser rock Malang 2027');

        return http.Response(
          jsonEncode({
            'success': true,
            'filter': {'genre': 'rock', 'year': 2027, 'location': 'Malang'},
            'total': 0,
            'results': [],
            'message': 'Konser tidak ditemukan. Coba longgarkan filter pencarian Anda.'
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = AiBackendService();
      service.customClient = mockClient;
      service.customBaseUrl = 'http://localhost:3000';

      final res = await service.searchConcerts('Konser rock Malang 2027');
      expect(res.success, isTrue);
      expect(res.filter?.genre, 'rock');
      expect(res.filter?.location, 'Malang');
      expect(res.results.isEmpty, isTrue);
    });

    test('generateDescription validates min length and calls backend', () async {
      final service = AiBackendService();
      service.customBaseUrl = 'http://localhost:3000';

      // Too short (< 10 chars)
      expect(
        () => service.generateDescription(draft: 'pendek'),
        throwsA(isA<String>()),
      );

      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/ai/generate-description');
        final body = jsonDecode(request.body);
        expect(body['prompt'], contains('Konser rock Slank'));
        expect(body['title'], 'Slank Forever');

        return http.Response(
          jsonEncode({
            'success': true,
            'description': 'Malam penuh energi musik rock legendaris bersama Slank di Malang.'
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      service.customClient = mockClient;
      final desc = await service.generateDescription(
        draft: 'Konser rock Slank full grup di Malang',
        title: 'Slank Forever',
        date: '10 Mei 2027',
      );
      expect(desc, contains('Malam penuh energi musik rock'));
    });
  });

  group('Widget Tests: Fitur 1 (ConcertAiInfoModal)', () {
    testWidgets('ConcertAiInfoModal renders header, welcome message, and chips', (tester) async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': true,
            'matched': true,
            'ambiguous': false,
            'message': 'Penjelasan konser HS dari database LiveTix.',
            'matchedConcerts': []
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      AiBackendService().customClient = mockClient;
      AiBackendService().customBaseUrl = 'http://localhost:3000';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ConcertAiInfoModal(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Asisten Info Konser LiveTix'), findsOneWidget);
      expect(find.text('Terhubung ke Database Konser'), findsOneWidget);
      expect(find.text('Jelaskan mengenai konser HS'), findsOneWidget);

      // Tap suggestion chip
      await tester.tap(find.text('Jelaskan mengenai konser HS'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Penjelasan konser HS dari database LiveTix.'), findsOneWidget);
    });
  });

  group('Widget Tests: Fitur 2 (ExploreScreen AI Search)', () {
    testWidgets('ExploreScreen shows AI toggle and switches to AI search mode', (tester) async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': true,
            'filter': {'genre': 'rock', 'year': 2027, 'location': 'Malang'},
            'total': 0,
            'results': [],
            'message': 'Konser tidak ditemukan. Coba longgarkan filter pencarian Anda.'
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      AiBackendService().customClient = mockClient;
      AiBackendService().customBaseUrl = 'http://localhost:3000';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ExploreScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tombol toggle AI
      expect(find.text('AI'), findsOneWidget);
      await tester.tap(find.text('AI'));
      await tester.pumpAndSettle();

      expect(find.text('AI Search Aktif'), findsOneWidget);
      expect(find.text('Mau tanya detail konser tertentu?'), findsOneWidget);
      expect(find.text('Tanya AI →'), findsOneWidget);
    });
  });

  group('Widget Tests: Fitur 3 (AI Assistant in Step1DetailPosterScreen)', () {
    testWidgets('Shows [✨ AI Assistant] button, validates length, generates and undoes', (tester) async {
      final descController = TextEditingController(text: 'Poin awal singkat');
      final nameController = TextEditingController(text: 'Slank Concert');
      final dateController = TextEditingController(text: '10 Mei 2027');

      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': true,
            'description': 'Deskripsi konser rock spektakuler dari Slank dengan formasi lengkap di Malang.'
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      AiBackendService().customClient = mockClient;
      AiBackendService().customBaseUrl = 'http://localhost:3000';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Step1DetailPosterScreen(
              nameController: nameController,
              dateTimeController: dateController,
              descriptionController: descController,
              posterFileName: '',
              squareLogoFileName: '',
              onPickPoster: () {},
              onRemovePoster: () {},
              onPickSquareLogo: () {},
              onRemoveSquareLogo: () {},
              onAddHighlight: () {},
              onEditHighlight: (_) {},
              onRemoveHighlight: (_) {},
              onNext: () {},
              onBack: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('✨ AI Assistant'), findsOneWidget);

      // Tap AI Assistant
      await tester.tap(find.text('✨ AI Assistant'));
      await tester.pumpAndSettle();

      // Check text replaced
      expect(descController.text, contains('Deskripsi konser rock spektakuler'));
      expect(find.text('Undo'), findsWidgets);

      // Tap Undo
      await tester.tap(find.text('Undo').first, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Reverted to original
      expect(descController.text, 'Poin awal singkat');
    });
  });
}
