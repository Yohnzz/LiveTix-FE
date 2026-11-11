import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Komponen universal untuk merender gambar konser dari berbagai sumber:
/// 1. Data URL Base64 (`data:image/png;base64,...` atau `data:image/jpeg;base64,...`)
/// 2. Raw Uint8List bytes
/// 3. Network URL (`http://...` atau `https://...`)
/// 4. Asset lokal (`assets/...`)
/// 5. Fallback ke placeholder/ikon dengan gradien yang elegan jika tidak ada gambar
class ConcertImageWidget extends StatelessWidget {
  final String? imageSource;
  final Uint8List? imageBytes;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Widget? fallbackWidget;
  final IconData fallbackIcon;
  final String? fallbackLabel;

  const ConcertImageWidget({
    super.key,
    this.imageSource,
    this.imageBytes,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.fallbackWidget,
    this.fallbackIcon = Icons.image_outlined,
    this.fallbackLabel,
  });

  bool get hasImage {
    if (imageBytes != null && imageBytes!.isNotEmpty) return true;
    final src = imageSource?.trim() ?? '';
    return src.isNotEmpty &&
        (src.startsWith('data:image/') ||
            src.startsWith('http://') ||
            src.startsWith('https://') ||
            src.startsWith('assets/'));
  }

  Uint8List? _extractBytes() {
    if (imageBytes != null && imageBytes!.isNotEmpty) {
      return imageBytes;
    }
    final src = imageSource?.trim() ?? '';
    if (src.startsWith('data:image/')) {
      final commaIdx = src.indexOf(',');
      if (commaIdx != -1) {
        try {
          return base64Decode(src.substring(commaIdx + 1));
        } catch (_) {
          return null;
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    final extractedBytes = _extractBytes();

    if (extractedBytes != null) {
      content = Image.memory(
        extractedBytes,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => _buildFallback(),
      );
    } else {
      final src = imageSource?.trim() ?? '';
      if (src.startsWith('http://') || src.startsWith('https://')) {
        content = Image.network(
          src,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => _buildFallback(),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: width,
              height: height,
              color: const Color(0xFFF1F5F9),
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          },
        );
      } else if (src.startsWith('assets/')) {
        content = Image.asset(
          src,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => _buildFallback(),
        );
      } else {
        content = _buildFallback();
      }
    }

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: content,
      );
    }

    return content;
  }

  Widget _buildFallback() {
    if (fallbackWidget != null) return fallbackWidget!;

    return Container(
      width: width,
      height: height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF1B2A8C), // Navy
            Color(0xFF6B1D7C),
            Color(0xFFC2185B), // Magenta
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(fallbackIcon, size: 28, color: Colors.white70),
            if (fallbackLabel != null && fallbackLabel!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  fallbackLabel!,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
