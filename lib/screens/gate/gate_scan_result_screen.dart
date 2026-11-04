import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/gate_model.dart';

/// Halaman Tampilan Hasil Pemindaian Tiket di Gate
/// Menampilkan status Sukses (Hijau), Sudah Pernah Dipakai (Merah), atau Salah Gate (Amber).
class GateScanResultScreen extends StatefulWidget {
  final GateScanRecord record;
  final GateModel gate;
  final VoidCallback onScanNext;

  const GateScanResultScreen({
    super.key,
    required this.record,
    required this.gate,
    required this.onScanNext,
  });

  @override
  State<GateScanResultScreen> createState() => _GateScanResultScreenState();
}

class _GateScanResultScreenState extends State<GateScanResultScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  Timer? _autoAdvanceTimer;

  @override
  void initState() {
    super.initState();

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // Jika tiket Valid, mulai animasi progress bar 2 detik dan lanjut scan otomatis
    if (widget.record.status == GateScanStatus.valid) {
      _progressController.forward();
      _autoAdvanceTimer = Timer(const Duration(milliseconds: 2000), () {
        if (mounted) {
          _handleScanNext();
        }
      });
    }
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    _progressController.dispose();
    super.dispose();
  }

  void _handleScanNext() {
    _autoAdvanceTimer?.cancel();
    Navigator.pop(context);
    widget.onScanNext();
  }

  void _handleClose() {
    _autoAdvanceTimer?.cancel();
    Navigator.pop(context);
  }

  void _showCoordinatorContact() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hubungi Koordinator Lapangan'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Koordinator Gate Area:\nBpk. Hendra Wijaya (+62 811-2233-4455)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            SizedBox(height: 10),
            Text(
              'Gunakan radio komunikasi saluran Channel 3 untuk penanganan kendala duplikasi tiket.',
              style: TextStyle(fontSize: 13, color: Color(0xFF475467)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.record.status) {
      case GateScanStatus.valid:
        return _buildSuccessScreen();
      case GateScanStatus.alreadyUsed:
        return _buildAlreadyUsedScreen();
      case GateScanStatus.wrongGate:
        return _buildWrongGateScreen();
      case GateScanStatus.refunded:
        return _buildCancelledOrRefundedScreen();
      case GateScanStatus.invalid:
        return _buildInvalidScreen();
    }
  }

  // ==========================================
  // HASIL SUKSES: TIKET VALID (HIJAU)
  // ==========================================
  Widget _buildSuccessScreen() {
    const bgColor = Color(0xFF00B368);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              const Spacer(flex: 1),

              // Ikon Lingkaran Ceklis Putih
              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.check_rounded,
                  color: bgColor,
                  size: 64,
                ),
              ),
              const SizedBox(height: 18),

              // Judul: TIKET
              const Text(
                'TIKET',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 24),

              // Kartu Putih Detail Tiket Penonton
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x26000000),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Nama penonton', widget.record.attendeeName),
                    const Divider(height: 22, color: Color(0xFFF1F5F9)),
                    _buildDetailRow('Kategori & jumlah', widget.record.category),
                    const Divider(height: 22, color: Color(0xFFF1F5F9)),
                    _buildDetailRow('Blok / nomor pintu', widget.record.doorNumber),
                    const Divider(height: 22, color: Color(0xFFF1F5F9)),
                    _buildDetailRow('Waktu scan', widget.record.formattedTime),
                  ],
                ),
              ),

              const Spacer(flex: 2),

              // Info Lanjut Scan Otomatis
              const Text(
                'Lanjut scan otomatis dalam 2 detik',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),

              // Bar Progress 2 Detik
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  height: 4,
                  width: double.infinity,
                  color: Colors.white.withValues(alpha: 0.3),
                  child: AnimatedBuilder(
                    animation: _progressController,
                    builder: (context, child) {
                      return FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: _progressController.value,
                        child: Container(color: Colors.white),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Tombol Putih: Scan Berikutnya
              SizedBox(
                height: 52,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _handleScanNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1B2A8C),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Scan Berikutnya',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // HASIL PERINGATAN: SUDAH PERNAH DIPAKAI (MERAH)
  // ==========================================
  Widget _buildAlreadyUsedScreen() {
    const bgColor = Color(0xFFE53935);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              const Spacer(flex: 1),

              // Ikon Lingkaran X Putih
              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.close_rounded,
                  color: bgColor,
                  size: 64,
                ),
              ),
              const SizedBox(height: 16),

              // Label PERINGATAN
              const Text(
                'PERINGATAN',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: Color(0xFFFFCDD2),
                ),
              ),
              const SizedBox(height: 4),

              // Judul: TIKET SUDAH PERNAH DIPAKAI!
              const Text(
                'TIKET SUDAH\nPERNAH DIPAKAI!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),

              // Subtitle: Tolak masuk
              const Text(
                'Tolak masuk',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 20),

              // Kartu Putih Detail Tiket Penonton
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x26000000),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Nama penonton', widget.record.attendeeName),
                    const Divider(height: 22, color: Color(0xFFF1F5F9)),
                    _buildDetailRow('Kategori & jumlah', widget.record.category),
                    const Divider(height: 22, color: Color(0xFFF1F5F9)),
                    _buildDetailRow(
                      'Discan sebelumnya',
                      widget.record.previousScanInfo ?? '17:15 WIB · Gate A',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Kotak Peringatan Petugas & Waktu Scan Awal
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFFCDD2)),
                ),
                child: Text(
                  widget.record.message ??
                      'Tiket ini telah discan pukul 17:15 WIB di Gate A oleh Petugas Budi.',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFB71C1C),
                    height: 1.35,
                  ),
                ),
              ),

              const Spacer(flex: 2),

              // Tombol Putih: Tutup & Scan Lagi
              SizedBox(
                height: 50,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _handleClose,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1B2A8C),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Tutup & Scan Lagi',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Tombol Outlined Putih: Hubungi Koordinator
              SizedBox(
                height: 50,
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _showCoordinatorContact,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Hubungi Koordinator',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // HASIL PERINGATAN: SALAH GATE (ORANYE - SCREENSHOT 1)
  // ==========================================
  Widget _buildWrongGateScreen() {
    const bgColor = Color(0xFFF59E0B);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              const Spacer(flex: 1),

              // Ikon Lingkaran Putih Tanda Seru
              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x26000000),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.priority_high_rounded,
                  color: bgColor,
                  size: 60,
                ),
              ),
              const SizedBox(height: 18),

              const Text(
                'TIDAK BERLAKU DI GATE INI',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),

              const Text(
                'SALAH GATE!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),

              const Text(
                'Arahkan penonton ke gate yang benar',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),

              // Kartu Putih Detail Tiket Penonton
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x26000000),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Nama penonton', widget.record.attendeeName),
                    const Divider(height: 22, color: Color(0xFFF1F5F9)),
                    _buildDetailRow('Kategori tiket', widget.record.category),
                    const Divider(height: 22, color: Color(0xFFF1F5F9)),
                    _buildDetailRow(
                      'Gate tujuan',
                      widget.record.targetGate ?? 'Gate VIP · sisi barat',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Alert Banner Kuning
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Text(
                  widget.record.message ??
                      'Tiket VIP, mohon arahkan penonton ke Gate VIP sebelah barat.',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF78350F),
                    height: 1.35,
                  ),
                ),
              ),

              const Spacer(flex: 2),

              // Tombol Putih: Tutup & Scan Lagi
              SizedBox(
                height: 50,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _handleClose,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1B2A8C),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Tutup & Scan Lagi',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // HASIL PERINGATAN: TIKET DIBATALKAN / REFUND (SCREENSHOT 2)
  // ==========================================
  Widget _buildCancelledOrRefundedScreen() {
    const bgColor = Color(0xFFF59E0B);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              const Spacer(flex: 1),

              // Ikon Lingkaran Putih Tanda Seru
              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x26000000),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.priority_high_rounded,
                  color: bgColor,
                  size: 60,
                ),
              ),
              const SizedBox(height: 18),

              const Text(
                'TIKET TIDAK AKTIF',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),

              const Text(
                'TIKET DIBATALKAN',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),

              const Text(
                'Telah diajukan refund dana',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),

              // Kartu Putih Detail Tiket Penonton
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x26000000),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Nama penonton', widget.record.attendeeName),
                    const Divider(height: 22, color: Color(0xFFF1F5F9)),
                    _buildDetailRow(
                      'Event',
                      widget.record.eventTitle ?? 'Soundwave Fest 2026',
                    ),
                    const Divider(height: 22, color: Color(0xFFF1F5F9)),
                    _buildDetailRow('Status tiket', 'Refund diproses'),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Alert Banner Kuning
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Text(
                  'Jangan izinkan masuk. Arahkan penonton ke aplikasi: Tiket saya › Refund.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF78350F),
                    height: 1.35,
                  ),
                ),
              ),

              const Spacer(flex: 2),

              // Tombol Putih: Tutup & Scan Lagi
              SizedBox(
                height: 50,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _handleClose,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1B2A8C),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Tutup & Scan Lagi',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // HASIL PERINGATAN: TIDAK VALID (ABU-ABU)
  // ==========================================
  Widget _buildInvalidScreen() {
    const bgColor = Color(0xFF334155);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              const Spacer(flex: 1),

              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: bgColor,
                  size: 56,
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'TIKET TIDAK VALID',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Kode QR tidak dikenali sistem LiveTix',
                style: TextStyle(fontSize: 14, color: Colors.white70),
              ),
              const SizedBox(height: 20),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Kode terbaca: ${widget.record.ticketCode}\nPastikan penonton menunjukkan QR tiket resmi dari aplikasi LiveTix.',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF475467)),
                ),
              ),

              const Spacer(flex: 2),

              SizedBox(
                height: 50,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _handleClose,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1B2A8C),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Tutup & Scan Lagi',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String caption, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          caption,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}
