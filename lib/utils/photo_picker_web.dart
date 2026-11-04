// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

bool get isPlatformFilePickerSupported => true;

Future<Uint8List?> pickPlatformImageBytes() {
  final completer = Completer<Uint8List?>();
  final input = html.FileUploadInputElement()
    ..accept = 'image/png,image/jpeg,image/webp,image/gif';

  bool settled = false;
  void completeOnce(Uint8List? bytes) {
    if (!settled) {
      settled = true;
      completer.complete(bytes);
    }
  }

  input.onChange.listen((_) {
    final files = input.files;
    if (files == null || files.isEmpty) {
      completeOnce(null);
      return;
    }
    final file = files.first;
    final reader = html.FileReader();
    reader.onLoadEnd.listen((_) {
      final res = reader.result;
      if (res is Uint8List) {
        completeOnce(res);
      } else if (res is ByteBuffer) {
        completeOnce(res.asUint8List());
      } else {
        completeOnce(null);
      }
    });
    reader.onError.listen((_) => completeOnce(null));
    reader.readAsArrayBuffer(file);
  });

  // Jika pengguna membatalkan dialog pemilihan file di browser
  html.window.onFocus.first.then((_) {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!settled && (input.files == null || input.files!.isEmpty)) {
        completeOnce(null);
      }
    });
  });

  input.click();
  return completer.future;
}
