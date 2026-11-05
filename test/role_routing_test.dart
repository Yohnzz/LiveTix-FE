import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livetix/screens/admin/admin_shell.dart';
import 'package:livetix/screens/auth/login_screen.dart';
import 'package:livetix/screens/home/home_screen.dart';
import 'package:livetix/screens/promoter/promoter_main_screen.dart';
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

    testWidgets('Uji Coba Cepat 1-Klik Role Penonton auto-fill dan masuk ke HomeScreen',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Role: Penonton / User'));
      await tester.tap(find.text('Role: Penonton / User'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('Rafi Firmansyah'), findsWidgets);
    });

    testWidgets('Uji Coba Cepat 1-Klik Role Produser auto-fill dan masuk ke PromoterMainScreen',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Role: Produser / Promotor'));
      await tester.tap(find.text('Role: Produser / Promotor'));
      await tester.pumpAndSettle();

      expect(find.byType(PromoterMainScreen), findsOneWidget);
    });

    testWidgets('Uji Coba Cepat 1-Klik Role Admin auto-fill dan masuk ke AdminShell',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Role: Super Admin'));
      await tester.tap(find.text('Role: Super Admin'));
      await tester.pumpAndSettle();

      expect(find.byType(AdminShell), findsOneWidget);
      expect(find.text('Halo, Admin'), findsOneWidget);
    });
  });
}
