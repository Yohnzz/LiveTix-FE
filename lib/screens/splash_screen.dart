import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../widgets/logo_mark.dart';
import '../screens/home/home_screen.dart';
import '../screens/admin/admin_shell.dart';
import '../screens/promoter/promoter_pin_lock_screen.dart';
import '../screens/gate_crew/gate_crew_main_screen.dart';
import '../services/data_service.dart';

/// Layar pembuka (Splash Screen) LiveTix dengan desain modern, visual logo & tipografi menawan,
/// serta transisi halus ke dasbor role (Admin, Produser, User) atau mode Tamu (Guest).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutBack),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();
    _startSessionCheckAndNavigate();
  }

  Future<void> _startSessionCheckAndNavigate() async {
    // Jalankan pemulihan sesi di latar belakang sambil menikmati animasi splash
    final sessionFuture = DataService().restoreSupabaseSession();
    final delayFuture = Future.delayed(const Duration(milliseconds: 2200));

    await Future.wait([sessionFuture, delayFuture]);
    if (!mounted) return;

    final user = DataService().currentUserNotifier.value;
    Widget targetScreen;
    RouteSettings? settings;

    if (user != null) {
      final role = user.role.trim().toLowerCase();
      if (role == 'admin') {
        targetScreen = const AdminShell();
        settings = const RouteSettings(name: AdminShell.routeName);
      } else if (role == 'produser' || role == 'producer' || role == 'promoter') {
        targetScreen = resolveProducerEntryScreen(
          name: user.name,
          phone: user.phone,
        );
      } else if (role == 'gatecrew' || role == 'crew') {
        targetScreen = const GateCrewMainScreen();
        settings = const RouteSettings(name: GateCrewMainScreen.routeName);
      } else {
        targetScreen = HomeScreen(
          isGuest: false,
          userName: user.name,
          userInitials: user.initials,
        );
      }
    } else {
      targetScreen = const HomeScreen(isGuest: true);
    }

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        settings: settings,
        pageBuilder: (_, animation, __) => targetScreen,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 450),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.splashBg,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Latar belakang atmosfer panggung konser (ambient lighting halus)
          Positioned(
            top: size.height * 0.35 - 150,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF6366F1).withValues(alpha: 0.18),
                    const Color(0xFFC026D3).withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Konten Utama: Logo + Teks LiveTix
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo Mark dengan soft ambient glow
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF9333EA).withValues(alpha: 0.28),
                              blurRadius: 36,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const LogoMark(size: 96),
                      ),
                      const SizedBox(height: 20),

                      // Tipografi Nama Brand LiveTix
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [
                            Colors.white,
                            Color(0xFFE0E7FF),
                            Color(0xFFF3E8FF),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds),
                        child: Text(
                          'LiveTix',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
