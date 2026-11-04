// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:typed_data';

enum QrShareOutcome {
  sharedNatively,
  downloadedFallback,
  cancelled,
  unsupported,
}

Future<QrShareOutcome> platformShareQrImage({
  required Uint8List pngBytes,
  required String fileName,
  required String title,
  required String text,
}) async {
  final nav = html.window.navigator;

  if (pngBytes.isNotEmpty) {
    // 1. Coba panggil fitur Bagikan bawaan HP (Web Share API Level 2 dengan file gambar PNG)
    try {
      final webFile = html.File([pngBytes], fileName, {'type': 'image/png'});
      await nav.share({
        'files': [webFile],
        'title': title,
        'text': text,
      });
      return QrShareOutcome.sharedNatively;
    } catch (err) {
      final msg = err.toString().toLowerCase();
      if (msg.contains('abort') || msg.contains('cancel')) {
        return QrShareOutcome.cancelled;
      }
    }

    // 2. Jika browser hanya mendukung Web Share teks tanpa file, unduh PNG ber-watermark + buka dialog Share teks
    try {
      platformDownloadQrImage(pngBytes: pngBytes, fileName: fileName);
      await nav.share({
        'title': title,
        'text': text,
      });
      return QrShareOutcome.sharedNatively;
    } catch (err) {
      final msg = err.toString().toLowerCase();
      if (msg.contains('abort') || msg.contains('cancel')) {
        return QrShareOutcome.cancelled;
      }
    }

    // 3. Fallback desktop browser: simpan langsung gambar PNG ber-watermark ke perangkat
    if (platformDownloadQrImage(pngBytes: pngBytes, fileName: fileName)) {
      return QrShareOutcome.downloadedFallback;
    }
  }

  return QrShareOutcome.unsupported;
}

bool platformDownloadQrImage({
  required Uint8List pngBytes,
  required String fileName,
}) {
  if (pngBytes.isEmpty) return false;
  try {
    final blob = html.Blob([pngBytes], 'image/png');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..download = fileName
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    Future.delayed(const Duration(seconds: 1), () {
      html.Url.revokeObjectUrl(url);
    });
    return true;
  } catch (_) {
    return false;
  }
}
