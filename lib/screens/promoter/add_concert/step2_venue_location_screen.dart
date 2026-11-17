import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../models/promoter_models.dart';
import '../../../services/promoter_data_service.dart';
import '../../../services/venue_geocoding_service.dart';
import '../widgets/promoter_step_indicator.dart';

class Step2VenueLocationScreen extends StatefulWidget {
  final String venueName;
  final String venueAddress;
  final String venueSearchQuery;

  /// Koordinat venue yang sudah tersimpan (jika ada) agar peta langsung
  /// menampilkan lokasi yang benar saat user kembali ke langkah ini.
  final double? initialLatitude;
  final double? initialLongitude;

  final void Function(String name, String address, String query)?
      onVenueChanged;

  /// Dipanggil setiap koordinat venue berubah (cari, klik peta, geser pin, GPS).
  final void Function(double latitude, double longitude)? onCoordinatesChanged;

  /// ID objek OpenStreetMap untuk lokasi terpilih (null untuk titik peta/GPS).
  final void Function(String? placeId)? onPlaceIdChanged;

  final VoidCallback onNext;
  final VoidCallback onBack;

  const Step2VenueLocationScreen({
    super.key,
    required this.venueName,
    required this.venueAddress,
    required this.venueSearchQuery,
    this.initialLatitude,
    this.initialLongitude,
    this.onVenueChanged,
    this.onCoordinatesChanged,
    this.onPlaceIdChanged,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<Step2VenueLocationScreen> createState() =>
      _Step2VenueLocationScreenState();
}

class _Step2VenueLocationScreenState extends State<Step2VenueLocationScreen> {
  // Venue populer: label chip -> kata kunci yang dicari ke OpenStreetMap.
  static const List<({String label, String query})> _presets = [
    (label: 'Stadion Gajayana', query: 'Stadion Gajayana Malang'),
    (label: 'GBK Senayan', query: 'Stadion Utama Gelora Bung Karno Jakarta'),
    (label: 'ICE BSD Tangerang', query: 'Indonesia Convention Exhibition BSD'),
    (label: 'GBT Surabaya', query: 'Stadion Gelora Bung Tomo Surabaya'),
    (label: 'Manahan Solo', query: 'Stadion Manahan Solo'),
    (label: 'GWK Bali', query: 'Garuda Wisnu Kencana Bali'),
  ];

  final VenueGeocodingService _places = VenueGeocodingService();

  late String _currentVenueName;
  late String _currentVenueAddress;
  late String _currentSearchQuery;
  String? _currentPlaceId;
  int? _activePreset;

  // Pusat Indonesia hanya sebagai posisi awal kamera. Marker & validasi
  // memakai _hasSelectedLocation supaya tidak ada lokasi palsu.
  double _currentLatitude = -2.5489;
  double _currentLongitude = 118.0149;
  bool _hasSelectedLocation = false;
  int _reverseRequestId = 0;

  final MapController _mapController = MapController();
  bool _mapReady = false;
  bool _isDraggingPin = false;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  bool _isSearching = false;
  bool _isLoadingResults = false;
  bool _isResolvingPoint = false;
  bool _isLocating = false;
  List<VenueSearchResult> _suggestions = [];
  Timer? _debounceTimer;
  int _searchRequestId = 0;

  bool _isManualEditExpanded = false;
  late TextEditingController _manualNameController;
  late TextEditingController _manualAddressController;

  @override
  void initState() {
    super.initState();
    _currentVenueName = widget.venueName;
    _currentVenueAddress = widget.venueAddress;
    _currentSearchQuery = widget.venueSearchQuery;

    if (_isValidCoordinate(
      widget.initialLatitude,
      widget.initialLongitude,
    )) {
      _currentLatitude = widget.initialLatitude!;
      _currentLongitude = widget.initialLongitude!;
      _hasSelectedLocation = true;
    }

    _searchController.text = _currentSearchQuery;
    _manualNameController = TextEditingController(text: _currentVenueName);
    _manualAddressController =
        TextEditingController(text: _currentVenueAddress);

    _restoreInitialLocation();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _manualNameController.dispose();
    _manualAddressController.dispose();
    _mapController.dispose();
    _places.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  String _errorText(Object e) =>
      e is VenueGeocodingException ? e.message : 'Terjadi kesalahan: $e';

  bool _isValidCoordinate(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    if (lat.isNaN || lng.isNaN) return false;
    if (lat == 0 && lng == 0) return false;
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }

  bool get _hasValidLocation =>
      _hasSelectedLocation &&
      _isValidCoordinate(_currentLatitude, _currentLongitude);

  /// Saat reverse geocoding gagal, jangan biarkan nama/alamat lama menempel
  /// pada koordinat baru. Pengguna diminta mengisi detail secara manual.
  void _clearUnresolvedVenueDetails() {
    if (!mounted) return;
    setState(() {
      _currentVenueName = '';
      _currentVenueAddress = '';
      _currentSearchQuery = '';
      _searchController.clear();
      _manualNameController.clear();
      _manualAddressController.clear();
      _activePreset = null;
    });
    widget.onVenueChanged?.call('', '', '');
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor:
              isError ? const Color(0xFFDC2626) : const Color(0xFF1B2A8C),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  void _moveCamera(double lat, double lng, {double zoom = 16}) {
    if (!_isValidCoordinate(lat, lng) || !_mapReady) return;
    _mapController.move(LatLng(lat, lng), zoom);
  }

  /// Jika venue sudah pernah dipilih tapi koordinatnya belum dikirim parent,
  /// cari lagi ke OpenStreetMap supaya pin muncul di tempat yang benar.
  Future<void> _restoreInitialLocation() async {
    if (_hasValidLocation) return;
    final q = widget.venueSearchQuery.trim().isNotEmpty
        ? widget.venueSearchQuery.trim()
        : widget.venueName.trim();
    if (q.isEmpty) return;

    try {
      final results = await _places.search(q);
      if (!mounted || results.isEmpty) return;
      final v = results.first;
      if (!_isValidCoordinate(v.latitude, v.longitude)) return;
      setState(() {
        _currentLatitude = v.latitude;
        _currentLongitude = v.longitude;
        _hasSelectedLocation = true;
        _currentPlaceId = v.placeId.isEmpty ? null : v.placeId;
        if (_currentVenueAddress.trim().isEmpty) {
          _currentVenueAddress = v.address;
          _manualAddressController.text = v.address;
        }
        if (_currentVenueName.trim().isEmpty) {
          _currentVenueName = v.title;
          _manualNameController.text = v.title;
        }
        _isSearching = false;
        _suggestions = [];
      });
      _moveCamera(v.latitude, v.longitude);
      widget.onVenueChanged?.call(
        _currentVenueName,
        _currentVenueAddress,
        _currentSearchQuery,
      );
      widget.onCoordinatesChanged?.call(v.latitude, v.longitude);
      widget.onPlaceIdChanged?.call(_currentPlaceId);
    } catch (_) {
      // Diam saja; user tetap bisa mencari manual.
    }
  }

  // ---------------------------------------------------------------------------
  // Search (autocomplete real-time dari OpenStreetMap/Nominatim)
  // ---------------------------------------------------------------------------
  void _onSearchQueryChanged(String val) {
    _debounceTimer?.cancel();
    final query = val.trim();
    final requestId = ++_searchRequestId;

    if (query.isEmpty) {
      setState(() {
        _isLoadingResults = false;
        _suggestions = [];
        _isSearching = false;
      });
      return;
    }

    // Nominatim membatasi 1 request/detik, jadi tunggu pengguna selesai
    // mengetik (debounce 700 ms) dan jangan cari untuk 1-2 huruf.
    setState(() {
      _isLoadingResults = query.length >= 3;
      _isSearching = true;
      if (query.length < 3) _suggestions = [];
    });
    if (query.length < 3) return;

    _debounceTimer = Timer(const Duration(milliseconds: 700), () async {
      try {
        final results = await _places.search(query);
        if (!mounted || requestId != _searchRequestId) return;
        setState(() {
          _suggestions = results;
          _isLoadingResults = false;
        });
      } catch (e) {
        if (!mounted || requestId != _searchRequestId) return;
        setState(() {
          _suggestions = [];
          _isLoadingResults = false;
        });
        _showMessage(_errorText(e), isError: true);
      }
    });
  }

  void _selectSuggestion(VenueSearchResult suggestion) {
    _debounceTimer?.cancel();
    _searchRequestId++;
    _selectVenue(
      suggestion.toVenueLocation(),
      placeId: suggestion.placeId.isEmpty ? null : suggestion.placeId,
    );
  }

  /// Tombol "Cari" / Enter: cari teks ke OpenStreetMap dan ambil hasil teratas.
  Future<void> _applyDirectAddress(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return;

    _debounceTimer?.cancel();
    _searchRequestId++;
    setState(() => _isLoadingResults = true);

    try {
      final results = await _places.search(cleanQuery);
      if (!mounted) return;
      if (results.isEmpty) {
        _showMessage(
          'Lokasi "$cleanQuery" tidak ditemukan di peta. Coba kata kunci lain.',
          isError: true,
        );
      } else {
        final result = results.first;
        _selectVenue(
          result.toVenueLocation(),
          placeId: result.placeId.isEmpty ? null : result.placeId,
        );
      }
    } catch (e) {
      _showMessage(_errorText(e), isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingResults = false;
          _isSearching = false;
        });
        _searchFocusNode.unfocus();
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Memilih lokasi (dari mana pun) -> satu pintu
  // ---------------------------------------------------------------------------
  void _selectVenue(
    PromoterVenueLocation venue, {
    String? placeId,
    int? presetIndex,
    bool animate = true,
    bool silent = false,
  }) {
    if (!_isValidCoordinate(venue.latitude, venue.longitude)) {
      _showMessage(
        'Lokasi dari peta tidak memiliki koordinat yang valid. Coba pilih hasil lain.',
        isError: true,
      );
      return;
    }

    final query =
        venue.city.isEmpty ? venue.name : '${venue.name} ${venue.city}';

    setState(() {
      _currentVenueName = venue.name;
      _currentVenueAddress = venue.address;
      _currentLatitude = venue.latitude;
      _currentLongitude = venue.longitude;
      _hasSelectedLocation = true;
      _currentPlaceId = placeId;
      _currentSearchQuery = query;
      _activePreset = presetIndex;
      _searchController.text = venue.name;
      _manualNameController.text = venue.name;
      _manualAddressController.text = venue.address;
      _isSearching = false;
      _suggestions = [];
    });
    _searchFocusNode.unfocus();

    if (animate) _moveCamera(venue.latitude, venue.longitude);

    widget.onVenueChanged?.call(venue.name, venue.address, query);
    widget.onCoordinatesChanged?.call(venue.latitude, venue.longitude);
    widget.onPlaceIdChanged?.call(placeId);

    if (!silent) {
      _showMessage('Lokasi dipilih: ${venue.name}');
    }
  }

  // ---------------------------------------------------------------------------
  // Klik / geser pin di peta -> reverse geocoding
  // ---------------------------------------------------------------------------
  Future<void> _onMapPicked(LatLng point) async {
    if (!_isValidCoordinate(point.latitude, point.longitude)) return;
    final requestId = ++_reverseRequestId;
    setState(() {
      _currentLatitude = point.latitude;
      _currentLongitude = point.longitude;
      _hasSelectedLocation = true;
      _currentPlaceId = null;
      _activePreset = null;
      _isResolvingPoint = true;
    });
    widget.onCoordinatesChanged?.call(point.latitude, point.longitude);
    widget.onPlaceIdChanged?.call(null);

    try {
      final venue = await _places.reverse(
        point.latitude,
        point.longitude,
      );
      if (!mounted || requestId != _reverseRequestId) return;
      _selectVenue(venue.toVenueLocation(), animate: false, silent: true);
    } catch (e) {
      if (!mounted || requestId != _reverseRequestId) return;
      _clearUnresolvedVenueDetails();
      _showMessage(
        '${_errorText(e)} Titik tetap tersimpan, silakan isi nama/alamat venue secara manual.',
        isError: true,
      );
    } finally {
      if (mounted && requestId == _reverseRequestId) {
        setState(() => _isResolvingPoint = false);
      }
    }
  }

  /// Mulai geser pin: hentikan reverse geocoding yang masih berjalan supaya
  /// hasil lama tidak menimpa posisi pin yang baru.
  void _handlePinDragStart(DragStartDetails details) {
    _reverseRequestId++;
    setState(() {
      _isDraggingPin = true;
      _isResolvingPoint = false;
      _currentPlaceId = null;
      _activePreset = null;
    });
    widget.onPlaceIdChanged?.call(null);
  }

  /// Geser pin mengikuti jari tanpa memanggil Nominatim di setiap frame.
  void _handlePinDragUpdate(DragUpdateDetails details) {
    if (!_mapReady) return;
    final camera = _mapController.camera;
    final current = LatLng(_currentLatitude, _currentLongitude);
    final nextOffset = camera.latLngToScreenOffset(current) + details.delta;
    final nextPoint = camera.screenOffsetToLatLng(nextOffset);
    if (!_isValidCoordinate(nextPoint.latitude, nextPoint.longitude)) return;

    setState(() {
      _currentLatitude = nextPoint.latitude;
      _currentLongitude = nextPoint.longitude;
      _hasSelectedLocation = true;
    });
  }

  /// Setelah pin dilepas, cari alamat untuk posisi terakhir saja.
  void _handlePinDragEnd(DragEndDetails details) {
    setState(() => _isDraggingPin = false);
    _onMapPicked(LatLng(_currentLatitude, _currentLongitude));
  }

  // ---------------------------------------------------------------------------
  // GPS perangkat
  // ---------------------------------------------------------------------------
  Future<void> _useCurrentGpsLocation() async {
    if (_isLocating) return;
    setState(() => _isLocating = true);

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        _showMessage('Aktifkan layanan lokasi (GPS) di perangkat Anda.',
            isError: true);
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        _showMessage('Izin lokasi ditolak.', isError: true);
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        _showMessage(
          'Izin lokasi ditolak permanen. Aktifkan lewat pengaturan aplikasi.',
          isError: true,
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;

      // Tampilkan pin lebih dulu supaya pengguna langsung melihat posisinya,
      // lalu lengkapi dengan alamat hasil reverse geocoding.
      setState(() {
        _currentLatitude = position.latitude;
        _currentLongitude = position.longitude;
        _hasSelectedLocation = true;
        _currentPlaceId = null;
        _activePreset = null;
        _isResolvingPoint = true;
      });
      _moveCamera(position.latitude, position.longitude);
      widget.onCoordinatesChanged?.call(position.latitude, position.longitude);
      widget.onPlaceIdChanged?.call(null);

      try {
        final venue = await _places.reverse(
          position.latitude,
          position.longitude,
          nameOverride: 'Lokasi Anda Saat Ini',
        );
        if (!mounted) return;
        _selectVenue(venue.toVenueLocation());
      } catch (e) {
        if (!mounted) return;
        _clearUnresolvedVenueDetails();
        _showMessage(
          '${_errorText(e)} Titik GPS tetap tersimpan, silakan isi nama/alamat venue secara manual.',
          isError: true,
        );
      }
    } on TimeoutException {
      _showMessage('Gagal mendapatkan lokasi GPS. Coba lagi di tempat terbuka.',
          isError: true);
    } catch (e) {
      _showMessage(_errorText(e), isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLocating = false;
          _isResolvingPoint = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Edit manual nama/alamat (koordinat tidak berubah)
  // ---------------------------------------------------------------------------
  void _applyManualEdit() {
    final name = _manualNameController.text.trim();
    final address = _manualAddressController.text.trim();
    if (name.isEmpty) {
      _showMessage('Nama venue tidak boleh kosong.', isError: true);
      return;
    }

    setState(() {
      _currentVenueName = name;
      _currentVenueAddress = address;
      _currentSearchQuery = name;
      _searchController.text = name;
      _isManualEditExpanded = false;
    });

    widget.onVenueChanged?.call(name, address, name);
    _showMessage('Detail lokasi venue konser berhasil diperbarui!');
  }

  // ---------------------------------------------------------------------------
  // Chip venue populer -> cari ke OpenStreetMap
  // ---------------------------------------------------------------------------
  Future<void> _selectPreset(int index) async {
    final preset = _presets[index];
    final previousPreset = _activePreset;
    setState(() {
      _isLoadingResults = true;
      _activePreset = index;
    });
    try {
      final results = await _places.search(preset.query);
      if (!mounted) return;
      if (results.isEmpty) {
        setState(() => _activePreset = previousPreset);
        _showMessage('${preset.label} tidak ditemukan di peta.',
            isError: true);
      } else {
        final result = results.first;
        _selectVenue(
          result.toVenueLocation(),
          placeId: result.placeId.isEmpty ? null : result.placeId,
          presetIndex: index,
        );
      }
    } catch (e) {
      if (mounted) setState(() => _activePreset = previousPreset);
      _showMessage(_errorText(e), isError: true);
    } finally {
      if (mounted) setState(() => _isLoadingResults = false);
    }
  }

  Widget _buildPresetChip({
    required int index,
    required bool isDarkMode,
    required Color textColor,
    required Color cardBorder,
  }) {
    final isSelected = _activePreset == index;
    return InkWell(
      onTap: () => _selectPreset(index),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1B2A8C)
              : (isDarkMode
                  ? const Color(0xFF1F2937)
                  : const Color(0xFFF2F4F7)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF1B2A8C) : cardBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.place_rounded,
              size: 13,
              color: isSelected ? Colors.white : const Color(0xFFC2185B),
            ),
            const SizedBox(width: 5),
            Text(
              _presets[index].label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Peta OpenStreetMap (gratis, tanpa API key)
  // ---------------------------------------------------------------------------
  void _zoomBy(double delta) {
    if (!_mapReady) return;
    final camera = _mapController.camera;
    final zoom = (camera.zoom + delta).clamp(3.0, 19.0).toDouble();
    _mapController.move(camera.center, zoom);
  }

  Widget _buildMapControl(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      elevation: 2,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 20, color: const Color(0xFF1B2A8C)),
        ),
      ),
    );
  }

  Widget _buildMap() {
    final center = _hasSelectedLocation
        ? LatLng(_currentLatitude, _currentLongitude)
        : const LatLng(-2.5489, 118.0149);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 280,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: _hasSelectedLocation ? 15 : 5,
                minZoom: 3,
                maxZoom: 19,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                onMapReady: () {
                  _mapReady = true;
                  if (_hasSelectedLocation) {
                    _moveCamera(_currentLatitude, _currentLongitude);
                  }
                },
                onTap: (tapPosition, point) => _onMapPicked(point),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.livetix',
                  maxNativeZoom: 19,
                ),
                if (_hasSelectedLocation)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(_currentLatitude, _currentLongitude),
                        width: 52,
                        height: 52,
                        alignment: Alignment.bottomCenter,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanStart: _handlePinDragStart,
                          onPanUpdate: _handlePinDragUpdate,
                          onPanEnd: _handlePinDragEnd,
                          child: const Tooltip(
                            message: 'Geser pin untuk memindahkan lokasi',
                            child: Icon(
                              Icons.location_on_rounded,
                              size: 46,
                              color: Color(0xFFC2185B),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            // Atribusi wajib saat memakai tile OpenStreetMap.
            Positioned(
              left: 0,
              bottom: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                color: Colors.white.withValues(alpha: 0.82),
                child: const Text(
                  '© OpenStreetMap contributors',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
            ),

            // Zoom untuk perangkat tanpa gestur pinch (mis. desktop/web).
            Positioned(
              top: 10,
              left: 10,
              child: Column(
                children: [
                  _buildMapControl(Icons.add_rounded, () => _zoomBy(1)),
                  const SizedBox(height: 6),
                  _buildMapControl(Icons.remove_rounded, () => _zoomBy(-1)),
                ],
              ),
            ),

            // Status saat mencari alamat dari titik yang dipilih.
            if (_isResolvingPoint || _isDraggingPin)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isDraggingPin)
                        const Icon(
                          Icons.open_with_rounded,
                          size: 12,
                          color: Color(0xFF1B2A8C),
                        )
                      else
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      const SizedBox(width: 6),
                      Text(
                        _isDraggingPin
                            ? 'Lepaskan pin...'
                            : 'Mencari alamat...',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
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
    );
  }

  Widget _buildSelectedLocationCard({
    required Color cardBg,
    required Color cardBorder,
    required Color textColor,
    required Color subtextColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFF1B2A8C),
              shape: BoxShape.circle,
            ),
            child:
                const Icon(Icons.place_rounded, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentVenueName.isEmpty
                      ? 'Belum ada lokasi dipilih'
                      : _currentVenueName,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
                if (_currentVenueAddress.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    _currentVenueAddress,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: subtextColor,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                if (_hasValidLocation)
                  Text(
                    '${_currentLatitude.toStringAsFixed(6)}, ${_currentLongitude.toStringAsFixed(6)}',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: subtextColor,
                    ),
                  )
                else
                  Text(
                    'Cari lokasi atau ketuk peta untuk menaruh pin venue.',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: subtextColor,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleNext() {
    if (!_hasValidLocation) {
      _showMessage(
        'Tentukan lokasi venue terlebih dahulu: cari nama venue, ketuk peta, geser pin, atau gunakan GPS.',
        isError: true,
      );
      return;
    }
    if (_currentVenueName.trim().isEmpty &&
        _currentVenueAddress.trim().isEmpty) {
      _showMessage(
        'Nama atau alamat venue belum terisi. Pilih lokasi lewat pencarian atau peta.',
        isError: true,
      );
      return;
    }
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final service = PromoterDataService();

    return ValueListenableBuilder<bool>(
      valueListenable: service.isDarkModeNotifier,
      builder: (context, isDarkMode, _) {
        final textColor = isDarkMode ? Colors.white : const Color(0xFF101828);
        final subtextColor =
            isDarkMode ? Colors.white70 : const Color(0xFF667085);
        final cardBg = isDarkMode ? const Color(0xFF1B2232) : Colors.white;
        final cardBorder =
            isDarkMode ? Colors.white12 : const Color(0xFFE4E7EC);

        final showDropdown =
            _isSearching && _searchController.text.trim().isNotEmpty;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar with Kembali and Theme Toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: widget.onBack,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chevron_left_rounded,
                            size: 22,
                            color: textColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Kembali',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      isDarkMode
                          ? Icons.dark_mode_outlined
                          : Icons.wb_sunny_outlined,
                      size: 22,
                      color: textColor,
                    ),
                    onPressed: service.toggleTheme,
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Title & Subtitle
              Text(
                'Pilih Tempat Konser',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Langkah 2 dari 5: Cari dan tentukan lokasi venue konser langsung dari peta',
                style: TextStyle(
                  fontSize: 13,
                  color: subtextColor,
                ),
              ),

              const SizedBox(height: 16),

              // Stepper (Steps 1 & 2 active dari 5 langkah)
              const PromoterStepIndicator(currentStep: 2, totalSteps: 5),

              const SizedBox(height: 20),

              // Info: peta & pencarian lokasi gratis tanpa API key.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? const Color(0xFF141F36)
                      : const Color(0xFFEEF4FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF1B2A8C).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFF1B2A8C),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.map_rounded,
                        color: Colors.white,
                        size: 15,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'Peta OpenStreetMap · gratis tanpa API key',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: isDarkMode
                                        ? Colors.white
                                        : const Color(0xFF1B2A8C),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.verified_rounded,
                                  size: 13, color: Color(0xFF16A34A)),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Ketik nama venue atau alamat, ketuk titik di peta, atau geser pin. Data peta © OpenStreetMap contributors.',
                            style: TextStyle(
                              fontSize: 11,
                              color: subtextColor,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Pencarian lokasi dari OpenStreetMap

              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color:
                        _isSearching ? const Color(0xFF1B2A8C) : cardBorder,
                    width: _isSearching ? 1.8 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.search_rounded,
                            size: 22,
                            color: Color(0xFF1B2A8C),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              onChanged: _onSearchQueryChanged,
                              textInputAction: TextInputAction.search,
                              onSubmitted: _applyDirectAddress,
                              onTap: () {
                                if (_searchController.text.trim().isNotEmpty) {
                                  setState(() => _isSearching = true);
                                }
                              },
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                              decoration: InputDecoration(
                                hintText:
                                    'Ketik alamat / nama venue di peta...',
                                hintStyle: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.normal,
                                  color: subtextColor,
                                ),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          if (_isLoadingResults)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF1B2A8C),
                              ),
                            )
                          else if (_searchController.text.isNotEmpty) ...[
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchQueryChanged('');
                              },
                              color: subtextColor,
                            ),
                            InkWell(
                              onTap: () =>
                                  _applyDirectAddress(_searchController.text),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1B2A8C),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.search_rounded,
                                        size: 14, color: Colors.white),
                                    SizedBox(width: 4),
                                    Text(
                                      'Cari',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Quick Action Row below Search Bar
                    Padding(
                      padding:
                          const EdgeInsets.only(left: 14, right: 14, bottom: 10),
                      child: Row(
                        children: [
                          InkWell(
                            onTap: _isLocating ? null : _useCurrentGpsLocation,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? const Color(0xFF141F36)
                                    : const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFF22C55E)
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_isLocating)
                                    const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF16A34A),
                                      ),
                                    )
                                  else
                                    const Icon(Icons.my_location_rounded,
                                        size: 13, color: Color(0xFF16A34A)),
                                  const SizedBox(width: 5),
                                  Text(
                                    _isLocating
                                        ? 'Mencari lokasi...'
                                        : 'Gunakan Lokasi GPS Saya',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF16A34A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (_isSearching)
                            GestureDetector(
                              onTap: () {
                                setState(() => _isSearching = false);
                                _searchFocusNode.unfocus();
                              },
                              child: const Text(
                                'Tutup Hasil',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1B2A8C),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Saran real-time dari OpenStreetMap
                    if (showDropdown) ...[
                      const Divider(height: 1),
                      if (_suggestions.isEmpty && !_isLoadingResults)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Tidak ada hasil. Coba kata kunci lain atau ketuk titik langsung di peta.',
                            style: TextStyle(
                              fontSize: 12,
                              color: subtextColor,
                            ),
                          ),
                        )
                      else
                        Container(
                          constraints: const BoxConstraints(maxHeight: 280),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: _suggestions.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1, indent: 46),
                            itemBuilder: (ctx, index) {
                              final s = _suggestions[index];
                              final isCurrent = s.placeId == _currentPlaceId;

                              return ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 2),
                                leading: Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: isCurrent
                                        ? const Color(0xFF1B2A8C)
                                        : const Color(0xFFF2F4F7),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.place_rounded,
                                    size: 18,
                                    color: isCurrent
                                        ? Colors.white
                                        : const Color(0xFFC2185B),
                                  ),
                                ),
                                title: Text(
                                  s.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isCurrent
                                        ? const Color(0xFF1B2A8C)
                                        : textColor,
                                  ),
                                ),
                                subtitle: s.subtitle.isEmpty
                                    ? null
                                    : Text(
                                        s.subtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: subtextColor,
                                        ),
                                      ),
                                trailing: isCurrent
                                    ? const Icon(
                                        Icons.check_circle_rounded,
                                        color: Color(0xFF1B2A8C),
                                        size: 18,
                                      )
                                    : null,
                                onTap: () => _selectSuggestion(s),
                              );
                            },
                          ),
                        ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Rekomendasi Pilihan Venue Populer (1-Tap Selection)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    for (var i = 0; i < _presets.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      _buildPresetChip(
                        index: i,
                        isDarkMode: isDarkMode,
                        textColor: textColor,
                        cardBorder: cardBorder,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Peta OpenStreetMap
              _buildMap(),

              const SizedBox(height: 12),

              _buildSelectedLocationCard(
                cardBg: cardBg,
                cardBorder: cardBorder,
                textColor: textColor,
                subtextColor: subtextColor,
              ),

              const SizedBox(height: 16),

              // Manual Fine-Tune Address Expandable Accordion
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cardBorder),
                ),
                child: Column(
                  children: [
                    InkWell(
                      onTap: () {
                        setState(() {
                          _isManualEditExpanded = !_isManualEditExpanded;
                        });
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.edit_location_alt_rounded,
                                    size: 18,
                                    color: Color(0xFF1B2A8C),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Sesuaikan Detail Alamat / Gedung Manual',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: textColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              _isManualEditExpanded
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              size: 20,
                              color: subtextColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_isManualEditExpanded) ...[
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nama Venue / Gedung',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: subtextColor,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _manualNameController,
                              style: TextStyle(
                                fontSize: 13,
                                color: textColor,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Contoh: Grand Ballroom Lantai 3',
                                filled: true,
                                fillColor: isDarkMode
                                    ? const Color(0xFF141A29)
                                    : const Color(0xFFF9FAFB),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: cardBorder),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Alamat Lengkap & Patokan Akses',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: subtextColor,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _manualAddressController,
                              maxLines: 2,
                              style: TextStyle(
                                fontSize: 13,
                                color: textColor,
                              ),
                              decoration: InputDecoration(
                                hintText:
                                    'Tulis jalan, nomor, kecamatan, kode pos...',
                                filled: true,
                                fillColor: isDarkMode
                                    ? const Color(0xFF141A29)
                                    : const Color(0xFFF9FAFB),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: cardBorder),
                                ),
                                contentPadding: const EdgeInsets.all(12),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _applyManualEdit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1B2A8C),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                ),
                                child: const Text(
                                  'Simpan Perubahan Alamat',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Bottom Primary Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _handleNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B2A8C), // Navy
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Konfirmasi Lokasi & Lanjut',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}