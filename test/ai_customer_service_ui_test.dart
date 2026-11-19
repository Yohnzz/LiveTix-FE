import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livetix/screens/promoter/producer_customer_service_screen.dart';
import 'package:livetix/services/customer_service_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AI Customer Service UI Tests', () {
    setUp(() {
      final cs = CustomerServiceService();
      cs.isAiAutoReplyEnabled = false; // Disable auto-reply for deterministic UI tests
    });

    testWidgets('User CS screen shows AI 24/7 badge and quick question chips',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProducerCustomerServiceScreen(
            senderRole: 'User',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check AppBar AI badge
      expect(find.text('AI 24/7'), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome), findsWidgets);

      // Check quick questions for User
      expect(find.text('TOPIK BANTUAN CEPAT:'), findsOneWidget);
      expect(
        find.text('Bagaimana cara scan QR E-Tiket di pintu gate?'),
        findsOneWidget,
      );
      expect(
        find.text('Konser dibatalkan, bagaimana proses refund 100%?'),
        findsOneWidget,
      );
    });

    testWidgets('Producer CS screen shows producer-specific quick question chips',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProducerCustomerServiceScreen(
            senderRole: 'Produser',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AI 24/7'), findsOneWidget);
      expect(find.text('Ketentuan potongan fee platform 2%'), findsOneWidget);
      expect(
        find.text('Syarat dokumen KTP & Lembar Penanggung Jawab'),
        findsOneWidget,
      );
      expect(
        find.text('Bagaimana cara menambah dan menugaskan Gate Crew?'),
        findsOneWidget,
      );
    });

    testWidgets('AI response message displays LiveTix AI Assistant badge',
        (tester) async {
      final cs = CustomerServiceService();
      final thread = cs.ensureThreadForAccount(
        role: 'User',
      );

      // Insert an AI message directly into the active user thread
      await cs.sendMessage(
        threadId: thread.threadId,
        text: 'Ini adalah jawaban otomatis dari asisten AI LiveTix.',
        isFromAdmin: true,
        senderName: 'LiveTix AI Assistant ✨',
        senderRole: 'AI Support',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: ProducerCustomerServiceScreen(
            senderRole: 'User',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('LiveTix AI Assistant ✨'), findsWidgets);
      expect(
        find.text('Ini adalah jawaban otomatis dari asisten AI LiveTix.'),
        findsOneWidget,
      );
    });

    testWidgets('Admin Inbox and Conversation shows AI Copilot bar and actions',
        (tester) async {
      final cs = CustomerServiceService();
      cs.ensureThreadForAccount(
        role: 'Produser',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: ProducerCustomerServiceScreen(
            isAdminInbox: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Admin inbox shows tabs
      expect(find.textContaining('Chat Produser'), findsOneWidget);
      expect(find.textContaining('Chat User'), findsOneWidget);

      // Tap on the first thread card in the ListView
      final threadCard = find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(InkWell),
          )
          .first;
      expect(threadCard, findsOneWidget);
      await tester.tap(threadCard);
      await tester.pumpAndSettle();

      // Verify AI Copilot badge and action buttons
      expect(find.text('AI Copilot'), findsOneWidget);
      expect(find.text('Ringkas Isu AI'), findsOneWidget);
      expect(find.text('Draf Balasan AI'), findsOneWidget);

      // Tap Draf Balasan AI
      await tester.tap(find.text('Draf Balasan AI'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Input field should now contain drafted text
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, isNotEmpty);
    });
  });
}
