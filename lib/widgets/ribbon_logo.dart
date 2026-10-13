import 'package:flutter/material.dart';

class RibbonLogo extends StatelessWidget {
  final double size;

  const RibbonLogo({super.key, this.size = 80});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RibbonLogoPainter(),
      ),
    );
  }
}

class _RibbonLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Gradient background ribbon - folded 'B' / loop play shape
    final path1 = Path();
    path1.moveTo(w * 0.22, h * 0.25);
    path1.cubicTo(w * 0.42, h * 0.08, w * 0.58, h * 0.20, w * 0.52, h * 0.42);
    path1.cubicTo(w * 0.48, h * 0.58, w * 0.32, h * 0.65, w * 0.22, h * 0.50);
    path1.close();

    final paint1 = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFA855F7), Color(0xFF3B82F6)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(path1, paint1);

    // Front ribbon loop / play arrow
    final path2 = Path();
    path2.moveTo(w * 0.40, h * 0.35);
    path2.lineTo(w * 0.78, h * 0.50);
    path2.cubicTo(w * 0.88, h * 0.54, w * 0.84, h * 0.68, w * 0.72, h * 0.75);
    path2.cubicTo(w * 0.58, h * 0.84, w * 0.36, h * 0.82, w * 0.28, h * 0.68);
    path2.cubicTo(w * 0.24, h * 0.60, w * 0.25, h * 0.45, w * 0.38, h * 0.40);
    path2.close();

    final paint2 = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF06B6D4), Color(0xFF3B82F6), Color(0xFF8B5CF6)],
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(path2, paint2);

    // Inner highlight
    final path3 = Path();
    path3.moveTo(w * 0.38, h * 0.44);
    path3.lineTo(w * 0.64, h * 0.53);
    path3.cubicTo(w * 0.68, h * 0.55, w * 0.62, h * 0.65, w * 0.52, h * 0.68);
    path3.close();

    final paint3 = Paint()
      ..color = const Color(0x59FFFFFF)
      ..style = PaintingStyle.fill;

    canvas.drawPath(path3, paint3);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
