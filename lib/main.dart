import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/app_colors.dart';
import 'screens/splash_screen.dart';
import 'services/data_service.dart';
import 'services/supabase_service.dart';
import 'utils/local_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi penyimpanan lokal persisten
  await LocalStorage.init();

  // Muat file environment (.env)
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('File .env tidak ditemukan atau gagal dimuat: $e');
  }

  // Inisialisasi Supabase Backend
  await SupabaseService.init();

  // Pulihkan sesi aktif jika pengguna sebelumnya sudah login
  await DataService().restoreSupabaseSession();

  // Sembunyikan status bar atas jika didukung platform agar tampilan lebih bersih
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: [SystemUiOverlay.bottom],
  );

  runApp(const LiveTixApp());
}

class LiveTixApp extends StatelessWidget {
  const LiveTixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: DataService().isDarkModeNotifier,
      builder: (context, isDark, _) {
        final overlayStyle = SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor:
              isDark ? AppColors.darkSurface : Colors.white,
          systemNavigationBarIconBrightness:
              isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarDividerColor: Colors.transparent,
        );

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlayStyle,
          child: MaterialApp(
            title: 'LiveTix',
            debugShowCheckedModeBanner: false,
            themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
            theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.light,
              scaffoldBackgroundColor: Colors.white,
              cardColor: Colors.white,
              textTheme: GoogleFonts.poppinsTextTheme(),
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.primary,
                brightness: Brightness.light,
                surface: Colors.white,
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.textDark,
                elevation: 0,
                scrolledUnderElevation: 0,
                toolbarHeight: 64,
                systemOverlayStyle: SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: Brightness.dark,
                  statusBarBrightness: Brightness.light,
                ),
              ),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              scaffoldBackgroundColor: AppColors.darkBg,
              cardColor: AppColors.darkSurface,
              textTheme: GoogleFonts.poppinsTextTheme(
                ThemeData(brightness: Brightness.dark).textTheme,
              ),
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.primary,
                brightness: Brightness.dark,
                surface: AppColors.darkSurface,
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: AppColors.darkBg,
                foregroundColor: AppColors.darkText,
                elevation: 0,
                scrolledUnderElevation: 0,
                toolbarHeight: 64,
                systemOverlayStyle: SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: Brightness.light,
                  statusBarBrightness: Brightness.dark,
                ),
              ),
            ),
            home: const SplashScreen(),
          ),
        );
      },
    );
  }
}
