import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_colors.dart';

/// Komponen tampilan QR Code terpusat untuk aplikasi LiveTix.
/// Menggunakan sementara `assets/images/qrcode.png` selama pengujian user,
/// dan otomatis beralih ke `qrCodeBytes` atau `qrCodeUrl` dari backend saat terhubung.
/// Mendukung penampilan kode tiket resmi di bawah gambar QR Code.
class AppQrCodeView extends StatelessWidget {
  static const String defaultTestingAssetPath = 'assets/images/qrcode.png';

  final String? qrCodeUrl;
  final Uint8List? qrCodeBytes;
  final double size;
  final double padding;
  final bool isDisabled;
  final bool showWatermark;
  final String semanticLabel;
  final String? ticketCode;
  final bool showCodeBelow;

  const AppQrCodeView({
    super.key,
    this.qrCodeUrl,
    this.qrCodeBytes,
    this.size = 156,
    this.padding = 12,
    this.isDisabled = false,
    this.showWatermark = false,
    this.semanticLabel = 'Kode QR LiveTix',
    this.ticketCode,
    this.showCodeBelow = true,
  });

  Widget _buildDefaultAssetImage(double innerSize) {
    return Image.asset(
      defaultTestingAssetPath,
      width: innerSize,
      height: innerSize,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.none,
      errorBuilder: (_, __, ___) => Center(
        child: Icon(
          Icons.qr_code_2_rounded,
          size: innerSize * 0.8,
          color: AppColors.textDark,
        ),
      ),
    );
  }

  Widget _buildQrImage(double innerSize) {
    if (qrCodeBytes != null && qrCodeBytes!.isNotEmpty) {
      return Image.memory(
        qrCodeBytes!,
        width: innerSize,
        height: innerSize,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.none,
        errorBuilder: (_, __, ___) => _buildDefaultAssetImage(innerSize),
      );
    }

    final url = qrCodeUrl?.trim() ?? '';
    if (url.isNotEmpty) {
      if (url.startsWith('http://') || url.startsWith('https://')) {
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
          errorBuilder: (_, __, ___) => _buildDefaultAssetImage(innerSize),
        );
      }
      return Image.asset(
        url,
        width: innerSize,
        height: innerSize,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.none,
        errorBuilder: (_, __, ___) => _buildDefaultAssetImage(innerSize),
      );
    }

    return _buildDefaultAssetImage(innerSize);
  }

  @override
  Widget build(BuildContext context) {
    final innerSize = (size - (padding * 2)).clamp(48.0, size);

    final qrBox = Semantics(
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

    if (ticketCode == null || ticketCode!.trim().isEmpty || !showCodeBelow) {
      return qrBox;
    }

    final code = ticketCode!.trim();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        qrBox,
        const SizedBox(height: 8),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            Clipboard.setData(ClipboardData(text: code));
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
              SnackBar(
                content: Text('Kode tiket $code berhasil disalin!'),
                duration: const Duration(seconds: 1),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.qr_code_2_rounded,
                  size: 14,
                  color: Color(0xFF475467),
                ),
                const SizedBox(width: 5),
                Text(
                  code,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    letterSpacing: 0.8,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(width: 5),
                const Icon(
                  Icons.copy_rounded,
                  size: 12,
                  color: Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
