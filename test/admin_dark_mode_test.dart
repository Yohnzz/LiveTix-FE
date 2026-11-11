import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:livetix/core/app_colors.dart';
import 'package:livetix/models/approval_models.dart';
import 'package:livetix/screens/admin/admin_cancellation_approved_screen.dart';
import 'package:livetix/screens/admin/admin_cancellation_detail_screen.dart';
import 'package:livetix/screens/admin/admin_dashboard_screen.dart';
import 'package:livetix/screens/admin/admin_notification_screen.dart';
import 'package:livetix/screens/admin/admin_profile_screen.dart';
import 'package:livetix/screens/admin/admin_refund_detail_screen.dart';
import 'package:livetix/screens/admin/admin_refund_monitoring_screen.dart';
import 'package:livetix/screens/admin/admin_reject_screen.dart';
import 'package:livetix/screens/admin/admin_review_cancellation_screen.dart';
import 'package:livetix/screens/admin/admin_review_concert_screen.dart';
import 'package:livetix/screens/admin/admin_shell.dart';
import 'package:livetix/screens/admin/admin_user_detail_screen.dart';
import 'package:livetix/screens/admin/admin_users_screen.dart';
import 'package:livetix/screens/admin/widgets/admin_theme.dart';
import 'package:livetix/screens/explore/explore_screen.dart';
import 'package:livetix/screens/ticket/ticket_screen.dart';
import 'package:livetix/services/admin_service.dart';
import 'package:livetix/services/data_service.dart';

