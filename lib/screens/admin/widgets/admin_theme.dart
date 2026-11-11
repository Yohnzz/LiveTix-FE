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

  // Dark palette (WCAG AA >= 4.5:1 on #1E293B and #0B1120)
  static const darkBackground = Color(0xFF0B1120);
  static const darkSurface = Color(0xFF1E293B);
  static const darkSurfaceAlt = Color(0xFF283548);
  static const darkBorder = Color(0xFF334155);
  static const darkTextPrimary = Color(0xFFF8FAFC);
  static const darkTextSecondary = Color(0xFFCBD5E1);
  static const darkTextMuted = Color(0xFF94A3B8);

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

  static Color surfaceAltOf(BuildContext context) =>
      isDark(context) ? darkSurfaceAlt : const Color(0xFFF8FAFC);

  static Color borderOf(BuildContext context) =>
      isDark(context) ? darkBorder : border;

  static Color dividerOf(BuildContext context) =>
      isDark(context) ? darkBorder : const Color(0xFFF1F5F9);

  static Color textPrimaryOf(BuildContext context) =>
      isDark(context) ? darkTextPrimary : textDark;

  static Color textSecondaryOf(BuildContext context) =>
      isDark(context) ? darkTextSecondary : textGrey;

  static Color textMutedOf(BuildContext context) =>
      isDark(context) ? darkTextMuted : textGrey;

  static Color accentOf(BuildContext context) =>
      isDark(context) ? const Color(0xFFA5B4FC) : navy;

  static Color primaryButtonBgOf(BuildContext context) =>
      isDark(context) ? indigo : navy;

  static Color magentaOf(BuildContext context) =>
      isDark(context) ? const Color(0xFFF472B6) : magenta;

  static Color pinkAccentOf(BuildContext context) =>
      isDark(context) ? const Color(0xFFF472B6) : const Color(0xFFC2185B);

  static Color avatarBgOf(BuildContext context) =>
      isDark(context) ? const Color(0xFF312E81) : avatarBg;

  static Color successOf(BuildContext context) =>
      isDark(context) ? const Color(0xFF4ADE80) : success;

  static Color successBgOf(BuildContext context) =>
      isDark(context) ? const Color(0xFF064E3B) : const Color(0xFFECFDF5);

  static Color successBorderOf(BuildContext context) =>
      isDark(context) ? const Color(0xFF059669) : const Color(0xFFA7F3D0);

  static Color dangerOf(BuildContext context) =>
      isDark(context) ? const Color(0xFFFCA5A5) : danger;

  static Color dangerBgOf(BuildContext context) =>
      isDark(context) ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2);

  static Color dangerSoftBgOf(BuildContext context) =>
      isDark(context) ? const Color(0xFF3F1219) : dangerSoft;

  static Color dangerBorderOf(BuildContext context) =>
      isDark(context) ? const Color(0xFF991B1B) : const Color(0xFFFECACA);

  static Color warningOf(BuildContext context) =>
      isDark(context) ? const Color(0xFFFCD34D) : const Color(0xFF92400E);

  static Color warningBgOf(BuildContext context) =>
      isDark(context) ? const Color(0xFF422006) : const Color(0xFFFEF3C7);

  static Color warningBorderOf(BuildContext context) =>
      isDark(context) ? const Color(0xFFB45309) : const Color(0xFFFCD34D);

  static Color infoOf(BuildContext context) =>
      isDark(context) ? const Color(0xFF93C5FD) : const Color(0xFF1E3A8A);

  static Color infoBgOf(BuildContext context) =>
      isDark(context) ? const Color(0xFF172554) : const Color(0xFFEFF6FF);

  static Color infoBorderOf(BuildContext context) =>
      isDark(context) ? const Color(0xFF1D4ED8) : const Color(0xFFBFDBFE);

  static Color purpleOf(BuildContext context) =>
      isDark(context) ? const Color(0xFFE9D5FF) : const Color(0xFF7C3AED);

  static Color purpleBgOf(BuildContext context) =>
      isDark(context) ? const Color(0xFF3B0764) : const Color(0xFFF3E8FF);

  static Color disabledBgOf(BuildContext context) =>
      isDark(context) ? darkBorder : const Color(0xFFE2E8F0);

  static Color disabledFgOf(BuildContext context) =>
      isDark(context) ? darkTextSecondary : textGrey;

  /// Pasangan (background, foreground) ber-kontras tinggi untuk badge role User/Produser/Admin/Gatecrew.
  static (Color bg, Color fg) roleBadgeColors(
      BuildContext context, String role) {
    final dark = isDark(context);
    switch (role.toLowerCase()) {
      case 'produser':
        return (purpleBgOf(context), purpleOf(context));
      case 'gatecrew':
        return (
          successBgOf(context),
          dark ? const Color(0xFF4ADE80) : const Color(0xFF059669),
        );
      case 'admin':
        return (
          infoBgOf(context),
          dark ? const Color(0xFF93C5FD) : const Color(0xFF1E3A8A),
        );
      default:
        return (
          infoBgOf(context),
          dark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB),
        );
    }
  }
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
    final txtSec =
        isDark ? AdminColors.darkTextSecondary : AdminColors.textGrey;
    final bdr = isDark ? AdminColors.darkBorder : AdminColors.border;
    final accent = isDark ? const Color(0xFFA5B4FC) : AdminColors.navy;

    return base.copyWith(
      scaffoldBackgroundColor: bg,
      cardColor: surf,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AdminColors.navy,
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: accent,
        onPrimary: isDark ? AdminColors.darkBackground : Colors.white,
        surface: surf,
        onSurface: txt,
      ),
      textTheme: GoogleFonts.poppinsTextTheme(base.textTheme).apply(
        bodyColor: txt,
        displayColor: txt,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accent),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surf,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: txt,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(
          color: txtSec,
          fontSize: 14,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: isDark ? AdminColors.darkTextMuted : AdminColors.textGrey),
        labelStyle: TextStyle(color: txtSec),
        floatingLabelStyle: TextStyle(color: accent),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: bdr),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surf,
        surfaceTintColor: Colors.transparent,
        textStyle: TextStyle(color: txt, fontSize: 13),
      ),
      dividerColor: bdr,
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
