import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// Kartu header ungu bergradasi dengan bintang dan konfeti seperti di Figma.
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
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Bintang dan dekorasi sudut
          const Positioned(top: 20, left: 24, child: Icon(Icons.star_border, color: Colors.amber, size: 18)),
          const Positioned(top: 45, left: 60, child: _Dot(size: 5, color: Colors.white70)),
          const Positioned(top: 18, right: 36, child: Icon(Icons.star_border, color: Colors.white60, size: 14)),
          const Positioned(top: 70, right: 28, child: _Dot(size: 6, color: Colors.amber)),
          const Positioned(bottom: 24, left: 36, child: _Dot(size: 4, color: Colors.purpleAccent)),
          const Positioned(bottom: 30, right: 40, child: Icon(Icons.star_border, color: Colors.white70, size: 16)),
          const Positioned(bottom: 18, right: 75, child: _Triangle(color: Colors.amber, size: 7)),
          child,
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final double size;
  final Color color;
  const _Dot({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _Triangle extends StatelessWidget {
  final double size;
  final Color color;
  const _Triangle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _TrianglePainter(color),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
