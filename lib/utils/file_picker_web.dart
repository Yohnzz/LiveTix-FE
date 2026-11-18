// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'file_picker_stub.dart';

export 'file_picker_stub.dart' show PickedFileResult;

Future<String?> pickNativeFile({String accept = '.jpg,.jpeg,.png,.pdf,image/*'}) async {
  final completer = Completer<String?>();
  final uploadInput = html.FileUploadInputElement();
  uploadInput.accept = accept;

  uploadInput.onChange.listen((event) {
    final files = uploadInput.files;
    if (files != null && files.isNotEmpty) {
      if (!completer.isCompleted) completer.complete(files.first.name);
    } else if (!completer.isCompleted) {
      completer.complete(null);
    }
  });
  // File inputs do not emit a change event when their dialog is dismissed.
  // When focus returns, allow a selected file's change event time to arrive
  // before treating the interaction as cancelled.
  html.window.onFocus.first.then((_) {
    Timer(const Duration(milliseconds: 100), () {
      if (!completer.isCompleted) completer.complete(null);
    });
  });

  uploadInput.click();

  return completer.future;
}

Future<PickedFileResult?> pickNativeFileWithContent({
  String accept = '.csv,.xlsx,.xls,.txt',
}) async {
  final completer = Completer<PickedFileResult?>();
  final uploadInput = html.FileUploadInputElement();
  uploadInput.accept = accept;
  uploadInput.click();

  uploadInput.onChange.listen((event) {
    final files = uploadInput.files;
    if (files != null && files.isNotEmpty) {
      final file = files.first;
      final reader = html.FileReader();
      reader.onLoadEnd.listen((_) {
        if (!completer.isCompleted) {
          final text = reader.result?.toString() ?? '';
          completer.complete(PickedFileResult(name: file.name, content: text));
        }
      });
      reader.onError.listen((_) {
        if (!completer.isCompleted) {
          completer.complete(PickedFileResult(name: file.name, content: ''));
        }
      });
      reader.readAsText(file);
    } else {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    }
  });

  return completer.future;
}

Future<bool> downloadTemplateFile({
  required String fileName,
  required String content,
  String mimeType = 'text/plain;charset=utf-8',
}) async {
  try {
    final bytes = utf8.encode(content);
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
    anchor.remove();
    return true;
  } catch (_) {
    return false;
  }
}

Future<bool> openExternalUrl(String url) async {
  try {
    html.window.open(url, '_blank');
    return true;
  } catch (_) {
    return false;
  }
}
