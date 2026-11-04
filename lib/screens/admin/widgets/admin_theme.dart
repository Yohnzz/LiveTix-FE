import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_colors.dart';

/// Warna layar Super Admin. Desainnya terang saja, jadi tidak ikut mode gelap aplikasi.
class AdminColors {
  AdminColors._();

  static const background = Color(0xFFF2F2F4);
  static const surface = Colors.white;
  static const border = Color(0xFFE4E7EC);
  static const textDark = Color(0xFF101828);
  static const textGrey = Color(0xFF667085);
  static const navy = AppColors.primary;
  static const magenta = Color(0xFFA21CAF);
  static const avatarBg = Color(0xFFF1EEFA);
  static const amberAvatar = Color(0xFFF5A623);
  static const danger = Color(0xFFC81E1E);
  static const dangerSoft = Color(0xFFFEF2F2);
  static const success = Color(0xFF15803D);

  static const gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3B1478), Color(0xFF6D28D9), Color(0xFFA3248F)],
    stops: [0, 0.55, 1],
  );

  static const dangerGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF7F1D1D), Color(0xFFB91C1C)],
  );
}

class AdminTheme {
  AdminTheme._();

  static ThemeData build() {
    final light = ThemeData(useMaterial3: true, brightness: Brightness.light);
    return light.copyWith(
      scaffoldBackgroundColor: AdminColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AdminColors.navy,
        brightness: Brightness.light,
        surface: AdminColors.surface,
      ),
      textTheme: GoogleFonts.poppinsTextTheme(light.textTheme).apply(
        bodyColor: AdminColors.textDark,
        displayColor: AdminColors.textDark,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AdminColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: AdminColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}

/// Membungkus setiap layar admin dengan tema terang dan status bar transparan.
class AdminScope extends StatelessWidget {
  final Widget child;

  const AdminScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AdminTheme.build(),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: child,
      ),
    );
  }
}
