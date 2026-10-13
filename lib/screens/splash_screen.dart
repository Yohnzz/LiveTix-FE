import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../widgets/logo_mark.dart';
import '../screens/home/home_screen.dart';

/// Splash 1: logo saja + versi. Splash 2: logo + teks "LiveTix". Lalu ke Home Guest.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _showName = false;

  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _showName = true);
    });
    Timer(const Duration(milliseconds: 3000), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen(isGuest: true)),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.splashBg,
      body: Stack(
        children: [
          Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: _showName
                  ? Row(
                      key: const ValueKey('name'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const LogoMark(size: 64),
                        const SizedBox(width: 8),
                        Text('LiveTix',
                            style: GoogleFonts.playfairDisplay(
                                fontSize: 36, color: Colors.white, fontWeight: FontWeight.w500)),
                      ],
                    )
                  : const LogoMark(key: ValueKey('logo'), size: 110),
            ),
          ),
          const Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Text('Version 1.0',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
