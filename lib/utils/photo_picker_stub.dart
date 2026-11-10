import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

bool get isPlatformFilePickerSupported => true;

Future<Uint8List?> pickPlatformImageBytes() async {
  try {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      return await picked.readAsBytes();
    }
  } catch (_) {}
  return null;
}
