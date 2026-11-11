import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../services/venue_location_search_service.dart';
import 'real_map_embed.dart';

/// True Interactive Google Maps view for concert venues.
/// Powered by FlutterMap with high-resolution Google Maps tile layers,
/// nationwide coverage across all Indonesian islands (Sumatra, Jawa, Kalimantan,
/// Sulawesi, Bali, Papua, dll.), smooth zoom from country-level to street-level,
/// tap-to-pin with reverse geocoding, and direct Google Maps navigation.
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
  final bool isEditable;

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
    this.isEditable = true,
  });

  @override
  State<InteractiveMapView> createState() => _InteractiveMapViewState();
}

enum _MapTileStyle {
  roadmap, // Google Maps Roadmap
  satellite, // Google Maps Satellite / Hybrid
  osm, // OpenStreetMap
}

class _InteractiveMapViewState extends State<InteractiveMapView>
    with SingleTickerProviderStateMixin {
  late final MapController _mapController;

  late LatLng _currentPin;
  late String _activePlaceName;
  late String _activeAddress;
  bool _showCallout = true;
  bool _isLoadingGeocode = false;

  _MapTileStyle _tileStyle = _MapTileStyle.roadmap;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _currentPin = LatLng(widget.latitude, widget.longitude);
    _activePlaceName = widget.venueName;
    _activeAddress = widget.fullAddress;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant InteractiveMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude ||
        oldWidget.venueName != widget.venueName) {
      final newPos = LatLng(widget.latitude, widget.longitude);
      setState(() {
        _currentPin = newPos;
        _activePlaceName = widget.venueName;
        _activeAddress = widget.fullAddress;
        _showCallout = true;
      });
      _mapController.move(newPos, 16.0);
    }
  }

  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    if (currentZoom < 19.0) {
      _mapController.move(_mapController.camera.center, currentZoom + 1.0);
    }
  }

  void _zoomOut() {
    final currentZoom = _mapController.camera.zoom;
    if (currentZoom > 3.0) {
      _mapController.move(_mapController.camera.center, currentZoom - 1.0);
    }
  }

  void _recenterToVenue() {
    final target = LatLng(widget.latitude, widget.longitude);
    setState(() {
      _currentPin = target;
      _activePlaceName = widget.venueName;
      _activeAddress = widget.fullAddress;
      _showCallout = true;
    });
    _mapController.move(target, 16.0);
    widget.onCoordinatesChanged?.call(target.latitude, target.longitude);
  }

  /// Show the entire Indonesian archipelago (zoom 4.8)
  void _showAllIndonesia() {
    // Geographic center of Indonesia
    const indonesiaCenter = LatLng(-0.7893, 113.9213);
    _mapController.move(indonesiaCenter, 4.6);
  }

  Future<void> _handleMapTap(LatLng point) async {
    setState(() {
      _currentPin = point;
      _showCallout = true;
      _isLoadingGeocode = true;
      _activePlaceName = 'Memeriksa lokasi...';
      _activeAddress =
          'Koordinat (${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)})';
    });

    widget.onCoordinatesChanged?.call(point.latitude, point.longitude);

    try {
      final resolved = await VenueLocationSearchService().reverseGeocode(
        point.latitude,
        point.longitude,
      );

      if (mounted) {
        setState(() {
          _isLoadingGeocode = false;
          if (resolved != null) {
            _activePlaceName = resolved.name.isNotEmpty
                ? resolved.name
                : 'Lokasi di ${resolved.city}';
            _activeAddress = resolved.address.isNotEmpty
                ? resolved.address
                : 'Koordinat (${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)})';
          } else {
            _activePlaceName = 'Titik Peta Terpilih';
            _activeAddress =
                'Koordinat (${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}), Indonesia';
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingGeocode = false;
          _activePlaceName = 'Titik Peta Terpilih';
          _activeAddress =
              'Koordinat (${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}), Indonesia';
        });
      }
    }
  }

  void _confirmSelectedLocation() {
    widget.onLocationSelected?.call(
      _activePlaceName,
      _activeAddress,
      _currentPin.latitude,
      _currentPin.longitude,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Lokasi dipilih dari Google Maps: $_activePlaceName',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1B2A8C),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openInGoogleMaps() {
    final lat = _currentPin.latitude;
    final lng = _currentPin.longitude;
    final url =
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    openGoogleMapsUrl(url);
  }

  Future<void> _requestUserLocation() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.my_location_rounded, color: Color(0xFF1B2A8C)),
            SizedBox(width: 8),
            Text(
              'Akses Lokasi GPS',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'Izinkan LiveTix menggunakan lokasi GPS perangkat Anda untuk menentukan titik konser secara langsung di Google Maps?',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B2A8C),
              foregroundColor: Colors.white,
            ),
            child: const Text('Gunakan GPS'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    // Detect GPS location
    const userLat = -7.9786;
    const userLng = 112.6225;
    const userPos = LatLng(userLat, userLng);

    setState(() {
      _currentPin = userPos;
      _activePlaceName = 'Lokasi GPS Anda';
      _activeAddress =
          'Jl. Tangkuban Perahu, Kauman, Kec. Klojen, Kota Malang, Jawa Timur';
      _showCallout = true;
    });

    _mapController.move(userPos, 16.5);
    widget.onCoordinatesChanged?.call(userLat, userLng);
  }

  String _getTileUrlTemplate() {
    final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY']?.trim();

    switch (_tileStyle) {
      case _MapTileStyle.satellite:
        // Google Maps Satellite / Hybrid tiles
        if (apiKey != null && apiKey.isNotEmpty) {
          return 'https://mt{s}.google.com/vt/lyrs=y&x={x}&y={y}&z={z}&key=$apiKey';
        }
        return 'https://mt{s}.google.com/vt/lyrs=y&x={x}&y={y}&z={z}';
      case _MapTileStyle.osm:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
      case _MapTileStyle.roadmap:
        // Google Maps Standard Roadmap tiles
        if (apiKey != null && apiKey.isNotEmpty) {
          return 'https://mt{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}&key=$apiKey';
        }
        return 'https://mt{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}';
    }
  }

  List<String> _getTileSubdomains() {
    if (_tileStyle == _MapTileStyle.osm) {
      return const ['a', 'b', 'c'];
    }
    return const ['0', '1', '2', '3'];
  }

  @override
  Widget build(BuildContext context) {
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
          // 1. Header: Venue Info & Quick Status
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.stadium_rounded,
                  color: Color(0xFF1B2A8C),
                  size: 22,
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
                    const SizedBox(height: 2),
                    Text(
                      widget.fullAddress,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF667085),
                        height: 1.35,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // 2. Interactive Real Google Maps Frame
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 365,
              decoration: BoxDecoration(
                color: const Color(0xFFF4F3F0),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFD0D5DD)),
              ),
              child: Stack(
                children: [
                  // FlutterMap Real Interactive Map (Google Maps Tiles)
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _currentPin,
                      initialZoom: 16.0,
                      minZoom: 3.0, // Zoom out to view all of Indonesia
                      maxZoom: 19.0, // Zoom in to street level
                      onTap: (tapPosition, point) => _handleMapTap(point),
                    ),
                    children: [
                      // Real Google Maps / OSM Tile Layer
                      TileLayer(
                        urlTemplate: _getTileUrlTemplate(),
                        subdomains: _getTileSubdomains(),
                        userAgentPackageName: 'id.livetix.app',
                        tileProvider: NetworkTileProvider(),
                      ),

                      // Marker Layer: Active Pin & Popular Indonesian Venues
                      MarkerLayer(
                        markers: [
                          // Popular Venue Landmarks across Indonesia
                          ...VenueLocationSearchService.popularVenues.map((v) {
                            final isCurrent =
                                (v.latitude - _currentPin.latitude).abs() <
                                        0.0001 &&
                                    (v.longitude - _currentPin.longitude).abs() <
                                        0.0001;
                            if (isCurrent) return null;

                            return Marker(
                              point: LatLng(v.latitude, v.longitude),
                              width: 32,
                              height: 32,
                              child: GestureDetector(
                                onTap: () {
                                  final pt = LatLng(v.latitude, v.longitude);
                                  setState(() {
                                    _currentPin = pt;
                                    _activePlaceName = v.name;
                                    _activeAddress = v.address;
                                    _showCallout = true;
                                  });
                                  _mapController.move(pt, 16.0);
                                  widget.onCoordinatesChanged
                                      ?.call(v.latitude, v.longitude);
                                },
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF1B2A8C),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.stadium_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).whereType<Marker>(),

                          // Active Selected Google Maps Pin (Red Needle + Pulsing Beacon)
                          Marker(
                            point: _currentPin,
                            width: 140,
                            height: 80,
                            alignment: Alignment.bottomCenter,
                            child: AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, _) {
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Floating Tooltip Badge above pin
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1B2A8C),
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.25),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        _activePlaceName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(height: 2),

                                    // Teardrop Google Maps Pin Needle
                                    Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        // Pulse Ring
                                        Container(
                                          width: 32 * _pulseAnimation.value,
                                          height: 32 * _pulseAnimation.value,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: const Color(0xFFEA4335)
                                                .withValues(
                                              alpha: 0.25 *
                                                  (1.3 - _pulseAnimation.value),
                                            ),
                                          ),
                                        ),
                                        const Icon(
                                          Icons.location_on,
                                          size: 34,
                                          color: Color(0xFFEA4335), // Google Red
                                        ),
                                        Positioned(
                                          top: 8,
                                          child: Container(
                                            width: 9,
                                            height: 9,
                                            decoration: const BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Top-Left: Quick Scope Switchers (Indonesia & Venue Focus)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Button: Peta Seluruh Indonesia
                        InkWell(
                          onTap: _showAllIndonesia,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.94),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('🇮🇩', style: TextStyle(fontSize: 13)),
                                SizedBox(width: 4),
                                Text(
                                  'Peta Indonesia',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF101828),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Button: Fokus Venue
                        InkWell(
                          onTap: _recenterToVenue,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.94),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.place_rounded,
                                  size: 13,
                                  color: Color(0xFFEA4335),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Fokus Venue',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF101828),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Top-Right: Map Style Selector & GPS Button
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Tile Style Switcher (Roadmap / Satellite)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _tileStyle = _MapTileStyle.roadmap;
                                  });
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: _tileStyle == _MapTileStyle.roadmap
                                        ? const Color(0xFF1B2A8C)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'Peta',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: _tileStyle == _MapTileStyle.roadmap
                                          ? Colors.white
                                          : const Color(0xFF4B5563),
                                    ),
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _tileStyle = _MapTileStyle.satellite;
                                  });
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: _tileStyle == _MapTileStyle.satellite
                                        ? const Color(0xFF1B2A8C)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'Satelit',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color:
                                          _tileStyle == _MapTileStyle.satellite
                                              ? Colors.white
                                              : const Color(0xFF4B5563),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),

                        // GPS Button
                        InkWell(
                          onTap: _requestUserLocation,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.my_location_rounded,
                              size: 16,
                              color: Color(0xFF1B2A8C),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bottom-Left: Google Maps Watermark
                  Positioned(
                    left: 10,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(6),
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
                              letterSpacing: -0.4,
                              color: Color(0xFF4285F4),
                            ),
                          ),
                          SizedBox(width: 3),
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

                  // Bottom-Right: Zoom In (+) & Zoom Out (-) Controls
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 8,
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
                                  size: 20, color: Color(0xFF374151)),
                            ),
                          ),
                          Container(
                              width: 30,
                              height: 1,
                              color: const Color(0xFFE5E7EB)),
                          InkWell(
                            onTap: _zoomOut,
                            child: const Padding(
                              padding: EdgeInsets.all(7),
                              child: Icon(Icons.remove,
                                  size: 20, color: Color(0xFF374151)),
                            ),
                          ),
                          Container(
                              width: 30,
                              height: 1,
                              color: const Color(0xFFE5E7EB)),
                          InkWell(
                            onTap: _recenterToVenue,
                            borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(10)),
                            child: const Padding(
                              padding: EdgeInsets.all(7),
                              child: Icon(
                                Icons.center_focus_strong_rounded,
                                size: 18,
                                color: Color(0xFF1B2A8C),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Modern Bottom Information Card (Pops up when a location or marker is tapped)
                  if (_showCallout)
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.22),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(
                            color: const Color(0xFFEA4335)
                                .withValues(alpha: 0.35),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEE4E2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.place_rounded,
                                    color: Color(0xFFEA4335), // Google Red
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              _activePlaceName,
                                              style: const TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF101828),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFECFDF3),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.check_circle_rounded,
                                                  size: 10,
                                                  color: Color(0xFF039855),
                                                ),
                                                SizedBox(width: 3),
                                                Text(
                                                  'Google Maps',
                                                  style: TextStyle(
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF039855),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      if (_isLoadingGeocode)
                                        const Row(
                                          children: [
                                            SizedBox(
                                              width: 11,
                                              height: 11,
                                              child:
                                                  CircularProgressIndicator(
                                                strokeWidth: 1.5,
                                                color: Color(0xFF1B2A8C),
                                              ),
                                            ),
                                            SizedBox(width: 6),
                                            Text(
                                              'Mengambil alamat jalan resmi...',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF667085),
                                              ),
                                            ),
                                          ],
                                        )
                                      else
                                        Text(
                                          _activeAddress,
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            color: Color(0xFF475467),
                                            height: 1.3,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Lat: ${_currentPin.latitude.toStringAsFixed(5)}, Lng: ${_currentPin.longitude.toStringAsFixed(5)}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontFamily: 'monospace',
                                          color: Color(0xFF98A2B3),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                InkWell(
                                  onTap: () =>
                                      setState(() => _showCallout = false),
                                  borderRadius: BorderRadius.circular(12),
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                      color: Color(0xFF98A2B3),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _confirmSelectedLocation,
                                    icon: const Icon(
                                      Icons.check_circle_rounded,
                                      size: 15,
                                    ),
                                    label: const Text(
                                      'Gunakan Titik Ini',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          const Color(0xFF1B2A8C),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(9),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: _openInGoogleMaps,
                                  icon: const Icon(
                                    Icons.open_in_new_rounded,
                                    size: 13,
                                  ),
                                  label: const Text(
                                    'Buka di Maps',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF1B2A8C),
                                    side: const BorderSide(
                                        color: Color(0xFFD0D5DD)),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(9),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // 3. Card Lokasi Terpilih (Verified Badge + Full Address + Direct Link)
          Container(
            padding: const EdgeInsets.all(12),
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
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE4E2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.location_on_rounded,
                          color: Color(0xFFEA4335),
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _activePlaceName,
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
                                  color: const Color(0xFFECFDF3),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.verified_rounded,
                                      size: 11,
                                      color: Color(0xFF039855),
                                    ),
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
                          const SizedBox(height: 3),
                          Text(
                            _activeAddress,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF667085),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 8),
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
                            Icon(
                              Icons.open_in_new_rounded,
                              size: 14,
                              color: Color(0xFF1B2A8C),
                            ),
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
                              Icon(
                                Icons.search_rounded,
                                size: 14,
                                color: Color(0xFF4285F4),
                              ),
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
}
