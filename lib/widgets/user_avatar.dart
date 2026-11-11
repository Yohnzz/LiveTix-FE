import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';

class AvatarColorTheme {
  final String name;
  final Color bgColor;
  final Color textColor;

  const AvatarColorTheme({
    required this.name,
    required this.bgColor,
    required this.textColor,
  });
}

/// Komponen avatar pengguna terpadu untuk menampilkan foto profil (MemoryImage),
/// siluet default bergaya ikon vektor navy, atau inisial dengan palet warna WCAG AA.
class UserAvatar extends StatelessWidget {
  static const List<AvatarColorTheme> themes = [
    AvatarColorTheme(
      name: 'Ungu Klasik',
      bgColor: Color(0xFFFCE7F3),
      textColor: Color(0xFF6B21A8),
    ),
    AvatarColorTheme(
      name: 'Biru Panggung',
      bgColor: Color(0xFFE0EAFF),
      textColor: Color(0xFF1B2A8C),
    ),
    AvatarColorTheme(
      name: 'Magenta Konser',
      bgColor: Color(0xFFFCE7F3),
      textColor: Color(0xFF9D174D),
    ),
    AvatarColorTheme(
      name: 'Hijau Zamrud',
      bgColor: Color(0xFFDCFCE7),
      textColor: Color(0xFF166534),
    ),
    AvatarColorTheme(
      name: 'Kuning Amber',
      bgColor: Color(0xFFFEF3C7),
      textColor: Color(0xFF92400E),
    ),
  ];

  final String initials;
  final Uint8List? imageBytes;
  final String? avatarUrl;
  final int colorIndex;
  final double size;
  final double fontSize;

  const UserAvatar({
    super.key,
    required this.initials,
    this.imageBytes,
    this.avatarUrl,
    this.colorIndex = -1,
    this.size = 54,
    this.fontSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    final hasCustomTheme = colorIndex >= 0 && colorIndex < themes.length;
    final theme = themes[hasCustomTheme ? colorIndex : 0];

    final effectiveBytes = imageBytes;

    if (effectiveBytes != null && effectiveBytes.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: theme.bgColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFFE4E7EC),
            width: 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.memory(
          effectiveBytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => hasCustomTheme
              ? _buildInitialsCenter(theme)
              : GuestAvatarIcon(size: size),
        ),
      );
    }

    if (avatarUrl != null && avatarUrl!.startsWith('http')) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: theme.bgColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFFE4E7EC),
            width: 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.network(
          avatarUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => hasCustomTheme
              ? _buildInitialsCenter(theme)
              : GuestAvatarIcon(size: size),
        ),
      );
    }

    if (!hasCustomTheme) {
      return GuestAvatarIcon(size: size);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.bgColor,
        shape: BoxShape.circle,
      ),
      child: _buildInitialsCenter(theme),
    );
  }

  Widget _buildInitialsCenter(AvatarColorTheme theme) {
    return Center(
      child: Text(
        initials.isNotEmpty ? initials : 'U',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: theme.textColor,
        ),
      ),
    );
  }
}

/// Ikon avatar profil berbentuk lingkaran abu-abu terang (#F2F4F7) berbingkai halus (#E4E7EC)
/// dengan siluet kepala solid dan lengkung bahu terbuka berwarna navy (#1B2A8C).
class GuestAvatarIcon extends StatelessWidget {
  final double size;

  const GuestAvatarIcon({
    super.key,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F7),
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFFE4E7EC),
          width: 1.5,
        ),
      ),
      child: CustomPaint(
        size: Size(size, size),
        painter: const _ProfileSilhouettePainter(),
      ),
    );
  }
}

class _ProfileSilhouettePainter extends CustomPainter {
  const _ProfileSilhouettePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w * 0.5;

    final headPaint = Paint()
      ..color = const Color(0xFF1B2A8C)
      ..style = PaintingStyle.fill;

    final shoulderPaint = Paint()
      ..color = const Color(0xFF1B2A8C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (w * 0.056).clamp(2.2, 3.6)
      ..strokeCap = StrokeCap.round;

    // Kepala lingkaran solid proporsional di bagian atas tengah
    canvas.drawCircle(
      Offset(cx, h * 0.36),
      w * 0.105,
      headPaint,
    );

    // Lengkung bahu terbuka menghadap bawah tanpa garis penutup horizontal
    final shoulderRect = Rect.fromCircle(
      center: Offset(cx, h * 0.75),
      radius: w * 0.205,
    );
    canvas.drawArc(
      shoulderRect,
      math.pi + 0.12,
      math.pi - 0.24,
      false,
      shoulderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
