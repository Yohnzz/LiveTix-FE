import 'package:flutter/material.dart';

class InteractiveMapView extends StatefulWidget {
  final String venueName;
  final String fullAddress;
  final String searchQuery;
  final double latitude;
  final double longitude;
  final VoidCallback? onSearchTap;
  final void Function(double lat, double lng)? onCoordinatesChanged;

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
  });

  @override
  State<InteractiveMapView> createState() => _InteractiveMapViewState();
}

class _InteractiveMapViewState extends State<InteractiveMapView> {
  double _zoomLevel = 1.0;
  String _mapType = 'Default'; // 'Default' | 'Satelit' | 'Terrain'
  Offset _panOffset = Offset.zero;

  void _zoomIn() {
    setState(() {
      if (_zoomLevel < 2.0) _zoomLevel += 0.25;
    });
  }

  void _zoomOut() {
    setState(() {
      if (_zoomLevel > 0.75) _zoomLevel -= 0.25;
    });
  }

  void _resetMap() {
    setState(() {
      _zoomLevel = 1.0;
      _panOffset = Offset.zero;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isSatellite = _mapType == 'Satelit';
    final isTerrain = _mapType == 'Terrain';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Map Container
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 290,
            color: isSatellite
                ? const Color(0xFF1E293B)
                : (isTerrain
                    ? const Color(0xFFE2E8D8)
                    : const Color(0xFFE5E9F0)),
            child: Stack(
              children: [
                // Custom Map Canvas with Zoom & Pan
                Positioned.fill(
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        _panOffset += details.delta * 0.7;
                      });
                    },
                    child: Transform.translate(
                      offset: _panOffset,
                      child: Transform.scale(
                        scale: _zoomLevel,
                        child: CustomPaint(
                          painter: _GoogleMapCanvasPainter(
                            isSatellite: isSatellite,
                            isTerrain: isTerrain,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Map Type Switcher (Peta / Satelit / Terrain) in top right
                Positioned(
                  top: 14,
                  right: 14,
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

                // Center Pin with Google Maps Marker Style
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

                // Coordinates pill in top left
                Positioned(
                  top: 14,
                  left: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.my_location_rounded,
                          size: 11,
                          color: Color(0xFF4ADE80),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${widget.latitude.toStringAsFixed(4)}, ${widget.longitude.toStringAsFixed(4)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Google Watermark in bottom left
                Positioned(
                  left: 14,
                  bottom: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(4),
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
                            fontSize: 12.5,
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

                // Map controls overlay (zoom in, zoom out, recenter) bottom right
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
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
                            width: 28, height: 1, color: const Color(0xFFE5E7EB)),
                        InkWell(
                          onTap: _zoomOut,
                          child: const Padding(
                            padding: EdgeInsets.all(7),
                            child: Icon(Icons.remove,
                                size: 18, color: Color(0xFF374151)),
                          ),
                        ),
                        Container(
                            width: 28, height: 1, color: const Color(0xFFE5E7EB)),
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

        const SizedBox(height: 14),

        // Lokasi Terpilih Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE4E7EC)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Google Maps pin icon container
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFEA4335).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(
                    Icons.location_on_rounded,
                    color: Color(0xFFEA4335),
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 14),
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
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF101828),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8FDF0),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_rounded,
                                  size: 11, color: Color(0xFF039855)),
                              SizedBox(width: 3),
                              Text(
                                'Maps Verified',
                                style: TextStyle(
                                  fontSize: 10,
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
        ),
      ],
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
    // Google Maps base warm cream
    final bgPaint = Paint()..color = const Color(0xFFF4F3F0);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Parks (Google Maps Green #CBE6A3)
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
        Rect.fromLTWH(size.width * 0.62, size.height * 0.52, size.width * 0.34, 90),
        const Radius.circular(16),
      ),
      parkPaint,
    );

    // River / Water (Google Maps Blue #A5C9EB)
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

    // Yellow Highway (Google Maps Orange/Yellow)
    final highwayPaint = Paint()
      ..color = const Color(0xFFFFD166)
      ..strokeWidth = 9
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(0, size.height * 0.45),
      Offset(size.width, size.height * 0.45),
      highwayPaint,
    );

    // White Main Arteries
    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 7
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(0, size.height * 0.72), Offset(size.width, size.height * 0.72), roadPaint);
    canvas.drawLine(Offset(size.width * 0.30, 0), Offset(size.width * 0.30, size.height), roadPaint);
    canvas.drawLine(Offset(size.width * 0.74, 0), Offset(size.width * 0.74, size.height), roadPaint);

    // Minor Local Streets
    final subRoadPaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(0, size.height * 0.22), Offset(size.width, size.height * 0.22), subRoadPaint);
    canvas.drawLine(Offset(0, size.height * 0.88), Offset(size.width, size.height * 0.88), subRoadPaint);
    canvas.drawLine(Offset(size.width * 0.52, 0), Offset(size.width * 0.52, size.height), subRoadPaint);
  }

  void _paintSatellite(Canvas canvas, Size size) {
    // Dark satellite tones
    final bgPaint = Paint()..color = const Color(0xFF1E2838);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final fieldPaint = Paint()..color = const Color(0xFF2D3E35);
    canvas.drawRect(Rect.fromLTWH(20, 20, size.width * 0.35, 70), fieldPaint);
    canvas.drawRect(Rect.fromLTWH(size.width * 0.6, size.height * 0.5, size.width * 0.35, 80), fieldPaint);

    // Highway overlay in satellite
    final roadPaint = Paint()
      ..color = Colors.white38
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(0, size.height * 0.45), Offset(size.width, size.height * 0.45), roadPaint);
    canvas.drawLine(Offset(size.width * 0.35, 0), Offset(size.width * 0.35, size.height), roadPaint);
  }

  void _paintTerrain(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFFE4ECD8);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final contourPaint = Paint()
      ..color = const Color(0xFFD0DCBE)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (double y = 40; y < size.height; y += 45) {
      final path = Path()
        ..moveTo(0, y)
        ..quadraticBezierTo(size.width * 0.5, y + 25, size.width, y);
      canvas.drawPath(path, contourPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
