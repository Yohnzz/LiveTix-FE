import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:livetix/core/ai_config.dart';
import 'package:livetix/services/ai_customer_service.dart';
import 'package:livetix/services/customer_service_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AiConfig Tests', () {
    test('Gemini API key is configured and valid', () {
      final key = AiConfig.geminiApiKey;
      expect(key, isNotEmpty);
      expect(key, contains('AQ.Ab8RN6L0'));
    });

    test('Primary model and fallback models are configured', () {
      expect(AiConfig.primaryModel, isNotEmpty);
      expect(AiConfig.fallbackModels, contains(AiConfig.primaryModel));
      expect(AiConfig.baseUrl, contains('googleapis.com'));
    });
  });

  group('AiCustomerService with MockClient (Simulated Gemini API 200)', () {
    late AiCustomerService aiService;

    setUp(() {
      aiService = AiCustomerService();
      aiService.customClient = MockClient((request) async {
        final bodyStr = request.body;
        final decoded = jsonDecode(bodyStr) as Map<String, dynamic>;
        final contents = decoded['contents'] as List<dynamic>? ?? [];
        final lastMsg = contents.isNotEmpty
            ? ((contents.last['parts'] as List<dynamic>)[0]['text'] as String)
            : '';

        String mockAnswer = 'Jawaban AI LiveTix';
        if (lastMsg.contains('scan')) {
          mockAnswer =
              'Halo! E-tiket dapat langsung di-scan di gate konser tanpa perlu dicetak.';
        } else if (lastMsg.contains('fee')) {
          mockAnswer =
              'Halo Promotor! Potongan fee platform LiveTix adalah 3% per tiket terjual.';
        } else if (lastMsg.contains('ringkas') || lastMsg.contains('riwayat')) {
          mockAnswer =
              'Ringkasan AI: Pengguna bertanya seputar kendala pembayaran tiket.';
        } else if (lastMsg.contains('draf')) {
          mockAnswer =
              'Halo, terima kasih telah menghubungi LiveTix. Kendala Anda sedang kami proses.';
        }

        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': mockAnswer}
                  ],
                  'role': 'model'
                },
                'finishReason': 'STOP'
              }
            ]
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
    });

    tearDown(() {
      aiService.customClient = null;
    });

    test('User CS query parses Gemini candidate response', () async {
      final reply = await aiService.generateCustomerServiceReply(
        userMessage: 'Bagaimana cara scan QR tiket?',
        role: 'User',
        userName: 'Budi',
      );

      expect(reply, contains('scan di gate'));
    });

    test('Producer CS query parses Gemini candidate response', () async {
      final reply = await aiService.generateCustomerServiceReply(
        userMessage: 'Berapa persen potongan fee?',
        role: 'Produser',
        userName: 'Promotor Indie',
      );

      expect(reply, contains('3%'));
    });

    test('Admin thread summarization parses Gemini candidate response', () async {
      final testMessages = [
        CsMessageModel(
          id: 'test-1',
          threadId: 'thread-user-1',
          senderId: 'user-1',
          senderName: 'Andi',
          senderEmail: 'andi@example.com',
          senderRole: 'User',
          isFromAdmin: false,
          message: 'Halo admin, saya bayar via QRIS BCA tapi pending.',
          createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
      ];

      final summary = await aiService.summarizeThread(
        messages: testMessages,
        userRole: 'User',
        userName: 'Andi',
      );

      expect(summary, contains('Ringkasan AI'));
    });

    test('Admin draft reply generation parses Gemini candidate response', () async {
      final testMessages = [
        CsMessageModel(
          id: 'test-2',
          threadId: 'thread-produser-1',
          senderId: 'prod-1',
          senderName: 'Promotor Soundwave',
          senderEmail: 'sound@example.com',
          senderRole: 'Produser',
          isFromAdmin: false,
          message: 'Kapan konser saya diverifikasi?',
          createdAt: DateTime.now().subtract(const Duration(minutes: 2)),
        ),
      ];

      final draft = await aiService.generateAdminDraftReply(
        messages: testMessages,
        userRole: 'Produser',
        userName: 'Promotor Soundwave',
      );

      expect(
        draft,
        anyOf(contains('Tim Support LiveTix'), contains('kami proses')),
      );
    });
  });

  group('AiCustomerService Offline & Fallback Knowledge Base', () {
    late AiCustomerService aiService;

    setUp(() {
      aiService = AiCustomerService();
      // Client throws error / network offline
      aiService.customClient = MockClient((request) async {
        return http.Response('{"error": "rate limit / offline"}', 429);
      });
    });

    tearDown(() {
      aiService.customClient = null;
    });

    test('User fallback answers QR scan questions accurately', () async {
      final reply = await aiService.generateCustomerServiceReply(
        userMessage: 'Bagaimana cara scan QR Tiket Saya?',
        role: 'User',
        userName: 'Rina',
      );
      expect(reply, contains('Tiket Saya'));
      expect(reply, contains('QR Code'));
    });

    test('User fallback answers refund policy questions accurately', () async {
      final reply = await aiService.generateCustomerServiceReply(
        userMessage: 'Apakah bisa refund tiket jika konser batal?',
        role: 'User',
        userName: 'Rina',
      );
      expect(reply, contains('100%'));
      expect(reply, contains('dikembalikan'));
    });

    test('Producer fallback answers verification status accurately', () async {
      final reply = await aiService.generateCustomerServiceReply(
        userMessage: 'Bagaimana status verifikasi dokumen KTP saya?',
        role: 'Produser',
        userName: 'Soundwave',
      );
      expect(reply, contains('KTP'));
      expect(reply, contains('1x24 jam'));
    });

    test('Producer fallback answers withdrawal / saldo questions accurately', () async {
      final reply = await aiService.generateCustomerServiceReply(
        userMessage: 'Berapa minimal tarik saldo dan pencairan dana?',
        role: 'Produser',
        userName: 'Soundwave',
      );
      expect(reply, contains('Rp 50.000'));
      expect(reply, contains('PIN Keamanan'));
    });
  });
}
