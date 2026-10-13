import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF1B2A8C); // tombol navy
  static const accent = Color(0xFFC2185B); // link magenta
  static const splashBg = Color(0xFF070B14);
  static const textDark = Color(0xFF101828);
  static const textGrey = Color(0xFF667085);
  static const border = Color(0xFFE4E7EC);
  static const searchBarBg = Color(0xFFF2F4F7);
  static const chipBorder = Color(0xFFE4E7EC);
  static const modalBoxBg = Color(0xFFF4F6FB);
  static const bannerYellow = Color(0xFFF59E0B);
  static const avatarBg = Color(0xFFFCE7F3);
  static const avatarText = Color(0xFF9333EA);

  static const headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF271C80), Color(0xFF971C91)],
  );
  static const logoGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFA020F0), Color(0xFF2D6BFF)],
  );
}
