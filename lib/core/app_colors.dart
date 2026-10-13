import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF1B2A8C); // tombol navy
  static const accent = Color(0xFFC2185B); // link magenta
  static const splashBg = Color(0xFF070B14);
  static const textDark = Color(0xFF101828);
  static const textGrey = Color(0xFF667085);
  static const border = Color(0xFFE4E7EC);
  static const headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3B2BB5), Color(0xFFA020B0)],
  );
  static const logoGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFA020F0), Color(0xFF2D6BFF)],
  );
}
