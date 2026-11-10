import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

class PickedFileResult {
  final String name;
  final String content;

  const PickedFileResult({
    required this.name,
    required this.content,
  });
}

Future<String?> pickNativeFile({String accept = '.jpg,.jpeg,.png,.pdf,image/*'}) async {
  try {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      return picked.name.isNotEmpty ? picked.name : picked.path;
    }
  } catch (_) {}
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
