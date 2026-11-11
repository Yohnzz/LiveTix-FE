import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/promoter_models.dart';
import '../../../services/promoter_data_service.dart';
import '../../../services/venue_location_search_service.dart';
import '../widgets/interactive_map_view.dart';
import '../widgets/promoter_step_indicator.dart';

class Step2VenueLocationScreen extends StatefulWidget {
  final String venueName;
  final String venueAddress;
  final String venueSearchQuery;
  final void Function(String name, String address, String query)? onVenueChanged;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const Step2VenueLocationScreen({
    super.key,
    required this.venueName,
    required this.venueAddress,
    required this.venueSearchQuery,
    this.onVenueChanged,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<Step2VenueLocationScreen> createState() =>
      _Step2VenueLocationScreenState();
}

class _Step2VenueLocationScreenState extends State<Step2VenueLocationScreen> {
  late String _currentVenueName;
  late String _currentVenueAddress;
  late String _currentSearchQuery;
  double _currentLatitude = -7.9786;
  double _currentLongitude = 112.6225;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  bool _isSearching = false;
  bool _isLoadingResults = false;
  List<PromoterVenueLocation> _searchResults = [];
  Timer? _debounceTimer;

  bool _isManualEditExpanded = false;
  late TextEditingController _manualNameController;
  late TextEditingController _manualAddressController;

  @override
  void initState() {
    super.initState();
    _currentVenueName = widget.venueName;
    _currentVenueAddress = widget.venueAddress;
    _currentSearchQuery = widget.venueSearchQuery;

    _searchController.text = _currentSearchQuery;
    _manualNameController = TextEditingController(text: _currentVenueName);
    _manualAddressController =
        TextEditingController(text: _currentVenueAddress);

    // Initial search seed
    _searchResults = VenueLocationSearchService.popularVenues;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _manualNameController.dispose();
    _manualAddressController.dispose();
    super.dispose();
  }

  void _onSearchQueryChanged(String val) {
    _debounceTimer?.cancel();
    final query = val.trim();

    if (query.isEmpty) {
      setState(() {
        _isLoadingResults = false;
        _searchResults = VenueLocationSearchService.popularVenues;
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isLoadingResults = true;
      _isSearching = true;
      _currentSearchQuery = query;
    });

    _debounceTimer = Timer(const Duration(milliseconds: 350), () async {
      final results = await VenueLocationSearchService().search(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoadingResults = false;
        });
      }
    });
  }

  void _applyDirectAddress(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return;

    setState(() {
      _isLoadingResults = true;
    });

    final results = await VenueLocationSearchService().search(cleanQuery);

    if (results.isNotEmpty) {
      _selectVenue(results.first);
    } else {
      final customVenue = PromoterVenueLocation(
        name: cleanQuery,
        address: cleanQuery.toLowerCase().contains('jl')
            ? cleanQuery
            : 'Lokasi di , Indonesia',
        city: 'Lokasi Pencarian',
        latitude: _currentLatitude,
        longitude: _currentLongitude,
      );
      _selectVenue(customVenue);
    }

    if (mounted) {
      setState(() {
        _isLoadingResults = false;
        _isSearching = false;
      });
      _searchFocusNode.unfocus();
    }
  }

  void _selectVenue(PromoterVenueLocation venue) {
    setState(() {
      _currentVenueName = venue.name;
      _currentVenueAddress = venue.address;
      _currentLatitude = venue.latitude;
      _currentLongitude = venue.longitude;
      _currentSearchQuery = '${venue.name} ${venue.city}';
      _searchController.text = _currentSearchQuery;
      _manualNameController.text = venue.name;
      _manualAddressController.text = venue.address;
      _isSearching = false;
    });
    _searchFocusNode.unfocus();

    if (widget.onVenueChanged != null) {
      widget.onVenueChanged!(
        venue.name,
        venue.address,
        '${venue.name} ${venue.city}',
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Lokasi dipilih: ${venue.name}',
                style: const TextStyle(fontWeight: FontWeight.w600),
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

  void _useCurrentGpsLocation() {
    const userVenue = PromoterVenueLocation(
      name: 'Lokasi Anda Saat Ini',
      address:
          '',
      city: '',
      latitude: 0,
      longitude: 0,
    );
    _selectVenue(userVenue);
  }

  void _applyManualEdit() {
    final name = _manualNameController.text.trim();
    final address = _manualAddressController.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _currentVenueName = name;
      _currentVenueAddress = address;
      _currentSearchQuery = name;
      _searchController.text = name;
      _isManualEditExpanded = false;
    });

    if (widget.onVenueChanged != null) {
      widget.onVenueChanged!(name, address, name);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Detail lokasi venue konser berhasil diperbarui!'),
        backgroundColor: const Color(0xFF1B2A8C),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _selectPreset(String keyword) {
    final lower = keyword.toLowerCase();
    final match = VenueLocationSearchService.popularVenues.firstWhere(
      (v) =>
          v.name.toLowerCase().contains(lower) ||
          v.city.toLowerCase().contains(lower),
      orElse: () => VenueLocationSearchService.popularVenues.first,
    );
    _selectVenue(match);
  }

  Widget _buildPresetChip({
    required String label,
    required bool isSelected,
    required bool isDarkMode,
    required Color textColor,
    required Color cardBorder,
  }) {
    return InkWell(
      onTap: () => _selectPreset(label),
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
              color: isSelected ? Colors.white : const Color(0xFFEA4335),
            ),
            const SizedBox(width: 5),
            Text(
              label,
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

  @override
  Widget build(BuildContext context) {
    final service = PromoterDataService();

    return ValueListenableBuilder<bool>(
      valueListenable: service.isDarkModeNotifier,
      builder: (context, isDarkMode, _) {
        final textColor =
            isDarkMode ? Colors.white : const Color(0xFF101828);
        final subtextColor =
            isDarkMode ? Colors.white70 : const Color(0xFF667085);
        final cardBg =
            isDarkMode ? const Color(0xFF1B2232) : Colors.white;
        final cardBorder =
            isDarkMode ? Colors.white12 : const Color(0xFFE4E7EC);

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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 4),
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
                'Langkah 2 dari 5: Cari dan tentukan lokasi venue konser langsung dari Google Maps',
                style: TextStyle(
                  fontSize: 13,
                  color: subtextColor,
                ),
              ),

              const SizedBox(height: 16),

              // Stepper (Steps 1 & 2 active dari 5 langkah)
              const PromoterStepIndicator(currentStep: 2, totalSteps: 5),

              const SizedBox(height: 20),

              // Google Maps Connected Notice Badge
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? const Color(0xFF141F36)
                      : const Color(0xFFEEF4FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF4285F4).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFF4285F4),
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
                          const Row(
                            children: [
                              Text(
                                'Terhubung dengan Google Maps',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1B2A8C),
                                ),
                              ),
                              SizedBox(width: 6),
                              Icon(Icons.verified_rounded,
                                  size: 13, color: Color(0xFF4285F4)),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Ketik alamat di kolom pencarian atau langsung klik titik jalan pada peta untuk menentukan lokasi venue.',
                            style: TextStyle(
                              fontSize: 11,
                              color: subtextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Live Google Maps Search Input
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _isSearching
                        ? const Color(0xFF4285F4)
                        : cardBorder,
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
                            color: Color(0xFFEA4335), // Google Red
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
                                setState(() => _isSearching = true);
                              },
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                              decoration: InputDecoration(
                                hintText:
                                    'Ketik alamat / nama venue di Google Maps...',
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
                                color: Color(0xFF4285F4),
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
                      padding: const EdgeInsets.only(
                          left: 14, right: 14, bottom: 10),
                      child: Row(
                        children: [
                          InkWell(
                            onTap: _useCurrentGpsLocation,
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
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.my_location_rounded,
                                      size: 13, color: Color(0xFF16A34A)),
                                  SizedBox(width: 5),
                                  Text(
                                    'Gunakan Lokasi GPS Saya',
                                    style: TextStyle(
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
                                  color: Color(0xFF4285F4),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Real-Time Search Results Dropdown List
                    if (_isSearching) ...[
                      const Divider(height: 1),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 280),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _searchResults.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, indent: 46),
                          itemBuilder: (ctx, index) {
                            final venue = _searchResults[index];
                            final isCurrent =
                                venue.name == _currentVenueName;

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
                                      : const Color(0xFFEA4335),
                                ),
                              ),
                              title: Text(
                                venue.name,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isCurrent
                                      ? const Color(0xFF1B2A8C)
                                      : textColor,
                                ),
                              ),
                              subtitle: Text(
                                venue.address,
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
                                  : Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isDarkMode
                                            ? Colors.white12
                                            : const Color(0xFFF2F4F7),
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        venue.city,
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w600,
                                          color: subtextColor,
                                        ),
                                      ),
                                    ),
                              onTap: () => _selectVenue(venue),
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
                    _buildPresetChip(
                      label: 'Stadion Gajayana',
                      isSelected: _currentVenueName.contains('Gajayana'),
                      isDarkMode: isDarkMode,
                      textColor: textColor,
                      cardBorder: cardBorder,
                    ),
                    const SizedBox(width: 8),
                    _buildPresetChip(
                      label: 'GBK Senayan',
                      isSelected: _currentVenueName.contains('GBK'),
                      isDarkMode: isDarkMode,
                      textColor: textColor,
                      cardBorder: cardBorder,
                    ),
                    const SizedBox(width: 8),
                    _buildPresetChip(
                      label: 'ICE BSD Tangerang',
                      isSelected: _currentVenueName.contains('ICE BSD'),
                      isDarkMode: isDarkMode,
                      textColor: textColor,
                      cardBorder: cardBorder,
                    ),
                    const SizedBox(width: 8),
                    _buildPresetChip(
                      label: 'GBT Surabaya',
                      isSelected: _currentVenueName.contains('Bung Tomo'),
                      isDarkMode: isDarkMode,
                      textColor: textColor,
                      cardBorder: cardBorder,
                    ),
                    const SizedBox(width: 8),
                    _buildPresetChip(
                      label: 'Manahan Solo',
                      isSelected: _currentVenueName.contains('Manahan'),
                      isDarkMode: isDarkMode,
                      textColor: textColor,
                      cardBorder: cardBorder,
                    ),
                    const SizedBox(width: 8),
                    _buildPresetChip(
                      label: 'GWK Bali',
                      isSelected: _currentVenueName.contains('GWK'),
                      isDarkMode: isDarkMode,
                      textColor: textColor,
                      cardBorder: cardBorder,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),
              // Interactive Google Maps Canvas View
              InteractiveMapView(
                venueName: _currentVenueName,
                fullAddress: _currentVenueAddress,
                searchQuery: _currentSearchQuery,
                latitude: _currentLatitude,
                longitude: _currentLongitude,
                onSearchTap: () {
                  setState(() => _isSearching = true);
                  _searchFocusNode.requestFocus();
                },
                onCoordinatesChanged: (lat, lng) {
                  setState(() {
                    _currentLatitude = lat;
                    _currentLongitude = lng;
                  });
                },
                onLocationSelected: (name, address, lat, lng) {
                  setState(() {
                    _currentVenueName = name;
                    _currentVenueAddress = address;
                    _currentLatitude = lat;
                    _currentLongitude = lng;
                    _currentSearchQuery = name;
                    _searchController.text = name;
                    _manualNameController.text = name;
                    _manualAddressController.text = address;
                  });
                  widget.onVenueChanged
                      ?.call(name, address, name);
                },
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
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.edit_location_alt_rounded,
                                  size: 18,
                                  color: Color(0xFF1B2A8C),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Sesuaikan Detail Alamat / Gedung Manual',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: textColor,
                                  ),
                                ),
                              ],
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
                                  borderSide:
                                      BorderSide(color: cardBorder),
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
                                  borderSide:
                                      BorderSide(color: cardBorder),
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
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10),
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
                  onPressed: widget.onNext,
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
