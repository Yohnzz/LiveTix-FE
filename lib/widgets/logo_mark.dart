import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// Logo LiveTix menggunakan aset assets/images/livetix-logo.png
class LogoMark extends StatelessWidget {
  final double size;
  const LogoMark({super.key, this.size = 100});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/livetix-logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => ShaderMask(
        shaderCallback: (r) => AppColors.logoGradient.createShader(r),
        child: Icon(Icons.play_circle_fill_rounded, size: size, color: Colors.white),
      ),
    );
  }
}
