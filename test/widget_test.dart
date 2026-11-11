import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:livetix/core/app_colors.dart';
import 'package:livetix/data/db_dummy.dart';
import 'package:livetix/models/ticket_order_model.dart';
import 'package:livetix/models/user_model.dart';
import 'package:livetix/screens/auth/forgot_password_screen.dart';
import 'package:livetix/screens/auth/login_screen.dart';
import 'package:livetix/screens/auth/otp_screen.dart';
import 'package:livetix/screens/auth/reset_password_screen.dart';
import 'package:livetix/screens/checkout/order_summary_screen.dart';
import 'package:livetix/screens/checkout/payment_method_screen.dart';
import 'package:livetix/screens/checkout/payment_screen.dart';
import 'package:livetix/screens/checkout/payment_success_screen.dart';
import 'package:livetix/screens/concert/concert_detail_screen.dart';
import 'package:livetix/screens/explore/explore_screen.dart';
import 'package:livetix/screens/home/home_screen.dart';
import 'package:livetix/screens/home/widgets/concert_card.dart';
import 'package:livetix/screens/home/widgets/featured_concert_card.dart';
import 'package:livetix/screens/profile/edit_profile_screen.dart';
import 'package:livetix/screens/profile/profile_screen.dart';
import 'package:livetix/screens/profile/refund_payment_method_screen.dart';
import 'package:livetix/screens/ticket/ticket_screen.dart';
import 'package:livetix/services/data_service.dart';
import 'package:livetix/utils/gate_qr_image_generator.dart';
import 'package:livetix/utils/local_storage.dart';
import 'package:livetix/utils/photo_picker.dart';
import 'package:livetix/utils/qr_share.dart';
import 'package:livetix/widgets/concert_media.dart';
import 'package:livetix/widgets/custom_checkbox.dart';
import 'package:livetix/widgets/qr_code_view.dart';
import 'package:livetix/widgets/user_avatar.dart';