double _relativeLuminance(Color c) {
  double lin(int channel) {
    final srgb = channel / 255.0;
    return srgb <= 0.03928
        ? srgb / 12.92
        : math.pow((srgb + 0.055) / 1.055, 2.4).toDouble();
  }

  final r = lin((c.r * 255.0).round());
  final g = lin((c.g * 255.0).round());
  final b = lin((c.b * 255.0).round());
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double _contrastRatio(Color fg, Color bg) {
  final l1 = _relativeLuminance(fg);
  final l2 = _relativeLuminance(bg);
  final lighter = math.max(l1, l2);
  final darker = math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

Future<void> _pumpWithDarkTheme(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.darkBg,
        cardColor: AppColors.darkSurface,
      ),
      home: child,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() async {
    DataService().setDarkMode(true);
    DataService().loginSync('admin@livetix.com', 'admin123');
    AdminService()
      ..reset()
      ..latency = Duration.zero;
    await AdminService().load();
    AdminNavigation.reset();
  });

  tearDown(() {
    DataService().setDarkMode(true);
    DataService().resetUsersForTesting();
    DataService().logout();
    AdminService().reset();
    AdminNavigation.reset();
  });

  group('Mode Gelap Admin & Pengguna - Kontras WCAG AA >= 4.5:1', () {
    testWidgets('AdminDashboardScreen & AdminProfileScreen terbaca jelas di mode gelap dan toggle terang/gelap bekerja',
        (tester) async {
      await _pumpWithDarkTheme(tester, const AdminShell());
      expect(find.byType(AdminDashboardScreen), findsOneWidget);

      // Verifikasi teks utama kartu & statistik di Dashboard Admin terhadap darkSurface
      final refundTitle =
          tester.widget<Text>(find.text('Monitoring Refund').first);
      expect(
        _contrastRatio(refundTitle.style!.color!, AdminColors.darkSurface),
        greaterThanOrEqualTo(4.5),
      );

      final refundSub = tester.widget<Text>(
          find.text('Pantau pengembalian dana konser dibatalkan'));
      expect(
        _contrastRatio(refundSub.style!.color!, AdminColors.darkSurface),
        greaterThanOrEqualTo(4.5),
      );

      final statLabel = tester.widget<Text>(find.text('Total Pengguna'));
      expect(
        _contrastRatio(statLabel.style!.color!, AdminColors.darkSurface),
        greaterThanOrEqualTo(4.5),
      );

      // Buka tab Profil Admin
      await tester.tap(find.bySemanticsLabel('Profil').last);
      await tester.pumpAndSettle();
      expect(find.byType(AdminProfileScreen), findsOneWidget);

      final totalDisetujuiText = tester.widget<Text>(
        find.text('Total Disetujui'),
      );
      expect(
        _contrastRatio(
            totalDisetujuiText.style!.color!, AdminColors.darkSurface),
        greaterThanOrEqualTo(4.5),
      );

      final logoutText = tester.widget<Text>(find.text('Keluar dari akun'));
      expect(
        _contrastRatio(logoutText.style!.color!, AdminColors.darkSurface),
        greaterThanOrEqualTo(4.5),
      );

      // Toggle ke Tema Terang lalu verifikasi teks kembali gelap kontras tinggi
      await tester.ensureVisible(find.byKey(const Key('admin_theme_switch')));
      await tester.tap(find.byKey(const Key('admin_theme_switch')));
      await tester.pumpAndSettle();
      expect(DataService().isDarkModeNotifier.value, isFalse);

      final logoutLight = tester.widget<Text>(find.text('Keluar dari akun'));
      expect(
        _contrastRatio(logoutLight.style!.color!, Colors.white),
        greaterThanOrEqualTo(4.5),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('AdminUsersScreen & dialog serta AdminUserDetailScreen bebas teks gelap pada latar gelap',
        (tester) async {
      await _pumpWithDarkTheme(tester, const AdminShell());
      await tester.tap(find.bySemanticsLabel('Kelola User').last);
      await tester.pumpAndSettle();
      expect(find.byType(AdminUsersScreen), findsOneWidget);

      // Buka dialog Ganti Nama lewat menu akun pertama
      final menuBtn = find.byTooltip('Menu Akun').first;
      await tester.ensureVisible(menuBtn);
      await tester.tap(menuBtn);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ganti Nama'));
      await tester.pumpAndSettle();

      final dialogTitle = tester.widget<Text>(find.text('Ganti Nama Pengguna'));
      expect(
        _contrastRatio(dialogTitle.style!.color!, AdminColors.darkSurface),
        greaterThanOrEqualTo(4.5),
      );
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();

      // Buka detail user pertama
      final rafiFinder = find.text('Rafi Firmansyah').first;
      await tester.ensureVisible(rafiFinder);
      await tester.pumpAndSettle();
      await tester.tap(rafiFinder);
      await tester.pumpAndSettle();
      expect(find.byType(AdminUserDetailScreen), findsOneWidget);

      final scaffold = tester.widget<Scaffold>(
        find.descendant(
          of: find.byType(AdminUserDetailScreen),
          matching: find.byType(Scaffold),
        ),
      );
      expect(scaffold.backgroundColor, AdminColors.darkBackground);

      final nameText =
          tester.widget<Text>(find.text('Rafi Firmansyah').first);
      expect(
        _contrastRatio(nameText.style!.color!, AdminColors.darkSurface),
        greaterThanOrEqualTo(4.5),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('AdminNotificationScreen, AdminReviewConcertScreen, dan AdminRejectScreen memakai permukaan & teks mode gelap',
        (tester) async {
      // 1. AdminNotificationScreen
      await _pumpWithDarkTheme(tester, const AdminNotificationScreen());
      final notifScaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(notifScaffold.backgroundColor, AdminColors.darkBackground);
      final notifTitle =
          tester.widget<Text>(find.text('Pendaftaran Produser Baru').first);
      expect(
        _contrastRatio(notifTitle.style!.color!, AdminColors.darkSurface),
        greaterThanOrEqualTo(4.5),
      );

      // 2. AdminReviewConcertScreen
      await _pumpWithDarkTheme(
        tester,
        const AdminReviewConcertScreen(concertId: 'cnc-001'),
      );
      final reviewScaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(reviewScaffold.backgroundColor, AdminColors.darkBackground);
      final inputField = tester.widget<TextField>(
        find.byKey(const Key('admin_review_concert_reason_input')),
      );
      expect(
        _contrastRatio(inputField.style!.color!, AdminColors.darkSurfaceAlt),
        greaterThanOrEqualTo(4.5),
      );

      // 3. AdminRejectScreen
      await _pumpWithDarkTheme(
        tester,
        const AdminRejectScreen(kind: ApprovalKind.producer, itemId: 'prd-001'),
      );
      final rejectScaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(rejectScaffold.backgroundColor, AdminColors.darkBackground);
      final rejectField = tester.widget<TextField>(find.byType(TextField));
      expect(
        _contrastRatio(rejectField.style!.color!, AdminColors.darkSurface),
        greaterThanOrEqualTo(4.5),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Layar Monitoring Refund & Pembatalan Admin terbungkus latar dan teks mode gelap',
        (tester) async {
      await _pumpWithDarkTheme(tester, const AdminRefundMonitoringScreen());
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        AdminColors.darkBackground,
      );

      await _pumpWithDarkTheme(
        tester,
        const AdminRefundDetailScreen(concertId: 'cnc-001'),
      );
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        AdminColors.darkBackground,
      );
      final progressLabel = tester.widget<Text>(find.text('Progres Refund'));
      expect(
        _contrastRatio(progressLabel.style!.color!, AdminColors.darkSurface),
        greaterThanOrEqualTo(4.5),
      );

      final concert = AdminService().concertsNotifier.value.first;
      await _pumpWithDarkTheme(
        tester,
        AdminCancellationDetailScreen(concert: concert),
      );
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        AdminColors.darkBackground,
      );

      await _pumpWithDarkTheme(
        tester,
        AdminReviewCancellationScreen(concert: concert),
      );
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        AdminColors.darkBackground,
      );

      await _pumpWithDarkTheme(
        tester,
        AdminCancellationApprovedScreen(
          concert: concert,
          decidedAt: DateTime(2026, 10, 24, 14, 0),
        ),
      );
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        AdminColors.darkBackground,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('ExploreScreen empty state & TicketScreen empty state kontras jelas di mode gelap',
        (tester) async {
      await _pumpWithDarkTheme(tester, const TicketScreen(isGuest: true));
      final emptyTicketTitle =
          tester.widget<Text>(find.text('Tidak Ada Tiket').first);
      expect(
        _contrastRatio(emptyTicketTitle.style!.color!, AppColors.darkBg),
        greaterThanOrEqualTo(4.5),
      );
      final loginPrompt = tester.widget<Text>(
        find.text('Silahkan Login Terlebih Dahulu'),
      );
      expect(
        _contrastRatio(loginPrompt.style!.color!, AppColors.darkBg),
        greaterThanOrEqualTo(4.5),
      );

      await _pumpWithDarkTheme(
        tester,
        const ExploreScreen(isGuest: true),
      );
      await tester.enterText(
          find.byType(TextField).first, 'konser_tidak_ada_xyz');
      await tester.pumpAndSettle();
      final emptyExploreTitle =
          tester.widget<Text>(find.text('Tidak ada konser yang cocok'));
      expect(
        _contrastRatio(emptyExploreTitle.style!.color!, AppColors.darkBg),
        greaterThanOrEqualTo(4.5),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
