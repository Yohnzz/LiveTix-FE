import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/ticket_order_model.dart';

/// Menghasilkan gambar PNG kartu QR Gate resmi LiveTix lengkap dengan:
/// - Nama Konser & Tanggal Konser
/// - Gambar QR Code tajam asli dari data tiket backend/database
/// - Informasi Gate, Kode Booking, & Kuota Multi-Scan (maks 4x scan)
/// - Watermark `LiveTix` diagonal dan cap footer resmi
class GateQrImageGenerator {
  GateQrImageGenerator._();

  static Future<ui.Image?> _decodeQrImage(UserTicketModel ticket) async {
    try {
      if (ticket.qrCodeBytes != null && ticket.qrCodeBytes!.isNotEmpty) {
        final codec = await ui.instantiateImageCodec(ticket.qrCodeBytes!);
        final frame = await codec.getNextFrame();
        return frame.image;
      }

      // Render QR code asli secara dinamis langsung dari data tiket backend
      final painter = QrPainter(
        data: ticket.effectiveQrData,
        version: QrVersions.auto,
        gapless: false,
      );
      return await painter.toImage(320);
    } catch (_) {
      return null;
    }
  }

  static void _drawText(
    ui.Canvas canvas, {
    required String text,
    required ui.Offset offset,
    required double maxWidth,
    required double fontSize,
    required ui.Color color,
    ui.FontWeight fontWeight = ui.FontWeight.w600,
    ui.TextAlign textAlign = ui.TextAlign.center,
    int maxLines = 2,
  }) {
    final paragraphStyle = ui.ParagraphStyle(
      textAlign: textAlign,
      maxLines: maxLines,
      ellipsis: '...',
    );
    final builder = ui.ParagraphBuilder(paragraphStyle)
      ..pushStyle(
        ui.TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
        ),
      )
      ..addText(text);
    final paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: maxWidth));
    canvas.drawParagraph(paragraph, offset);
  }

  static Future<Uint8List> generatePngBytes(UserTicketModel ticket) async {
    const double width = 720;
    const double height = 980;

    final qrImage = await _decodeQrImage(ticket);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, const ui.Rect.fromLTWH(0, 0, width, height));

    // 1. Latar kartu putih bersih dengan bingkai luar
    final bgPaint = ui.Paint()..color = const ui.Color(0xFFF8FAFC);
    canvas.drawRect(const ui.Rect.fromLTWH(0, 0, width, height), bgPaint);

    final cardRRect = ui.RRect.fromRectAndRadius(
      const ui.Rect.fromLTWH(28, 28, width - 56, height - 56),
      const ui.Radius.circular(32),
    );
    canvas.drawRRect(cardRRect, ui.Paint()..color = const ui.Color(0xFFFFFFFF));

    // 2. Header panggung navy-ke-magenta berisi Nama Konser & Tanggal Konser
    const headerRect = ui.Rect.fromLTWH(28, 28, width - 56, 250);
    final headerRRect = ui.RRect.fromRectAndCorners(
      headerRect,
      topLeft: const ui.Radius.circular(32),
      topRight: const ui.Radius.circular(32),
    );
    final headerPaint = ui.Paint()
      ..shader = ui.Gradient.linear(
        headerRect.topLeft,
        headerRect.bottomRight,
        const [ui.Color(0xFF1B2A8C), ui.Color(0xFF971C91)],
      );
    canvas.drawRRect(headerRRect, headerPaint);

    _drawText(
      canvas,
      text: 'LIVETIX · TIKET GATE RESMI',
      offset: const ui.Offset(64, 62),
      maxWidth: width - 128,
      fontSize: 18,
      fontWeight: ui.FontWeight.w700,
      color: const ui.Color(0xFFE0E7FF),
    );

    _drawText(
      canvas,
      text: ticket.concertTitle,
      offset: const ui.Offset(64, 102),
      maxWidth: width - 128,
      fontSize: 34,
      fontWeight: ui.FontWeight.w800,
      color: const ui.Color(0xFFFFFFFF),
      maxLines: 2,
    );

    _drawText(
      canvas,
      text: '${ticket.date} · ${ticket.time}',
      offset: const ui.Offset(64, 194),
      maxWidth: width - 128,
      fontSize: 21,
      fontWeight: ui.FontWeight.w600,
      color: const ui.Color(0xFFFFFFFF),
      maxLines: 1,
    );

    _drawText(
      canvas,
      text: ticket.venue,
      offset: const ui.Offset(64, 228),
      maxWidth: width - 128,
      fontSize: 18,
      fontWeight: ui.FontWeight.w400,
      color: const ui.Color(0xFFE2E8F0),
      maxLines: 1,
    );

    // 3. Pola Watermark LiveTix diagonal di area badan tiket
    canvas.save();
    canvas.clipRRect(cardRRect);
    canvas.translate(width / 2, 580);
    canvas.rotate(-24 * math.pi / 180);
    for (int row = -2; row <= 2; row++) {
      for (int col = -1; col <= 1; col++) {
        _drawText(
          canvas,
          text: 'LiveTix',
          offset: ui.Offset((col * 250) - 110, (row * 120) - 20),
          maxWidth: 220,
          fontSize: 34,
          fontWeight: ui.FontWeight.w800,
          color: const ui.Color(0x141B2A8C),
          maxLines: 1,
        );
      }
    }
    canvas.restore();

    // 4. Kotak QR Code untuk scan di gerbang masuk
    const double qrBoxSize = 360;
    const double qrLeft = (width - qrBoxSize) / 2;
    const double qrTop = 322;
    final qrFrame = ui.RRect.fromRectAndRadius(
      const ui.Rect.fromLTWH(qrLeft, qrTop, qrBoxSize, qrBoxSize),
      const ui.Radius.circular(24),
    );
    canvas.drawRRect(qrFrame, ui.Paint()..color = const ui.Color(0xFFFFFFFF));
    canvas.drawRRect(
      qrFrame,
      ui.Paint()
        ..color = const ui.Color(0xFFD0D5DD)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    if (qrImage != null) {
      final src = ui.Rect.fromLTWH(
        0,
        0,
        qrImage.width.toDouble(),
        qrImage.height.toDouble(),
      );
      const dst = ui.Rect.fromLTWH(
        qrLeft + 28,
        qrTop + 28,
        qrBoxSize - 56,
        qrBoxSize - 56,
      );
      canvas.drawImageRect(
        qrImage,
        src,
        dst,
        ui.Paint()..filterQuality = ui.FilterQuality.none,
      );
    }

    // Cap Watermark LiveTix di sudut bawah kotak QR
    final badgeRRect = ui.RRect.fromRectAndRadius(
      const ui.Rect.fromLTWH((width - 168) / 2, qrTop + qrBoxSize - 22, 168, 36),
      const ui.Radius.circular(18),
    );
    canvas.drawRRect(badgeRRect, ui.Paint()..color = const ui.Color(0xFF1B2A8C));
    _drawText(
      canvas,
      text: 'LiveTix Watermark',
      offset: const ui.Offset((width - 168) / 2, qrTop + qrBoxSize - 13),
      maxWidth: 168,
      fontSize: 15,
      fontWeight: ui.FontWeight.w700,
      color: const ui.Color(0xFFFFFFFF),
      maxLines: 1,
    );

    // 5. Informasi Gate, Kode Booking, & Kuota Scan
    _drawText(
      canvas,
      text: '${ticket.gate} · Kategori ${ticket.category} · ${ticket.bookingCode}',
      offset: const ui.Offset(60, 726),
      maxWidth: width - 120,
      fontSize: 21,
      fontWeight: ui.FontWeight.w700,
      color: const ui.Color(0xFF101828),
      maxLines: 1,
    );

    final scanPill = ui.RRect.fromRectAndRadius(
      const ui.Rect.fromLTWH(88, 770, width - 176, 56),
      const ui.Radius.circular(16),
    );
    canvas.drawRRect(scanPill, ui.Paint()..color = const ui.Color(0xFFECFDF5));
    _drawText(
      canvas,
      text:
          '1 QR Berlaku ${ticket.qrScanQuota}x Scan di Gate (${ticket.quantity} Tiket)',
      offset: const ui.Offset(100, 785),
      maxWidth: width - 200,
      fontSize: 20,
      fontWeight: ui.FontWeight.w700,
      color: const ui.Color(0xFF065F46),
      maxLines: 1,
    );

    _drawText(
      canvas,
      text: 'Diterbitkan resmi oleh LiveTix · Tunjukkan QR ini pada petugas gate',
      offset: const ui.Offset(60, 862),
      maxWidth: width - 120,
      fontSize: 16,
      fontWeight: ui.FontWeight.w500,
      color: const ui.Color(0xFF475467),
      maxLines: 2,
    );

    // Bingkai kartu luar
    canvas.drawRRect(
      cardRRect,
      ui.Paint()
        ..color = const ui.Color(0xFFE4E7EC)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final picture = recorder.endRecording();
    final renderedImage = await picture.toImage(width.toInt(), height.toInt());
    final byteData =
        await renderedImage.toByteData(format: ui.ImageByteFormat.png);
    if (byteData != null) {
      return byteData.buffer.asUint8List();
    }
    return Uint8List(0);
  }
}
