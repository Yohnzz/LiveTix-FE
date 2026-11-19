import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livetix/models/user_model.dart';
import 'package:livetix/screens/auth/google_verification_screen.dart';
import 'package:livetix/screens/auth/user_verification_screen.dart';
import 'package:livetix/services/data_service.dart';

void main() {
  setUp(() => DataService().logout());
  tearDown(() => DataService().logout());

  group('UserModel status role Google', () {
    test('akun Google dengan status role kosong belum memilih role', () {
      const user = UserModel(
        name: 'Google User',
        email: 'google@email.com',
        phone: '',
        password: '',
        googleId: 'google-123',
      );
      expect(user.isGoogleAccount, isTrue);
      expect(user.hasSelectedRole, isFalse);
    });

    test('status role pending berarti role sudah dipilih', () {
      const user = UserModel(
        name: 'Google Produser',
        email: 'produser@email.com',
        phone: '',
        password: '',
        googleId: 'google-456',
        role: 'Produser',
        roleVerificationStatus: 'pending',
      );
      expect(user.hasSelectedRole, isTrue);
    });
  });

  group('Halaman Verifikasi Google', () {
    const googleUser = UserModel(
      name: 'Sinta Google',
      email: 'sinta.google@email.com',
      phone: '',
      password: '',
      googleId: 'google-789',
    );

    testWidgets('menampilkan info akun dan mewajibkan role dipilih',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(
            home: GoogleVerificationScreen(initialUser: googleUser)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Verifikasi Google'), findsOneWidget);
      expect(find.text('Sinta Google'), findsOneWidget);
      expect(find.text('sinta.google@email.com'), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const Key('google_role_continue_btn')),
      );
      await tester.tap(find.byKey(const Key('google_role_continue_btn')));
      await tester.pumpAndSettle();

      expect(
        find.text('Pilih role akun terlebih dahulu sebelum melanjutkan.'),
        findsOneWidget,
      );
      expect(find.byType(UserVerificationScreen), findsNothing);
    });

    testWidgets('gagal menyimpan role menampilkan error tanpa pindah halaman',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(
            home: GoogleVerificationScreen(initialUser: googleUser)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('google_role_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('User').last);
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('google_role_continue_btn')),
      );
      await tester.tap(find.byKey(const Key('google_role_continue_btn')));
      await tester.pumpAndSettle();

      expect(
          find.textContaining('Sesi Google tidak ditemukan'), findsOneWidget);
      expect(find.byType(UserVerificationScreen), findsNothing);
    });
  });
}
