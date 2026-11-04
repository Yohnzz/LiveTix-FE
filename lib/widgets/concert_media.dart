import 'package:flutter/material.dart';
import '../models/concert_model.dart';

/// Latar belakang Banner Highlight Persegi Panjang (landscape) untuk:
/// 1. Carousel Highlight di Beranda
/// 2. Header paling atas di Halaman Detail Konser
///
/// Menampilkan foto penuh (full-bleed) unggahan Produser jika tersedia,
/// atau fallback gradien panggung + motif konsentris LiveTix.
class ConcertHighlightBannerSurface extends StatelessWidget {
  final ConcertModel? concert;
  final List<Color>? gradientOverride;
  final BorderRadius borderRadius;
  final Widget child;

  const ConcertHighlightBannerSurface({
    super.key,
    required this.concert,
    this.gradientOverride,
    this.borderRadius = BorderRadius.zero,
    required this.child,
  });

  bool get _hasCustomBanner =>
      (concert?.bannerImageBytes != null &&
          concert!.bannerImageBytes!.isNotEmpty) ||
      (concert?.bannerImageUrl != null &&
          concert!.bannerImageUrl!.trim().isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final colors = gradientOverride ??
        concert?.highlightGradientColors ??
        const [Color(0xFF271C80), Color(0xFF971C91)];

    return ClipRRect(
      borderRadius: borderRadius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Lapisan hit-test penuh agar seluruh area banner dapat diklik
          const ColoredBox(color: Colors.transparent),

          // Lapisan dasar gradien panggung (tampil penuh jika belum ada foto produser)
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
            ),
          ),

          if (_hasCustomBanner) ...[
            _buildBannerImage(),
            // Scrim gelap agar teks putih & badge di atas foto tetap terbaca (WCAG AA)
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x38000000),
                    Color(0x59000000),
                    Color(0xBD070B14),
                  ],
                  stops: [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ] else
            // Motif identitas piringan/vinyl konsentris saat belum ada foto produser
            Positioned(
              right: -28,
              top: 22,
              child: IgnorePointer(
                child: Container(
                  width: 156,
                  height: 156,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.10),
                      width: 16,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.14),
                          width: 8,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          child,
        ],
      ),
    );
  }

  Widget _buildBannerImage() {
    final bytes = concert?.bannerImageBytes;
    if (bytes != null && bytes.isNotEmpty) {
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    }

    final url = concert?.bannerImageUrl?.trim() ?? '';
    if (url.startsWith('assets/')) {
      return Image.asset(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }
}

/// Thumbnail Logo Konser Persegi (1:1) untuk kartu daftar konser
/// baik di Beranda (Konser Trending) maupun di Halaman Jelajah.
class ConcertSquareLogo extends StatelessWidget {
  final ConcertModel concert;
  final double size;
  final double borderRadius;
  final Widget fallbackChild;

  const ConcertSquareLogo({
    super.key,
    required this.concert,
    this.size = 54,
    this.borderRadius = 14,
    required this.fallbackChild,
  });

  bool get _hasCustomLogo =>
      (concert.logoImageBytes != null && concert.logoImageBytes!.isNotEmpty) ||
      (concert.logoImageUrl != null && concert.logoImageUrl!.trim().isNotEmpty);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: concert.iconBgColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: _hasCustomLogo ? _buildSquareImage() : Center(child: fallbackChild),
    );
  }

  Widget _buildSquareImage() {
    final bytes = concert.logoImageBytes;
    if (bytes != null && bytes.isNotEmpty) {
      return Image.memory(
        bytes,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Center(child: fallbackChild),
      );
    }

    final url = concert.logoImageUrl?.trim() ?? '';
    if (url.startsWith('assets/')) {
      return Image.asset(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Center(child: fallbackChild),
      );
    }

    return Image.network(
      url,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Center(child: fallbackChild),
    );
  }
}
