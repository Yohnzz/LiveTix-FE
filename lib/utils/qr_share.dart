import 'dart:typed_data';

import 'qr_share_stub.dart'
    if (dart.library.html) 'qr_share_web.dart';

export 'qr_share_stub.dart'
    if (dart.library.html) 'qr_share_web.dart'
    show QrShareOutcome;

class QrSharePayload {
  final Uint8List pngBytes;
  final String fileName;
  final String title;
  final String text;

  const QrSharePayload({
    required this.pngBytes,
    required this.fileName,
    required this.title,
    required this.text,
  });
}

/// Utilitas berbagi gambar QR Gate tiket ke aplikasi lain di perangkat (WhatsApp, Telegram, dll.)
/// tanpa dependensi paket tambahan.
class QrShare {
  QrShare._();

  static Future<QrShareOutcome> Function(QrSharePayload payload)? testOverride;

  static Future<QrShareOutcome> shareGateQrImage({
    required Uint8List pngBytes,
    required String fileName,
    required String title,
    required String text,
  }) {
    final payload = QrSharePayload(
      pngBytes: pngBytes,
      fileName: fileName,
      title: title,
      text: text,
    );
    if (testOverride != null) {
      return testOverride!(payload);
    }
    return platformShareQrImage(
      pngBytes: pngBytes,
      fileName: fileName,
      title: title,
      text: text,
    );
  }

  static bool downloadGateQrImage({
    required Uint8List pngBytes,
    required String fileName,
  }) {
    return platformDownloadQrImage(pngBytes: pngBytes, fileName: fileName);
  }
}
