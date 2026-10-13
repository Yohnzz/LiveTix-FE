import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// Kartu header ungu bergradasi dengan ikon di tengah.
class AuthHeader extends StatelessWidget {
  final Widget child;
  final double height;
  const AuthHeader({super.key, required this.child, this.height = 190});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned(top: 18, left: 16, child: Icon(Icons.star_border, color: Colors.amber, size: 14)),
          const Positioned(bottom: 24, right: 20, child: Icon(Icons.star_border, color: Colors.amber, size: 14)),
          const Positioned(top: 30, right: 40, child: Icon(Icons.star_border, color: Colors.white54, size: 12)),
          child,
        ],
      ),
    );
  }
}
