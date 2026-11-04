import 'package:flutter/material.dart';
import '../../../services/venue_location_search_service.dart';
import 'real_map_embed.dart';

class InteractiveMapView extends StatefulWidget {
  final String venueName;
  final String fullAddress;
  final String searchQuery;
  final double latitude;
  final double longitude;
  final VoidCallback? onSearchTap;
  final void Function(double lat, double lng)? onCoordinatesChanged;
  final void Function(String name, String address, double lat, double lng)?
      onLocationSelected;

  const InteractiveMapView({
    super.key,
    this.venueName = 'Stadion Gajayana',
    this.fullAddress =
        'Jl. Tangkuban Perahu, Kauman, Kec. Klojen, Kota Malang, Jawa Timur 65119',
    this.searchQuery = 'Stadion Gajayana Malang',
    this.latitude = -7.9786,
    this.longitude = 112.6225,
    this.onSearchTap,
    this.onCoordinatesChanged,
    this.onLocationSelected,
  });

  @override
  State<InteractiveMapView> createState() => _InteractiveMapViewState();
}

class _InteractiveMapViewState extends State<InteractiveMapView> {
  int _zoomLevel = 16;
  String _mapType = 'Default'; // 'Default' (m) | 'Satelit' (k) | 'Terrain' (p)
  bool _useLiveGoogleMaps = true;
  Offset _panOffset = Offset.zero;

  String get _googleMapTypeParam {
    switch (_mapType) {
      case 'Satelit':
        return 'k';
      case 'Terrain':
        return 'p';
      case 'Default':
      default:
        return 'm';
    }
  }

  void _zoomIn() {
    setState(() {
      if (_zoomLevel < 20) _zoomLevel += 1;
    });
  }

  void _zoomOut() {
    setState(() {
      if (_zoomLevel > 10) _zoomLevel -= 1;
    });
  }

  void _resetMap() {
    setState(() {
      _zoomLevel = 16;
      _panOffset = Offset.zero;
    });
  }

  void _openInGoogleMaps() {
    final url = VenueLocationSearchService.getGoogleMapsUrl(
      widget.venueName,
      widget.fullAddress,
    );
    openGoogleMapsUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final isSatellite = _mapType == 'Satelit';
    final isTerrain = _mapType == 'Terrain';

    // Unique viewId per lat/lng/zoom/type so Flutter Web iframe reloads cleanly
    final viewId =
        'gmap-${widget.latitude.toStringAsFixed(4)}-${widget.longitude.toStringAsFixed(4)}-$_googleMapTypeParam-$_zoomLevel';
    final embedUrl = VenueLocationSearchService.getGoogleMapsEmbedUrl(
      widget.latitude,
      widget.longitude,
      mapType: _googleMapTypeParam,
      zoom: _zoomLevel,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4E7EC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header Lokasi Venue Konser (Icon Stadium + Title + Subtitle)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.stadium_rounded,
                  color: Color(0xFF1B2A8C),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.venueName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF101828),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.fullAddress,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF667085),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 2. Interactive Map Container with Rounded Corners
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 295,
              decoration: BoxDecoration(
                color: isSatellite
                    ? const Color(0xFF1E293B)
                    : (isTerrain
                        ? const Color(0xFFE2E8D8)
                        : const Color(0xFFE5E9F0)),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFD0D5DD)),
              ),
              child: Stack(
                children: [
                  // Real Google Maps Embed / Interactive Tile Canvas
                  Positioned.fill(
                    child: _useLiveGoogleMaps
                        ? getRealMapEmbed(
                            viewId: viewId,
                            mapUrl: embedUrl,
                            width: double.infinity,
                            height: 295,
                          )
                        : GestureDetector(
                            onPanUpdate: (details) {
                              setState(() {
                                _panOffset += details.delta * 0.7;
                              });
                            },
                            child: Transform.translate(
                              offset: _panOffset,
                              child: CustomPaint(
                                painter: _GoogleMapCanvasPainter(
                                  isSatellite: isSatellite,
                                  isTerrain: isTerrain,
                                ),
                              ),
                            ),
                          ),
                  ),

                  // Overlay Center Pin (Visible in Pin mode or as top badge)
                  if (!_useLiveGoogleMaps)
                    Center(
                      child: Transform.translate(
                        offset: _panOffset * 0.1,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Tooltip Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1B2A8C), // Navy
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF1B2A8C)
                                        .withValues(alpha: 0.4),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.place_rounded,
                                    size: 14,
                                    color: Color(0xFFFF4D4F),
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      widget.venueName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.2,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),

                            // Google Pin Needle
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFFEA4335)
                                        .withValues(alpha: 0.2),
                                  ),
                                ),
                                const Icon(
                                  Icons.location_on,
                                  size: 34,
                                  color: Color(0xFFEA4335), // Google Maps Red
                                ),
                                Positioned(
                                  top: 8,
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            // Shadow under pin
                            Container(
                              width: 14,
                              height: 5,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Coordinates Pill Badge (Top-Left)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.my_location_rounded,
                            size: 12,
                            color: Color(0xFF4ADE80),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${widget.latitude.toStringAsFixed(4)}, ${widget.longitude.toStringAsFixed(4)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Map Layer Switcher: Peta / Satelit / Terrain (Top-Right)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(3),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildTypeChip('Peta', 'Default'),
                          _buildTypeChip('Satelit', 'Satelit'),
                          _buildTypeChip('Terrain', 'Terrain'),
                        ],
                      ),
                    ),
                  ),

                  // Google Maps Watermark Badge (Bottom-Left)
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Google',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              color: Color(0xFF4285F4),
                            ),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Maps',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF5F6368),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Zoom Controls & Center Target Button (Bottom-Right)
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: _zoomIn,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(10)),
                            child: const Padding(
                              padding: EdgeInsets.all(7),
                              child: Icon(Icons.add,
                                  size: 18, color: Color(0xFF374151)),
                            ),
                          ),
                          Container(
                              width: 28,
                              height: 1,
                              color: const Color(0xFFE5E7EB)),
                          InkWell(
                            onTap: _zoomOut,
                            child: const Padding(
                              padding: EdgeInsets.all(7),
                              child: Icon(Icons.remove,
                                  size: 18, color: Color(0xFF374151)),
                            ),
                          ),
                          Container(
                              width: 28,
                              height: 1,
                              color: const Color(0xFFE5E7EB)),
                          InkWell(
                            onTap: _resetMap,
                            borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(10)),
                            child: const Padding(
                              padding: EdgeInsets.all(7),
                              child: Icon(Icons.center_focus_strong_rounded,
                                  size: 17, color: Color(0xFF1B2A8C)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Small Toggle Strip between Live Google Maps & Native Pin
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      size: 13,
                      color: Color(0xFF4285F4),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _useLiveGoogleMaps
                          ? 'Google Maps Embed Langsung'
                          : 'Mode Pin & Drag Koordinat',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4B5563),
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _useLiveGoogleMaps = !_useLiveGoogleMaps;
                    });
                  },
                  child: Text(
                    _useLiveGoogleMaps
                        ? 'Ganti ke Mode Pin'
                        : 'Ganti ke Embed Live',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1B2A8C),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // 3. Card Lokasi Terpilih (Verified Badge + Full Address + Direct Link)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE4E7EC)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pink / Coral container with red pin icon
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE4E2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.location_on_rounded,
                          color: Color(0xFFEA4335),
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.venueName,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF101828),
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF3),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle_rounded,
                                        size: 11, color: Color(0xFF039855)),
                                    SizedBox(width: 4),
                                    Text(
                                      'Maps Verified',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF039855),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.fullAddress,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF667085),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                // Quick Actions: Open in Google Maps and Change Venue
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: _openInGoogleMaps,
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.open_in_new_rounded,
                                size: 14, color: Color(0xFF1B2A8C)),
                            SizedBox(width: 5),
                            Text(
                              'Buka di Google Maps',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1B2A8C),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (widget.onSearchTap != null)
                      InkWell(
                        onTap: widget.onSearchTap,
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search_rounded,
                                  size: 14, color: Color(0xFF4285F4)),
                              SizedBox(width: 5),
                              Text(
                                'Cari Lokasi Lain',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF4285F4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip(String label, String value) {
    final isSelected = _mapType == value;
    return GestureDetector(
      onTap: () => setState(() => _mapType = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1B2A8C) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF4B5563),
          ),
        ),
      ),
    );
  }
}

