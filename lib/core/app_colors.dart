import 'package:flutter/material.dart';
import '../services/data_service.dart';

class AppColors {
  // Brand & Accent Colors
  static const primary = Color(0xFF1B2A8C); // tombol navy
  static const primaryDark = Color(0xFF60A5FA); // navy/sky blue untuk tema gelap
  static const accent = Color(0xFFC2185B); // link magenta
  static const favoritePink = Color(0xFFE91E8C); // tombol disukai / love pink (#E91E8C)
  static const splashBg = Color(0xFF070B14);
  static const bannerYellow = Color(0xFFF59E0B);
  static const citySelectedShadow = Color(0xFFC654C3); // shadow highlight tombol kota aktif

  // Light Mode Tokens
  static const textDark = Color(0xFF101828);
  static const textGrey = Color(0xFF667085);
  static const border = Color(0xFFE4E7EC);
  static const searchBarBg = Color(0xFFF2F4F7);
  static const chipBorder = Color(0xFFE4E7EC);
  static const modalBoxBg = Color(0xFFF4F6FB);
  static const avatarBg = Color(0xFFFCE7F3);
  static const avatarText = Color(0xFF9333EA);

  // Dark Mode Tokens (Slate Deep Palette)
  static const darkBg = Color(0xFF0B1120); // slate-950 latar belakang dasar
  static const darkSurface = Color(0xFF1E293B); // slate-800 kartu & container
  static const darkSurfaceVariant = Color(0xFF283548); // slate-750 input & chip aktif
  static const darkBorder = Color(0xFF334155); // slate-700 garis tepi kontras
  static const darkText = Color(0xFFF8FAFC); // slate-50 teks utama
  static const darkTextSecondary = Color(0xFF94A3B8); // slate-400 teks pendukung
  static const darkIconBox = Color(0xFF2D3B4F);
  static const darkModalBox = Color(0xFF162032);

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

  // Helper dinamis context-aware
  static bool isDark(BuildContext context) {
    return DataService().isDarkModeNotifier.value;
  }

  static Color bg(BuildContext context) =>
      isDark(context) ? darkBg : Colors.white;

  static Color card(BuildContext context) =>
      isDark(context) ? darkSurface : Colors.white;

  static Color cardAlt(BuildContext context) =>
      isDark(context) ? darkSurfaceVariant : const Color(0xFFF8F9FC);

  static Color borderCol(BuildContext context) =>
      isDark(context) ? darkBorder : border;

  static Color text(BuildContext context) =>
      isDark(context) ? darkText : textDark;

  static Color subtext(BuildContext context) =>
      isDark(context) ? darkTextSecondary : textGrey;

  static Color brand(BuildContext context) =>
      isDark(context) ? primaryDark : primary;

  static Color searchBg(BuildContext context) =>
      isDark(context) ? darkSurfaceVariant : searchBarBg;
}
