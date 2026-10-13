import 'package:flutter/material.dart';
import '../../../core/app_colors.dart';

class FeaturedConcertCard extends StatelessWidget {
  final VoidCallback? onTap;

  const FeaturedConcertCard({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Kartu Utama Bergradasi
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            height: 190,
            decoration: BoxDecoration(
              gradient: AppColors.headerGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1F1B2A8C),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Pita Kuning "★ Pilihan" di kiri atas
                Positioned(
                  top: 18,
                  left: 16,
                  child: ClipPath(
                    clipper: _RibbonClipper(),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(10, 6, 18, 6),
                      color: AppColors.bannerYellow,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, size: 14, color: Color(0xFF78350F)),
                          SizedBox(width: 4),
                          Text(
                            'Pilihan',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF78350F),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Ikon Bintang & Heart di kanan atas
                Positioned(
                  top: 18,
                  right: 16,
                  child: Row(
                    children: [
                      const Icon(Icons.star_border, color: Colors.white70, size: 20),
                      const SizedBox(width: 8),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.favorite_border, color: Colors.white, size: 20),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),

                // Dekorasi partikel (bintang, titik, segitiga)
                const Positioned(top: 60, left: 28, child: Icon(Icons.star_border, color: Colors.amber, size: 16)),
                const Positioned(top: 50, left: 110, child: _Dot(size: 6, color: Colors.purpleAccent)),
                const Positioned(top: 65, left: 88, child: _Dot(size: 5, color: Colors.amber)),
                const Positioned(top: 62, right: 90, child: Icon(Icons.star_border, color: Colors.amber, size: 16)),
                const Positioned(top: 58, right: 36, child: _Dot(size: 5, color: Colors.amber)),
                const Positioned(top: 88, right: 38, child: _Dot(size: 5, color: Colors.white)),
                const Positioned(top: 96, right: 8, child: _Triangle(size: 6, color: Colors.white70)),
                const Positioned(top: 110, right: 10, child: _Triangle(size: 6, color: Colors.white70)),
                const Positioned(top: 120, right: 48, child: _Triangle(size: 6, color: Colors.purpleAccent)),
                const Positioned(bottom: 22, left: 32, child: _Dot(size: 4, color: Colors.purpleAccent)),
                const Positioned(bottom: 30, left: 44, child: _Dot(size: 6, color: Colors.amber)),
                const Positioned(bottom: 40, left: 66, child: _Triangle(size: 6, color: Colors.amber)),
                const Positioned(bottom: 24, left: 108, child: _Triangle(size: 6, color: Colors.purpleAccent)),
                const Positioned(bottom: 35, right: 120, child: _Dot(size: 5, color: Colors.amber)),
                const Positioned(bottom: 26, right: 108, child: _Dot(size: 4, color: Colors.amber)),
                const Positioned(bottom: 30, right: 44, child: _Dot(size: 4, color: Colors.white)),
                const Positioned(bottom: 20, right: 52, child: Icon(Icons.star_border, color: Colors.purpleAccent, size: 14)),

                // Teks Utama Konser di bagian bawah
                const Positioned(
                  left: 16,
                  bottom: 20,
                  right: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '• Soundwave Fest 2026',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '12 Okt · Stadion Gajayana',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w400,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Indikator Pemesan di bawah kartu
        const Row(
          children: [
            SizedBox(
              width: 48,
              height: 20,
              child: Stack(
                children: [
                  _AvatarCircle(left: 0, color: Color(0xFFFCE7F3)),
                  _AvatarCircle(left: 12, color: Color(0xFFE0F2FE)),
                  _AvatarCircle(left: 24, color: Color(0xFFFEF3C7)),
                ],
              ),
            ),
            SizedBox(width: 8),
            Text(
              '128 orang sudah pesan tiket ini',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textGrey,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  final double left;
  final Color color;

  const _AvatarCircle({required this.left, required this.color});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
      ),
    );
  }
}

class _RibbonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()
      ..lineTo(size.width - 10, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(size.width - 10, size.height)
      ..lineTo(0, size.height)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
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
      painter: _TriangleCustomPainter(color),
    );
  }
}

class _TriangleCustomPainter extends CustomPainter {
  final Color color;
  _TriangleCustomPainter(this.color);

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