// 1x1 piksel PNG transparan valid untuk pengujian gambar profil & media konser produser
final Uint8List _kSamplePngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  tearDown(() {
    PhotoPicker.testOverride = null;
    QrShare.testOverride = null;
    DataService().logout();
  });

  testWidgets('ExploreScreen filters (Tanggal + Today, Harga ranges, Kota #C654C3 shadow)',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: ExploreScreen(isGuest: true)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    // 1. Hanya tombol Tanggal dan Harga di baris filter atas (tidak ada dropdown Kota/Genre)
    expect(find.byIcon(Icons.location_on_outlined), findsNothing);
    expect(find.byIcon(Icons.music_note_outlined), findsNothing);
    expect(find.text('Tanggal'), findsOneWidget);
    expect(find.text('Harga'), findsOneWidget);

    // 2. Tidak ada penulisan jumlah event di tombol Kota Populer
    expect(find.textContaining('128 event'), findsNothing);
    expect(find.textContaining('342 event'), findsNothing);
    expect(find.textContaining('210 event'), findsNothing);

    // 3. Klik tombol kota Malang -> muncul efek shadow belakang berwarna #C654C3
    await tester.tap(find.text('Malang'));
    await tester.pumpAndSettle();
    expect(find.text('Semua Kota'), findsOneWidget);

    final animatedContainers = tester.widgetList<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    final hasC654C3Shadow = animatedContainers.any((container) {
      final decoration = container.decoration;
      if (decoration is BoxDecoration && decoration.boxShadow != null) {
        return decoration.boxShadow!.any(
          (s) => s.color == AppColors.citySelectedShadow,
        );
      }
      return false;
    });
    expect(hasC654C3Shadow, isTrue);

    // Reset kota lewat tombol Semua Kota
    await tester.tap(find.text('Semua Kota'));
    await tester.pumpAndSettle();

    // 4. Klik filter Tanggal -> buka dialog kalender -> klik Today -> Pilih
    await tester.tap(find.text('Tanggal'));
    await tester.pumpAndSettle();
    expect(find.text('Pilih Tanggal Konser'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);

    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pilih'));
    await tester.pumpAndSettle();

    // Buka kembali dialog Tanggal -> klik Hapus untuk hapus filter tanggal
    await tester.tap(find.byIcon(Icons.calendar_month_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(find.text('Tanggal'), findsOneWidget);

    // 5. Klik filter Harga -> uji semua opsi rentang harga
    await tester.tap(find.text('Harga'));
    await tester.pumpAndSettle();
    expect(find.text('Termurah (< Rp50.000)'), findsOneWidget);
    expect(find.text('Rp50.000 - Rp150.000'), findsOneWidget);
    expect(find.text('Rp151.000 - Rp200.000'), findsOneWidget);
    expect(find.text('Termahal (> Rp200.000)'), findsOneWidget);

    await tester.tap(find.text('Termurah (< Rp50.000)'));
    await tester.pumpAndSettle();
    expect(find.text('Termurah < Rp50.000'), findsOneWidget);
    expect(find.text('Senja Akustik Braga'), findsOneWidget);

    await tester.tap(find.text('Termurah < Rp50.000'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rp50.000 - Rp150.000'));
    await tester.pumpAndSettle();
    expect(find.text('Jakarta Pop Weekend'), findsOneWidget);

    await tester.tap(find.text('Rp50.000 - Rp150.000'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rp151.000 - Rp200.000'));
    await tester.pumpAndSettle();
    expect(find.text('Nadin Amizah'), findsOneWidget);

    await tester.tap(find.text('Rp151.000 - Rp200.000'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Termahal (> Rp200.000)'));
    await tester.pumpAndSettle();
    expect(find.text('Termahal > Rp200.000'), findsOneWidget);
    expect(find.text('We The Fest Surabaya Showcase'), findsOneWidget);

    // Reset semua filter
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(find.text('Harga'), findsOneWidget);
  });

  testWidgets('ProfileScreen Guest hanya menampilkan Masuk ke Akun & ikon GuestAvatarIcon',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: ProfileScreen(isGuest: true)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GuestAvatarIcon), findsOneWidget);
    expect(find.text('Guest'), findsOneWidget);
    expect(find.text('Belum masuk akun'), findsOneWidget);
    expect(find.text('Masuk ke Akun'), findsOneWidget);

    // Semua menu khusus user yang sudah login tidak tampil pada Guest
    expect(find.text('Tiket dibeli'), findsNothing);
    expect(find.text('Konser dihadiri'), findsNothing);
    expect(find.text('Ulasan'), findsNothing);
    expect(find.text('AKUN'), findsNothing);
    expect(find.text('Edit profil'), findsNothing);
    expect(find.text('Metode pembayaran'), findsNothing);
    expect(find.text('Notifikasi'), findsNothing);
    expect(find.text('PREFERENSI'), findsNothing);
    expect(find.text('Mode tampilan'), findsNothing);
    expect(find.text('LAINNYA'), findsNothing);

    // Klik Masuk ke Akun -> navigasi ke LoginScreen
    await tester.tap(find.text('Masuk ke Akun'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('PaymentScreen tidak mengalami RenderFlex overflow pada layar sempit (320px & 358px)',
      (WidgetTester tester) async {
    final sampleConcert = DbDummy.concerts.first;
    final sampleOrder = OrderModel(
      orderId: 'ORD-TEST-01',
      concert: sampleConcert,
      tier: sampleConcert.ticketTiers.first,
      quantity: 1,
      customerName: 'Rafi Firmansyah',
      customerEmail: 'rafi@email.com',
      ticketPrice: 220000,
      serviceFee: 15000,
      taxAndAdmin: 28500,
      totalAmount: 263500,
    );

    for (final width in [320.0, 358.0, 375.0]) {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.15)),
          child: MaterialApp(home: PaymentScreen(order: sampleOrder)),
        ),
      );
      await tester.pump();

      expect(find.text('Virtual Account'), findsOneWidget);
      expect(find.text('Menunggu pembayaran'), findsOneWidget);
      expect(find.text('Saya Sudah Bayar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }

    await tester.tap(find.text('Salin').first);
    await tester.pump();
    expect(find.textContaining('berhasil disalin ke clipboard'), findsOneWidget);

    tester.view.reset();
  });

  testWidgets(
      'EditProfileScreen mendukung Edit Nama, Ganti Foto Profil, dan 2 Alur Ganti Password (Password Lama & Lupa Password)',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(375, 840);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    PhotoPicker.testOverride = () async => _kSamplePngBytes;
    final dataService = DataService();
    dataService.resetPasswordByEmail(email: 'rafi@email.com', newPassword: '123456');
    final loggedInUser = dataService.loginSync('rafi@email.com', '123456');
    expect(loggedInUser, isNotNull);

    await tester.pumpWidget(
      const MaterialApp(
        home: ProfileScreen(
          isGuest: false,
          userName: 'Rafi Firmansyah',
          userEmail: 'rafi@email.com',
          userInitials: 'RF',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Default tema awal pada dummy data adalah Dark
    expect(find.text('Dark'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('Light'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('Dark'), findsOneWidget);

    await tester.tap(find.text('Edit profil'));
    await tester.pumpAndSettle();
    expect(find.byType(EditProfileScreen), findsOneWidget);

    // 1. Uji Ganti Foto Profil (unggah dari perangkat + pilih tema avatar)
    await tester.tap(find.text('Ganti Foto Profil'));
    await tester.pumpAndSettle();
    expect(find.text('Pilih Foto dari Perangkat'), findsOneWidget);

    await tester.tap(find.text('Pilih Foto dari Perangkat'));
    await tester.pumpAndSettle();
    expect(dataService.currentUser?.profileImageBytes, isNotNull);
    expect(find.text('Foto profil berhasil diperbarui'), findsWidgets);

    await tester.tap(find.text('Ganti Foto Profil'));
    await tester.pumpAndSettle();
    expect(find.text('Hapus Foto Profil'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Tema Biru Panggung'));
    await tester.pumpAndSettle();
    expect(dataService.currentUser?.profileImageBytes, isNull);
    expect(dataService.currentUser?.avatarColorIndex, equals(1));

    // 2. Uji Edit Nama
    final nameField = find.widgetWithText(TextFormField, 'Rafi Firmansyah');
    await tester.enterText(nameField, 'Rafi Pratama');
    await tester.tap(find.text('Simpan Nama'));
    await tester.pumpAndSettle();
    expect(dataService.currentUser?.name, equals('Rafi Pratama'));
    expect(find.text('Nama profil berhasil diperbarui'), findsWidgets);

    // 3. Uji Ganti Password - Alur 1: [Masukkan password lama - Password Baru - Confirm Password] -> Done
    await tester.ensureVisible(find.text('Ganti Password'));
    await tester.tap(find.text('Ganti Password'));
    await tester.pumpAndSettle();

    final oldPassField = find.byKey(const Key('old_password_field'));
    final newPassField = find.byKey(const Key('new_password_field'));
    final confirmPassField = find.byKey(const Key('confirm_password_field'));

    await tester.enterText(oldPassField, 'salah99');
    await tester.enterText(newPassField, 'konser99');
    await tester.enterText(confirmPassField, 'konser99');
    await tester.ensureVisible(find.text('Simpan Password'));
    await tester.tap(find.text('Simpan Password'));
    await tester.pumpAndSettle();
    expect(find.text('Password lama tidak sesuai'), findsOneWidget);

    await tester.enterText(oldPassField, '123456');
    await tester.enterText(newPassField, 'konser99');
    await tester.enterText(confirmPassField, 'konser99');
    await tester.tap(find.text('Simpan Password'));
    await tester.pumpAndSettle();

    expect(dataService.currentUser?.password, equals('konser99'));
    expect(find.byKey(const Key('old_password_field')), findsNothing);
    expect(find.text('Kata sandi berhasil diperbarui'), findsWidgets);

    // 4. Uji Ganti Password - Alur 2: Klik Ganti Password -> Lupa Password? -> Verifikasi Email & Kode OTP -> Done
    await tester.ensureVisible(find.text('Ganti Password'));
    await tester.tap(find.text('Ganti Password'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Lupa Password?'));
    await tester.tap(find.text('Lupa Password?'));
    await tester.pumpAndSettle();

    expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    await tester.tap(find.text('Kirim Kode Verifikasi'));
    await tester.pumpAndSettle();

    expect(find.byType(OtpScreen), findsOneWidget);
    final otpFields = find.descendant(
      of: find.byType(OtpScreen),
      matching: find.byType(TextField),
    );
    expect(otpFields, findsNWidgets(6));
    for (int i = 0; i < 6; i++) {
      await tester.enterText(otpFields.at(i), '${i + 1}');
    }
    await tester.tap(find.text('Verifikasi Kode'));
    await tester.pumpAndSettle();

    expect(find.byType(ResetPasswordScreen), findsOneWidget);
    final resetFields = find.descendant(
      of: find.byType(ResetPasswordScreen),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(resetFields.at(0), 'pulih2026');
    await tester.enterText(resetFields.at(1), 'pulih2026');
    await tester.ensureVisible(find.text('Simpan Kata Sandi'));
    await tester.tap(find.text('Simpan Kata Sandi'));
    await tester.pumpAndSettle();

    expect(find.byType(EditProfileScreen), findsOneWidget);
    expect(dataService.currentUser?.password, equals('pulih2026'));

    await tester.tap(find.byTooltip('Kembali ke profil'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('Rafi Pratama'), findsOneWidget);

    dataService.updateProfile(name: 'Rafi Firmansyah', avatarColorIndex: -1);
    dataService.resetPasswordByEmail(email: 'rafi@email.com', newPassword: '123456');
  });

  testWidgets(
      'Agreement hanya tampil sekali jika belum disetujui, dan tidak tampil lagi setelah disetujui (LocalStorage & DataService)',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final dataService = DataService();
    dataService.setAgreementStatus(false);
    expect(dataService.hasAcceptedAgreement, isFalse);

    // Kunjungan pertama: AgreementDialog tampil
    await tester.pumpWidget(
      const MaterialApp(home: HomeScreen(isGuest: true)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(find.text('Permohonan dan persetujuan'), findsOneWidget);
    expect(find.byType(GuestAvatarIcon), findsOneWidget);

    // Centang persetujuan & klik Lanjutkan
    await tester.tap(find.byType(AppCheckbox));
    await tester.pump();
    await tester.tap(find.text('Lanjutkan'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Permohonan dan persetujuan'), findsNothing);
    expect(dataService.hasAcceptedAgreement, isTrue);
    expect(LocalStorage.getBool(LocalStorage.agreementAcceptedKey), isTrue);

    // Kunjungan kedua (misal kembali ke HomeScreen Guest / muat ulang): tidak muncul lagi
    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(key: ValueKey('second_visit'), isGuest: true),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(find.text('Permohonan dan persetujuan'), findsNothing);
  });

  testWidgets(
      'Dashboard Beranda: indikator carousel rata tengah tanpa 1/5 & pause, Konser Trending maks 5 terfilter, tombol Lihat Semua ke Jelajah, serta media Produser',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(375, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final dataService = DataService();
    dataService.setAgreementStatus(true);

    // Simulasikan unggahan gambar highlight persegi panjang & logo persegi dari Produser
    dataService.updateConcertMedia(
      concertId: 'featured-1',
      bannerImageBytes: _kSamplePngBytes,
      logoImageBytes: _kSamplePngBytes,
    );
    addTearDown(() {
      dataService.updateConcertMedia(
        concertId: 'featured-1',
        clearBannerImage: true,
        clearLogoImage: true,
      );
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(
          isGuest: true,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    // 1. Carousel Highlight: penomoran 1/5 dan tombol pause sudah dihapus, indikator rata tengah
    expect(find.byType(FeaturedConcertCarousel), findsOneWidget);
    expect(find.text('1/5'), findsNothing);
    expect(find.text('5/5'), findsNothing);
    expect(find.byTooltip('Jeda geser otomatis'), findsNothing);
    expect(find.bySemanticsLabel('Slide highlight 1'), findsOneWidget);

    final indicatorRow = tester.widget<Row>(
      find.ancestor(
        of: find.bySemanticsLabel('Slide highlight 1'),
        matching: find.byType(Row),
      ).first,
    );
    expect(indicatorRow.mainAxisAlignment, equals(MainAxisAlignment.center));

    // Pastikan kelima titik indikator berjajar horizontal sebaris (inline, dy identik & dx naik)
    final dotCenters = List.generate(
      5,
      (idx) => tester.getCenter(find.bySemanticsLabel('Slide highlight ${idx + 1}')),
    );
    for (int i = 1; i < dotCenters.length; i++) {
      expect(dotCenters[i].dy, equals(dotCenters[0].dy));
      expect(dotCenters[i].dx, greaterThan(dotCenters[i - 1].dx));
    }

    // Auto-slide setelah 4 detik tetap berjalan mulus
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 600));

    // Geser manual & kembali ke slide 1 lewat indikator titik tengah
    await tester.drag(find.byType(PageView), const Offset(-320, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.bySemanticsLabel('Slide highlight 1'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // 2. Seksi "Konser Trending" menggantikan "Segera hadir" & dibatasi maksimal 5 konser
    expect(find.text('Segera hadir'), findsNothing);
    expect(find.text('Konser Trending'), findsOneWidget);
    expect(find.byType(ConcertCard), findsNWidgets(5));
    expect(find.byType(ConcertSquareLogo), findsWidgets);

    // Filter kategori Pop (di DbDummy ada >5 konser Pop, tetap dibatasi maksimal 5 konser Pop)
    await tester.tap(find.bySemanticsLabel('Kategori Pop'));
    await tester.pump();
    expect(find.byType(ConcertCard), findsNWidgets(5));

    // Filter kategori Rock (di DbDummy ada 2 konser Rock, hanya menampilkan 2 konser yang terkena filter)
    await tester.ensureVisible(find.bySemanticsLabel('Kategori Rock'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Kategori Rock'));
    await tester.pump();
    expect(find.byType(ConcertCard), findsNWidgets(2));

    // Kembalikan ke Semua
    await tester.ensureVisible(find.bySemanticsLabel('Kategori Semua'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Kategori Semua'));
    await tester.pump();
    expect(find.byType(ConcertCard), findsNWidgets(5));

    // 3. Klik kartu highlight -> membuka Detail Konser dengan Banner Highlight Persegi Panjang di bagian paling atas
    await tester.tap(find.byType(PageView));
    await tester.pumpAndSettle();
    expect(find.byType(ConcertDetailScreen), findsOneWidget);
    expect(find.byType(ConcertHighlightBannerSurface), findsOneWidget);

    // Kembali ke Beranda lalu klik "Lihat Semua konser yang ada" -> berpindah ke halaman Jelajah
    await tester.tap(find.byTooltip('Kembali'));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.ensureVisible(find.text('Lihat Semua konser yang ada'));
    await tester.tap(find.text('Lihat Semua konser yang ada'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ExploreScreen), findsOneWidget);
  });

  testWidgets(
      'Header Kartu Profil Beranda: Guest menampilkan Guest, ID : -, & tombol Masuk di dalam card; User menampilkan Nama & ID 6 karakter',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final dataService = DataService();
    dataService.setAgreementStatus(true);

    // 1. Validasi aturan ID pengguna selalu tepat 6 karakter
    expect(UserModel.normalizeSixCharId('123456'), equals('123456'));
    expect(UserModel.normalizeSixCharId('98'), equals('000098'));
    expect(UserModel.normalizeSixCharId('987654321'), equals('987654'));
    expect(UserModel.generateSixCharId('rudi@livetix.id').length, equals(6));

    // 2. Uji Beranda Mode Guest (termasuk layar sempit 320px & zoom teks 200%)
    for (final width in [320.0, 375.0]) {
      tester.view.physicalSize = Size(width, 812);
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(
            textScaler: TextScaler.linear(width == 320.0 ? 1.5 : 1.0),
          ),
          child: const MaterialApp(home: HomeScreen(isGuest: true)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Halo, Guest'), findsNothing);
      expect(find.text('Malam ini ada apa?'), findsNothing);
      expect(find.byType(GuestAvatarIcon), findsOneWidget);
      expect(find.text('Guest'), findsOneWidget);
      expect(find.text('ID : -'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Masuk'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }

    // Klik tombol Masuk di sebelah kanan dalam card -> navigasi ke LoginScreen
    await tester.tap(find.widgetWithText(ElevatedButton, 'Masuk'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);

    // 3. Uji Beranda Mode User Terautentikasi (Nama lengkap + ID : 123456 6 karakter)
    final loggedIn = dataService.loginSync('rafi@email.com', '123456');
    expect(loggedIn, isNotNull);
    expect(loggedIn!.displayId, equals('123456'));
    expect(loggedIn.displayId.length, equals(6));

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          isGuest: false,
          userName: loggedIn.name,
          userInitials: loggedIn.initials,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Malam ini ada apa?'), findsNothing);
    expect(find.text('Rafi Firmansyah'), findsOneWidget);
    expect(find.text('ID : 123456'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Masuk'), findsNothing);
    expect(find.byType(GuestAvatarIcon), findsOneWidget);

    // Klik kartu profil di Beranda -> membuka tab Akun (ProfileScreen)
    await tester.tap(find.text('Rafi Firmansyah'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('ID : 123456'), findsOneWidget);
  });

  testWidgets('Responsivitas tablet, zoom teks, dan penutupan dialog via Escape',
      (WidgetTester tester) async {
    for (final size in [const Size(360, 780), const Size(768, 1024)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: MaterialApp(home: ExploreScreen(isGuest: true)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tanggal'));
      await tester.pumpAndSettle();
      expect(find.text('Pilih Tanggal Konser'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Pilih Tanggal Konser'), findsNothing);
    }
    tester.view.reset();
  });

  testWidgets(
      'Alur Pembayaran QRIS + 1 QR untuk 4 Tiket + Bagikan QR Ber-Watermark LiveTix + Navigasi ke Tiket',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(375, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final dataService = DataService();
    dataService.setAgreementStatus(true);
    dataService.loginSync('rafi@email.com', '123456');

    QrSharePayload? sharedPayload;
    QrShare.testOverride = (payload) async {
      sharedPayload = payload;
      return QrShareOutcome.sharedNatively;
    };

    final concert = DbDummy.concerts.first;
    final order = OrderModel(
      orderId: 'ORD-QRIS-401',
      concert: concert,
      tier: concert.ticketTiers[1],
      quantity: 4, // Maksimal 4 tiket -> tetap 1 QR dengan kuota 4x scan
      customerName: 'Rafi Firmansyah',
      customerEmail: 'rafi@email.com',
      ticketPrice: 350000,
      serviceFee: 15000,
      taxAndAdmin: 146500,
      totalAmount: 1561500,
    );

    await tester.pumpWidget(
      MaterialApp(home: OrderSummaryScreen(order: order)),
    );
    await tester.pumpAndSettle();

    // Klik Pilih Metode -> masuk ke PaymentMethodScreen
    await tester.tap(find.text('Pilih Metode'));
    await tester.pumpAndSettle();
    expect(find.byType(PaymentMethodScreen), findsOneWidget);
    expect(find.text('QRIS (Universal)'), findsOneWidget);
    expect(find.text('E-Wallet'), findsNothing);
    expect(find.text('Bank (Virtual Account)'), findsNothing);

    // Pilih QRIS (Universal) -> langsung masuk ke menu Barcode QRIS di PaymentScreen
    await tester.tap(find.byKey(const Key('payment_method_qris')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(PaymentScreen), findsOneWidget);
    expect(find.text('Barcode QRIS'), findsOneWidget);
    expect(find.text('01'), findsOneWidget); // Batas waktu awal 1 jam
    expect(find.byType(AppQrCodeView), findsOneWidget);
    expect(find.byKey(const Key('download_qris_button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('download_qris_button')));
    await tester.pump();
    expect(
      find.descendant(
        of: find.byType(AppQrCodeView),
        matching: find.byType(QrImageView),
      ),
      findsOneWidget,
    );

    // Konfirmasi pembayaran QRIS -> berhasil -> masuk ke PaymentSuccessScreen
    await tester.tap(find.text('Saya Sudah Bayar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();

    final simBtn = find.textContaining('Simulasi Bayar Berhasil');
    if (simBtn.evaluate().isNotEmpty) {
      await tester.tap(simBtn);
      await tester.pumpAndSettle();
    }

    expect(find.byType(PaymentSuccessScreen), findsOneWidget);
    expect(find.text('Pembayaran berhasil!'), findsOneWidget);
    expect(
      find.text('1 QR Berlaku untuk 4x Scan di Gate (4 Tiket)'),
      findsOneWidget,
    );

    // Uji generator gambar PNG ber-watermark LiveTix secara nyata
    final issuedTicket = dataService.userTicketsNotifier.value
        .firstWhere((t) => t.id == 'ORD-QRIS-401');
    expect(issuedTicket.qrScanQuota, equals(4));
    final generatedPng = await tester.runAsync(
      () => GateQrImageGenerator.generatePngBytes(issuedTicket),
    );
    expect(generatedPng, isNotNull);
    expect(generatedPng!.length, greaterThan(100));
    expect(generatedPng.sublist(0, 4), equals([137, 80, 78, 71])); // Signature PNG

    // Klik Bagikan QR -> pratinjau kartu ber-watermark LiveTix -> kirim ke aplikasi HP
    await tester.ensureVisible(find.text('Bagikan QR'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bagikan QR'));
    await tester.pumpAndSettle();
    expect(find.text('Bagikan QR Gate Konser'), findsOneWidget);
    expect(
      find.text('Watermark Resmi LiveTix · Valid untuk masuk gerbang konser'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Bagikan ke Aplikasi Chat / HP'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bagikan ke Aplikasi Chat / HP'));
    await tester.pumpAndSettle();

    expect(sharedPayload, isNotNull);
    expect(sharedPayload!.pngBytes, isNotEmpty);
    expect(sharedPayload!.text, contains(concert.title));
    expect(sharedPayload!.text, contains(concert.date));
    expect(sharedPayload!.text, contains('Watermark Resmi LiveTix'));

    // Klik Lihat di Menu Tiket -> langsung membuka tab Tiket pada HomeScreen
    await tester.ensureVisible(find.text('Lihat di Menu Tiket'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lihat di Menu Tiket'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(TicketScreen), findsOneWidget);
    expect(find.text('4 hari lagi'), findsNothing);
    expect(find.textContaining('4x scan'), findsWidgets);
  });

  testWidgets(
      'Alur Pembayaran QRIS Universal: Hanya QRIS yang tampil di pilihan pembayaran, barcode QRIS scannable, dan tombol Unduh QR Code berfungsi baik',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(375, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final dataService = DataService();
    dataService.setAgreementStatus(true);
    dataService.loginSync('rafi@email.com', '123456');

    final concert = DbDummy.concerts[2]; // Feast Live Session
    final order = OrderModel(
      orderId: 'ORD-QRIS-902',
      concert: concert,
      tier: concert.ticketTiers.first,
      quantity: 2,
      customerName: 'Rafi Firmansyah',
      customerEmail: 'rafi@email.com',
      ticketPrice: 320000,
      serviceFee: 15000,
      taxAndAdmin: 70500,
      totalAmount: 725500,
      paymentCategory: PaymentCategory.qris,
      paymentProvider: 'QRIS',
    );

    await tester.pumpWidget(
      MaterialApp(home: PaymentMethodScreen(order: order)),
    );
    await tester.pumpAndSettle();

    // Verifikasi bahwa pilihan E-Wallet dan Bank sudah dihapus, hanya QRIS Universal yang tampil
    expect(find.text('QRIS (Universal)'), findsOneWidget);
    expect(find.text('E-Wallet'), findsNothing);
    expect(find.text('Bank (Virtual Account)'), findsNothing);

    // Tap QRIS -> masuk ke halaman PaymentScreen
    await tester.tap(find.byKey(const Key('payment_method_qris')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(PaymentScreen), findsOneWidget);
    expect(find.text('Barcode QRIS'), findsOneWidget);
    expect(find.byType(AppQrCodeView), findsOneWidget);

    // Verifikasi tombol Unduh QR Code Pembayaran
    expect(find.byKey(const Key('download_qris_button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('download_qris_button')));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Metode Pembayaran Profil: akun baru belum memiliki rekening refund (tanpa dummy), tanpa tombol simulasi, dan registrasi rekening berhasil',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(375, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final dataService = DataService();
    dataService.loginSync('rafi@email.com', '123456');
    // Akun baru belum memiliki rekening refund terdaftar (null, bukan dummy)
    dataService.refundAccountNotifier.value = null;

    await tester.pumpWidget(
      const MaterialApp(home: RefundPaymentMethodScreen()),
    );
    await tester.pumpAndSettle();

    // 1. Verifikasi penegasan fungsi khusus penerimaan refund
    expect(find.text('Khusus Penerimaan Dana Refund'), findsOneWidget);
    expect(
      find.textContaining('hanya digunakan untuk menerima pencairan dana refund tiket'),
      findsOneWidget,
    );

    // 2. Verifikasi state awal akun baru: belum ada rekening (kosong, bukan dummy BCA)
    expect(find.text('Belum Ada Rekening Refund'), findsOneWidget);
    expect(find.text('Bank BCA'), findsNothing);
    expect(find.textContaining('8808'), findsNothing);

    // 3. Verifikasi tombol simulasi developer telah dihapus
    expect(find.byKey(const Key('simulate_cooldown_reset_button')), findsNothing);

    // 4. Tombol Daftarkan Rekening Refund aktif
    final registerBtn = tester.widget<ElevatedButton>(
      find.byKey(const Key('edit_refund_account_button')),
    );
    expect(registerBtn.onPressed, isNotNull);
    expect(find.text('Daftarkan Rekening Refund'), findsOneWidget);

    // 5. Klik Daftarkan Rekening Refund -> membuka modal pengaturan rekening refund
    await tester.tap(find.byKey(const Key('edit_refund_account_button')));
    await tester.pumpAndSettle();
    expect(find.text('Atur Rekening Penerima Refund'), findsOneWidget);

    // Pilih E-Wallet DANA
    await tester.ensureVisible(find.text('E-Wallet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('E-Wallet'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('refund_account_number_input')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('refund_account_number_input')),
      '081298765432',
    );
    await tester.ensureVisible(
      find.byKey(const Key('refund_confirm_checkbox')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('refund_confirm_checkbox')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('save_refund_account_submit_button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save_refund_account_submit_button')));
    await tester.pumpAndSettle();

    // 6. Modal tertutup, rekening terdaftar dan masa cooldown 1 minggu aktif
    expect(find.text('Atur Rekening Penerima Refund'), findsNothing);
    expect(find.textContaining('0812 •••• •••• 5432'), findsOneWidget);
    expect(find.textContaining('Masa Cooldown Aktif'), findsOneWidget);
    expect(dataService.refundAccount?.accountNumber, equals('081298765432'));
  });

  testWidgets(
      'ProfileScreen: Bahasa & Notifikasi dihapus pada User, Mode tampilan mengubah tema global (isDarkModeNotifier) dan default adalah Dark',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(375, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final dataService = DataService();
    // Pastikan default tema awal pada dummy data adalah Dark
    expect(dataService.isDarkModeNotifier.value, isTrue);

    await tester.pumpWidget(
      const MaterialApp(
        home: ProfileScreen(
          isGuest: false,
          userName: 'Rafi Firmansyah',
          userEmail: 'rafi@email.com',
          userInitials: 'RF',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verifikasi statistik profil: hanya 2 metrik database (Tiket dibeli & Total tiket aktif)
    expect(find.text('Tiket dibeli'), findsOneWidget);
    expect(find.text('Total tiket aktif'), findsOneWidget);
    expect(find.text('Konser dihadiri'), findsNothing);
    expect(find.text('Ulasan'), findsNothing);

    // 1. Verifikasi Bahasa telah dihapus dari PREFERENSI
    expect(find.text('Bahasa'), findsNothing);
    expect(find.text('Indonesia'), findsNothing);

    // 2. Verifikasi Notifikasi telah dihapus dari menu profil
    expect(find.text('Notifikasi'), findsNothing);

    // 3. Verifikasi Mode Tampilan switch hadir dengan status Dark
    expect(find.text('Mode tampilan'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);

    // 4. Ubah switch Mode Tampilan ke Light
    final switchFinder = find.byType(Switch);
    expect(switchFinder, findsOneWidget);
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    // Verifikasi tema global berubah ke Light di DataService
    expect(dataService.isDarkModeNotifier.value, isFalse);
    expect(find.text('Light'), findsOneWidget);

    // Kembalikan ke tema Dark
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();
    expect(dataService.isDarkModeNotifier.value, isTrue);
    expect(find.text('Dark'), findsOneWidget);
  });

  testWidgets(
      'Dashboard Beranda: Ikon notifikasi dengan badge 3 di sebelah kiri > membuka modal notifikasi',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(375, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final dataService = DataService();
    dataService.loginSync('rafi@email.com', '123456');

    // Berikan data tiket nyata pengguna untuk memicu notifikasi tiket
    dataService.userTicketsNotifier.value = [
      const UserTicketModel(
        id: 'tkt-test-1',
        bookingCode: 'LTX-TEST-01',
        concertTitle: 'Soundwave Fest 2026',
        concertSubtitle: '12 Okt · Stadion Gajayana',
        category: 'Festival',
        date: '12 Okt 2026',
        time: '19.00 WIB',
        gate: 'Gate A',
        block: 'FEST-01',
        venue: 'Stadion Gajayana',
        quantity: 2,
        totalPrice: 350000,
        status: 'Aktif',
        daysLeft: 14,
      ),
    ];

    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(
          isGuest: false,
          userName: 'Rafi Firmansyah',
          userInitials: 'RF',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    // 1. Verifikasi ikon notifikasi & badge angka hadir di header profil
    expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    // 2. Ikon > tetap ada di sebelah kanan notifikasi
    expect(find.byIcon(Icons.chevron_right_rounded), findsWidgets);

    // 3. Klik tombol notifikasi -> membuka lembar bottom sheet notifikasi
    await tester.tap(find.byTooltip('Notifikasi'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Notifikasi'), findsOneWidget);
    expect(find.text('2 baru'), findsOneWidget);
    expect(find.text('Tiket Konser Terbit'), findsOneWidget);
    expect(find.text('Jadwal Konser'), findsOneWidget);

    // Tutup modal notifikasi dengan tap area luar
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(find.text('2 baru'), findsNothing);
  });

  testWidgets(
      'Tombol Love (Favorit) di highlight carousel dan detail konser berwarna pink (#E91E8C) dan tersimpan di DataService',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(375, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final dataService = DataService();
    // Bersihkan favorit untuk pengujian deterministic
    dataService.favoriteConcertIdsNotifier.value = <String>{};

    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(
          isGuest: false,
          userName: 'Rafi Firmansyah',
          userInitials: 'RF',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    final featuredConcert = DbDummy.concerts.first;

    // 1. Temukan tombol favorit pada carousel highlight di Beranda
    final favButtonFinder = find.descendant(
      of: find.byType(FeaturedConcertCard),
      matching: find.byIcon(Icons.favorite_border_rounded),
    );
    expect(favButtonFinder, findsWidgets);

    // 2. Klik tombol love pada highlight card pertama
    await tester.tap(favButtonFinder.first);
    await tester.pumpAndSettle();

    // DataService menyimpan status konser sebagai disukai
    expect(dataService.isFavorite(featuredConcert.id), isTrue);

    // Ikon berubah menjadi terisi dan berwarna pink AppColors.favoritePink (#E91E8C)
    final pinkHeartFinder = find.byWidgetPredicate((widget) {
      if (widget is Icon &&
          widget.icon == Icons.favorite_rounded &&
          widget.color == AppColors.favoritePink) {
        return true;
      }
      return false;
    });
    expect(pinkHeartFinder, findsWidgets);

    // 3. Buka halaman Detail Konser untuk konser yang sama
    await tester.pumpWidget(
      MaterialApp(
        home: ConcertDetailScreen(
          concert: featuredConcert,
          isGuest: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verifikasi tombol favorit di Detail Konser juga aktif sinkron berwarna pink
    final detailPinkHeartFinder = find.byWidgetPredicate((widget) {
      if (widget is Icon &&
          widget.icon == Icons.favorite_rounded &&
          widget.color == AppColors.favoritePink) {
        return true;
      }
      return false;
    });
    expect(detailPinkHeartFinder, findsOneWidget);

    // Klik tombol favorit di detail konser untuk un-favorite
    await tester.tap(detailPinkHeartFinder);
    await tester.pumpAndSettle();

    // Status disukai terhapus secara sinkron di DataService
    expect(dataService.isFavorite(featuredConcert.id), isFalse);
  });

  testWidgets(
      'Filtering Disukai di Beranda & Jelajah: filter ganda kombinasi genre + disukai, unclick kembali ke filter tunggal, dan limit maksimal 10 konser',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(375, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final dataService = DataService();
    // Atur konser 'featured-1' (Pop) dan 'c8' (Rock) sebagai konser yang disukai
    dataService.favoriteConcertIdsNotifier.value = {'featured-1', 'c8'};

    // --- Uji Filter di ExploreScreen (Jelajah) ---
    await tester.pumpWidget(
      const MaterialApp(home: ExploreScreen(isGuest: false)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    // 1. Filter Disukai belum aktif -> tampil semua (dibatasi 10 konser)
    final initialCards = tester.widgetList<ConcertSquareLogo>(
      find.byType(ConcertSquareLogo),
    );
    expect(initialCards.length, lessThanOrEqualTo(10));

    // 2. Klik chip "Disukai" di Jelajah
    await tester.tap(find.text('Disukai'));
    await tester.pumpAndSettle();

    // Hasil filter menampilkan 2 konser favorit ('featured-1' dan 'c8')
    expect(find.text('Hasil Filter (2)'), findsOneWidget);
    expect(find.text('Soundwave Fest 2026'), findsOneWidget);
    expect(find.text('The Changcuters Rock Party'), findsOneWidget);

    // 3. Kombinasi 2 filter: pilih genre "Rock" saat "Disukai" masih aktif
    await tester.ensureVisible(find.text('Rock').first);
    await tester.tap(find.text('Rock').first);
    await tester.pumpAndSettle();

    // Hanya menampilkan konser yang bergenre Rock DAN Disukai ('c8' The Changcuters)
    expect(find.text('Hasil Filter (1)'), findsOneWidget);
    expect(find.text('The Changcuters Rock Party'), findsOneWidget);
    expect(find.text('Soundwave Fest 2026'), findsNothing);

    // 4. Unclick tombol "Disukai" -> kembali ke 1 filter tunggal yaitu Genre "Rock"
    await tester.ensureVisible(find.text('Disukai'));
    await tester.tap(find.text('Disukai'));
    await tester.pumpAndSettle();

    // Hasil filter kini menampilkan konser Rock tanpa filter Disukai
    expect(find.text('The Changcuters Rock Party'), findsOneWidget);
  });

  testWidgets(
      'HomeScreen Tab Akun: Toggle Mode Tampilan benar-benar berfungsi mengubah tema gelap terang pada Scaffold dan Bottom Nav',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(375, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final dataService = DataService();
    dataService.loginSync('rafi@email.com', '123456');
    dataService.setDarkMode(true);

    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(
          isGuest: false,
          userName: 'Rafi Firmansyah',
          userInitials: 'RF',
          initialNavIndex: 3,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verifikasi berada di tab Akun dan default tema Dark aktif
    expect(find.text('Akun'), findsWidgets);
    expect(find.text('Mode tampilan'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(dataService.isDarkModeNotifier.value, isTrue);

    // Verifikasi Scaffold HomeScreen memiliki background dark
    var homeScaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(homeScaffold.backgroundColor, equals(AppColors.darkBg));

    // 2. Toggle Mode Tampilan ke Light
    await tester.tap(find.text('Mode tampilan'));
    await tester.pumpAndSettle();

    expect(dataService.isDarkModeNotifier.value, isFalse);
    expect(find.text('Light'), findsOneWidget);

    // Verifikasi Scaffold HomeScreen segera berubah ke tema Light (Colors.white)
    homeScaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(homeScaffold.backgroundColor, equals(Colors.white));

    // 3. Toggle kembali ke Dark
    await tester.tap(find.text('Mode tampilan'));
    await tester.pumpAndSettle();

    expect(dataService.isDarkModeNotifier.value, isTrue);
    expect(find.text('Dark'), findsOneWidget);
    homeScaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(homeScaffold.backgroundColor, equals(AppColors.darkBg));
  });
}
