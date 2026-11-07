class PickedFileResult {
  final String name;
  final String content;

  const PickedFileResult({
    required this.name,
    required this.content,
  });
}

Future<String?> pickNativeFile({String accept = '.jpg,.jpeg,.png,.pdf,image/*'}) async {
  return null;
}

Future<PickedFileResult?> pickNativeFileWithContent({
  String accept = '.csv,.xlsx,.xls,.txt',
}) async {
  return null;
}

Future<bool> downloadTemplateFile({
  required String fileName,
  required String content,
  String mimeType = 'text/plain;charset=utf-8',
}) async {
  return true;
}

Future<bool> openExternalUrl(String url) async {
  return true;
}
