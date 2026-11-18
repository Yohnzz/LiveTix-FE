// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'file_picker_stub.dart';

export 'file_picker_stub.dart' show PickedFileResult;

/// Membuka file picker browser yang kompatibel dengan desktop maupun mobile web.
/// Elemen input di-attach ke DOM agar browser desktop (Chrome/Edge/Firefox) 
/// benar-benar membuka dialog file. Fallback timer 60 detik untuk berjaga-jaga.
Future<String?> pickNativeFile({String accept = '.jpg,.jpeg,.png,.pdf,image/*'}) async {
  final completer = Completer<String?>();

  final uploadInput = html.FileUploadInputElement()
    ..accept = accept
    ..style.display = 'none';

  // Harus di-attach ke DOM agar dialog file benar-benar muncul di browser desktop
  html.document.body?.append(uploadInput);

  StreamSubscription<html.Event>? changeSub;
  StreamSubscription<html.Event>? blurSub;
  StreamSubscription<html.Event>? focusSub;
  Timer? fallbackTimer;
  bool hadBlur = false;

  void cleanup() {
    changeSub?.cancel();
    blurSub?.cancel();
    focusSub?.cancel();
    fallbackTimer?.cancel();
    try {
      uploadInput.remove();
    } catch (_) {}
  }

  changeSub = uploadInput.onChange.listen((event) {
    final files = uploadInput.files;
    cleanup();
    if (!completer.isCompleted) {
      if (files != null && files.isNotEmpty) {
        completer.complete(files.first.name);
      } else {
        completer.complete(null);
      }
    }
  });

  // Browser desktop modern (Chrome/Edge/Safari/Firefox) memicu event 'cancel'
  // saat pengguna menutup dialog tanpa memilih file.
  uploadInput.addEventListener('cancel', (_) {
    Timer(const Duration(milliseconds: 200), () {
      cleanup();
      if (!completer.isCompleted) completer.complete(null);
    });
  });

  // Untuk browser yang tidak memicu event 'cancel', deteksi blur -> focus:
  // Hanya picu batal jika window sempat kehilangan fokus terlebih dahulu
  blurSub = html.window.onBlur.listen((_) => hadBlur = true);

  focusSub = html.window.onFocus.listen((_) {
    if (!hadBlur) return;
    Timer(const Duration(milliseconds: 1500), () {
      if (!completer.isCompleted) {
        final files = uploadInput.files;
        if (files == null || files.isEmpty) {
          cleanup();
          completer.complete(null);
        }
      }
    });
  });

  // Fallback: tutup completer setelah 120 detik jika dialog diabaikan
  fallbackTimer = Timer(const Duration(seconds: 120), () {
    cleanup();
    if (!completer.isCompleted) completer.complete(null);
  });

  uploadInput.click();

  return completer.future;
}

Future<PickedFileResult?> pickNativeFileWithContent({
  String accept = '.csv,.xlsx,.xls,.txt',
}) async {
  final completer = Completer<PickedFileResult?>();

  final uploadInput = html.FileUploadInputElement()
    ..accept = accept
    ..style.display = 'none';

  html.document.body?.append(uploadInput);

  StreamSubscription<html.Event>? changeSub;
  StreamSubscription<html.Event>? focusSub;
  Timer? fallbackTimer;

  void cleanup() {
    changeSub?.cancel();
    focusSub?.cancel();
    fallbackTimer?.cancel();
    try { uploadInput.remove(); } catch (_) {}
  }

  changeSub = uploadInput.onChange.listen((event) {
    final files = uploadInput.files;
    if (files != null && files.isNotEmpty) {
      final file = files.first;
      final reader = html.FileReader();
      reader.onLoadEnd.listen((_) {
        cleanup();
        if (!completer.isCompleted) {
          final text = reader.result?.toString() ?? '';
          completer.complete(PickedFileResult(name: file.name, content: text));
        }
      });
      reader.onError.listen((_) {
        cleanup();
        if (!completer.isCompleted) {
          completer.complete(PickedFileResult(name: file.name, content: ''));
        }
      });
      reader.readAsText(file);
    } else {
      cleanup();
      if (!completer.isCompleted) completer.complete(null);
    }
  });

  focusSub = html.window.onFocus.listen((_) {
    Timer(const Duration(milliseconds: 500), () {
      cleanup();
      if (!completer.isCompleted) completer.complete(null);
    });
  });

  fallbackTimer = Timer(const Duration(seconds: 60), () {
    cleanup();
    if (!completer.isCompleted) completer.complete(null);
  });

  uploadInput.click();

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
