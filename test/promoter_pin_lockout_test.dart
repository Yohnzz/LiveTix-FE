import 'package:flutter_test/flutter_test.dart';
import 'package:livetix/services/promoter_data_service.dart';
import 'package:livetix/utils/pin_hash.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PromoterDataService service;

  setUp(() {
    service = PromoterDataService();
    service.resetProducerVerificationStateForNewAccount('Test Producer');
    service.pinCodeNotifier.value = hashPin('123456');
    service.resetPinLockout();
  });

  group('Producer PIN Authentication & Lockout Tests', () {
    test('Verifikasi PIN benar berhasil dan membuka kunci sesi', () {
      expect(service.isPinUnlockedThisSession, isFalse);
      final ok = service.verifyPin('123456');
      expect(ok, isTrue);
      expect(service.isPinUnlockedThisSession, isTrue);
      expect(service.pinFailedAttemptsNotifier.value, 0);
      expect(service.isPinLockedOut, isFalse);
    });

    test('Verifikasi PIN salah gagal dan meningkatkan hitungan percobaan gagal', () async {
      expect(service.verifyPin('000000'), isFalse);
      expect(service.isPinUnlockedThisSession, isFalse);

      final attempts = await service.recordFailedPinAttempt();
      expect(attempts, 1);
      expect(service.pinFailedAttemptsNotifier.value, 1);
      expect(service.isPinLockedOut, isFalse);
    });

    test('Setelah 5 kali gagal berturut-turut, akun dikunci selama 10 menit (lockout)', () async {
      for (int i = 1; i <= 4; i++) {
        final a = await service.recordFailedPinAttempt();
        expect(a, i);
        expect(service.isPinLockedOut, isFalse);
      }

      // Percobaan ke-5
      final fifthAttempt = await service.recordFailedPinAttempt();
      expect(fifthAttempt, 5);
      expect(service.isPinLockedOut, isTrue);
      expect(service.pinLockedUntilNotifier.value, isNotNull);

      final rem = service.remainingPinLockoutDuration;
      expect(rem.inMinutes <= 10, isTrue);
      expect(rem.inSeconds > 0, isTrue);

      // Selama terkunci, verifyPin harus mengembalikan false bahkan jika PIN benar
      expect(service.verifyPin('123456'), isFalse);
    });

    test('Reset lockout mengembalikan akun ke status normal', () async {
      // Buat akun terkunci
      for (int i = 0; i < 5; i++) {
        await service.recordFailedPinAttempt();
      }
      expect(service.isPinLockedOut, isTrue);

      // Reset
      await service.resetPinLockout();
      expect(service.isPinLockedOut, isFalse);
      expect(service.pinFailedAttemptsNotifier.value, 0);
      expect(service.pinLockedUntilNotifier.value, isNull);

      // Sekarang PIN benar bisa masuk
      expect(service.verifyPin('123456'), isTrue);
    });
  });
}
