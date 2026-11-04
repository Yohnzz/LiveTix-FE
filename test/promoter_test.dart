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
    expect(find.text('12'), findsOneWidget);
    expect(find.text('TIKET TERJUAL'), findsOneWidget);
    expect(find.text('8.450'), findsOneWidget);
    expect(find.text('TOTAL PENDAPATAN'), findsOneWidget);
    expect(find.text('Rp 2.115.000.000'), findsOneWidget);
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
    expect(find.text('Semua'), findsOneWidget);
    expect(find.text('Draft'), findsOneWidget);
    expect(find.text('Menunggu'), findsOneWidget);
    expect(find.text('Disetujui'), findsOneWidget);
    expect(find.text('Ditolak'), findsOneWidget);
  });

  testWidgets('AddConcertFlow steps 3 to 4, Detail Status Konser, and Customer Service',
      (WidgetTester tester) async {
    PromoterDataService().quotaRemainingNotifier.value = 5;

    await tester.pumpWidget(
      const MaterialApp(
        home: AddConcertFlow(initialStep: 3),
      ),
    );

    // Step 3: Paket Harga Tiket
    expect(find.text('Paket Harga Tiket'), findsOneWidget);
    expect(find.text('VIP Nusantara'), findsOneWidget);
    expect(find.text('Festival'), findsOneWidget);
    expect(find.text('1.700 Tiket'), findsOneWidget);
    expect(find.text('Simpan & Tinjau Ringkasan'), findsOneWidget);

    await tester.tap(find.text('Simpan & Tinjau Ringkasan'));
    await tester.pumpAndSettle();

    // Step 4: Ringkasan Pengajuan
    expect(find.text('Ringkasan Pengajuan'), findsOneWidget);
    expect(find.text('Langkah terakhir: Cek ulang sebelum mengajukan approval'),
        findsOneWidget);
    expect(find.text('Detail Konser'), findsOneWidget);
    expect(find.text('Paket Tiket Terpilih'), findsOneWidget);
    expect(find.text('Kirim untuk Approval Admin'), findsOneWidget);

    PromoterDataService().quotaRemainingNotifier.value = 5;
    await tester.tap(find.text('Kirim untuk Approval Admin'));
    await tester.pumpAndSettle();

    // ConcertStatusDetailScreen (Menunggu Approval)
    expect(find.text('Harmoni Nusantara 2026'), findsOneWidget);
    expect(find.text('Pengajuan baru sedang ditinjau kurasi LiveTix'), findsOneWidget);
  });

  testWidgets('ProducerVerificationFlow requires manual KTP upload and navigates through all 4 screens',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ProducerVerificationFlow(),
      ),
    );

    // Step 1: Isi data diri Produser
    expect(find.text('Isi data diri Produser'), findsOneWidget);
    expect(
      find.text('Langkah 1 dari 2: Informasi dasar penanggung jawab'),
      findsOneWidget,
    );
    expect(find.text('Lanjut ke Unggah Dokumen'), findsOneWidget);

    await tester.tap(find.text('Lanjut ke Unggah Dokumen'));
    await tester.pumpAndSettle();

    // Step 2: Unggah Dokumen KTP (Starts not uploaded!)
    expect(find.text('Unggah Dokumen KTP'), findsOneWidget);
    expect(find.text('Dokumen yang dibutuhkan'), findsOneWidget);
    expect(find.text('Pilih Dokumen KTP'), findsOneWidget);

    // User manually opens the upload sheet and uploads KTP
    await tester.tap(find.text('Pilih Dokumen KTP'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Unggah Dokumen KTP'));
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    // Now KTP is uploaded and shows Ganti Dokumen KTP
    expect(find.text('Ganti Dokumen KTP'), findsOneWidget);
    expect(find.text('Ajukan Approval Verifikasi'), findsOneWidget);

    // Dismiss any pending SnackBars before tapping
    final scaffoldMessenger = tester.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).first);
    scaffoldMessenger.clearSnackBars();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ajukan Approval Verifikasi'));
    await tester.pumpAndSettle();

    // Step 3: Status Akun Anda (Approval Menunggu)
    expect(find.text('Status Akun Anda'), findsOneWidget);
    expect(find.text('Progres Pendaftaran'), findsOneWidget);
    expect(find.text('Sedang Ditinjau Admin'), findsOneWidget);
    expect(find.text('Cek Status Akun'), findsOneWidget);

    await tester.tap(find.text('Cek Status Akun'));
    await tester.pumpAndSettle();

    // Step 4: Status Verifikasi (Approval Ditolak)
    expect(find.text('Status Verifikasi'), findsOneWidget);
    expect(find.text('Alasan Penolakan'), findsOneWidget);
    expect(find.text('3 Hari 0 Jam 0 Menit'), findsOneWidget);
    expect(find.text('Ajukan Ulang Verifikasi'), findsOneWidget);
    expect(find.text('Hubungi Admin Kami'), findsOneWidget);
  });
}
