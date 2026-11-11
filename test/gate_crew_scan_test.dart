import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:livetix/models/gate_crew_models.dart';
import 'package:livetix/models/ticket_order_model.dart';
import 'package:livetix/screens/gate_crew/gate_crew_main_screen.dart';
import 'package:livetix/services/data_service.dart';
import 'package:livetix/services/gate_crew_service.dart';

void main() {
  setUp(() {
    DataService().logout();
  });

  tearDown(() {
    DataService().logout();
  });

  group('Gate Crew Scanner & Ticket Verification Tests', () {
    test('Verifikasi tiket resmi: berhasil jika konser dan gate sesuai',
        () async {
      final service = GateCrewService();
      const testTicket = UserTicketModel(
        id: 'tck-101',
        bookingCode: 'SWV-VALID-01',
        concertTitle: 'Konser Musik Akbar 2026',
        concertSubtitle: 'Stadion Utama',
        category: 'VIP Gold',
        date: '25 Nov 2026',
        time: '19:00 WIB',
        gate: 'Gate A',
        block: 'VIP-01',
        venue: 'Stadion Utama',
        quantity: 2,
        totalPrice: 1500000,
        status: 'Aktif',
        qrScanQuota: 2,
        qrScansUsed: 0,
      );

      DataService().userTicketsNotifier.value = [testTicket];

      final result = await service.verifyTicketInDatabase(
        scannedCode: 'SWV-VALID-01',
        currentConcertId: 'c1',
        currentGate: 'Gate A',
      );

      expect(result.isValid, isTrue);
      expect(result.status, 'Berhasil');
      expect(result.category, 'VIP Gold');
      expect(result.gateName, 'Gate A');
      expect(result.quota, 2);
      expect(result.used, 0);
      expect(result.remaining, 2);
    });

    test('Verifikasi tiket: ditolak jika salah pos gate', () async {
      final service = GateCrewService();
      const testTicket = UserTicketModel(
        id: 'tck-102',
        bookingCode: 'SWV-GATE-B-01',
        concertTitle: 'Konser Musik Akbar 2026',
        concertSubtitle: 'Stadion Utama',
        category: 'Festival',
        date: '25 Nov 2026',
        time: '19:00 WIB',
        gate: 'Gate B',
        block: 'FEST-01',
        venue: 'Stadion Utama',
        quantity: 1,
        totalPrice: 500000,
        status: 'Aktif',
        qrScanQuota: 1,
        qrScansUsed: 0,
      );

      DataService().userTicketsNotifier.value = [testTicket];

      // Petugas berada di Gate A, tetapi tiket dialokasikan untuk Gate B
      final result = await service.verifyTicketInDatabase(
        scannedCode: 'SWV-GATE-B-01',
        currentConcertId: 'c1',
        currentGate: 'Gate A',
      );

      expect(result.isValid, isFalse);
      expect(result.isWrongGate, isTrue);
      expect(result.status, 'Ditolak (Salah Gate)');
      expect(result.invalidReason, contains('Salah Pos Gate'));
      expect(result.invalidReason, contains('Gate B'));
    });

    test('Verifikasi tiket: ditolak jika kuota multi-scan telah habis',
        () async {
      final service = GateCrewService();
      const testTicket = UserTicketModel(
        id: 'tck-103',
        bookingCode: 'SWV-EXHAUSTED-01',
        concertTitle: 'Konser Musik Akbar 2026',
        concertSubtitle: 'Stadion Utama',
        category: 'Reguler',
        date: '25 Nov 2026',
        time: '19:00 WIB',
        gate: 'Gate A',
        block: 'REG-01',
        venue: 'Stadion Utama',
        quantity: 2,
        totalPrice: 600000,
        status: 'Aktif',
        qrScanQuota: 2,
        qrScansUsed: 2, // Kuota 2 sudah terpakai 2
      );

      DataService().userTicketsNotifier.value = [testTicket];

      final result = await service.verifyTicketInDatabase(
        scannedCode: 'SWV-EXHAUSTED-01',
        currentConcertId: 'c1',
        currentGate: 'Gate A',
      );

      expect(result.isValid, isFalse);
      expect(result.status, 'Ditolak (Habis Kuota)');
      expect(result.remaining, 0);
    });

    test('Verifikasi tiket: ditolak jika status tiket direfund', () async {
      final service = GateCrewService();
      const testTicket = UserTicketModel(
        id: 'tck-104',
        bookingCode: 'SWV-REFUND-01',
        concertTitle: 'Konser Musik Akbar 2026',
        concertSubtitle: 'Stadion Utama',
        category: 'VIP',
        date: '25 Nov 2026',
        time: '19:00 WIB',
        gate: 'Gate A',
        block: 'VIP-02',
        venue: 'Stadion Utama',
        quantity: 1,
        totalPrice: 1000000,
        status: 'Reffund',
        qrScanQuota: 1,
        qrScansUsed: 0,
      );

      DataService().userTicketsNotifier.value = [testTicket];

      final result = await service.verifyTicketInDatabase(
        scannedCode: 'SWV-REFUND-01',
        currentConcertId: 'c1',
        currentGate: 'Gate A',
      );

      expect(result.isValid, isFalse);
      expect(result.status, 'Ditolak (Direfund)');
    });

    test('Eksekusi check-in rombongan (multi-scan) berhasil memperbarui tiket',
        () async {
      final service = GateCrewService();
      const testTicket = UserTicketModel(
        id: 'tck-105',
        bookingCode: 'SWV-GROUP-01',
        concertTitle: 'Konser Musik Akbar 2026',
        concertSubtitle: 'Stadion Utama',
        category: 'Tribun VIP',
        date: '25 Nov 2026',
        time: '19:00 WIB',
        gate: 'Gate A',
        block: 'TRB-01',
        venue: 'Stadion Utama',
        quantity: 4,
        totalPrice: 2000000,
        status: 'Aktif',
        qrScanQuota: 4,
        qrScansUsed: 0,
      );

      DataService().userTicketsNotifier.value = [testTicket];

      final validRes = await service.verifyTicketInDatabase(
        scannedCode: 'SWV-GROUP-01',
        currentConcertId: 'c1',
        currentGate: 'Gate A',
      );

      expect(validRes.isValid, isTrue);
      expect(validRes.remaining, 4);

      // Check-in 2 orang pertama
      await service.executeCheckIn(
        ticket: validRes,
        countToUse: 2,
        gateName: 'Gate A',
        crewId: 'crew-001',
        crewName: 'Petugas Test',
        crewEmail: 'test.crew@livetix.com',
        concertTitle: 'Konser Musik Akbar 2026',
      );

      // Cek sisa kuota setelah check-in
      final updatedRes = await service.verifyTicketInDatabase(
        scannedCode: 'SWV-GROUP-01',
        currentConcertId: 'c1',
        currentGate: 'Gate A',
      );

      expect(updatedRes.isValid, isTrue);
      expect(updatedRes.used, 2);
      expect(updatedRes.remaining, 2);
    });

    testWidgets(
        'GateCrewMainScreen: Kamera aktif, tombol simulasi debug dihilangkan, input manual tersedia',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Setup user login sebagai Gatecrew dengan assignment aktif
      DataService().loginSync('gatecrew@livetix.com', 'password123');

      GateCrewService().teamCrewNotifier.value = [
        GateCrewMemberModel(
          id: '400000',
          name: 'Petugas Gate A',
          email: 'gatecrew@livetix.com',
          phone: '081377889900',
          approvalStatus: 'approved',
          activeAssignment: GateCrewAssignmentModel(
            id: 'cgc-001',
            concertId: 'c1',
            concertTitle: 'Soundwave Fest 2026',
            venue: 'Stadion Utama',
            gateName: 'Gate A',
            assignedAt: DateTime.now(),
          ),
        ),
      ];

      await tester.pumpWidget(const MaterialApp(home: GateCrewMainScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 1. Header Gate Crew Scanner & Banner Konser
      expect(find.text('GATE CREW SCANNER'), findsOneWidget);
      expect(find.text('Soundwave Fest 2026'), findsOneWidget);

      // 2. MobileScanner kamera terpasang
      expect(find.byType(MobileScanner), findsOneWidget);

      // 3. Tombol-tombol simulasi debug telah DIHILANGKAN (Aplikasi Jadi)
      expect(find.text('SIMULASI SCAN TIKET (PENGUJIAN)'), findsNothing);
      expect(find.text('Scan Valid (1 Orang)'), findsNothing);
      expect(find.text('Scan Rombongan (4 Orang)'), findsNothing);
      expect(find.text('Scan Tiket Terpakai (Habis)'), findsNothing);

      // 4. Tombol input manual di AppBar tersedia
      final manualInputBtn = find.byTooltip('Input Kode Manual');
      expect(manualInputBtn, findsOneWidget);

      // Buka dialog input manual
      await tester.tap(manualInputBtn);
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('Input Kode Tiket'), findsOneWidget);
      expect(find.text('Validasi Tiket'), findsOneWidget);
    });
  });
}
