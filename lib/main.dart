import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/app_colors.dart';
import 'screens/splash_screen.dart';

void main() => runApp(const LiveTixApp());

class LiveTixApp extends StatelessWidget {
  const LiveTixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LiveTix',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        textTheme: GoogleFonts.poppinsTextTheme(),
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
      ),
      home: const SplashScreen(),
    );
  }
}
