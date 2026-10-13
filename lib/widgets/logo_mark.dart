import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// Placeholder logo. Ganti dengan Image.asset('assets/images/logo.png') jika sudah ada aset.
class LogoMark extends StatelessWidget {
  final double size;
  const LogoMark({super.key, this.size = 100});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (r) => AppColors.logoGradient.createShader(r),
      child: Icon(Icons.play_circle_fill_rounded, size: size, color: Colors.white),
    );
  }
}
