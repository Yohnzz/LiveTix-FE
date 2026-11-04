import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_colors.dart';
import '../models/ticket_order_model.dart';
import '../utils/gate_qr_image_generator.dart';
import '../utils/qr_share.dart';
import 'qr_code_view.dart';

/// Menampilkan pratinjau kartu QR Gate ber-watermark `LiveTix`
/// dan memanggil fitur Bagikan bawaan perangkat (HP / browser) untuk dikirim ke teman.
class ShareGateQrSheet extends StatefulWidget {
  final UserTicketModel ticket;

  const ShareGateQrSheet({
    super.key,
    required this.ticket,
  });

  static Future<void> show(BuildContext context, UserTicketModel ticket) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ShareGateQrSheet(ticket: ticket),
    );
  }

  @override
  State<ShareGateQrSheet> createState() => _ShareGateQrSheetState();
}

class _ShareGateQrSheetState extends State<ShareGateQrSheet> {
  static final Uint8List _fallbackPngBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  );

  Uint8List? _cachedPngBytes;
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    _prepareWatermarkedPng();
  }

  Future<void> _prepareWatermarkedPng() async {
    if (QrShare.testOverride != null) return;
    try {
      final generated = await GateQrImageGenerator.generatePngBytes(widget.ticket);
      if (mounted && generated.isNotEmpty) {
        setState(() {
          _cachedPngBytes = generated;
        });
      }
    } catch (_) {
      // Tetap aman jika lingkungan pengujian tanpa rasterizer penuh
    }
  }

  String get _safeFileName {
    final cleanCode =
        widget.ticket.bookingCode.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    return 'LiveTix-QR-${cleanCode.isEmpty ? widget.ticket.id : cleanCode}.png';
  }

  String get _shareCaption {
    return 'Tiket Gate ${widget.ticket.concertTitle}\n'
        'Tanggal: ${widget.ticket.date} (${widget.ticket.time})\n'
        'Lokasi: ${widget.ticket.venue} - ${widget.ticket.gate}\n'
        'Kode Booking: ${widget.ticket.bookingCode}\n'
        '1 QR Berlaku untuk ${widget.ticket.qrScanQuota}x Scan di Gate (${widget.ticket.quantity} Tiket) · Watermark Resmi LiveTix';
  }

  Future<Uint8List> _resolvePngBytes() async {
    if (_cachedPngBytes != null && _cachedPngBytes!.isNotEmpty) {
      return _cachedPngBytes!;
    }
    if (QrShare.testOverride != null) {
      final assetData =
          await rootBundle.load(AppQrCodeView.defaultTestingAssetPath);
      return assetData.buffer.asUint8List();
    }
    final generated = await GateQrImageGenerator.generatePngBytes(widget.ticket);
    if (generated.isNotEmpty) {
      _cachedPngBytes = generated;
      return generated;
    }
    return _fallbackPngBytes;
  }

  Future<void> _handleNativeShare() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      final bytes = await _resolvePngBytes();
      final outcome = await QrShare.shareGateQrImage(
        pngBytes: bytes,
        fileName: _safeFileName,
        title: 'QR Gate ${widget.ticket.concertTitle} - LiveTix',
        text: _shareCaption,
      );

      if (!mounted) return;
      if (outcome == QrShareOutcome.sharedNatively) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Gambar QR Gate ber-watermark LiveTix siap dibagikan ke temanmu',
            ),
            backgroundColor: AppColors.primary,
          ),
        );
      } else if (outcome == QrShareOutcome.downloadedFallback) {
        await Clipboard.setData(ClipboardData(text: _shareCaption));
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Gambar QR ber-watermark LiveTix diunduh & detail konser disalin untuk dikirim ke chat',
            ),
            backgroundColor: AppColors.primary,
          ),
        );
      } else if (outcome == QrShareOutcome.unsupported) {
        await Clipboard.setData(ClipboardData(text: _shareCaption));
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Detail & QR Gate ber-watermark LiveTix disalin untuk dibagikan',
            ),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  Future<void> _handleDownloadPng() async {
    final bytes = await _resolvePngBytes();
    final downloaded = QrShare.downloadGateQrImage(
      pngBytes: bytes,
      fileName: _safeFileName,
    );
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          downloaded
              ? 'Gambar QR Gate ber-watermark LiveTix berhasil disimpan'
              : 'Kartu QR Gate ber-watermark LiveTix telah disiapkan',
        ),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ticket = widget.ticket;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD0D5DD),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Bagikan QR Gate Konser',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Tutup pratinjau QR',
                  onPressed: () => Navigator.pop(context),
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  icon: const Icon(Icons.close_rounded, color: AppColors.textDark),
                ),
              ],
            ),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Gambar kartu QR di bawah dilengkapi nama konser, tanggal, dan watermark resmi LiveTix untuk dikirim ke teman rombonganmu.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF475467),
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Pratinjau Kartu QR Gate Ber-Watermark LiveTix
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border, width: 1.2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12101828),
                    blurRadius: 14,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  children: [
                    // Header Nama Konser & Tanggal Konser
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                      decoration: const BoxDecoration(
                        gradient: AppColors.headerGradient,
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'LIVETIX · TIKET GATE RESMI',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFE0E7FF),
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            ticket.concertTitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${ticket.date} · ${ticket.time}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            ticket.venue,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Badan Kartu dengan Pola Watermark LiveTix & Gambar QR Code
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _LiveTixWatermarkPainter(),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                          child: Column(
                            children: [
                              AppQrCodeView(
                                qrCodeUrl: ticket.qrCodeUrl,
                                qrCodeBytes: ticket.qrCodeBytes,
                                size: 164,
                                padding: 14,
                                showWatermark: true,
                                ticketCode: ticket.bookingCode,
                                semanticLabel:
                                    'QR Gate ${ticket.concertTitle} ber-watermark LiveTix',
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '${ticket.gate} · ${ticket.category} · ${ticket.bookingCode}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFA7F3D0),
                                  ),
                                ),
                                child: Text(
                                  '1 QR Berlaku ${ticket.qrScanQuota}x Scan di Gate (${ticket.quantity} Tiket)',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF065F46),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Watermark Resmi LiveTix · Valid untuk masuk gerbang konser',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF475467),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Tombol Aksi Bagikan ke Aplikasi HP & Simpan Gambar
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isSharing ? null : _handleNativeShare,
                icon: const Icon(Icons.share_rounded, size: 18),
                label: Text(
                  _isSharing
                      ? 'Menyiapkan Gambar QR...'
                      : 'Bagikan ke Aplikasi Chat / HP',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                onPressed: _handleDownloadPng,
                icon: const Icon(
                  Icons.download_rounded,
                  size: 18,
                  color: AppColors.textDark,
                ),
                label: const Text(
                  'Simpan Gambar QR Gate',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveTixWatermarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-22 * math.pi / 180);

    const textStyle = TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w800,
      color: Color(0x141B2A8C),
      letterSpacing: 1.0,
    );

    for (double y = -size.height; y <= size.height; y += 64) {
      for (double x = -size.width; x <= size.width; x += 130) {
        final painter = TextPainter(
          text: const TextSpan(text: 'LiveTix', style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        painter.paint(canvas, Offset(x, y));
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
