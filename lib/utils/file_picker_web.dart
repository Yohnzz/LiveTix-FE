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
