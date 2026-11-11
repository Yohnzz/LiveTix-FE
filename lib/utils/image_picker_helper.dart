import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class PickedConcertImage {
  final String name;
  final String dataUrl;
  final Uint8List bytes;
  final int sizeInBytes;

  const PickedConcertImage({
    required this.name,
    required this.dataUrl,
    required this.bytes,
    required this.sizeInBytes,
  });

  String get formattedSize {
    if (sizeInBytes < 1024) return '$sizeInBytes B';
    if (sizeInBytes < 1024 * 1024) {
      return '${(sizeInBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class ImagePickerHelper {
  static final ImagePicker _picker = ImagePicker();

  /// Memilih satu gambar dari galeri / file sistem perangkat
  static Future<PickedConcertImage?> pickImage({
    double maxWidth = 1200,
    double maxHeight = 1200,
    int imageQuality = 78,
  }) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality,
      );

      if (file == null) return null;

      final bytes = await file.readAsBytes();
      final name = file.name;
      final ext = name.toLowerCase().split('.').last;
      final mime = (ext == 'png')
          ? 'image/png'
          : (ext == 'webp')
              ? 'image/webp'
              : 'image/jpeg';
      final base64String = base64Encode(bytes);
      final dataUrl = 'data:$mime;base64,$base64String';

      return PickedConcertImage(
        name: name,
        dataUrl: dataUrl,
        bytes: bytes,
        sizeInBytes: bytes.length,
      );
    } catch (e) {
      debugPrint('Error pickImage: $e');
      return null;
    }
  }

  /// Memilih banyak gambar highlight dari galeri / file sistem perangkat
  static Future<List<PickedConcertImage>> pickMultiImages({
    double maxWidth = 1200,
    double maxHeight = 1200,
    int imageQuality = 78,
  }) async {
    try {
      final List<XFile> files = await _picker.pickMultiImage(
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality,
      );

      final results = <PickedConcertImage>[];
      for (final file in files) {
        final bytes = await file.readAsBytes();
        final name = file.name;
        final ext = name.toLowerCase().split('.').last;
        final mime = (ext == 'png')
            ? 'image/png'
            : (ext == 'webp')
                ? 'image/webp'
                : 'image/jpeg';
        final base64String = base64Encode(bytes);
        final dataUrl = 'data:$mime;base64,$base64String';

        results.add(PickedConcertImage(
          name: name,
          dataUrl: dataUrl,
          bytes: bytes,
          sizeInBytes: bytes.length,
        ));
      }
      return results;
    } catch (e) {
      debugPrint('Error pickMultiImages: $e');
      return [];
    }
  }
}
