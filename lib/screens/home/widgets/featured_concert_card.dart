import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/app_colors.dart';
import '../../../models/concert_model.dart';
import '../../../services/data_service.dart';
import '../../../widgets/concert_media.dart';

class FeaturedConcertCarousel extends StatefulWidget {
  final List<ConcertModel> concerts;
  final ValueChanged<ConcertModel> onConcertTap;

  const FeaturedConcertCarousel({
    super.key,
    required this.concerts,
    required this.onConcertTap,
  });

  @override
  State<FeaturedConcertCarousel> createState() => _FeaturedConcertCarouselState();
}

class _FeaturedConcertCarouselState extends State<FeaturedConcertCarousel> {
  static const List<List<Color>> _stageGradients = [
    [Color(0xFF271C80), Color(0xFF971C91)],
    [Color(0xFF0F3D5E), Color(0xFF1B2A8C)],
    [Color(0xFF4A154B), Color(0xFF971C91)],
    [Color(0xFF1E1B4B), Color(0xFF6B1D5C)],
    [Color(0xFF1B2A8C), Color(0xFF6B1D5C)],
  ];

  static const List<String> _ribbonLabels = [
    'Pilihan',
    'Tur Spesial',
    'Reuni',
    'Populer',
    'Konser Tunggal',
  ];

