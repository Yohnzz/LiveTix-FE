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
    // Android: coba simpan ke folder Download publik, Pictures, atau DCIM
    if (Platform.isAndroid) {
      final candidates = [
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Pictures',
        '/storage/emulated/0/DCIM/Camera',
        '/storage/emulated/0/DCIM',
      ];
      for (final path in candidates) {
        final dir = Directory(path);
        if (dir.existsSync()) {
          try {
            final file = File('${dir.path}/$fileName');
            file.writeAsBytesSync(pngBytes, flush: true);
            return true;
          } catch (_) {}
        }
      }
    }
    // Fallback: temp folder
    final tempDir = Directory.systemTemp;
    final file = File('${tempDir.path}/$fileName');
    file.writeAsBytesSync(pngBytes, flush: true);
    return true;
  } catch (_) {
    return false;
  }
}
