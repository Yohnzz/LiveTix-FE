import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_colors.dart';
import '../../../services/data_service.dart';

/// Palet warna dinamis Super Admin yang mendukung Mode Terang & Mode Gelap.
class AdminColors {
  AdminColors._();

  static const background = Color(0xFFF6F7FB);
  static const surface = Colors.white;
  static const border = Color(0xFFE2E8F0);
  static const textDark = Color(0xFF0F172A);
  static const textGrey = Color(0xFF64748B);
  static const navy = AppColors.primary;
  static const indigo = Color(0xFF4F46E5);
  static const magenta = Color(0xFFA21CAF);
  static const avatarBg = Color(0xFFEEF2FF);
  static const amberAvatar = Color(0xFFF5A623);
  static const danger = Color(0xFFDC2626);
  static const dangerSoft = Color(0xFFFEF2F2);
  static const success = Color(0xFF15803D);

  // Dark palette
  static const darkBackground = Color(0xFF0B1120);
  static const darkSurface = Color(0xFF1E293B);
  static const darkBorder = Color(0xFF334155);
  static const darkTextPrimary = Color(0xFFF8FAFC);
  static const darkTextSecondary = Color(0xFF94A3B8);

  /// Gradien header Beranda Admin yang disatukan ke seluruh halaman Admin.
  static const gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1B2A8C), Color(0xFF4F46E5)],
  );

  static const dangerGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF7F1D1D), Color(0xFFB91C1C)],
  );

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color bgOf(BuildContext context) =>
      isDark(context) ? darkBackground : background;

  static Color surfaceOf(BuildContext context) =>
      isDark(context) ? darkSurface : surface;

  static Color borderOf(BuildContext context) =>
      isDark(context) ? darkBorder : border;

  static Color textPrimaryOf(BuildContext context) =>
      isDark(context) ? darkTextPrimary : textDark;

  static Color textSecondaryOf(BuildContext context) =>
      isDark(context) ? darkTextSecondary : textGrey;

  static Color accentOf(BuildContext context) =>
      isDark(context) ? const Color(0xFF818CF8) : navy;

  static Color avatarBgOf(BuildContext context) =>
      isDark(context) ? const Color(0xFF312E81) : avatarBg;
}

class AdminTheme {
  AdminTheme._();

  static ThemeData build({bool isDark = false}) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
    );
    final bg = isDark ? AdminColors.darkBackground : AdminColors.background;
    final surf = isDark ? AdminColors.darkSurface : AdminColors.surface;
    final txt = isDark ? AdminColors.darkTextPrimary : AdminColors.textDark;

    return base.copyWith(
      scaffoldBackgroundColor: bg,
      cardColor: surf,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AdminColors.navy,
        brightness: isDark ? Brightness.dark : Brightness.light,
        surface: surf,
      ),
      textTheme: GoogleFonts.poppinsTextTheme(base.textTheme).apply(
        bodyColor: txt,
        displayColor: txt,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surf,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surf,
        surfaceTintColor: Colors.transparent,
      ),
      dividerColor: isDark ? AdminColors.darkBorder : AdminColors.border,
    );
  }
}

/// Membungkus setiap layar Admin dan mendengarkan perubahan tema (Gelap/Terang) secara reaktif.
class AdminScope extends StatelessWidget {
  final Widget child;

  const AdminScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: DataService().isDarkModeNotifier,
      builder: (context, isDark, _) {
        return Theme(
          data: AdminTheme.build(isDark: isDark),
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
              statusBarBrightness: Brightness.dark,
              systemNavigationBarColor:
                  isDark ? AdminColors.darkSurface : Colors.white,
              systemNavigationBarIconBrightness:
                  isDark ? Brightness.light : Brightness.dark,
            ),
            child: child,
          ),
        );
      },
    );
  }
}
