import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:livetix/data/admin_dummy.dart';
import 'package:livetix/models/approval_models.dart';
import 'package:livetix/screens/admin/admin_approval_screen.dart';
import 'package:livetix/screens/admin/admin_concert_detail_screen.dart';
import 'package:livetix/screens/admin/admin_producer_detail_screen.dart';
import 'package:livetix/screens/admin/admin_shell.dart';
import 'package:livetix/screens/auth/login_screen.dart';
import 'package:livetix/screens/home/home_screen.dart';
import 'package:livetix/services/admin_service.dart';
import 'package:livetix/services/data_service.dart';

Future<void> _pumpAdmin(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: const AdminShell(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapTab(WidgetTester tester, String label) async {
  final finder = find.text(label);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _tapNav(WidgetTester tester, String label) async {
  await tester.tap(find.bySemanticsLabel(label).last);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    AdminService()
      ..reset()
      ..latency = Duration.zero;
    AdminNavigation.reset();
    DataService().loginSync('admin@livetix.com', 'admin123');
  });

  tearDown(() {
    DataService().resetUsersForTesting();
    DataService().logout();
    AdminService().reset();
    AdminNavigation.reset();
  });

  group('Model approval', () {
    test(
        'ProducerApplicationModel fromJson dan toJson sinkron dengan promoter_profiles',
        () {
      final model =
          ProducerApplicationModel.fromJson(AdminDummy.producers.first);
      expect(model.companyName, 'PT Harmony Entertainment');
      expect(model.email, 'harmony@email.com');
      expect(model.approvalStatus, ApprovalStatus.pending);

      final json = model.toJson();
      expect(json['company_name'], 'PT Harmony Entertainment');
      expect(json['user_id'], 'usr-101');
      expect(json['is_verified'], false);
      expect(json.containsKey('email'), isFalse);
      expect(
          ProducerApplicationModel.fromJson({...json, 'email': model.email}).id,
          model.id);
    });

    test(
        'ConcertSubmissionModel membaca ticket_tiers dan menulis kolom concerts saja',
        () {
      final model = ConcertSubmissionModel.fromJson(AdminDummy.concerts.first);
      expect(model.title, 'Soundwave Fest 2026');
      expect(model.tiers.length, 2);
      expect(model.tiers.first.remainingQuota, model.tiers.first.totalQuota);

      final json = model.toJson();
      expect(json['promoter_id'], 'prd-006');
      expect(json['status'], 'draft');
      expect(json.containsKey('ticket_tiers'), isFalse);
      expect(model.tiers.first.toJson()['concert_id'], 'cnc-001');
    });

    test('ApprovalStatus.fromValue memakai pending untuk nilai tak dikenal',
        () {
      expect(ApprovalStatus.fromValue('approved'), ApprovalStatus.approved);
      expect(ApprovalStatus.fromValue('rejected'), ApprovalStatus.rejected);
      expect(ApprovalStatus.fromValue('aneh'), ApprovalStatus.pending);
      expect(ApprovalStatus.fromValue(null), ApprovalStatus.pending);
    });

    test('format tanggal dan angka', () {
      expect(ApprovalFormat.dayMonthYear(DateTime(2026, 12, 5)), '05 Des 2026');
      expect(ApprovalFormat.dayFullMonthYear(DateTime(2026, 10, 24)),
          '24 Oktober 2026');
      expect(ApprovalFormat.rupiah(1006500), 'Rp1.006.500');
      expect(ApprovalFormat.thousands(1248), '1,248');
      expect(ApprovalFormat.initialsOf('Rizky Event Organizer'), 'RE');
      expect(ApprovalFormat.initialsOf('Soundwave'), 'SO');
    });
  });

  group('AdminService', () {
    test('jumlah menunggu dihitung dari daftar, bukan angka tetap', () async {
      final service = AdminService();
      await service.load();
      expect(service.pendingProducerCount, 4);
      expect(service.pendingConcertCount, 3);
      expect(service.pendingTotal, 8);
      final recent = service.recentPending();
      expect(recent.map((e) => e.title),
          ['Soundwave Fest 2026', 'PT Harmony Entertainment']);
    });

    test(
        'setujui produser menambah produser aktif dan tidak bisa diputuskan dua kali',
        () async {
      final service = AdminService();
      await service.load();
      final before = service.statsNotifier.value.activeProducers;

      final approved = service.approveProducer('prd-001');
      expect(approved?.approvalStatus, ApprovalStatus.approved);
      expect(approved?.isVerified, isTrue);
      expect(service.statsNotifier.value.activeProducers, before + 1);
      expect(service.pendingProducerCount, 3);

      expect(service.approveProducer('prd-001'), isNull);
      expect(service.rejectProducer('prd-001', 'Alasan apa pun'), isNull);
      expect(service.statsNotifier.value.activeProducers, before + 1);
    });

    test('tolak wajib beralasan dan menyimpan alasan', () async {
      final service = AdminService();
      await service.load();
      expect(service.rejectProducer('prd-002', '   '), isNull);
      expect(service.producerById('prd-002')?.approvalStatus,
          ApprovalStatus.pending);

      final rejected =
          service.rejectProducer('prd-002', ' Dokumen belum lengkap ');
      expect(rejected?.approvalStatus, ApprovalStatus.rejected);
      expect(rejected?.rejectionReason, 'Dokumen belum lengkap');
    });

    test('setujui konser mengubah status ERD menjadi published', () async {
      final service = AdminService();
      await service.load();
      final approved = service.approveConcert('cnc-001');
      expect(approved?.status, 'published');
      expect(approved?.approvalStatus, ApprovalStatus.approved);
      expect(service.approveConcert('tidak-ada'), isNull);
    });

    test('load gagal menghasilkan state error lalu pulih setelah dicoba lagi',
        () async {
      final service = AdminService()..simulateFailure = true;
      await service.load();
      expect(service.loadState.value, AdminLoadState.error);
      service.simulateFailure = false;
      await service.load(force: true);
      expect(service.loadState.value, AdminLoadState.ready);
      expect(service.producersNotifier.value, isNotEmpty);
    });
  });

  group('Layar Super Admin', () {
    testWidgets('Dashboard menampilkan angka statistik dan approval terbaru',
        (tester) async {
      await _pumpAdmin(tester);
      expect(tester.takeException(), isNull);

      expect(find.text('Dashboard Utama'), findsOneWidget);
      expect(find.text('Halo, Admin'), findsOneWidget);
      expect(find.text('1,248'), findsOneWidget);
      expect(find.text('32'), findsOneWidget);
      expect(find.text('18'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('Approval Terbaru'), findsOneWidget);
      expect(find.text('PT Harmony Entertainment'), findsOneWidget);
      expect(find.text('Pengajuan: Produser Baru · 22 Okt'), findsOneWidget);
      expect(find.text('Soundwave Fest 2026'), findsOneWidget);
      expect(find.text('Pengajuan: Konser Baru · 23 Okt'), findsOneWidget);
    });

    testWidgets('Dashboard menampilkan error lalu memuat ulang lewat Coba lagi',
        (tester) async {
      AdminService().simulateFailure = true;
      await _pumpAdmin(tester);
      expect(find.text('Data belum bisa dimuat'), findsOneWidget);

      AdminService().simulateFailure = false;
      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();
      expect(find.text('Data belum bisa dimuat'), findsNothing);
      expect(find.text('Halo, Admin'), findsOneWidget);
    });

    testWidgets(
        'Bottom nav berpindah ke empat tab: Beranda, Approval, Kelola User, dan Profil',
        (tester) async {
      await _pumpAdmin(tester);

      await _tapNav(tester, 'Approval');
      expect(find.text('Approval Produser'), findsOneWidget);

      await _tapNav(tester, 'Kelola User');
      expect(find.text('Kelola Pengguna'), findsOneWidget);
      expect(find.text('Rafi Firmansyah'), findsOneWidget);

      await _tapNav(tester, 'Profil');
      expect(find.text('Super Admin'), findsWidgets);
      expect(find.text('Approval Hari Ini'), findsOneWidget);
      expect(find.text('Total Approval'), findsOneWidget);

      await _tapNav(tester, 'Beranda');
      expect(find.text('Halo, Admin'), findsOneWidget);
    });

    testWidgets(
        'Approval Produser: tab status, hitungan, dan daftar sesuai data',
        (tester) async {
      await _pumpAdmin(tester);
      await _tapNav(tester, 'Approval');

      expect(find.text('Menunggu (4)'), findsOneWidget);
      expect(find.text('Indie Stage Productions'), findsOneWidget);
      expect(find.text('indie@email.com · 21 Okt 2026'), findsOneWidget);
      expect(find.text('Menunggu'), findsAtLeastNWidgets(3));

      await _tapTab(tester, 'Ditolak');
      await tester.pumpAndSettle();
      expect(find.text('Sinar Panggung Promosi'), findsOneWidget);
      expect(find.text('Indie Stage Productions'), findsNothing);

      await _tapTab(tester, 'Disetujui');
      await tester.pumpAndSettle();
      expect(find.text('CV Musik Nusantara'), findsOneWidget);
      expect(find.text('Soundwave Productions'), findsOneWidget);
    });

    testWidgets(
        'Alur setujui produser: detail, konfirmasi, hasil, kembali ke daftar',
        (tester) async {
      await _pumpAdmin(tester);

      await tester.tap(find.text('PT Harmony Entertainment'));
      await tester.pumpAndSettle();
      expect(find.text('Detail Produser'), findsOneWidget);
      expect(find.text('Dokumen Legalitas'), findsOneWidget);

      await tester.tap(find.text('Setujui Produser'));
      await tester.pumpAndSettle();
      expect(find.text('Setujui produser?'), findsOneWidget);

      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(find.text('Setujui produser?'), findsNothing);
      expect(AdminService().pendingProducerCount, 4);

      await tester.tap(find.text('Setujui Produser'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Setujui'));
      await tester.pumpAndSettle();
      expect(find.text('Approval Berhasil!'), findsOneWidget);
      expect(find.text('Approval Sukses'), findsOneWidget);
      expect(find.text('Terverifikasi'), findsOneWidget);
      expect(find.text('Suka dengan produser ini?'), findsOneWidget);
      expect(AdminService().pendingProducerCount, 3);

      await tester.tap(find.text('Kembali ke Beranda'));
      await tester.pumpAndSettle();
      expect(find.text('Halo, Admin'), findsOneWidget);
      expect(find.text('33'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
    });

    testWidgets(
        'Alur tinjau dan tolak produser (Image 3, 4, 5): dokumen legalitas, buka tinjau, validasi alasan 0/300, kirim penolakan',
        (tester) async {
      await _pumpAdmin(tester);

      await tester.tap(find.text('PT Harmony Entertainment'));
      await tester.pumpAndSettle();

      // Image 3: Detail Produser
      expect(find.text('Detail Produser'), findsOneWidget);
      expect(find.text('0812 3456 7890'), findsOneWidget);
      expect(find.text('Jl. Sudirman No. 45, Jakarta'), findsOneWidget);
      expect(find.text('Dokumen Legalitas'), findsOneWidget);
      expect(find.text('KTP Penanggung Jawab'), findsOneWidget);
      expect(find.text('SIUP / TDUP'), findsOneWidget);
      expect(find.text('Akta Pendirian Perusahaan'), findsOneWidget);

      // Buka pratinjau dokumen legalitas
      await tester.tap(find.text('SIUP / TDUP'));
      await tester.pumpAndSettle();
      expect(find.text('Dokumen Legalitas: SIUP / TDUP'), findsOneWidget);
      await tester.tap(find.text('Tutup'));
      await tester.pumpAndSettle();

      // Masukkan catatan awal di Detail Produser
      final notesFinder = find.byKey(const Key('admin_review_notes_input'));
      await tester.scrollUntilVisible(notesFinder, 150);
      await tester.pumpAndSettle();
      await tester.enterText(notesFinder, 'Dokumen NIB tidak sesuai');
      await tester.pumpAndSettle();

      // Klik Tolak Pendaftaran -> Navigasi ke Tinjau Produser (Image 4 & 5)
      await tester.tap(find.text('Tolak Pendaftaran'));
      await tester.pumpAndSettle();

      expect(find.text('Tinjau Produser'), findsOneWidget);
      expect(find.text('Periksa data pengajuan dan berikan keputusan'),
          findsOneWidget);
      expect(find.textContaining('Menunggu Verifikasi'), findsOneWidget);
      expect(find.text('Dokumen Pengajuan'), findsOneWidget);
      expect(find.text('NIB Perusahaan'), findsOneWidget);
      expect(find.text('Lihat'), findsNWidgets(2));

      // Buka pratinjau NIB Perusahaan
      await tester.tap(find.text('Lihat').first);
      await tester.pumpAndSettle();
      expect(find.text('Pratinjau Resmi: NIB Perusahaan'), findsOneWidget);
      await tester.tap(find.text('Tutup'));
      await tester.pumpAndSettle();

      // Tombol Kirim Penolakan
      final submitButtonFinder =
          find.widgetWithText(FilledButton, 'Kirim Penolakan');
      expect(submitButtonFinder, findsOneWidget);
      final submitBtn = tester.widget<FilledButton>(submitButtonFinder);
      expect(submitBtn.onPressed, isNotNull);

      // Ketik alasan lengkap sesuai Image 5
      const fullReason =
          'NIB yang dilampirkan tidak sesuai dengan nama perusahaan yang didaftarkan, dan nomor telepon penanggung jawab tidak dapat diverifikasi. Silakan perbaiki data tersebut lalu ajukan kembali.';
      final reasonFinder =
          find.byKey(const Key('admin_review_producer_reason_input'));
      await tester.scrollUntilVisible(reasonFinder, 150);
      await tester.pumpAndSettle();
      await tester.enterText(reasonFinder, fullReason);
      await tester.pump();

      expect(find.text('${fullReason.length}/300'), findsOneWidget);

      // Klik Kirim Penolakan
      await tester.tap(submitButtonFinder);
      await tester.pumpAndSettle();

      // Layar Hasil Ditolak (Image 1: Approval Ditolak)
      expect(find.text('Approval Ditolak'), findsOneWidget);
      expect(find.text('Pengajuan Ditolak'), findsOneWidget);
      expect(find.text('Pendaftaran produser telah ditolak'), findsOneWidget);
      expect(find.text('PT Harmony Entertainment'), findsOneWidget);
      expect(find.text('24 Oktober 2026'), findsOneWidget);
      expect(find.text(fullReason), findsOneWidget);

      // Buka Lihat Detail -> Layar Detail Produser Ditolak (Image 2)
      await tester.tap(find.text('Lihat Detail'));
      await tester.pumpAndSettle();
      expect(find.text('Detail Produser'), findsOneWidget);
      expect(find.text('Profil produser yang pengajuannya ditolak'),
          findsOneWidget);
      expect(find.textContaining('Ditolak · 22 Okt 2026'), findsOneWidget);
      expect(find.text('Alasan Penolakan'), findsOneWidget);
      expect(find.text('Admin Verifikasi'), findsOneWidget);
      expect(find.text('24 Okt 2026 · 14.20 WIB'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Statistik Produser'), 150);
      expect(find.text('Statistik Produser'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Konser Diajukan'), 150);
      expect(find.text('Konser Diajukan'), findsOneWidget);
      expect(find.text('Tiket Terjual'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Belum ada konser'), 150);
      expect(find.text('Belum ada konser'), findsOneWidget);
      expect(find.text('Konser dapat diajukan setelah produser disetujui.'),
          findsOneWidget);

      // Kembali ke Approval Ditolak
      await tester.tap(find.text('Kembali'));
      await tester.pumpAndSettle();
      expect(find.text('Approval Ditolak'), findsOneWidget);

      // Kembali ke Beranda
      await tester.tap(find.text('Kembali ke Beranda'));
      await tester.pumpAndSettle();
      expect(find.text('Dashboard Utama'), findsOneWidget);
    });

    testWidgets(
        'Alur tolak konser: Detail Konser, Tinjau Konser, validasi alasan, dan read-only view',
        (tester) async {
      await _pumpAdmin(tester);

      AdminNavigation.openApproval(ApprovalKind.concert);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Jazz Night 2026'));
      await tester.pumpAndSettle();

      // Detail Konser
      expect(find.text('Detail Konser'), findsOneWidget);
      expect(find.text('Jazz'), findsOneWidget);
      expect(find.text('Produser: PT Harmony Ent.'), findsOneWidget);
      expect(find.text('Balai Sarbini, Jakarta'), findsOneWidget);
      expect(find.text('Total Kapasitas'), findsOneWidget);
      expect(find.text('5,000 Kursi'), findsOneWidget);
      expect(find.text('Kategori Tiket'), findsOneWidget);
      expect(find.text('VIP'), findsOneWidget);
      expect(find.text('Rp500.000'), findsOneWidget);
      expect(find.text('Kapasitas: 100 kursi'), findsOneWidget);
      expect(find.text('Reguler'), findsOneWidget);
      expect(find.text('Rp200.000'), findsOneWidget);
      expect(find.text('Kapasitas: 500 kursi'), findsOneWidget);
      expect(find.text('Tolak Konser'), findsOneWidget);
      expect(find.text('Setujui Konser'), findsOneWidget);

      // Buka Tinjau Konser
      await tester.tap(find.text('Tolak Konser'));
      await tester.pumpAndSettle();
      expect(find.text('Tinjau Konser'), findsOneWidget);
      expect(find.text('Periksa pengajuan dan berikan keputusan'),
          findsOneWidget);
      expect(find.text('Kapasitas Total'), findsOneWidget);
      expect(find.text('5.000 Kursi'), findsOneWidget);
      expect(find.text('Alasan Penolakan'), findsOneWidget);
      expect(find.text('0/300'), findsOneWidget);

      final submitBtnFinder =
          find.widgetWithText(FilledButton, 'Kirim Penolakan');
      expect(submitBtnFinder, findsOneWidget);
      final submitBtn = tester.widget<FilledButton>(submitBtnFinder);
      expect(submitBtn.onPressed, isNull);

      // Ketik alasan konser
      const concertReason = 'Izin keramaian belum dilampirkan dari kepolisian.';
      final reasonField =
          find.byKey(const Key('admin_review_concert_reason_input'));
      await tester.enterText(reasonField, concertReason);
      await tester.pump();
      expect(find.text('${concertReason.length}/300'), findsOneWidget);

      // Tombol aktif dan ditekan
      await tester.tap(submitBtnFinder);
      await tester.pumpAndSettle();

      // Layar Approval Ditolak untuk konser
      expect(find.text('Approval Ditolak'), findsOneWidget);
      expect(find.text('Pengajuan Ditolak'), findsOneWidget);
      expect(find.text('Jazz Night 2026'), findsOneWidget);
      expect(find.text(concertReason), findsOneWidget);
      expect(AdminService().concertById('cnc-003')?.approvalStatus,
          ApprovalStatus.rejected);

      // Buka Lihat Detail -> Detail Konser read-only
      await tester.tap(find.text('Lihat Detail'));
      await tester.pumpAndSettle();
      expect(find.text('Detail Konser'), findsOneWidget);
      expect(find.text('Informasi penjualan dan performa tiket'), findsOneWidget);
      expect(find.text('Ditolak'), findsOneWidget);
      expect(find.text('Kapasitas Total'), findsOneWidget);
      expect(find.text('5.000 Kursi'), findsOneWidget);
      expect(find.text('Alasan Penolakan'), findsOneWidget);
      expect(find.text('Ditinjau oleh Admin'), findsOneWidget);
      expect(find.text(concertReason), findsOneWidget);
      expect(find.text('Tolak Konser'), findsNothing);
      expect(find.text('Setujui Konser'), findsNothing);

      // Kembali ke Approval Ditolak
      Navigator.of(tester.element(find.byType(AdminConcertDetailScreen))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Kembali ke Beranda'));
      await tester.pumpAndSettle();
      expect(find.text('Dashboard Utama'), findsOneWidget);

      // Buka Approval Konser tab Ditolak
      AdminNavigation.openApproval(ApprovalKind.concert);
      await tester.pumpAndSettle();
      await _tapTab(tester, 'Ditolak');
      await tester.pumpAndSettle();
      expect(find.text('Jazz Night 2026'), findsOneWidget);
      expect(find.text('Dangdut Fest'), findsOneWidget);
    });

    testWidgets(
        'Approval Konser (Image 2): 3 konser menunggu, cari, filter bulan, dan state kosong dengan reset',
        (tester) async {
      await _pumpAdmin(tester);
      AdminNavigation.openApproval(ApprovalKind.concert);
      await tester.pumpAndSettle();

      // Menunggu (3) menampilkan Soundwave Fest 2026, Harmoni Nusantara 2026, dan Jazz Night 2026
      expect(find.text('Menunggu (3)'), findsOneWidget);
      expect(find.text('Soundwave Fest 2026'), findsOneWidget);
      expect(find.text('Harmoni Nusantara 2026'), findsOneWidget);
      expect(find.text('Jazz Night 2026'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'harmoni');
      await tester.pumpAndSettle();
      expect(find.text('Harmoni Nusantara 2026'), findsOneWidget);
      expect(find.text('Soundwave Fest 2026'), findsNothing);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('Konser tidak ditemukan'), findsOneWidget);

      await tester.tap(find.text('Reset filter'));
      await tester.pumpAndSettle();
      expect(find.text('Harmoni Nusantara 2026'), findsOneWidget);
      expect(find.text('Soundwave Fest 2026'), findsOneWidget);

      await tester.tap(find.text('Bulan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('November').last);
      await tester.pumpAndSettle();
      expect(find.text('Harmoni Nusantara 2026'), findsOneWidget);
      expect(find.text('Soundwave Fest 2026'), findsNothing);

      await tester.tap(find.text('November').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Semua bulan'));
      await tester.pumpAndSettle();

      // Tab Ditolak menampilkan Dangdut Fest berstatus Ditolak
      await _tapTab(tester, 'Ditolak');
      await tester.pumpAndSettle();
      expect(find.text('Dangdut Fest'), findsOneWidget);
    });

    testWidgets('Keluar dari akun kembali ke beranda tamu', (tester) async {
      await _pumpAdmin(tester);
      await _tapNav(tester, 'Profil');

      await tester.drag(find.byType(ListView).last, const Offset(0, -350));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keluar dari akun'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(find.byType(AdminShell), findsOneWidget);

      await tester.tap(find.text('Keluar dari akun'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Keluar'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(AdminShell), findsNothing);
      expect(DataService().isGuest, isTrue);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'Layar kecil 320 px dengan teks 2x tidak overflow di semua layar',
        (tester) async {
      await _pumpAdmin(tester, size: const Size(320, 568), textScale: 2.0);
      expect(tester.takeException(), isNull);

      await _tapNav(tester, 'Approval');
      expect(tester.takeException(), isNull);
      AdminNavigation.openApproval(ApprovalKind.concert);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final jazzFinder = find.descendant(
        of: find.byType(AdminApprovalScreen),
        matching: find.text('Jazz Night 2026'),
      );
      await tester.drag(find.byType(ListView).last, const Offset(0, -350));
      await tester.pumpAndSettle();
      await tester.tap(jazzFinder);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Tolak Konser'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Layar Kelola Pengguna (Image 4): filter chip role (Semua, User, Produser, Admin) dan pencarian pengguna',
        (tester) async {
      await _pumpAdmin(tester);
      await _tapNav(tester, 'Kelola User');

      expect(find.text('Kelola Pengguna'), findsOneWidget);
      expect(find.text('Daftar seluruh role pengguna terdaftar di Soundwave'),
          findsOneWidget);
      expect(find.text('Cari pengguna...'), findsOneWidget);

      // Pastikan semua 5 user dummy terdaftar pada chip Semua
      expect(find.text('Rafi Firmansyah'), findsOneWidget);
      expect(find.text('PT Harmony Ent.'), findsOneWidget);
      expect(find.text('Super Admin'), findsOneWidget);
      expect(find.text('Nadin Amizah'), findsOneWidget);
      expect(find.text('Katty Perry'), findsOneWidget);

      // Filter Role 'User'
      await tester.tap(find.byKey(const ValueKey('filter_chip_User')));
      await tester.pumpAndSettle();
      expect(find.text('Rafi Firmansyah'), findsOneWidget);
      expect(find.text('Katty Perry'), findsOneWidget);
      expect(find.text('PT Harmony Ent.'), findsNothing);
      expect(find.text('Nadin Amizah'), findsNothing);

      // Filter Role 'Produser'
      await tester.tap(find.byKey(const ValueKey('filter_chip_Produser')));
      await tester.pumpAndSettle();
      expect(find.text('PT Harmony Ent.'), findsOneWidget);
      expect(find.text('Nadin Amizah'), findsOneWidget);
      expect(find.text('Rafi Firmansyah'), findsNothing);

      // Filter Role 'Admin'
      final adminChip = find.byKey(const ValueKey('filter_chip_Admin'));
      await tester.ensureVisible(adminChip);
      await tester.tap(adminChip);
      await tester.pumpAndSettle();
      expect(find.text('Super Admin'), findsOneWidget);
      expect(find.text('PT Harmony Ent.'), findsNothing);

      // Kembali ke 'Semua'
      final semuaChip = find.byKey(const ValueKey('filter_chip_Semua'));
      await tester.ensureVisible(semuaChip);
      await tester.tap(semuaChip);
      await tester.pumpAndSettle();

      // Cari berdasarkan nama
      await tester.enterText(find.byType(TextField), 'Rafi');
      await tester.pumpAndSettle();
      expect(find.text('Rafi Firmansyah'), findsOneWidget);
      expect(find.text('Katty Perry'), findsNothing);

      // Cari yang tidak ada -> empty state
      await tester.enterText(find.byType(TextField), 'xyz123abc');
      await tester.pumpAndSettle();
      expect(find.text('Pengguna tidak ditemukan'), findsOneWidget);

      // Bersihkan pencarian via icon clear
      await tester.tap(find.byIcon(Icons.clear_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Rafi Firmansyah'), findsOneWidget);
      expect(find.text('Katty Perry'), findsOneWidget);
    });

    testWidgets(
        'Layar Detail Pengguna (Image 5): metrik tiket & konser, info akun, riwayat transaksi, dan toggle status akun',
        (tester) async {
      await _pumpAdmin(tester);
      await _tapNav(tester, 'Kelola User');

      // Tap Rafi Firmansyah untuk membuka Detail Pengguna (Image 5)
      await tester.tap(find.text('Rafi Firmansyah'));
      await tester.pumpAndSettle();

      expect(find.text('Detail Pengguna'), findsOneWidget);
      expect(find.text('RF'), findsOneWidget);
      expect(find.text('Rafi Firmansyah'), findsOneWidget);

      // 3 Metrik
      expect(find.text('12'), findsOneWidget);
      expect(find.text('Tiket Dibeli'), findsOneWidget);
      expect(find.text('9'), findsOneWidget);
      expect(find.text('Konser Dihadiri'), findsOneWidget);
      expect(find.text('Favorit'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);

      // Informasi Akun
      expect(find.text('Nomor HP'), findsOneWidget);
      expect(find.text('0812 3456 7890'), findsOneWidget);
      expect(find.text('Bergabung Sejak'), findsOneWidget);
      expect(find.text('12 Juni 2025'), findsOneWidget);
      expect(find.text('Status Akun'), findsOneWidget);
      expect(find.text('Aktif'), findsOneWidget);

      // Riwayat Transaksi
      expect(find.text('Riwayat Transaksi'), findsOneWidget);
      expect(find.text('Soundwave Fest 2026'), findsOneWidget);
      expect(find.text('INV/20261012/992 · Rp1.006.500'), findsOneWidget);
      expect(find.text('Berhasil'), findsOneWidget);

      // Tombol Nonaktifkan Akun
      expect(find.text('Nonaktifkan Akun'), findsOneWidget);
      await tester.tap(find.text('Nonaktifkan Akun'));
      await tester.pumpAndSettle();

      // Dialog Konfirmasi
      expect(find.text('Nonaktifkan Akun?'), findsOneWidget);
      await tester.tap(find.text('Nonaktifkan'));
      await tester.pumpAndSettle();

      // Status berubah menjadi Nonaktif dan tombol berubah menjadi Aktifkan Akun
      expect(find.text('Nonaktif'), findsOneWidget);
      expect(find.text('Aktifkan Akun'), findsOneWidget);
      expect(AdminService().userById('usr-001')?.isActive, false);

      // Aktifkan kembali
      await tester.tap(find.text('Aktifkan Akun'));
      await tester.pumpAndSettle();
      expect(find.text('Aktifkan Akun?'), findsOneWidget);
      await tester.tap(find.text('Aktifkan'));
      await tester.pumpAndSettle();

      expect(find.text('Aktif'), findsOneWidget);
      expect(find.text('Nonaktifkan Akun'), findsOneWidget);
      expect(AdminService().userById('usr-001')?.isActive, true);

      // Test Ganti Nama di Detail Pengguna
      expect(find.byKey(const ValueKey('btn_ganti_nama')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('btn_ganti_nama')));
      await tester.pumpAndSettle();
      expect(find.text('Ganti Nama Pengguna'), findsOneWidget);
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Nama Baru'), 'Rafi F. Perkasa');
      await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
      await tester.pumpAndSettle();
      expect(find.text('Rafi F. Perkasa'), findsAtLeastNWidgets(1));
      expect(AdminService().userById('usr-001')?.name, 'Rafi F. Perkasa');

      // Verifikasi Fitur Ganti Password telah dihapus dari Kelola User Detail
      expect(find.byKey(const ValueKey('btn_ganti_password')), findsNothing);
      expect(find.text('Ganti Password'), findsNothing);
    });

    testWidgets(
        'AdminUsersScreen: Aksi menu popup Ganti Nama hadir dan fitur Ganti Password telah dihapus dari kelola user',
        (tester) async {
      await _pumpAdmin(tester);
      await _tapNav(tester, 'Kelola User');

      // Buka popup menu akun pada kartu pertama
      final moreBtnFinder = find.byTooltip('Menu Akun').first;
      await tester.tap(moreBtnFinder);
      await tester.pumpAndSettle();

      // Pilih Ganti Nama
      expect(find.text('Ganti Nama'), findsOneWidget);
      expect(find.text('Lihat Detail'), findsOneWidget);
      // Verifikasi Ganti Password tidak ada di popup menu
      expect(find.text('Ganti Password'), findsNothing);

      await tester.tap(find.text('Ganti Nama'));
      await tester.pumpAndSettle();
      expect(find.text('Ganti Nama Pengguna'), findsOneWidget);
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Nama Baru'), 'Rafi F. Popup');
      await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
      await tester.pumpAndSettle();
      expect(find.text('Rafi F. Popup'), findsOneWidget);
    });

    testWidgets(
        'AdminProfileScreen: Mode Tampilan switch toggle langsung, Notifikasi, Customer Service, dan Keluar',
        (tester) async {
      await _pumpAdmin(tester);
      await _tapNav(tester, 'Profil');

      // 1. Verifikasi header awal
      expect(find.text('Super Admin'), findsOneWidget);
      expect(find.text('AD'), findsOneWidget);
      expect(find.text(DataService().currentUser?.email ?? 'admin@livetix.com'),
          findsOneWidget);

      // 2. Mode Tampilan menjadi toggle switch langsung
      expect(find.text('Mode Tampilan'), findsOneWidget);
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);
      final initialMode = DataService().isDarkModeNotifier.value;
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();
      expect(DataService().isDarkModeNotifier.value, !initialMode);
      // Toggle kembali
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();
      expect(DataService().isDarkModeNotifier.value, initialMode);

      // 3. Notifikasi
      expect(find.text('Notifikasi'), findsOneWidget);
      await tester.tap(find.text('Notifikasi'));
      await tester.pumpAndSettle();
      expect(find.text('Notifikasi Admin'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.chevron_left_rounded).first);
      await tester.pumpAndSettle();

      // 4. Customer Service
      expect(find.text('Customer Service (Admin Inbox)'), findsOneWidget);

      // 5. Keluar dari Akun
      expect(find.text('Keluar dari akun'), findsOneWidget);
    });

    testWidgets(
        'Alur Penonaktifan Akun User / Produser (Image 1 - 5): Detail Produser, form Nonaktifkan User, Akun Nonaktif, dan Detail User',
        (tester) async {
      await _pumpAdmin(tester);

      // Ke tab Approval -> Disetujui
      await _tapNav(tester, 'Approval');
      await _tapTab(tester, 'Disetujui');
      await tester.pumpAndSettle();
      expect(find.text('CV Musik Nusantara'), findsOneWidget);

      // Buka Detail Produser (Image 5)
      await tester.tap(find.text('CV Musik Nusantara'));
      await tester.pumpAndSettle();

      expect(find.text('Detail Produser'), findsOneWidget);
      expect(find.text('Profil produser yang telah disetujui'), findsOneWidget);
      expect(find.text('CV Musik Nusantara'), findsOneWidget);
      expect(find.text('Terverifikasi · 24 Okt 2026'), findsOneWidget);
      expect(find.text('Statistik Produser'), findsOneWidget);
      expect(find.text('Konser Diajukan'), findsOneWidget);
      expect(find.text('Konser Aktif'), findsAtLeastNWidgets(1));
      expect(find.text('Tiket Terjual'), findsOneWidget);
      expect(find.text('12,450'), findsOneWidget);
      expect(find.text('Soundwave Fest 2026'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Jazz Night 2026'), 150);
      expect(find.text('Jazz Night 2026'), findsOneWidget);
      expect(find.text('Nonaktifkan Produser'), findsOneWidget);
      expect(find.text('Kembali'), findsOneWidget);

      // Klik Nonaktifkan Produser -> Buka Nonaktifkan Produser (Image 4 & 5)
      await tester.tap(find.text('Nonaktifkan Produser'));
      await tester.pumpAndSettle();

      expect(find.text('Nonaktifkan Produser'), findsOneWidget);
      expect(find.text('Tinjau akun sebelum menonaktifkan'), findsOneWidget);
      expect(find.text('Statistik Produser'), findsOneWidget);
      expect(find.text('Konser Diajukan'), findsOneWidget);
      expect(find.text('Konser Aktif'), findsAtLeastNWidgets(1));
      expect(find.text('Tiket Terjual'), findsOneWidget);
      await tester.scrollUntilVisible(
          find.text('2 konser aktif akan otomatis dihentikan sementara'), 150);
      expect(find.text('2 konser aktif akan otomatis dihentikan sementara'),
          findsOneWidget);
      expect(find.text('0/300'), findsOneWidget);

      // Tombol Nonaktifkan Akun awalnya nonaktif
      final submitButton =
          find.widgetWithText(FilledButton, 'Nonaktifkan Akun');
      expect(submitButton, findsOneWidget);
      final initialButton = tester.widget<FilledButton>(submitButton);
      expect(initialButton.onPressed, isNull);

      // Isi alasan (Image 5)
      final reasonField = find.byType(TextField);
      await tester.enterText(reasonField,
          'Akun terindikasi menjual tiket di luar sistem resmi dan menerima 6 laporan pembeli dalam 30 hari terakhir. Akun dinonaktifkan sementara menunggu klarifikasi produser.');
      await tester.pumpAndSettle();

      expect(find.text('166/300'), findsOneWidget);
      final activeButton = tester.widget<FilledButton>(submitButton);
      expect(activeButton.onPressed, isNotNull);

      // Submit penonaktifan -> Result screen (Image 3)
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(find.text('Akun Nonaktif'), findsOneWidget);
      expect(find.text('Penonaktifan Akun User'), findsOneWidget);
      expect(find.text('Nama Produser'), findsOneWidget);
      expect(find.text('CV Musik Nusantara'), findsOneWidget);
      expect(find.text('Tanggal Penolakan'), findsOneWidget);
      expect(find.text('Ditolak'), findsOneWidget);
      expect(find.text('Alasan Penolakan'), findsOneWidget);
      expect(
          find.text(
              'Akun terindikasi menjual tiket di luar sistem resmi dan menerima 6 laporan pembeli dalam 30 hari terakhir. Akun dinonaktifkan sementara menunggu klarifikasi produser.'),
          findsOneWidget);
      expect(find.text('Lihat Detail'), findsOneWidget);
      expect(find.text('Kembali ke Beranda'), findsOneWidget);

      // Klik Lihat Detail -> Detail Produser (Image 1)
      await tester.tap(find.text('Lihat Detail'));
      await tester.pumpAndSettle();

      expect(find.text('Detail Produser'), findsOneWidget);
      expect(find.text('Profil produser yang telah disetujui'), findsOneWidget);
      expect(find.text('Nonaktif · 24 Okt 2026'), findsOneWidget);
      expect(find.text('Statistik Produser'), findsOneWidget);
      expect(find.text('Konser Diajukan'), findsOneWidget);
      expect(find.text('Konser Dihentikan'), findsOneWidget);
      expect(find.text('Tiket Terjual'), findsOneWidget);
      expect(find.text('12,450'), findsOneWidget);
      expect(find.text('Nonaktifkan Produser'), findsNothing);
    });

    testWidgets(
        'Layar Profil Super Admin (Image 3): gradien ungu, kartu stat 45 & 128, menu AKUN, PENGATURAN, dan LAINNYA',
        (tester) async {
      await _pumpAdmin(tester);
      await _tapNav(tester, 'Profil');

      // Header gradien & profil
      expect(find.text('Super Admin'), findsWidgets);
      expect(find.text('AD'), findsOneWidget);

      // 2 Kartu Statistik
      expect(find.text('Approval Hari Ini'), findsOneWidget);
      expect(find.text('45'), findsOneWidget);
      expect(find.text('Total Approval'), findsOneWidget);
      expect(find.text('128'), findsOneWidget);

      // Seksi AKUN
      expect(find.text('AKUN'), findsOneWidget);
      expect(find.text('Edit Profil'), findsOneWidget);
      expect(find.text('Ubah Kata Sandi'), findsOneWidget);

      // Seksi PENGATURAN
      expect(find.text('PENGATURAN'), findsOneWidget);
      expect(find.text('Notifikasi'), findsOneWidget);
      expect(find.text('Mode Tampilan'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
      expect(find.text('Bahasa'), findsOneWidget);
      expect(find.text('Indonesia'), findsOneWidget);

      // Seksi LAINNYA
      expect(find.text('LAINNYA'), findsOneWidget);
      expect(find.text('Pusat Bantuan'), findsOneWidget);
      expect(find.text('Tentang Aplikasi'), findsOneWidget);
      expect(find.text('Kebijakan Privasi'), findsOneWidget);
      expect(find.text('Keluar dari akun'), findsOneWidget);

      // Dialog keluar dibatalkan tetap di Profil
      await tester.drag(find.byType(ListView).last, const Offset(0, -350));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keluar dari akun'));
      await tester.pumpAndSettle();
      expect(find.text('Keluar dari akun?'), findsOneWidget);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(find.text('Super Admin'), findsWidgets);
    });

    testWidgets(
        'Layar Notifikasi Super Admin (Image 3): tab Semua (5), Approval, Sistem, badge belum dibaca, dan klik item',
        (tester) async {
      await _pumpAdmin(tester);

      // Klik ikon notifikasi di header dashboard
      final notifBtn = find.byTooltip('Notifikasi');
      expect(notifBtn, findsOneWidget);
      await tester.tap(notifBtn);
      await tester.pumpAndSettle();

      // Header Notifikasi
      expect(find.text('Notifikasi'), findsOneWidget);
      expect(find.text('Aktivitas dan log sistem terbaru'), findsOneWidget);

      // Tab bar Semua (5), Approval, Sistem
      expect(find.text('Semua (5)'), findsOneWidget);
      expect(find.text('Approval'), findsOneWidget);
      expect(find.text('Sistem'), findsOneWidget);

      // 5 Notifikasi awal di tab Semua
      expect(find.text('Pendaftaran Produser Baru'), findsOneWidget);
      expect(find.text('Konser Baru Diajukan'), findsOneWidget);
      expect(find.text('Approval Berhasil'), findsOneWidget);
      expect(find.text('Pengguna Baru'), findsOneWidget);
      expect(find.text('Laporan Mingguan'), findsOneWidget);

      // Filter tab Approval -> 3 item
      await tester.tap(find.text('Approval'));
      await tester.pumpAndSettle();
      expect(find.text('Pendaftaran Produser Baru'), findsOneWidget);
      expect(find.text('Konser Baru Diajukan'), findsOneWidget);
      expect(find.text('Approval Berhasil'), findsOneWidget);
      expect(find.text('Pengguna Baru'), findsNothing);
      expect(find.text('Laporan Mingguan'), findsNothing);

      // Filter tab Sistem -> 2 item
      await tester.tap(find.text('Sistem'));
      await tester.pumpAndSettle();
      expect(find.text('Pengguna Baru'), findsOneWidget);
      expect(find.text('Laporan Mingguan'), findsOneWidget);
      expect(find.text('Pendaftaran Produser Baru'), findsNothing);

      // Kembali ke tab Semua dan klik Pendaftaran Produser Baru -> buka Detail Produser
      await tester.tap(find.text('Semua (5)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pendaftaran Produser Baru'));
      await tester.pumpAndSettle();

      expect(find.text('Detail Produser'), findsOneWidget);
      expect(find.text('PT Harmony Entertainment'), findsOneWidget);
    });

    testWidgets(
        'Detail Produser nonaktif (Image 1): status Nonaktif · 24 Okt 2026, Statistik Produser (Konser Dihentikan: 5), dan tanpa tombol aksi',
        (tester) async {
      final service = AdminService();
      await service.load();
      service.deactivateProducer(
          'prd-001', 'Pelanggaran kebijakan penjualan tiket.');

      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(
          home: AdminProducerDetailScreen(producerId: 'prd-001'),
        ),
      );
      await tester.pumpAndSettle();

      // Image 1: Header
      expect(find.text('Detail Produser'), findsOneWidget);
      expect(find.text('Profil produser yang telah disetujui'), findsOneWidget);

      // Kartu info produser
      expect(find.text('PT Harmony Entertainment'), findsOneWidget);
      expect(find.text('harmony@email.com'), findsOneWidget);
      expect(find.text('Nonaktif · 24 Okt 2026'), findsOneWidget);
      expect(find.text('0812 3456 7890'), findsOneWidget);
      expect(find.text('Jl. Sudirman No. 45, Jakarta'), findsOneWidget);

      // Statistik Produser
      expect(find.text('Statistik Produser'), findsOneWidget);
      expect(find.text('Konser Diajukan'), findsOneWidget);
      expect(find.text('Konser Dihentikan'), findsOneWidget);
      expect(find.text('Tiket Terjual'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('12,450'), findsOneWidget);

      // Tanpa tombol aksi di bottomBar
      expect(find.text('Nonaktifkan Produser'), findsNothing);
      expect(find.text('Setujui Produser'), findsNothing);
    });

    testWidgets(
        'Approval Konser (Image 2): inisial SO, HA, JA, badge Menunggu, pill Pembatalan / Perubahan, dan info tiket terjual',
        (tester) async {
      await _pumpAdmin(tester);
      AdminNavigation.openApproval(ApprovalKind.concert);
      await tester.pumpAndSettle();

      expect(find.text('Approval Konser'), findsOneWidget);
      expect(find.text('Verifikasi pengajuan tayang konser baru'),
          findsOneWidget);
      expect(find.text('Menunggu (3)'), findsOneWidget);

      // Avatar Inisial dua huruf (Image 2)
      expect(find.text('SO'), findsOneWidget);
      expect(find.text('HA'), findsOneWidget);
      expect(find.text('JA'), findsOneWidget);

      // 3 Konser dengan subjudul dan pill
      expect(find.text('Soundwave Fest 2026'), findsOneWidget);
      expect(find.text('Java Promotor · 19 Okt 2026'), findsOneWidget);
      expect(find.text('4,200 tiket terjual'), findsOneWidget);

      expect(find.text('Harmoni Nusantara 2026'), findsOneWidget);
      expect(find.text('Nusa Event · 19 Okt 2026'), findsOneWidget);
      expect(find.text('0 tiket terjual'), findsOneWidget);

      expect(find.text('Jazz Night 2026'), findsOneWidget);
      expect(find.text('PT Harmony Ent. · 18 Okt 2026'), findsOneWidget);
      expect(find.text('Ubah venue'), findsOneWidget);

      // Pill Pembatalan (2x) dan Perubahan (1x)
      expect(find.text('Pembatalan'), findsNWidgets(2));
      expect(find.text('Perubahan'), findsOneWidget);
    });

    testWidgets(
        'Alur Detail Pembatalan dan Modal Setujui Pembatalan (Image 3 & Image 5): info konser, alasan bergaris merah, dampak pembatalan, 4 poin otomatis, dan persetujuan',
        (tester) async {
      await _pumpAdmin(tester);
      AdminNavigation.openApproval(ApprovalKind.concert);
      await tester.pumpAndSettle();

      // Klik Soundwave Fest 2026 (request_type == 'cancellation')
      await tester.tap(find.text('Soundwave Fest 2026'));
      await tester.pumpAndSettle();

      // Image 3: Detail Pembatalan
      expect(find.text('Detail Pembatalan'), findsOneWidget);
      expect(find.text('Tinjau pengajuan pembatalan konser'), findsOneWidget);

      // Card 1
      expect(find.text('Soundwave Fest 2026'), findsOneWidget);
      expect(find.text('Produser: Java Promotor'), findsOneWidget);
      expect(find.text('12 Okt 2026 · 19.00 WIB'), findsOneWidget);
      expect(find.text('Stadion Gajayana, Malang'), findsOneWidget);

      // Card 2: Alasan Pembatalan
      expect(find.text('Alasan Pembatalan'), findsOneWidget);
      expect(find.text('19 Okt 2026, 14:02'), findsOneWidget);
      expect(
        find.textContaining('Izin keramaian dari kepolisian belum terbit'),
        findsOneWidget,
      );
      expect(find.text('Lampiran: surat_izin_polres.pdf'), findsOneWidget);

      // Card 3: Dampak Pembatalan
      expect(find.text('Dampak Pembatalan'), findsOneWidget);
      expect(find.text('4,200 / 5,000'), findsOneWidget);
      expect(find.text('Pembeli terdampak'), findsOneWidget);
      expect(find.text('1,860 orang'), findsOneWidget);
      expect(find.text('Refund 100% ke pembeli'), findsOneWidget);
      expect(find.text('Rp2.115.000.000'), findsNWidgets(2));
      expect(find.text('Dana produser ditahan'), findsOneWidget);

      // Tombol bawah
      expect(find.text('Tolak Pembatalan'), findsOneWidget);
      expect(find.text('Setujui Pembatalan'), findsOneWidget);

      // Klik Setujui Pembatalan -> Modal BottomSheet (Image 5)
      await tester.tap(find.text('Setujui Pembatalan'));
      await tester.pumpAndSettle();

      expect(find.text('Setujui pembatalan konser?'), findsOneWidget);
      expect(find.text('Yang akan terjadi otomatis:'), findsOneWidget);
      expect(find.text('Konser berstatus Dibatalkan'), findsOneWidget);
      expect(find.text('Penjualan tiket ditutup seketika'), findsOneWidget);
      expect(find.text('Refund 100% ke 1,860 pembeli'), findsOneWidget);
      expect(find.text('Total Rp2.115.000.000 termasuk biaya layanan'),
          findsOneWidget);
      expect(find.text('Pembeli dinotifikasi'), findsOneWidget);
      expect(
          find.text('Mengisi rekening / e-wallet di aplikasi'), findsOneWidget);
      expect(find.text('Produser diberi tahu'), findsOneWidget);
      expect(find.text('Laporan refund tersedia di dasbor produser'),
          findsOneWidget);
      expect(find.text('Tindakan ini tidak dapat diurungkan.'), findsOneWidget);

      // Klik Ya, Setujui Pembatalan -> Pembatalan Disetujui (Image 1)
      await tester.tap(find.text('Ya, Setujui Pembatalan'));
      await tester.pumpAndSettle();

      expect(find.text('Pembatalan Disetujui!'), findsOneWidget);
      expect(find.text('Refund otomatis diproses ke pembeli'), findsOneWidget);
      expect(find.text('Nama Konser'), findsOneWidget);
      expect(find.text('Soundwave Fest 2026'), findsOneWidget);
      expect(find.text('Dibatalkan'), findsOneWidget);
      expect(find.text('1,860 orang · Rp2.115.000.000'), findsOneWidget);
      expect(find.text('Pembeli dan produser sudah dinotifikasi.'), findsOneWidget);
      expect(find.text('Lihat Pantau Refund'), findsOneWidget);
      expect(find.text('Kembali ke Beranda'), findsOneWidget);
      expect(AdminService().concertById('cnc-001')?.status, 'cancelled');

      // Dari Image 1: Klik Lihat Pantau Refund -> Masuk ke Monitoring Refund (Image 2)
      await tester.tap(find.text('Lihat Pantau Refund'));
      await tester.pumpAndSettle();

      expect(find.text('Monitoring Refund'), findsOneWidget);
      expect(find.text('Pantau pengembalian dana konser dibatalkan'), findsOneWidget);
      expect(find.text('Total dikembalikan'), findsOneWidget);
      expect(find.text('Rp1,74 M'), findsOneWidget);
      expect(find.text('Perlu tindakan'), findsOneWidget);
      expect(find.text('210'), findsOneWidget);
      expect(find.text('Berjalan (2)'), findsOneWidget);
      expect(find.text('Selesai'), findsOneWidget);
      expect(find.text('Perlu data'), findsOneWidget);
    });

    testWidgets(
        'Detail Pembatalan dengan 0 tiket terjual (Image 4): Harmoni Nusantara 2026, status Belum ada, dan box tanpa refund',
        (tester) async {
      await _pumpAdmin(tester);
      AdminNavigation.openApproval(ApprovalKind.concert);
      await tester.pumpAndSettle();

      // Klik Harmoni Nusantara 2026 (0 tiket terjual)
      await tester.tap(find.text('Harmoni Nusantara 2026'));
      await tester.pumpAndSettle();

      // Image 4: Header & Info Konser
      expect(find.text('Detail Pembatalan'), findsOneWidget);
      expect(find.text('Harmoni Nusantara 2026'), findsOneWidget);
      expect(find.text('Produser: Nusa Event'), findsOneWidget);
      expect(find.text('14 Nov 2026 · 19.00 WIB'), findsOneWidget);
      expect(find.text('Balai Sarbini, Jakarta'), findsOneWidget);

      // Card 2: Alasan Pembatalan
      expect(find.text('Alasan Pembatalan'), findsOneWidget);
      expect(find.text('Lampiran: surat_izin_polres.pdf'), findsOneWidget);

      // Card 3 (Image 4): Status Pembelian Tiket (Belum ada)
      expect(find.text('Status Pembelian Tiket'), findsOneWidget);
      expect(find.text('Belum ada'), findsOneWidget);
      expect(find.text('Tiket terjual'), findsOneWidget);
      expect(find.text('0 / 5,000'), findsOneWidget);
      expect(find.text('Tidak ada pembeli, jadi tidak ada refund.'), findsOneWidget);
      expect(find.text('Konser langsung ditutup setelah disetujui.'), findsOneWidget);

      // Bottom bar
      expect(find.text('Tolak Pembatalan'), findsOneWidget);
      expect(find.text('Setujui Pembatalan'), findsOneWidget);

      // Modal BottomSheet untuk 0 pembeli
      await tester.tap(find.text('Setujui Pembatalan'));
      await tester.pumpAndSettle();

      expect(find.text('Setujui pembatalan konser?'), findsOneWidget);
      expect(find.text('Tidak ada refund ke pembeli'), findsOneWidget);
      expect(find.text('0 pembeli terdampak pembatalan'), findsOneWidget);

      // Klik Setujui Pembatalan -> Pembatalan Disetujui (Image 1 dengan 0 orang)
      await tester.tap(find.text('Ya, Setujui Pembatalan'));
      await tester.pumpAndSettle();

      expect(find.text('Pembatalan Disetujui!'), findsOneWidget);
      expect(find.text('Harmoni Nusantara 2026'), findsOneWidget);
      expect(find.text('0 orang · Rp0'), findsOneWidget);
    });

    testWidgets(
        'Monitoring Refund dan Detail Refund (Image 2 & Image 3): metrik 3 kartu, daftar pembeli, pengingat, dan ekspor',
        (tester) async {
      await _pumpAdmin(tester);

      // Akses Monitoring Refund melalui Banner di Beranda
      await tester.tap(find.text('Monitoring Refund'));
      await tester.pumpAndSettle();

      // Image 2: Monitoring Refund
      expect(find.text('Monitoring Refund'), findsOneWidget);
      expect(find.text('Pantau pengembalian dana konser dibatalkan'), findsOneWidget);
      expect(find.text('Total dikembalikan'), findsOneWidget);
      expect(find.text('Rp1,74 M'), findsOneWidget);
      expect(find.text('Perlu tindakan'), findsOneWidget);
      expect(find.text('210'), findsOneWidget);

      // Kartu 1: Soundwave Fest 2026
      expect(find.text('Soundwave Fest 2026'), findsOneWidget);
      expect(find.text('2,940 / 4,200 tiket'), findsOneWidget);
      expect(find.text('70%'), findsOneWidget);
      expect(find.text('Dana kembali: Rp1.480.500.000'), findsOneWidget);

      // Kartu 2: Jazz Night 2026
      expect(find.text('Jazz Night 2026'), findsOneWidget);
      expect(find.text('520 / 4,300 tiket'), findsOneWidget);
      expect(find.text('12%'), findsOneWidget);
      expect(find.text('Dana kembali: Rp262.400.000'), findsOneWidget);

      // Klik Lihat › pada Soundwave Fest 2026 -> Masuk ke Detail Refund (Image 3)
      await tester.tap(find.text('Lihat ›').first);
      await tester.pumpAndSettle();

      // Image 3: Detail Refund Header & Kartu Progres
      expect(find.text('Detail Refund'), findsOneWidget);
      expect(find.text('Soundwave Fest 2026'), findsOneWidget);
      expect(find.text('Progres Refund'), findsOneWidget);
      expect(find.text('2,940 / 4,200 tiket'), findsOneWidget);
      expect(find.text('Rp1.480.500.000 dari Rp2.115.000.000'), findsOneWidget);

      // 3 Kartu Metrik
      expect(find.text('2,940'), findsOneWidget);
      expect(find.text('Selesai'), findsWidgets);
      expect(find.text('1,050'), findsOneWidget);
      expect(find.text('Diproses'), findsWidgets);
      expect(find.text('210'), findsWidgets);
      expect(find.text('Perlu data'), findsWidgets);

      // Batas Refund
      expect(find.text('Batas refund pembeli'), findsOneWidget);
      expect(find.text('30 Nov 2026 · sisa 42 hari'), findsOneWidget);

      // Scroll ke bawah untuk melihat Daftar Pembeli secara penuh
      await tester.drag(find.byType(ListView).last, const Offset(0, -300));
      await tester.pumpAndSettle();

      // Daftar Pembeli
      expect(find.text('Daftar Pembeli'), findsOneWidget);
      expect(find.text('Rafi Ardiansyah'), findsOneWidget);
      expect(find.text('2 tiket · BCA ••9012'), findsOneWidget);
      expect(find.text('Budi Santoso'), findsOneWidget);
      expect(find.text('4 tiket · Belum isi rekening'), findsOneWidget);
      expect(find.text('Nadia Putri'), findsOneWidget);
      expect(find.text('1 tiket · GoPay ••4410'), findsOneWidget);

      // Tombol Aksi Bawah
      expect(find.text('Kirim Pengingat (210)'), findsOneWidget);
      expect(find.text('Ekspor Laporan'), findsOneWidget);

      // Tap Kirim Pengingat
      await tester.tap(find.text('Kirim Pengingat (210)'));
      await tester.pump();
      expect(
        find.textContaining('Pengingat berhasil dikirim ke 210 pembeli'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // Tap Ekspor Laporan
      await tester.tap(find.text('Ekspor Laporan'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Laporan refund berhasil diekspor.'), findsOneWidget);
    });

    testWidgets(
        'Alur Tinjau Pembatalan dan Penolakan Pembatalan (Image 4): quick chips, counter 500, dan kirim penolakan',
        (tester) async {
      await _pumpAdmin(tester);
      AdminNavigation.openApproval(ApprovalKind.concert);
      await tester.pumpAndSettle();

      // Buka Detail Pembatalan -> Klik Tolak Pembatalan -> Buka Tinjau Pembatalan (Image 4)
      await tester.tap(find.text('Soundwave Fest 2026'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tolak Pembatalan'));
      await tester.pumpAndSettle();

      // Image 4: Header
      expect(find.text('Tinjau Pembatalan'), findsOneWidget);
      expect(
          find.text('Periksa pengajuan dan berikan keputusan'), findsOneWidget);
      expect(find.text('Soundwave Fest 2026'), findsOneWidget);

      // Form
      expect(find.text('Alasan Penolakan'), findsOneWidget);
      expect(find.text('Wajib diisi, akan dikirim ke produser'), findsOneWidget);
      expect(find.text('Bukti kurang'), findsOneWidget);
      expect(find.text('Dokumen tidak valid'), findsOneWidget);
      expect(find.text('0/500'), findsOneWidget);
      expect(find.text('Konser tetap aktif sampai disetujui.'), findsOneWidget);

      // Klik quick chip Bukti kurang
      await tester.tap(find.text('Bukti kurang'));
      await tester.pumpAndSettle();

      const expectedTemplate =
          'Mohon lampirkan surat resmi dari Polres yang menyatakan izin keramaian tidak diterbitkan, lalu ajukan kembali pembatalan.';
      expect(find.text('${expectedTemplate.length}/500'), findsOneWidget);

      // Klik Kirim Penolakan
      await tester.tap(find.text('Kirim Penolakan'));
      await tester.pumpAndSettle();

      expect(find.text('Approval Ditolak'), findsOneWidget);
      expect(find.text('Pengajuan Ditolak'), findsOneWidget);
      expect(AdminService().concertById('cnc-001')?.approvalStatus,
          ApprovalStatus.rejected);
      expect(AdminService().concertById('cnc-001')?.cancellationReviewReason,
          expectedTemplate);
    });
  });

  testWidgets('Login admin@livetix.com otomatis masuk ke shell Super Admin',
      (tester) async {
    DataService().logout();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'admin@livetix.com');
    await tester.enterText(fields.at(1), 'admin123');
    await tester.ensureVisible(find.text('Masuk').last);
    await tester.tap(find.text('Masuk').last);
    await tester.pumpAndSettle();

    expect(find.byType(AdminShell), findsOneWidget);
    expect(find.text('Halo, Admin'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });
}