  late final PageController _pageController;
  Timer? _autoSlideTimer;
  int _currentIndex = 0;
  bool _isUserDragging = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.91);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _autoSlideTimer?.cancel();
    } else {
      _startOrResetAutoSlide();
    }
  }

  @override
  void didUpdateWidget(covariant FeaturedConcertCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.concerts.length != widget.concerts.length) {
      if (_currentIndex >= widget.concerts.length) {
        _currentIndex = 0;
      }
      _startOrResetAutoSlide();
    }
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startOrResetAutoSlide() {
    _autoSlideTimer?.cancel();
    if (widget.concerts.length <= 1) return;
    final reduceMotion =
        mounted ? (MediaQuery.maybeDisableAnimationsOf(context) ?? false) : false;
    if (reduceMotion) return;

    _autoSlideTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || _isUserDragging || !_pageController.hasClients) {
        return;
      }
      final nextPage = (_currentIndex + 1) % widget.concerts.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 480),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _jumpToSlide(int index) {
    if (!_pageController.hasClients) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
    _startOrResetAutoSlide();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.concerts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          height: 196,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollStartNotification &&
                  notification.dragDetails != null) {
                _isUserDragging = true;
                _autoSlideTimer?.cancel();
              } else if (notification is ScrollEndNotification) {
                if (_isUserDragging) {
                  _isUserDragging = false;
                  _startOrResetAutoSlide();
                }
              }
              return false;
            },
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: const {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.trackpad,
                },
              ),
              child: ValueListenableBuilder<Set<String>>(
                valueListenable: DataService().favoriteConcertIdsNotifier,
                builder: (context, favoriteIds, _) {
                  return PageView.builder(
                    controller: _pageController,
                    padEnds: false,
                    physics: const PageScrollPhysics(),
                    itemCount: widget.concerts.length,
                    onPageChanged: (index) {
                      setState(() => _currentIndex = index);
                    },
                    itemBuilder: (context, index) {
                      final concert = widget.concerts[index];
                      final gradientColors = concert.highlightGradientColors.isNotEmpty
                          ? concert.highlightGradientColors
                          : _stageGradients[index % _stageGradients.length];
                      final ribbonText = _ribbonLabels[index % _ribbonLabels.length];
                      final isLast = index == widget.concerts.length - 1;
                      final isFav = favoriteIds.contains(concert.id);

                      return Padding(
                        padding: EdgeInsets.only(right: isLast ? 0 : 12),
                        child: FeaturedConcertCard(
                          concert: concert,
                          gradientColors: gradientColors,
                          ribbonLabel: ribbonText,
                          isFavorite: isFav,
                          onFavoriteToggle: () =>
                              DataService().toggleFavorite(concert.id),
                          onTap: () => widget.onConcertTap(concert),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
        if (widget.concerts.length > 1) ...[
          // Indikator titik posisi slide berjajar horizontal (inline) tepat di tengah tanpa penomoran & tombol jeda
          Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.concerts.length, (index) {
                  return Padding(
                    padding: EdgeInsets.only(
                      right: index == widget.concerts.length - 1 ? 0 : 2,
                    ),
                    child: _CarouselDotIndicator(
                      index: index,
                      isActive: index == _currentIndex,
                      onTap: () => _jumpToSlide(index),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _CarouselDotIndicator extends StatefulWidget {
  final int index;
  final bool isActive;
  final VoidCallback onTap;

  const _CarouselDotIndicator({
    required this.index,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_CarouselDotIndicator> createState() => _CarouselDotIndicatorState();
}

class _CarouselDotIndicatorState extends State<_CarouselDotIndicator> {
  bool _isHovered = false;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final dotColor = widget.isActive
        ? (isDark ? AppColors.primaryDark : AppColors.primary)
        : (_isHovered
            ? (isDark ? const Color(0xFF64748B) : const Color(0xFF98A2B3))
            : (isDark ? const Color(0xFF334155) : const Color(0xFFD0D5DD)));

    return Semantics(
      button: true,
      selected: widget.isActive,
      excludeSemantics: true,
      label: 'Slide highlight ${widget.index + 1}',
      child: InkWell(
        onTap: widget.onTap,
        onHover: (hovered) => setState(() => _isHovered = hovered),
        onFocusChange: (focused) => setState(() => _isFocused = focused),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: widget.isActive ? 32 : 16,
          height: 44,
          child: Center(
            widthFactor: 1.0,
            heightFactor: 1.0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: widget.isActive ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                borderRadius: BorderRadius.circular(8),
                border: _isFocused
                    ? Border.all(color: AppColors.primary, width: 1.5)
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FeaturedConcertCard extends StatelessWidget {
  final ConcertModel? concert;
  final List<Color>? gradientColors;
  final String ribbonLabel;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onTap;

  const FeaturedConcertCard({
    super.key,
    this.concert,
    this.gradientColors,
    this.ribbonLabel = 'Pilihan',
    this.isFavorite = false,
    this.onFavoriteToggle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = concert?.title ?? 'Soundwave Fest 2026';
    final dateVenue = concert != null
        ? '${concert!.shortDate} · ${concert!.venue}'
        : '12 Okt 2026 · Stadion Gajayana, Malang';
    final categoryPrice = concert != null
        ? '${concert!.category} · Mulai ${concert!.formattedPrice}'
        : 'Pop · Mulai Rp220.000';

    return Semantics(
      button: true,
      label: 'Highlight konser $title, $dateVenue',
      child: Container(
        width: double.infinity,
        height: 196,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F1B2A8C),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: ConcertHighlightBannerSurface(
              concert: concert,
              gradientOverride: gradientColors,
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  // Pita kuning di kiri atas
                  Positioned(
                    top: 16,
                    left: 16,
                    child: ClipPath(
                      clipper: _RibbonClipper(),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(10, 6, 18, 6),
                        color: AppColors.bannerYellow,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: Color(0xFF451A03),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              ribbonLabel,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF451A03),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Tombol favorit interaktif di kanan atas (44x44 tap target)
                  if (onFavoriteToggle != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        tooltip:
                            isFavorite ? 'Hapus dari favorit' : 'Simpan ke favorit',
                        onPressed: onFavoriteToggle,
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                        icon: Icon(
                          isFavorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color:
                              isFavorite ? AppColors.favoritePink : Colors.white,
                          size: 22,
                        ),
                      ),
                    ),

                  // Informasi utama konser di bagian bawah kartu
                  Positioned(
                    left: 16,
                    bottom: 18,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.34),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            categoryPrice,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          dateVenue,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w400,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
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
