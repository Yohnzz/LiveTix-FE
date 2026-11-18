// lib/screens/scanner/ticket_scanner_screen.dart
// FASE 4 - Layar Scanner QR Tiket untuk Petugas Gate
// Menggunakan mobile_scanner untuk membaca QR, lalu memanggil
// TicketValidatorService → Edge Function validate-ticket.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/data_service.dart';
import '../../services/ticket_validator_service.dart';

class TicketScannerScreen extends StatefulWidget {
  const TicketScannerScreen({super.key});

  @override
  State<TicketScannerScreen> createState() => _TicketScannerScreenState();
}

class _TicketScannerScreenState extends State<TicketScannerScreen>
    with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    returnImage: false,
    formats: const [BarcodeFormat.qrCode],
  );

  bool _isProcessing = false;
  bool _torchOn = false;

  // State hasil scan terakhir
  _ScanResult? _lastResult;
  Timer? _resetTimer;

  final _currentUser = DataService().currentUser;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _controller.stop();
    } else if (state == AppLifecycleState.resumed) {
      _controller.start();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _resetTimer?.cancel();
    _controller.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final barcode = capture.barcodes.firstOrNull;
    final raw = barcode?.rawValue;
    if (raw == null || raw.isEmpty) return;

    // Format payload QR tiket: ticket_id.kode_tiket.signature (3 segmen titik)
    // Jika bukan format ini, tampilkan pesan format tidak dikenal
    final parts = raw.split('.');
    if (parts.length != 3) {
      _showResult(_ScanResult.invalid(
        qrRaw: raw,
        reason: 'Format QR tidak dikenal.\nPastikan QR ini adalah e-tiket LiveTix.',
      ));
      return;
    }

    setState(() => _isProcessing = true);
    await _controller.stop();

    try {
      final result = await TicketValidatorService().validateQrPayload(
        qrPayload: raw,
        gateUserId: _currentUser?.id,
      );

      if (!mounted) return;

      if (result.valid) {
        HapticFeedback.heavyImpact();
        _showResult(_ScanResult.valid(
          qrRaw: raw,
          tierName: result.tierName ?? 'Tiket',
          scansUsed: result.scansUsed,
          scanQuota: result.scanQuota,
          scansLeft: result.scansLeft,
        ));
      } else {
        HapticFeedback.vibrate();
        _showResult(_ScanResult.invalid(
          qrRaw: raw,
          reason: result.reasonLabel,
        ));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showResult(_ScanResult result) {
    _resetTimer?.cancel();
    setState(() => _lastResult = result);
    // Auto-reset setelah 4 detik agar scanner siap lagi
    _resetTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() => _lastResult = null);
      _controller.start();
    });
  }

  void _resetScan() {
    _resetTimer?.cancel();
    setState(() => _lastResult = null);
    _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Scan E-Tiket',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            tooltip: _torchOn ? 'Matikan senter' : 'Nyalakan senter',
            icon: Icon(
              _torchOn ? Icons.flash_off_rounded : Icons.flash_on_rounded,
              color: Colors.white,
            ),
            onPressed: () {
              _controller.toggleTorch();
              setState(() => _torchOn = !_torchOn);
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          // ── Kamera Scanner ──────────────────────────────────────────────
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // ── Overlay Viewfinder ──────────────────────────────────────────
          _buildViewfinderOverlay(),

          // ── Loading Indicator ───────────────────────────────────────────
          if (_isProcessing)
            const Center(
              child: Card(
                color: Colors.black87,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 14),
                      Text(
                        'Memverifikasi tiket...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Panel Hasil Scan ────────────────────────────────────────────
          if (_lastResult != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildResultPanel(_lastResult!),
            ),
        ],
      ),
    );
  }

  Widget _buildViewfinderOverlay() {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      const boxSize = 260.0;
      final left = (w - boxSize) / 2;
      final top = (h - boxSize) / 2 - 40;

      return Stack(
        children: [
          // Semi-transparent overlay
          ColorFiltered(
            colorFilter: const ColorFilter.mode(
              Color(0x99000000),
              BlendMode.srcOut,
            ),
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.transparent,
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                ),
                Positioned(
                  left: left,
                  top: top,
                  child: Container(
                    width: boxSize,
                    height: boxSize,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Corner brackets
          Positioned(
            left: left,
            top: top,
            child: _buildCornerBrackets(boxSize),
          ),

          // Teks panduan
          Positioned(
            left: 0,
            right: 0,
            top: top + boxSize + 24,
            child: const Text(
              'Arahkan kamera ke QR Code e-tiket LiveTix',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildCornerBrackets(double boxSize) {
    const bracketLen = 28.0;
    const bracketWidth = 3.5;
    const radius = 12.0;
    final color = _lastResult == null
        ? Colors.white
        : _lastResult!.isValid
            ? const Color(0xFF22C55E)
            : const Color(0xFFEF4444);

    return SizedBox(
      width: boxSize,
      height: boxSize,
      child: CustomPaint(
        painter: _BracketPainter(
          color: color,
          bracketLen: bracketLen,
          bracketWidth: bracketWidth,
          radius: radius,
        ),
      ),
    );
  }

  Widget _buildResultPanel(_ScanResult result) {
    final isValid = result.isValid;
    final bg = isValid ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    final icon = isValid ? Icons.check_circle_rounded : Icons.cancel_rounded;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        24 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white38,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          Icon(icon, color: Colors.white, size: 52),
          const SizedBox(height: 12),

          Text(
            isValid ? 'Tiket Valid ✓' : 'Tiket Tidak Valid ✗',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),

          if (isValid) ...[
            Text(
              result.tierName ?? 'Tiket',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Scan ${result.scansUsed} dari ${result.scanQuota} '
                '· Sisa ${result.scansLeft} scan',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                result.reason ?? 'Tiket tidak dapat divalidasi',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton(
              onPressed: _resetScan,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Scan Berikutnya',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Data class hasil scan ─────────────────────────────────────────────────────

class _ScanResult {
  final bool isValid;
  final String qrRaw;
  final String? tierName;
  final String? reason;
  final int scansUsed;
  final int scanQuota;
  final int scansLeft;

  const _ScanResult({
    required this.isValid,
    required this.qrRaw,
    this.tierName,
    this.reason,
    this.scansUsed = 0,
    this.scanQuota = 1,
    this.scansLeft = 0,
  });

  factory _ScanResult.valid({
    required String qrRaw,
    required String tierName,
    required int scansUsed,
    required int scanQuota,
    required int scansLeft,
  }) =>
      _ScanResult(
        isValid: true,
        qrRaw: qrRaw,
        tierName: tierName,
        scansUsed: scansUsed,
        scanQuota: scanQuota,
        scansLeft: scansLeft,
      );

  factory _ScanResult.invalid({
    required String qrRaw,
    required String reason,
  }) =>
      _ScanResult(
        isValid: false,
        qrRaw: qrRaw,
        reason: reason,
      );
}

// ── Custom Painter: sudut bracket viewfinder ──────────────────────────────────

class _BracketPainter extends CustomPainter {
  final Color color;
  final double bracketLen;
  final double bracketWidth;
  final double radius;

  const _BracketPainter({
    required this.color,
    required this.bracketLen,
    required this.bracketWidth,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = bracketWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;
    final r = radius;
    final l = bracketLen;

    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(0, l + r)
        ..lineTo(0, r)
        ..arcToPoint(Offset(r, 0), radius: Radius.circular(r))
        ..lineTo(l + r, 0),
      paint,
    );
    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(w - l - r, 0)
        ..lineTo(w - r, 0)
        ..arcToPoint(Offset(w, r), radius: Radius.circular(r))
        ..lineTo(w, l + r),
      paint,
    );
    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(0, h - l - r)
        ..lineTo(0, h - r)
        ..arcToPoint(Offset(r, h), radius: Radius.circular(r))
        ..lineTo(l + r, h),
      paint,
    );
    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(w - l - r, h)
        ..lineTo(w - r, h)
        ..arcToPoint(Offset(w, h - r), radius: Radius.circular(r))
        ..lineTo(w, h - l - r),
      paint,
    );
  }

  @override
  bool shouldRepaint(_BracketPainter oldDelegate) =>
      oldDelegate.color != color;
}
