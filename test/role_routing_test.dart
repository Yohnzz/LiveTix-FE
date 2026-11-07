import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livetix/screens/admin/admin_shell.dart';
import 'package:livetix/screens/auth/login_screen.dart';
import 'package:livetix/screens/gate_crew/gate_crew_main_screen.dart';
import 'package:livetix/screens/home/home_screen.dart';
import 'package:livetix/screens/promoter/promoter_main_screen.dart';
import 'package:livetix/screens/promoter/promoter_pin_lock_screen.dart';
import 'package:livetix/services/admin_service.dart';
import 'package:livetix/services/data_service.dart';

void main() {
  setUp(() {
    DataService().logout();
    AdminService().reset();
    AdminNavigation.reset();
  });

  tearDown(() {
    DataService().logout();
    AdminService().reset();
    AdminNavigation.reset();
  });

  group('Alur Autentikasi dan Routing Berdasarkan Role', () {
    testWidgets('Login sebagai User (Penonton) langsung masuk ke HomeScreen terautentikasi',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      expect(textFields, findsNWidgets(2));

      await tester.enterText(textFields.at(0), 'rafi@email.com');
      await tester.enterText(textFields.at(1), '123456');

      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Masuk'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Masuk'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.text('Rafi Firmansyah'), findsWidgets);
    });

    testWidgets('Login sebagai Produser langsung masuk ke PromoterMainScreen (Portal Produser)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'producer@soundwave.com');
      await tester.enterText(textFields.at(1), 'producer123');

      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Masuk'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Masuk'));
      await tester.pumpAndSettle();

      // Meminta PIN Keamanan 6-Digit terlebih dahulu sebelum masuk ke Portal Produser
      expect(find.byType(PromoterPinLockScreen), findsOneWidget);
      await tester.enterText(find.byType(TextField), '123456');
      await tester.tap(find.text('Buka Aplikasi Produser'));
      await tester.pumpAndSettle();

      expect(find.byType(PromoterMainScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.text('Dasbor'), findsOneWidget);
      expect(find.text('Konser'), findsOneWidget);
      expect(find.text('Keuangan'), findsOneWidget);
      expect(find.text('Profil'), findsOneWidget);
    });

    testWidgets('Login sebagai Admin langsung masuk ke AdminShell (Portal Super Admin)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'admin@livetix.com');
      await tester.enterText(textFields.at(1), 'admin123');

      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Masuk'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Masuk'));
      await tester.pumpAndSettle();

      expect(find.byType(AdminShell), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.text('Halo, Admin'), findsOneWidget);
    });

    testWidgets('Login sebagai Gatecrew langsung masuk ke GateCrewMainScreen',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'gatecrew@livetix.com');
      await tester.enterText(textFields.at(1), 'password123');

      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Masuk'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Masuk'));
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.byType(GateCrewMainScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.text('GATE CREW SCANNER'), findsOneWidget);
    });

    testWidgets('Login sebagai Gatecrew yang belum di-invite menampilkan status belum ada tugas',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'gatecrew2@livetix.com');
      await tester.enterText(textFields.at(1), 'gatecrew123');

      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Masuk'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Masuk'));
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.byType(GateCrewMainScreen), findsOneWidget);
      expect(find.text('Anda Tidak Memiliki Tugas Gate'), findsOneWidget);
    });
  });
}
