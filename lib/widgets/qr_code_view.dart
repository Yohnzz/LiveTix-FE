import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../core/app_colors.dart';

/// Komponen tampilan QR Code terpusat untuk aplikasi LiveTix.
/// Menggunakan `qrData` dengan `qr_flutter` untuk merender QR Code asli yang scannable (bukan dummy),
/// dan otomatis mendukung `qrCodeBytes` atau `qrCodeUrl` dari backend.
class AppQrCodeView extends StatelessWidget {
  final String? qrData;
  final String? qrCodeUrl;
  final Uint8List? qrCodeBytes;
  final double size;
  final double padding;
  final bool isDisabled;
  final bool showWatermark;
  final String semanticLabel;

  const AppQrCodeView({
    super.key,
    this.qrData,
    this.qrCodeUrl,
    this.qrCodeBytes,
    this.size = 156,
    this.padding = 12,
    this.isDisabled = false,
    this.showWatermark = false,
    this.semanticLabel = 'Kode QR LiveTix',
  });

  Widget _buildVectorPlaceholder(double innerSize) {
    return Center(
      child: Icon(
        Icons.qr_code_2_rounded,
        size: innerSize * 0.85,
        color: isDisabled ? const Color(0xFF94A3B8) : AppColors.textDark,
      ),
    );
  }

  Widget _buildQrImage(double innerSize) {
    // 1. Prioritas Utama: Jika qrData diberikan (string QRIS dari Midtrans atau kode e-tiket unik dari database Supabase)
    final effectiveData = qrData?.trim() ?? '';
    if (effectiveData.isNotEmpty) {
      return QrImageView(
        data: effectiveData,
        version: QrVersions.auto,
        size: innerSize,
        gapless: false,
        eyeStyle: QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: isDisabled ? const Color(0xFF94A3B8) : Colors.black,
        ),
        dataModuleStyle: QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: isDisabled ? const Color(0xFF94A3B8) : Colors.black,
        ),
        errorStateBuilder: (cxt, err) => _buildVectorPlaceholder(innerSize),
      );
    }

    // 2. Jika diberikan byte gambar mentah
    if (qrCodeBytes != null && qrCodeBytes!.isNotEmpty) {
      return Image.memory(
        qrCodeBytes!,
        width: innerSize,
        height: innerSize,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.none,
        errorBuilder: (_, __, ___) => _buildVectorPlaceholder(innerSize),
      );
    }

    // 3. Jika diberikan URL gambar resmi (CDN / Midtrans)
    final url = qrCodeUrl?.trim() ?? '';
    if (url.isNotEmpty && (url.startsWith('http://') || url.startsWith('https://'))) {
      return Image.network(
        url,
        width: innerSize,
        height: innerSize,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.none,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return SizedBox(
            width: innerSize,
            height: innerSize,
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: AppColors.primary,
                ),
              ),
            ),
          );
        },
        errorBuilder: (_, __, ___) => _buildVectorPlaceholder(innerSize),
      );
    }

    // 4. Fallback Dinamis jika label semantik memuat kode booking / ID tiket nyata
    if (semanticLabel.isNotEmpty &&
        !semanticLabel.toLowerCase().contains('kode qr livetix')) {
      final cleanLabelData = semanticLabel
          .replaceAll('Kode QR E-Tiket', '')
          .replaceAll('Kode Barcode QRIS Pembayaran LiveTix', '')
          .trim();
      if (cleanLabelData.isNotEmpty) {
        return QrImageView(
          data: cleanLabelData,
          version: QrVersions.auto,
          size: innerSize,
          gapless: false,
          eyeStyle: QrEyeStyle(
            eyeShape: QrEyeShape.square,
            color: isDisabled ? const Color(0xFF94A3B8) : Colors.black,
          ),
          dataModuleStyle: QrDataModuleStyle(
            dataModuleShape: QrDataModuleShape.square,
            color: isDisabled ? const Color(0xFF94A3B8) : Colors.black,
          ),
          errorStateBuilder: (cxt, err) => _buildVectorPlaceholder(innerSize),
        );
      }
    }

    // Fallback bersih menggunakan ikon vektor tanpa ketergantungan file asset eksternal
    return _buildVectorPlaceholder(innerSize);
  }

  @override
  Widget build(BuildContext context) {
    final innerSize = (size - (padding * 2)).clamp(48.0, size);

    return Semantics(
      image: true,
      label: semanticLabel,
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: isDisabled ? const Color(0xFFF3F4F6) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDisabled ? const Color(0xFFD1D5DB) : AppColors.border,
            width: 1.2,
          ),
          boxShadow: isDisabled
              ? null
              : const [
                  BoxShadow(
                    color: Color(0x0A101828),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: isDisabled ? 0.25 : 1.0,
              child: _buildQrImage(innerSize),
            ),
            if (showWatermark && !isDisabled)
              Positioned(
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'LiveTix',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            if (isDisabled)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF374151),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'NONAKTIF',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
