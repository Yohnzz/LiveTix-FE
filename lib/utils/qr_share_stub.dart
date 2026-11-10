import 'dart:io';
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
  return QrShareOutcome.unsupported;
}

bool platformDownloadQrImage({
  required Uint8List pngBytes,
  required String fileName,
}) {
  try {
    if (pngBytes.isEmpty) return false;
    // Android: coba simpan ke folder Download publik
    if (Platform.isAndroid) {
      final downloadDir = Directory('/storage/emulated/0/Download');
      if (downloadDir.existsSync()) {
        final file = File('${downloadDir.path}/$fileName');
        file.writeAsBytesSync(pngBytes);
        return true;
      }
    }
    // Fallback: temp folder
    final tempDir = Directory.systemTemp;
    final file = File('${tempDir.path}/$fileName');
    file.writeAsBytesSync(pngBytes);
    return true;
  } catch (_) {
    return false;
  }
}
