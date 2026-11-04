import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livetix/models/promoter_models.dart';
import 'package:livetix/screens/promoter/add_concert/step2_venue_location_screen.dart';
import 'package:livetix/screens/promoter/cancellation/promoter_cancel_concert_screen.dart';
import 'package:livetix/screens/promoter/cancellation/promoter_cancellation_status_screen.dart';
import 'package:livetix/screens/promoter/cancellation/promoter_cancellation_approved_screen.dart';
import 'package:livetix/screens/promoter/promoter_manage_concert_screen.dart';
import 'package:livetix/services/venue_location_search_service.dart';

void main() {
  const sampleConcert = PromoterConcertItem(
    id: 'test-1',
    title: 'Soundwave Fest 2026',
    dateAndVenue: '12 Okt · Stadion Gajayana',
    date: '12 Okt 2026',
    time: '19:00 WIB',
    venueName: 'Stadion Gajayana',
    venueAddress:
        'Jl. Tangkuban Perahu, Kauman, Kec. Klojen, Kota Malang, Jawa Timur 65119',
    status: ConcertStatus.disetujui,
    ticketsSold: 4200,
    affectedBuyersCount: 1860,
    totalRefundAmount: 2115000000,
    refundDoneCount: 2940,
    refundProcessingCount: 1050,
    refundPendingAccountCount: 210,
    cancellationSubmissionDate: '19 Okt 2026, 14:02',
    cancellationApprovalDate: '20 Okt 2026, 09:15',
    tiers: [
      PromoterTicketTier(
        id: 't1',
        name: 'VIP',
        price: 750000,
        quota: 1000,
      ),
      PromoterTicketTier(
        id: 't2',
        name: 'Festival',
        price: 350000,
        quota: 4000,
      ),
    ],
  );

  group('VenueLocationSearchService tests', () {
    test('Searches preset venues and custom locations seamlessly', () async {
      final service = VenueLocationSearchService();

      // Search existing venue
      final gbkResults = await service.search('GBK');
      expect(gbkResults.isNotEmpty, true);
      expect(gbkResults.any((v) => v.name.contains('GBK') || v.name.contains('Gelora Bung Karno')), true);

      // Search anywhere (custom query)
      final customResults = await service.search('Alun-alun Kota Bandung');
      expect(customResults.isNotEmpty, true);
      expect(customResults.any((v) => v.name.contains('Alun-alun Kota Bandung')), true);
    });
  });

  group('Google Maps Step 2 Venue Location Screen tests', () {
    testWidgets('Renders Google Maps search and location selection', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Step2VenueLocationScreen(
              venueName: 'Stadion Gajayana',
              venueAddress: 'Jl. Tangkuban Perahu, Malang',
              venueSearchQuery: 'Stadion Gajayana Malang',
              onNext: () {},
              onBack: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pilih Tempat Konser'), findsOneWidget);
      expect(find.text('Terhubung dengan Google Maps'), findsOneWidget);
      expect(find.text('Gunakan Lokasi GPS Saya'), findsOneWidget);
      expect(find.text('Google'), findsOneWidget);
      expect(find.text('Konfirmasi Lokasi & Lanjut'), findsOneWidget);
    });
  });

  group('Batalkan Konser Screen & BottomSheet Modal (Images 1 & 2)', () {
    testWidgets('Renders cancel form, categories, info box and opens confirmation modal', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PromoterCancelConcertScreen(concert: sampleConcert),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Batalkan Konser'), findsOneWidget);
      expect(find.text('Isi alasan pembatalan untuk diajukan ke admin'), findsOneWidget);
      expect(find.text('Soundwave Fest 2026'), findsOneWidget);
      expect(find.text('Kategori alasan'), findsOneWidget);
      expect(find.text('Perizinan'), findsOneWidget);
      expect(find.text('Venue'), findsOneWidget);
      expect(find.text('Keamanan'), findsOneWidget);
      expect(find.text('Lainnya'), findsOneWidget);
      expect(find.text('Uang tiket akan dikembalikan'), findsOneWidget);
      expect(find.textContaining('Rp2.115.000.000'), findsWidgets);
      expect(find.text('Ajukan Pembatalan'), findsOneWidget);

      // Scroll into view & Tap Ajukan Pembatalan to open bottom sheet modal (Image 2)
      await tester.ensureVisible(find.text('Ajukan Pembatalan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ajukan Pembatalan'));
      await tester.pumpAndSettle();

      expect(find.text('Ajukan pembatalan konser?'), findsOneWidget);
      expect(find.text('4.200 tiket'), findsOneWidget);
      expect(find.text('Maks. 1x24 jam'), findsOneWidget);
      expect(find.textContaining('Pembatalan tidak dapat diurungkan setelah disetujui'), findsOneWidget);
      expect(find.text('Ya, Ajukan Pembatalan'), findsOneWidget);
      expect(find.text('Kembali'), findsWidgets);
    });
  });

  group('Status Pembatalan Screen (Images 3 & 4)', () {
    testWidgets('Renders status stepper, tickets sold progress, and zero tickets variant', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PromoterCancellationStatusScreen(concert: sampleConcert),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Status Pembatalan'), findsOneWidget);
      expect(find.text('Menunggu Persetujuan Admin'), findsOneWidget);
      expect(find.text('Pengajuan dikirim'), findsOneWidget);
      expect(find.text('Ditinjau admin'), findsOneWidget);
      expect(find.text('Refund otomatis ke pembeli'), findsOneWidget);
      expect(find.text('Konser resmi dibatalkan'), findsOneWidget);
      expect(find.text('4.200 / 5.000'), findsOneWidget);
      expect(find.text('1.860 orang'), findsOneWidget);
      expect(find.text('Hubungi Admin Konser'), findsOneWidget);
      expect(find.text('Kembali ke Dasbor'), findsOneWidget);

      // Test 0 tickets sold variant (Image 4)
      await tester.pumpWidget(
        MaterialApp(
          home: PromoterCancellationStatusScreen(
            concert: sampleConcert.copyWith(ticketsSold: 0),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Belum ada'), findsOneWidget);
      expect(find.text('0 / 5.000'), findsOneWidget);
      expect(find.text('Tidak ada pembeli, jadi tidak ada refund yang perlu diproses.'), findsOneWidget);
    });
  });

  group('Pembatalan Disetujui Screen (Image 5)', () {
    testWidgets('Renders approved banner and refund progress breakdown', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PromoterCancellationApprovedScreen(concert: sampleConcert),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pembatalan Disetujui'), findsOneWidget);
      expect(find.text('Konser resmi dibatalkan'), findsOneWidget);
      expect(find.text('Disetujui'), findsOneWidget);
      expect(find.text('Progres refund pembeli'), findsOneWidget);
      expect(find.text('2.940 / 4.200 tiket selesai'), findsOneWidget);
      expect(find.text('Refund selesai'), findsOneWidget);
      expect(find.text('2.940'), findsOneWidget);
      expect(find.text('Sedang diproses'), findsOneWidget);
      expect(find.text('1.050'), findsOneWidget);
      expect(find.text('Menunggu data rekening pembeli'), findsOneWidget);
      expect(find.text('210'), findsOneWidget);
      expect(find.text('Unduh Laporan Refund'), findsOneWidget);
      expect(find.text('Kembali ke Dasbor'), findsOneWidget);
    });
  });

  group('PromoterManageConcertScreen button position', () {
    testWidgets('Shows Batalkan Konser button underneath Ajukan Perubahan Informasi Konser', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PromoterManageConcertScreen(concert: sampleConcert),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ajukan Perubahan Informasi Konser'), findsOneWidget);
      expect(find.text('Batalkan Konser'), findsOneWidget);
    });
  });
}
