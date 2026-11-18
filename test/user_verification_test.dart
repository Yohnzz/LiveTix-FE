import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livetix/models/user_model.dart';
import 'package:livetix/screens/auth/login_screen.dart';
import 'package:livetix/screens/auth/user_verification_screen.dart';
import 'package:livetix/screens/home/home_screen.dart';
import 'package:livetix/services/data_service.dart';

void main() {
  setUp(() => DataService().logout());
  tearDown(() => DataService().logout());

  group('UserModel verifikasi identitas', () {
    test('User tanpa NIK 16 digit dianggap belum terverifikasi', () {
      const user = UserModel(
        name: 'Baru',
        email: 'baru@email.com',
        phone: '0812',
        password: 'x',
        nik: '123',
        isVerified: true,
      );
      expect(user.isIdentityVerified, isFalse);
    });

    test('User dengan NIK 16 digit dan flag verified dianggap terverifikasi', () {
      const user = UserModel(
        name: 'Rafi',
        email: 'rafi@email.com',
        phone: '0812',
        password: 'x',
        nik: '3573011205950001',
        isVerified: true,
      );
      expect(user.isIdentityVerified, isTrue);
    });

    test('fromJson membaca nik dan is_verified', () {
      final user = UserModel.fromJson({
        'id': 'u1',
        'name': 'Rafi',
        'role': 'User',
        'nik': '3573011205950001',
        'is_verified': true,
      });
      expect(user.isIdentityVerified, isTrue);
      expect(user.nik, '3573011205950001');
    });
  });

  group('Routing User berdasarkan verifikasi', () {
    test('resolveUserEntryScreen: belum verifikasi -> UserVerificationScreen', () {
      const unverified = UserModel(
        name: 'Baru',
        email: 'baru@email.com',
        phone: '0812',
        password: 'x',
      );
      expect(resolveUserEntryScreen(unverified), isA<UserVerificationScreen>());
    });

    test('resolveUserEntryScreen: sudah verifikasi -> HomeScreen', () {
      const verified = UserModel(
        name: 'Rafi',
        email: 'rafi@email.com',
        phone: '0812',
        password: 'x',
        nik: '3573011205950001',
        isVerified: true,
      );
      expect(resolveUserEntryScreen(verified), isA<HomeScreen>());
    });

    testWidgets(
        'Login User baru wajib isi NIK dan Nama Lengkap sebelum masuk Beranda',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'penonton.baru@email.com');
      await tester.enterText(fields.at(1), 'password123');
      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Masuk'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Masuk'));
      await tester.pumpAndSettle();

      expect(find.byType(UserVerificationScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);

      final submit = find.byKey(const Key('user_verification_submit_btn'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('NIK wajib diisi'), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);

      await tester.enterText(
          find.byKey(const Key('user_verification_nik_field')), '12345');
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('NIK harus tepat 16 digit angka'), findsOneWidget);

      await tester.enterText(
          find.byKey(const Key('user_verification_nik_field')),
          '3573011205950009');
      await tester.enterText(
          find.byKey(const Key('user_verification_name_field')),
          'Penonton Baru');
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(DataService().currentUser?.nik, '3573011205950009');
      expect(DataService().currentUser?.isIdentityVerified, isTrue);
    });
  });
}

