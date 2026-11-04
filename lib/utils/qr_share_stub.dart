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
  return false;
}
