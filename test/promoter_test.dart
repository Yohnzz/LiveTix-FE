import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livetix/screens/promoter/promoter_main_screen.dart';
import 'package:livetix/screens/promoter/promoter_concert_list_screen.dart';
import 'package:livetix/screens/promoter/add_concert/add_concert_flow.dart';
import 'package:livetix/screens/promoter/verification/producer_verification_flow.dart';
import 'package:livetix/services/promoter_data_service.dart';

void main() {
  testWidgets('PromoterMainScreen renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PromoterMainScreen(),
      ),
    );

    // Verify Promotor dashboard text
    expect(find.text('Malam ini ada apa?'), findsOneWidget);
    expect(find.text('Java Promotor'), findsOneWidget);
    expect(find.text('TERVERIFIKASI'), findsOneWidget);
    expect(find.text('TOTAL KONSER'), findsOneWidget);
    expect(find.text('TIKET TERJUAL'), findsOneWidget);
    expect(find.text('TOTAL PENDAPATAN'), findsOneWidget);
  });

  testWidgets('PromoterConcertListScreen renders filter tabs and quota banner',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PromoterConcertListScreen(),
        ),
      ),
    );

    expect(find.text('Daftar Konser'), findsOneWidget);
    expect(find.text('Aktif'), findsWidgets);
    expect(find.text('Selesai (Riwayat)'), findsOneWidget);
    expect(find.text('Semua'), findsOneWidget);
    expect(find.text('Draft'), findsOneWidget);
    expect(find.text('Menunggu'), findsOneWidget);
    expect(find.text('Disetujui'), findsOneWidget);
    expect(find.text('Ditolak'), findsOneWidget);
  });

  testWidgets('AddConcertFlow steps 3 to 4 starts empty and submits to Detail Status Konser',
      (WidgetTester tester) async {
    PromoterDataService().quotaRemainingNotifier.value = 5;

    await tester.pumpWidget(
      const MaterialApp(
        home: AddConcertFlow(initialStep: 3),
      ),
    );

    // Step 3: Paket Harga Tiket (starts with empty fields)
    expect(find.text('Paket Harga Tiket'), findsOneWidget);
    expect(find.text('0 Tiket'), findsOneWidget);
    expect(find.text('Lanjut ke Pilih Gate Crew'), findsOneWidget);

    await tester.tap(find.text('Lanjut ke Pilih Gate Crew'));
    await tester.pumpAndSettle();

    // Step 4: Pilih Gate Crew
    expect(find.text('Pilih & Tugaskan Gate Crew'), findsOneWidget);
    expect(find.text('Lanjut ke Ringkasan & Approval'), findsOneWidget);

    await tester.tap(find.text('Lanjut ke Ringkasan & Approval'));
    await tester.pumpAndSettle();

    // Step 5: Ringkasan Pengajuan
    expect(find.text('Ringkasan Pengajuan'), findsOneWidget);
    expect(find.text('Detail Konser'), findsOneWidget);
    expect(find.text('Paket Tiket Terpilih'), findsOneWidget);
    expect(find.text('Kirim untuk Approval Admin'), findsOneWidget);

    PromoterDataService().quotaRemainingNotifier.value = 5;
    await tester.tap(find.text('Kirim untuk Approval Admin'));
    await tester.pumpAndSettle();

    // ConcertStatusDetailScreen (Menunggu Approval)
    expect(find.text('Pengajuan baru sedang ditinjau kurasi LiveTix'), findsOneWidget);
  });

  testWidgets('ProducerVerificationFlow requires KTP, Lembar Penanggung Jawab, and PIN setup',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ProducerVerificationFlow(),
      ),
    );

    // Step 1: Isi data diri Produser
    expect(find.text('Isi data diri Produser'), findsOneWidget);
    expect(
      find.text('Langkah 1 dari 3: Informasi dasar penanggung jawab'),
      findsOneWidget,
    );
    expect(find.text('Lanjut ke Unggah Dokumen'), findsOneWidget);

    final nextStep1Btn = find.text('Lanjut ke Unggah Dokumen');
    await tester.ensureVisible(nextStep1Btn);
    await tester.tap(nextStep1Btn);
    await tester.pumpAndSettle();

    // Step 2: Unggah Dokumen KTP + Lembar Penanggung Jawab
    expect(find.text('Unggah Dokumen KTP'), findsOneWidget);
    expect(find.text('Dokumen yang dibutuhkan'), findsOneWidget);
    expect(find.text('Pilih Dokumen KTP'), findsOneWidget);
    expect(
      find.text('Unduh Template Lembar Penanggung Jawab (.doc)'),
      findsOneWidget,
    );

    // 1. Upload KTP
    await tester.tap(find.text('Pilih Dokumen KTP'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Unggah Dokumen KTP'));
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(find.text('Ganti Dokumen KTP'), findsOneWidget);

    // Clear SnackBar
    final scaffoldMessenger =
        tester.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).first);
    scaffoldMessenger.clearSnackBars();
    await tester.pumpAndSettle();

    // 2. Upload Lembar Penanggung Jawab
    final letterBtn = find.text('Unggah Lembar Penanggung Jawab');
    await tester.ensureVisible(letterBtn);
    await tester.tap(letterBtn);
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(ElevatedButton, 'Unggah Lembar Penanggung Jawab'),
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    scaffoldMessenger.clearSnackBars();
    await tester.pumpAndSettle();

    final nextPinBtn = find.text('Ajukan Approval Verifikasi');
    await tester.ensureVisible(nextPinBtn);
    await tester.tap(nextPinBtn);
    await tester.pumpAndSettle();

    // Step 3: Buat PIN Keamanan
    expect(find.text('Buat PIN Keamanan'), findsOneWidget);
    final pinFields = find.byType(TextField);
    expect(pinFields, findsNWidgets(2));
    await tester.enterText(pinFields.at(0), '123456');
    await tester.enterText(pinFields.at(1), '123456');
    await tester.pump();

    final submitPinBtn = find.text('Simpan PIN & Ajukan Verifikasi ke Admin');
    await tester.ensureVisible(submitPinBtn);
    await tester.tap(submitPinBtn);
    await tester.pumpAndSettle();

    // Step 4: Status Akun Anda (Approval Menunggu)
    expect(find.text('Status Akun Anda'), findsOneWidget);
    expect(find.text('Progres Pendaftaran'), findsOneWidget);
    expect(find.text('Sedang Ditinjau Admin'), findsOneWidget);
    expect(find.text('Cek Status Akun'), findsOneWidget);

    await tester.tap(find.text('Cek Status Akun'));
    await tester.pumpAndSettle();

    // Step 5: Status Verifikasi (Approval Ditolak)
    expect(find.text('Status Verifikasi'), findsOneWidget);
    expect(find.text('Alasan Penolakan'), findsOneWidget);
    expect(find.textContaining('Hari'), findsOneWidget);
    expect(find.text('Ajukan Ulang Verifikasi (Terkunci)'), findsOneWidget);
    expect(find.text('Hubungi Admin Kami'), findsOneWidget);
  });
}
