import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livetix/screens/promoter/promoter_main_screen.dart';
import 'package:livetix/screens/promoter/promoter_concert_list_screen.dart';
import 'package:livetix/screens/promoter/promoter_pin_lock_screen.dart';
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

    // Tambahkan minimal 1 kategori tiket agar lolos validasi Step 3
    await tester.tap(find.text('Tambah Kategori Tiket'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'VIP');
    await tester.enterText(find.byType(TextField).at(1), '500000');
    await tester.enterText(find.byType(TextField).at(2), '100');
    await tester.tap(find.text('Simpan Kategori'));
    await tester.pumpAndSettle();

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

  testWidgets(
      'ProducerVerificationFlow requires data diri, rekening, KTP, Lembar Penanggung Jawab, then PIN and goes to PIN lock',
      (WidgetTester tester) async {
    PromoterDataService().resetProducerVerificationStateForNewAccount('Rafi');
    String? nextPickedFileName;
    await tester.pumpWidget(
      MaterialApp(
        home: ProducerVerificationFlow(
          filePicker: (accept) async {
            final fileName = nextPickedFileName;
            nextPickedFileName = null;
            return fileName;
          },
        ),
      ),
    );

    // Step 1: Isi data diri Produser + rekening
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

    // Belum diisi: tetap di langkah 1 dengan pesan validasi
    expect(find.text('Isi data diri Produser'), findsOneWidget);
    expect(find.text('Nama lengkap penanggung jawab wajib diisi.'),
        findsOneWidget);

    await tester.enterText(
        find.byType(TextField).at(0), 'Rafi Firmansyah');
    await tester.tap(nextStep1Btn);
    await tester.pumpAndSettle();
    expect(find.text('Tanggal lahir wajib dipilih.'), findsOneWidget);

    await tester.tap(find.byType(TextField).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(nextStep1Btn);
    await tester.pumpAndSettle();
    expect(find.text('Nama bank wajib diisi.'), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('verification_bank_name_field')), 'BCA');
    await tester.enterText(
        find.byKey(const Key('verification_bank_account_number_field')),
        '123');
    await tester.tap(nextStep1Btn);
    await tester.pumpAndSettle();
    expect(find.text('Nomor rekening harus 8 sampai 20 digit angka.'),
        findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('verification_bank_account_number_field')),
        '8820192831');
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

    // Cancellation returns null and leaves the picker sheet open without upload.
    await tester.tap(find.text('Pilih Dokumen KTP'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(
        OutlinedButton,
        'Pilih File dari Perangkat / Explorer',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pilih File dari Perangkat / Explorer'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close).last);
    await tester.pumpAndSettle();
    expect(find.text('Pilih Dokumen KTP'), findsOneWidget);

    // Unsupported extensions cannot complete an upload.
    await tester.tap(find.text('Pilih Dokumen KTP'));
    await tester.pumpAndSettle();
    nextPickedFileName = 'ktp_rafi.txt';
    await tester.tap(
      find.widgetWithText(
        OutlinedButton,
        'Pilih File dari Perangkat / Explorer',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pilih File dari Perangkat / Explorer'), findsNothing);
    expect(find.text('Pilih Dokumen KTP'), findsOneWidget);
    expect(
      find.text('Format dokumen KTP harus .jpg, .jpeg, .png, atau .pdf.'),
      findsOneWidget,
    );

    // A valid KTP filename completes the first required upload.
    await tester.tap(find.text('Pilih Dokumen KTP'));
    await tester.pumpAndSettle();
    nextPickedFileName = 'ktp_rafi_firmansyah.JPG';
    await tester.tap(
      find.widgetWithText(
        OutlinedButton,
        'Pilih File dari Perangkat / Explorer',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ganti Dokumen KTP'), findsOneWidget);
    expect(find.textContaining('ktp_rafi_firmansyah.JPG'), findsOneWidget);

    // KTP alone is insufficient to advance to PIN; the required letter picker opens.
    final scaffoldMessenger = tester.state<ScaffoldMessengerState>(
      find.byType(ScaffoldMessenger).first,
    );
    final nextPinBtn = find.text('Lanjut Buat PIN');
    scaffoldMessenger.clearSnackBars();
    await tester.pumpAndSettle();
    await tester.ensureVisible(nextPinBtn);
    await tester.tap(nextPinBtn);
    await tester.pumpAndSettle();
    expect(find.text('Buat PIN Keamanan'), findsNothing);
    expect(find.text('Pilih File Word / PDF dari Perangkat'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close).last);
    await tester.pumpAndSettle();

    // Cancellation of the responsibility-letter picker also leaves state unchanged.
    final letterBtn = find.text('Unggah Lembar Penanggung Jawab').first;
    await tester.ensureVisible(letterBtn);
    await tester.tap(letterBtn);
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(
        OutlinedButton,
        'Pilih File Word / PDF dari Perangkat',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pilih File Word / PDF dari Perangkat'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close).last);
    await tester.pumpAndSettle();

    // Reject a non-document extension, then accept the valid letter selection.
    await tester.tap(find.text('Unggah Lembar Penanggung Jawab').first);
    await tester.pumpAndSettle();
    nextPickedFileName = 'surat.txt';
    await tester.tap(
      find.widgetWithText(
        OutlinedButton,
        'Pilih File Word / PDF dari Perangkat',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pilih File Word / PDF dari Perangkat'), findsNothing);
    expect(
      find.text('Format lembar penanggung jawab harus .doc, .docx, atau .pdf.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Unggah Lembar Penanggung Jawab').first);
    await tester.pumpAndSettle();
    nextPickedFileName = 'Lembar_Penanggung_Jawab.docx';
    await tester.tap(
      find.widgetWithText(
        OutlinedButton,
        'Pilih File Word / PDF dari Perangkat',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Lembar_Penanggung_Jawab.docx'), findsOneWidget);

    scaffoldMessenger.clearSnackBars();
    await tester.pumpAndSettle();
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

    final submitPinBtn = find.text('Simpan PIN & Selesaikan Verifikasi');
    await tester.ensureVisible(submitPinBtn);
    await tester.tap(submitPinBtn);
    await tester.pumpAndSettle();

    // Setelah verifikasi: lanjut ke halaman PIN, lalu Beranda Produser
    final service = PromoterDataService();
    expect(service.verificationStatusNotifier.value, 'approved');
    expect(service.bankNameNotifier.value, 'BCA');
    expect(service.bankAccountNumberNotifier.value, '8820192831');
    expect(find.byType(PromoterPinLockScreen), findsOneWidget);
  });

  test('Produser terverifikasi langsung diarahkan ke halaman PIN, belum verifikasi ke alur verifikasi',
      () {
    final service = PromoterDataService();
    service.verificationStatusNotifier.value = 'unverified';
    expect(resolveProducerEntryScreen(), isA<ProducerVerificationFlow>());

    service.verificationStatusNotifier.value = 'approved';
    service.isPinUnlockedThisSession = false;
    expect(resolveProducerEntryScreen(), isA<PromoterPinLockScreen>());
  });
}