class _GoogleMapCanvasPainter extends CustomPainter {
  final bool isSatellite;
  final bool isTerrain;

  _GoogleMapCanvasPainter({
    required this.isSatellite,
    required this.isTerrain,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (isSatellite) {
      _paintSatellite(canvas, size);
    } else if (isTerrain) {
      _paintTerrain(canvas, size);
    } else {
      _paintStandardGoogleMap(canvas, size);
    }
  }

  void _paintStandardGoogleMap(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFFF4F3F0);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final parkPaint = Paint()..color = const Color(0xFFCCEADA);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.04, 25, size.width * 0.38, 85),
        const Radius.circular(14),
      ),
      parkPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
            size.width * 0.62, size.height * 0.52, size.width * 0.34, 90),
        const Radius.circular(16),
      ),
      parkPaint,
    );

    final waterPaint = Paint()
      ..color = const Color(0xFFAADAFF)
      ..strokeWidth = 16
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final riverPath = Path()
      ..moveTo(-10, size.height * 0.82)
      ..quadraticBezierTo(
        size.width * 0.42,
        size.height * 0.88,
        size.width * 0.88,
        size.height * 0.42,
      )
      ..lineTo(size.width + 10, size.height * 0.36);
    canvas.drawPath(riverPath, waterPaint);

    final highwayPaint = Paint()
      ..color = const Color(0xFFFFD166)
      ..strokeWidth = 9
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(0, size.height * 0.45),
      Offset(size.width, size.height * 0.45),
      highwayPaint,
    );

    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(size.width * 0.35, 0),
      Offset(size.width * 0.35, size.height),
      roadPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.72, 0),
      Offset(size.width * 0.72, size.height),
      roadPaint,
    );
  }

  void _paintSatellite(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFF1E293B);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final fieldPaint = Paint()..color = const Color(0xFF14532D);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.1, 30, size.width * 0.35, 75),
        const Radius.circular(8),
      ),
      fieldPaint,
    );

    final roadPaint = Paint()
      ..color = const Color(0xFF475569)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(0, size.height * 0.5),
      Offset(size.width, size.height * 0.5),
      roadPaint,
    );
  }

  void _paintTerrain(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFFE8ECD7);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final hillPaint = Paint()
      ..color = const Color(0xFFD1DCBA)
      ..style = PaintingStyle.fill;
    final hillPath = Path()
      ..moveTo(0, size.height * 0.7)
      ..quadraticBezierTo(
        size.width * 0.3,
        size.height * 0.4,
        size.width * 0.6,
        size.height * 0.65,
      )
      ..quadraticBezierTo(
        size.width * 0.85,
        size.height * 0.9,
        size.width,
        size.height * 0.75,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(hillPath, hillPaint);
  }

  @override
  bool shouldRepaint(covariant _GoogleMapCanvasPainter oldDelegate) {
    return oldDelegate.isSatellite != isSatellite ||
        oldDelegate.isTerrain != isTerrain;
  }
}
