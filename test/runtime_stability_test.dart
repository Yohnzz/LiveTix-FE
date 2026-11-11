import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:livetix/main.dart';
import 'package:livetix/models/concert_model.dart';
import 'package:livetix/models/promoter_models.dart';
import 'package:livetix/models/ticket_order_model.dart';
import 'package:livetix/screens/admin/admin_shell.dart';
import 'package:livetix/screens/checkout/payment_screen.dart';
import 'package:livetix/screens/checkout/select_ticket_screen.dart';
import 'package:livetix/screens/concert/concert_detail_screen.dart';
import 'package:livetix/screens/splash_screen.dart';
import 'package:livetix/screens/ticket/ticket_screen.dart';
import 'package:livetix/services/admin_service.dart';
import 'package:livetix/services/data_service.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    DataService().logout();
    AdminService()
      ..reset()
      ..latency = Duration.zero;
    AdminNavigation.reset();
  });

  tearDown(() {
    DataService().logout();
    AdminService().reset();
    AdminNavigation.reset();
  });

  group('Stabilitas Runtime Supabase & Flutter Web', () {
    testWidgets('Route awal /admin aman untuk guest dan langsung ke AdminShell saat admin login',
        (tester) async {
      tester.binding.platformDispatcher.defaultRouteNameTestValue = '/admin';
      addTearDown(tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);

      // 1. Guest membuka /admin: tidak error route, diarahkan ke SplashScreen
      await tester.pumpWidget(const LiveTixApp());
      expect(tester.takeException(), isNull);
      expect(find.byType(SplashScreen), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // 2. Admin sudah login membuka /admin: langsung masuk AdminShell
      DataService().loginSync('admin1@gmail.com', 'admin123');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(const LiveTixApp());
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(AdminShell), findsOneWidget);
    });

    testWidgets(
        'stockVersionNotifier dan PaymentScreen tidak memicu setState during build maupun fetch loop',
        (tester) async {
      DataService().loginSync('rafi@email.com', '123456');
      final concert = DataService().rawConcerts.first;
      final tier = concert.ticketTiers.isNotEmpty
          ? concert.ticketTiers.first
          : const TicketTierModel(
              id: 'vip-test',
              name: 'VIP',
              description: 'Tiket VIP',
              price: 350000,
              totalQuota: 100,
            );

      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: [
              const TicketScreen(isGuest: false),
              ConcertDetailScreen(concert: concert, isGuest: false),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Simulasikan update stockVersionNotifier berulang (seperti Realtime / adjustLocalTierStock)
      final beforeVersion = DataService().stockVersionNotifier.value;
      DataService().adjustLocalTierStock(concert.id, tier.id, reservedDelta: 1);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(DataService().stockVersionNotifier.value, beforeVersion + 1);

      // Navigasi ke SelectTicketScreen lalu ke PaymentScreen sementara TicketScreen masih aktif
      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: [
              const TicketScreen(isGuest: false),
              SelectTicketScreen(concert: concert, initialTier: tier),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      DataService().adjustLocalTierStock(concert.id, tier.id, reservedDelta: 1);
      await tester.pump();
      expect(tester.takeException(), isNull);

      final order = OrderModel(
        orderId: 'ORD-999111',
        concert: concert,
        tier: tier,
        quantity: 1,
        customerName: 'Rafi',
        customerEmail: 'rafi@email.com',
        ticketPrice: tier.price,
        serviceFee: 15000,
        taxAndAdmin: 10000,
        totalAmount: tier.price + 25000,
        expiresAt: DateTime.now().add(const Duration(minutes: 45)),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: [
              const TicketScreen(isGuest: false),
              PaymentScreen(order: order),
            ],
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);

      await tester.pump(const Duration(milliseconds: 50));
      expect(
        DataService()
            .userTicketsNotifier
            .value
            .any((t) => t.id == 'ORD-999111'),
        isTrue,
      );

      // Logout aman tanpa melempar exception sinkron
      DataService().logout();
      expect(DataService().currentUser, isNull);
    });

    test('PromoterConcertItem.toJson tidak menduplikasi data:image base64 raksasa ke banyak kolom',
        () {
      const sampleBase64 = 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD/';
      const item = PromoterConcertItem(
        id: 'concert-test-1',
        title: 'Konser Uji',
        dateAndVenue: 'Sabtu · Malang',
        date: '12 Des 2026',
        venueName: 'Stadion Rampal',
        venueAddress: 'Jl. Panglima Sudirman, Malang',
        posterFileName: 'poster.jpg',
        posterDataUrl: sampleBase64,
        squareLogoFileName: 'logo.jpg',
        squareLogoDataUrl: sampleBase64,
        status: ConcertStatus.menunggu,
        likesCount: '0',
        tiers: [],
      );

      final json = item.toJson();
      expect(json['banner_image_url'], sampleBase64);
      expect(json['logo_image_url'], sampleBase64);
      expect(json.containsKey('poster_data_url'), isFalse);
      expect(json.containsKey('square_logo_data_url'), isFalse);
      expect(json.containsKey('square_logo_url'), isFalse);
    });
  });
}
