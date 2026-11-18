import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

class PickedFileResult {
  final String name;
  final String content;

  const PickedFileResult({
    required this.name,
    required this.content,
  });
}

List<String> _extensionsFromAccept(String accept) => accept
    .split(',')
    .map((value) => value.trim().replaceFirst(RegExp(r'^\.'), ''))
    .where((value) => value.isNotEmpty && !value.contains('/'))
    .toSet()
    .toList();

Future<PlatformFile?> _pickFile(String accept) async {
  final extensions = _extensionsFromAccept(accept);
  final result = await FilePicker.platform.pickFiles(
    type: extensions.isEmpty ? FileType.any : FileType.custom,
    allowedExtensions: extensions.isEmpty ? null : extensions,
    allowMultiple: false,
    withData: true,
  );
  if (result == null || result.files.isEmpty) return null;
  return result.files.first;
}

Future<String?> pickNativeFile({
  String accept = '.jpg,.jpeg,.png,.pdf,image/*',
}) async {
  try {
    final picked = await _pickFile(accept);
    return picked?.name;
  } catch (_) {
    return null;
  }
}

Future<PickedFileResult?> pickNativeFileWithContent({
  String accept = '.csv,.xlsx,.xls,.txt',
}) async {
  try {
    final picked = await _pickFile(accept);
    if (picked == null) return null;
    final bytes = picked.bytes ??
        (picked.path == null ? null : await File(picked.path!).readAsBytes());
    if (bytes == null) return null;
    return PickedFileResult(name: picked.name, content: utf8.decode(bytes));
  } catch (_) {
    return null;
  }
}

Future<bool> downloadTemplateFile({
  required String fileName,
  required String content,
  String mimeType = 'text/plain;charset=utf-8',
}) async {
  try {
    final bytes = Uint8List.fromList(utf8.encode(content));
    final extension = fileName.contains('.')
        ? fileName.split('.').last
        : null;
    final savedPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Simpan template',
      fileName: fileName,
      type: extension == null ? FileType.any : FileType.custom,
      allowedExtensions: extension == null ? null : [extension],
      bytes: bytes,
    );
    return savedPath != null;
  } catch (_) {
    return false;
  }
}

Future<bool> openExternalUrl(String url) async {
  try {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      return await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  } catch (_) {
    return false;
  }
}
