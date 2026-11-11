import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:livetix/data/db_dummy.dart';
import 'package:livetix/models/concert_model.dart';
import 'package:livetix/models/promoter_models.dart';
import 'package:livetix/models/ticket_order_model.dart';
import 'package:livetix/models/user_model.dart';
import 'package:livetix/screens/admin/admin_dashboard_screen.dart';
import 'package:livetix/screens/checkout/payment_screen.dart';
import 'package:livetix/screens/checkout/select_ticket_screen.dart';
import 'package:livetix/screens/promoter/promoter_manage_concert_screen.dart';
import 'package:livetix/services/admin_service.dart';
import 'package:livetix/services/customer_service_service.dart';
import 'package:livetix/services/data_service.dart';
import 'package:livetix/utils/local_storage.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  tearDown(() {
    DataService().logout();
  });

  test('UserModel reads and writes url_foto and avatar_url consistently', () {
    final user = UserModel.fromJson({
      'id': 'u-999999',
      'name': 'Rudi Santoso',
      'email': 'rudi@mail.com',
      'phone': '08123456789',
      'url_foto':
          'https://arvydukozxjvwwhqnbth.supabase.co/storage/v1/object/public/avatars/u-999999.jpg',
    });

    expect(
      user.avatarUrl,
      'https://arvydukozxjvwwhqnbth.supabase.co/storage/v1/object/public/avatars/u-999999.jpg',
    );
    final json = user.toJson();
    expect(json['url_foto'], user.avatarUrl);
    expect(json['avatar_url'], user.avatarUrl);
  });

  test(
      'TicketTierModel availableStock and local reserve/release deltas update atomically',
      () {
    const tier = TicketTierModel(
      id: 'tier-vip',
      name: 'VIP',
      description: 'Area Depan Panggung',
      price: 500000,
      quota: 10,
      totalQuota: 10,
      soldCount: 3,
      reservedCount: 2,
    );
    expect(tier.availableStock, 5);
    expect(tier.isEffectivelySoldOut, isFalse);

    final depleted = tier.copyWith(soldCount: 8, reservedCount: 2);
    expect(depleted.availableStock, 0);
    expect(depleted.isEffectivelySoldOut, isTrue);

    final dataService = DataService();
    final sampleConcert = dataService.rawConcerts.first;
    final sampleTier = sampleConcert.ticketTiers.first;
    final beforeReserved = sampleTier.reservedCount;
    final beforeAvail = sampleTier.availableStock;

    // Reserve 2 tickets
    dataService.adjustLocalTierStock(
      sampleConcert.id,
      sampleTier.id,
      reservedDelta: 2,
    );
    var updated = dataService.rawConcerts
        .firstWhere((c) => c.id == sampleConcert.id)
        .ticketTiers
        .firstWhere((t) => t.id == sampleTier.id);
    expect(updated.reservedCount, beforeReserved + 2);
    expect(updated.availableStock, beforeAvail - 2);

    // Release 2 reserved tickets back to stock
    dataService.adjustLocalTierStock(
      sampleConcert.id,
      sampleTier.id,
      reservedDelta: -2,
    );
    updated = dataService.rawConcerts
        .firstWhere((c) => c.id == sampleConcert.id)
        .ticketTiers
        .firstWhere((t) => t.id == sampleTier.id);
    expect(updated.reservedCount, beforeReserved);
    expect(updated.availableStock, beforeAvail);
  });

  testWidgets(
      'SelectTicketScreen validates stock and blocks payment when quantity exceeds availableStock',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final dataService = DataService();
    dataService.loginSync('rafi@email.com', '123456');

    const limitedTier = TicketTierModel(
      id: 'tier-limited',
      name: 'Festival Terbatas',
      description: 'Tersedia sedikit',
      price: 300000,
      quota: 10,
      totalQuota: 10,
      soldCount: 7,
      reservedCount: 1, // availableStock = 2
    );

    const concert = ConcertModel(
      id: 'concert-limit-test',
      title: 'Indie Night 2026',
      date: '10 Desember 2026',
      venue: 'Stadion Kridosono',
      price: 300000,
      category: 'Indie',
      ticketTiers: [limitedTier],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: SelectTicketScreen(concert: concert, initialTier: limitedTier),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Tersedia 2 tiket'), findsOneWidget);

    // Increase quantity from 1 -> 2 -> 3 (> availableStock 2)
    final addButton = find.byIcon(Icons.add);
    await tester.ensureVisible(addButton);
    await tester.tap(addButton);
    await tester.pump();
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Maaf, tiket yang tersedia saat ini hanya tersisa 2 tiket. Silakan kurangi jumlah pembelian.',
      ),
      findsOneWidget,
    );

    // Bottom button changes to 'Stok Tidak Cukup' and stays disabled
    expect(find.text('Stok Tidak Cukup'), findsOneWidget);
    final ElevatedButton submitButton = tester.widget(
      find.widgetWithText(ElevatedButton, 'Stok Tidak Cukup'),
    );
    expect(submitButton.onPressed, isNull);
  });

  testWidgets(
      'PaymentScreen allows user to cancel payment with Batalkan Pembayaran and marks ticket Expired/Cancelled',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final dataService = DataService();
    dataService.loginSync('rafi@email.com', '123456');

    final concert = DbDummy.concerts.first;
    final tier = concert.ticketTiers.first;
    final initialReserved = tier.reservedCount;

    // Simulate checkout reserving 2 tickets for 1 hour
    dataService.adjustLocalTierStock(
      concert.id,
      tier.id,
      reservedDelta: 2,
    );

    final order = OrderModel(
      orderId: 'ORD-CANCEL-101',
      concert: concert,
      tier: tier,
      quantity: 2,
      customerName: 'Rafi',
      customerEmail: 'rafi@email.com',
      ticketPrice: tier.price,
      serviceFee: 5000,
      taxAndAdmin: 46500,
      totalAmount: tier.price * 2 + 51500,
      paymentCategory: PaymentCategory.qris,
      paymentProvider: 'QRIS',
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
    );

    await tester.pumpWidget(MaterialApp(home: PaymentScreen(order: order)));
    await tester.pump(const Duration(milliseconds: 200));

    final cancelBtn = find.byKey(const Key('cancel_payment_button'));
    expect(cancelBtn, findsOneWidget);
    await tester.tap(cancelBtn);
    await tester.pumpAndSettle();

    expect(find.text('Batalkan Pembayaran?'), findsOneWidget);
    await tester.tap(find.text('Ya, Batalkan'));
    await tester.pumpAndSettle();

    final cancelledTicket = dataService.userTicketsNotifier.value
        .firstWhere((t) => t.id == 'ORD-CANCEL-101');
    expect(cancelledTicket.status, 'Expired/Cancelled');

    final updatedTier = dataService.rawConcerts
        .firstWhere((c) => c.id == concert.id)
        .ticketTiers
        .firstWhere((t) => t.id == tier.id);
    expect(updatedTier.reservedCount, initialReserved);
  });

  test(
      'DataService concert likes optimistic UI cancels pending debounce timer cleanly on quick unlike',
      () {
    final dataService = DataService();
    dataService.loginSync('rafi@email.com', '123456');

    expect(dataService.isFavorite('concert-like-1'), isFalse);

    // Like immediately sets optimistic state
    dataService.toggleFavorite('concert-like-1');
    expect(dataService.isFavorite('concert-like-1'), isTrue);

    // Unlike within 5 seconds cancels pending debounce timer cleanly
    dataService.toggleFavorite('concert-like-1');
    expect(dataService.isFavorite('concert-like-1'), isFalse);
  });

  testWidgets(
      'PromoterConcertItem defaults to empty gates and PromoterManageConcertScreen shows stock breakdown & gate crew warning',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const concert = PromoterConcertItem(
      id: 'prom-concert-1',
      title: 'Konser Uji Produser',
      dateAndVenue: '20 Des 2026 · ICE BSD',
      date: '20 Des 2026',
      time: '19:00',
      venueName: 'ICE BSD Hall 1',
      venueAddress: 'Tangerang',
      description: 'Konser Uji',
      status: ConcertStatus.disetujui,
      tiers: [
        PromoterTicketTier(
          id: 'pt-1',
          name: 'Tribun',
          price: 250000,
          quota: 100,
          soldCount: 30,
          reservedCount: 10,
        ),
      ],
    );

    // Defaults to empty gates instead of prefilled Gate A/B/C
    expect(concert.gates, isEmpty);
    expect(concert.totalSoldTickets, 30);
    expect(concert.totalReservedTickets, 10);
    expect(concert.remainingTickets, 60);

    final parsedFromJson = PromoterConcertItem.fromJson({
      'id': 'prom-json-1',
      'title': 'Dari DB',
      'event_date': '2026-12-20',
      'venue': 'ICE BSD',
      'status': 'published',
    });
    expect(parsedFromJson.gates, isEmpty);

    await tester.pumpWidget(
      const MaterialApp(
        home: PromoterManageConcertScreen(concert: concert),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Jangan lupa untuk mengisi gate dan invite minimal crew pada setiap gatenya.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Tersedia: 60'), findsOneWidget);
    expect(find.textContaining('Pending: 10'), findsOneWidget);
    expect(find.textContaining('Terjual: 30'), findsOneWidget);
  });

  testWidgets(
      'CustomerServiceService tracks User & Produser threads with receiver metadata and AdminDashboardScreen renders CS shortcut',
      (WidgetTester tester) async {
    LocalStorage.remove('livetix_cs_threads_v2');
    final cs = CustomerServiceService();

    final prodThread = cs.ensureThreadForAccount(
      accountId: 'prod-1',
      accountName: 'Harmony Promotor',
      accountEmail: 'harmony@prod.id',
      role: 'Produser',
    );
    expect(prodThread.userRole, 'Produser');
    expect(prodThread.threadId, 'thread-produser-harmony@prod.id');

    await cs.sendMessage(
      threadId: prodThread.threadId,
      text: 'Halo Admin, butuh verifikasi konser',
      isFromAdmin: false,
      senderName: 'Harmony Promotor',
      senderEmail: 'harmony@prod.id',
      senderRole: 'Produser',
    );

    final latest = cs.getThreadById(prodThread.threadId)!;
    expect(latest.messages.last.receiverRole, 'Admin');
    expect(latest.messages.last.senderRole, 'Produser');
    expect(latest.unreadAdminCount, greaterThan(0));

    await cs.sendMessage(
      threadId: prodThread.threadId,
      text: 'Siap, sedang kami proses.',
      isFromAdmin: true,
    );

    final afterAdminReply = cs.getThreadById(prodThread.threadId)!;
    expect(afterAdminReply.messages.last.isFromAdmin, isTrue);
    expect(afterAdminReply.messages.last.receiverRole, 'Produser');
    expect(afterAdminReply.unreadAdminCount, 0);

    // AdminDashboardScreen displays Customer Service Live card
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    AdminService()
      ..reset()
      ..latency = Duration.zero;
    await tester.runAsync(() => AdminService().load());

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AdminDashboardScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final scrollFinder = find.byType(SingleChildScrollView);
    if (scrollFinder.evaluate().isNotEmpty) {
      await tester.drag(scrollFinder.first, const Offset(0, -300));
      await tester.pump();
    }

    expect(find.text('Customer Service Live'), findsOneWidget);
  });
}
