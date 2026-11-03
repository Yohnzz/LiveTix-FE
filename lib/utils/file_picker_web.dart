// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;

Future<String?> pickNativeFile() async {
  final completer = Completer<String?>();
  final uploadInput = html.FileUploadInputElement();
  uploadInput.accept = '.jpg,.jpeg,.png,.pdf,image/*';
  uploadInput.click();

  uploadInput.onChange.listen((event) {
    final files = uploadInput.files;
    if (files != null && files.isNotEmpty) {
      final file = files.first;
      if (!completer.isCompleted) {
        completer.complete(file.name);
      }
    } else {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    }
  });

  return completer.future;
}
