import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../models/concert_model.dart';
import '../../services/data_service.dart';
import '../../widgets/concert_media.dart';
import '../concert/concert_detail_screen.dart';

enum _PriceFilterOption {
  all('Semua Harga', 'Harga'),
  under50k('Termurah (< Rp50.000)', 'Termurah < Rp50.000'),
  range50to150k('Rp50.000 - Rp150.000', 'Rp50.000 - Rp150.000'),
  range151to200k('Rp151.000 - Rp200.000', 'Rp151.000 - Rp200.000'),
  over200k('Termahal (> Rp200.000)', 'Termahal > Rp200.000');

  final String menuLabel;
  final String chipLabel;
  const _PriceFilterOption(this.menuLabel, this.chipLabel);

  bool matches(int price) {
    switch (this) {
      case _PriceFilterOption.all:
        return true;
      case _PriceFilterOption.under50k:
        return price < 50000;
      case _PriceFilterOption.range50to150k:
        return price >= 50000 && price <= 150000;
      case _PriceFilterOption.range151to200k:
        return price > 150000 && price <= 200000;
      case _PriceFilterOption.over200k:
        return price > 200000;
    }
  }
}

class ExploreScreen extends StatefulWidget {
  final bool isGuest;

  const ExploreScreen({super.key, this.isGuest = false});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final DataService _dataService = DataService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  static const List<String> _shortMonths = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  List<CityModel> _popularCities = [];
  List<String> _genres = ['Semua'];
  List<ConcertModel> _allConcerts = [];
  List<ConcertModel> _filteredConcerts = [];
  bool _isLoading = true;
  String? _loadError;

  bool _onlyFavorites = false;
  String _selectedCity = 'Semua';
  String _selectedGenre = 'Semua';
  DateTime? _selectedDate;
  _PriceFilterOption _selectedPrice = _PriceFilterOption.all;
  String _searchQuery = '';

  bool get _hasActiveFilter =>
      _onlyFavorites ||
      _selectedCity != 'Semua' ||
      _selectedGenre != 'Semua' ||
      _selectedDate != null ||
      _selectedPrice != _PriceFilterOption.all ||
      _searchQuery.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadDataFromService();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDataFromService() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final cities = await _dataService.getCities();
      final genres = await _dataService.getGenres();
      final concerts = await _dataService.getEvents();

      if (!mounted) return;
      setState(() {
        _popularCities = cities;
        _genres = genres;
        _allConcerts = concerts;
        _filteredConcerts =
            concerts.length > 10 ? concerts.take(10).toList() : concerts;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Gagal memuat daftar konser. Periksa koneksi lalu coba lagi.';
      });
    }
  }

  void _applyFilters() {
    final q = _searchQuery.trim().toLowerCase();

    final results = _allConcerts.where((concert) {
      // 0. Filter Disukai jika _onlyFavorites aktif
      final matchFav = !_onlyFavorites || _dataService.isFavorite(concert.id);

      final matchCity = _selectedCity == 'Semua' ||
          concert.venue.toLowerCase().contains(_selectedCity.toLowerCase());

      final matchGenre = _selectedGenre == 'Semua' ||
          concert.category.toLowerCase() == _selectedGenre.toLowerCase();

      bool matchDate = true;
      if (_selectedDate != null) {
        final concertDt = concert.parsedDate;
        matchDate = concertDt != null &&
            concertDt.year == _selectedDate!.year &&
            concertDt.month == _selectedDate!.month &&
            concertDt.day == _selectedDate!.day;
      }

      final matchPrice = _selectedPrice.matches(concert.price);

      final matchQuery = q.isEmpty ||
          concert.title.toLowerCase().contains(q) ||
          concert.subtitle.toLowerCase().contains(q) ||
          concert.venue.toLowerCase().contains(q) ||
          concert.category.toLowerCase().contains(q);

      return matchFav && matchCity && matchGenre && matchDate && matchPrice && matchQuery;
    }).toList();

    if (_selectedPrice == _PriceFilterOption.under50k) {
      results.sort((a, b) => a.price.compareTo(b.price));
    } else if (_selectedPrice == _PriceFilterOption.over200k) {
      results.sort((a, b) => b.price.compareTo(a.price));
    }

    // Batasi maksimal 10 konser jika filtering menghasilkan lebih dari 10 konser
    var limitedResults = results;
    if (limitedResults.length > 10) {
      limitedResults = limitedResults.take(10).toList();
    }

    setState(() {
      _filteredConcerts = limitedResults;
    });
  }

  void _resetAllFilters() {
    setState(() {
      _onlyFavorites = false;
      _selectedCity = 'Semua';
      _selectedGenre = 'Semua';
      _selectedDate = null;
      _selectedPrice = _PriceFilterOption.all;
      _searchQuery = '';
      _searchController.clear();
      _filteredConcerts = _allConcerts.length > 10
          ? _allConcerts.take(10).toList()
          : List.from(_allConcerts);
    });
  }

  void _onCityCardTapped(String cityName) {
    setState(() {
      if (_selectedCity.toLowerCase() == cityName.toLowerCase()) {
        _selectedCity = 'Semua';
      } else {
        _selectedCity = cityName;
      }
    });
    _applyFilters();
  }

  String _formatShortDate(DateTime dt) {
    return '${dt.day} ${_shortMonths[dt.month]} ${dt.year}';
  }

  Future<void> _openDateFilterDialog() async {
    final eventDates = _allConcerts
        .map((c) => c.parsedDate)
        .whereType<DateTime>()
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet();

    final result = await showDialog<_DatePickerResult>(
      context: context,
      builder: (ctx) => _ExploreDatePickerDialog(
        initialDate: _selectedDate,
        eventDates: eventDates,
      ),
    );

    if (result == null || !mounted) return;
    setState(() {
      _selectedDate = result.cleared ? null : result.date;
    });
    _applyFilters();
  }

  void _openConcertDetail(ConcertModel concert) {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'ConcertDetailScreen'),
        builder: (_) => ConcertDetailScreen(
          concert: concert,
          isGuest: widget.isGuest,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewTop = MediaQuery.of(context).viewPadding.top;
    final topSpacing = viewTop > 0 ? viewTop + 16 : 38.0;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.bg(context),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.brand(context)),
              const SizedBox(height: 12),
              Text(
                'Memuat daftar konser...',
                style: TextStyle(fontSize: 13, color: AppColors.subtext(context)),
              ),
            ],
          ),
        ),
      );
    }

    final isDark = AppColors.isDark(context);

    if (_loadError != null) {
      return Scaffold(
        backgroundColor: AppColors.bg(context),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 42, color: Color(0xFFB91C1C)),
                const SizedBox(height: 12),
                Text(
                  _loadError!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppColors.darkText : AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: _loadDataFromService,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Muat Ulang'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: EdgeInsets.only(left: 20, right: 20, top: topSpacing, bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Jelajah',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkText : AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Temukan konser & artis favoritmu',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_hasActiveFilter)
                  Material(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: _resetAllFilters,
                      borderRadius: BorderRadius.circular(12),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.refresh_rounded, size: 15, color: Color(0xFFB91C1C)),
                              SizedBox(width: 4),
                              Text(
                                'Reset',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFB91C1C),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),

            _buildSearchBar(),
            const SizedBox(height: 14),

            // Hanya mempertahankan filter Tanggal (date picker + Today) dan Harga
            _buildTopFiltersRow(),
            const SizedBox(height: 24),

            // Bagian Kota Populer dengan efek shadow #C654C3 saat aktif & tanpa total event
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Kota populer',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkText : AppColors.textDark,
                    ),
                  ),
                ),
                if (_selectedCity != 'Semua')
                  TextButton(
                    onPressed: () {
                      setState(() => _selectedCity = 'Semua');
                      _applyFilters();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      minimumSize: const Size(44, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text(
                      'Semua Kota',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _buildPopularCitiesRow(),
            const SizedBox(height: 22),

            Text(
              'Genre',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkText : AppColors.textDark,
              ),
            ),
            const SizedBox(height: 12),
            _buildGenrePillsRow(),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _hasActiveFilter
                        ? 'Hasil Filter (${_filteredConcerts.length})'
                        : 'Sedang trending',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkText : AppColors.textDark,
                    ),
                  ),
                ),
                if (_hasActiveFilter) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${_filteredConcerts.length} konser',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textGrey,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),

            if (_filteredConcerts.isEmpty)
              _buildEmptyState()
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredConcerts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final concert = _filteredConcerts[index];
                  return _buildTrendingConcertCard(concert);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    final isDark = AppColors.isDark(context);

    return Semantics(
      label: 'Cari artis, venue, atau kota',
      textField: true,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceVariant : AppColors.searchBarBg,
          borderRadius: BorderRadius.circular(14),
          border: isDark ? Border.all(color: AppColors.darkBorder) : null,
        ),
        child: Row(
          children: [
            Icon(
              Icons.search,
              size: 20,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textGrey,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  _searchQuery = val;
                  _applyFilters();
                },
                style: TextStyle(
                  fontSize: 13.5,
                  color: isDark ? AppColors.darkText : AppColors.textDark,
                ),
                decoration: InputDecoration(
                  hintText: 'Cari artis, venue, atau kota',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textGrey,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              IconButton(
                tooltip: 'Hapus kata kunci pencarian',
                onPressed: () {
                  _searchController.clear();
                  _searchQuery = '';
                  _applyFilters();
                },
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                padding: EdgeInsets.zero,
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textGrey,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopFiltersRow() {
    final isDark = AppColors.isDark(context);
    final isDateActive = _selectedDate != null;
    final dateText = isDateActive ? _formatShortDate(_selectedDate!) : 'Tanggal';
    final isPriceActive = _selectedPrice != _PriceFilterOption.all;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        // 1. Filter Tanggal (membuka pemilih tanggal/bulan/tahun + tombol Today)
        Material(
          color: isDateActive
              ? (isDark ? const Color(0xFF1E3A8A) : const Color(0xFFE0EAFF))
              : (isDark ? AppColors.darkSurface : Colors.white),
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            onTap: _openDateFilterDialog,
            borderRadius: BorderRadius.circular(22),
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isDateActive
                      ? (isDark ? AppColors.primaryDark : AppColors.primary)
                      : (isDark ? AppColors.darkBorder : AppColors.chipBorder),
                  width: isDateActive ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_month_outlined,
                    size: 17,
                    color: isDateActive
                        ? (isDark ? AppColors.primaryDark : AppColors.primary)
                        : (isDark ? AppColors.darkTextSecondary : AppColors.textGrey),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    dateText,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isDateActive ? FontWeight.w700 : FontWeight.w500,
                      color: isDateActive
                          ? (isDark ? AppColors.primaryDark : AppColors.primary)
                          : (isDark ? AppColors.darkText : AppColors.textDark),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: isDateActive
                        ? (isDark ? AppColors.primaryDark : AppColors.primary)
                        : (isDark ? AppColors.darkTextSecondary : AppColors.textGrey),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 2. Filter Harga (Termurah <50rb, 50rb-150rb, 151rb-200rb, Termahal >200rb)
        PopupMenuButton<_PriceFilterOption>(
          tooltip: 'Filter rentang harga tiket',
          constraints: const BoxConstraints(minWidth: 230, maxWidth: 320),
          onSelected: (option) {
            setState(() => _selectedPrice = option);
            _applyFilters();
          },
          initialValue: _selectedPrice,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 6,
          color: isDark ? AppColors.darkSurface : Colors.white,
          itemBuilder: (context) {
            return _PriceFilterOption.values.map((option) {
              final isChosen = option == _selectedPrice;
              return PopupMenuItem<_PriceFilterOption>(
                value: option,
                height: 44,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        option.menuLabel,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isChosen ? FontWeight.w700 : FontWeight.w500,
                          color: isChosen
                              ? (isDark ? AppColors.primaryDark : AppColors.primary)
                              : (isDark ? AppColors.darkText : AppColors.textDark),
                        ),
                      ),
                    ),
                    if (isChosen) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.check_rounded,
                        size: 17,
                        color: isDark ? AppColors.primaryDark : AppColors.primary,
                      ),
                    ],
                  ],
                ),
              );
            }).toList();
          },
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isPriceActive
                  ? (isDark ? const Color(0xFF1E3A8A) : const Color(0xFFE0EAFF))
                  : (isDark ? AppColors.darkSurface : Colors.white),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isPriceActive
                    ? (isDark ? AppColors.primaryDark : AppColors.primary)
                    : (isDark ? AppColors.darkBorder : AppColors.chipBorder),
                width: isPriceActive ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.payments_outlined,
                  size: 17,
                  color: isPriceActive
                      ? (isDark ? AppColors.primaryDark : AppColors.primary)
                      : (isDark ? AppColors.darkTextSecondary : AppColors.textGrey),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _selectedPrice.chipLabel,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isPriceActive ? FontWeight.w700 : FontWeight.w500,
                      color: isPriceActive
                          ? (isDark ? AppColors.primaryDark : AppColors.primary)
                          : (isDark ? AppColors.darkText : AppColors.textDark),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: isPriceActive
                      ? (isDark ? AppColors.primaryDark : AppColors.primary)
                      : (isDark ? AppColors.darkTextSecondary : AppColors.textGrey),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPopularCitiesRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      child: Row(
        children: _popularCities.map((city) {
          final isSelected = _selectedCity.toLowerCase() == city.name.toLowerCase();
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Semantics(
              button: true,
              selected: isSelected,
              label: 'Filter kota ${city.name}',
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                transform: Matrix4.translationValues(0, isSelected ? -2.0 : 0.0, 0),
                decoration: BoxDecoration(
                  color: city.bgColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.citySelectedShadow
                        : city.textColor.withValues(alpha: 0.18),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? const [
                          BoxShadow(
                            color: AppColors.citySelectedShadow,
                            blurRadius: 0,
                            offset: Offset(0, 4),
                          ),
                          BoxShadow(
                            color: Color(0x73C654C3),
                            blurRadius: 12,
                            spreadRadius: 0.5,
                            offset: Offset(0, 6),
                          ),
                        ]
                      : null,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _onCityCardTapped(city.name),
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 98,
                      height: 54,
                      child: Center(
                        child: Text(
                          city.name,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: city.textColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGenrePillsRow() {
    final isDark = AppColors.isDark(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Filter Disukai (dapat dikombinasikan dengan genre yang dipilih)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Semantics(
              button: true,
              selected: _onlyFavorites,
              label: 'Filter Disukai',
              child: Material(
                color: _onlyFavorites
                    ? (isDark ? const Color(0xFF831843) : const Color(0xFFFCE7F3))
                    : (isDark ? AppColors.darkSurface : Colors.white),
                borderRadius: BorderRadius.circular(22),
                child: InkWell(
                  onTap: () {
                    setState(() => _onlyFavorites = !_onlyFavorites);
                    _applyFilters();
                  },
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: _onlyFavorites
                            ? AppColors.favoritePink
                            : (isDark ? AppColors.darkBorder : AppColors.border),
                        width: _onlyFavorites ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _onlyFavorites
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 16,
                          color: _onlyFavorites
                              ? AppColors.favoritePink
                              : (isDark ? AppColors.darkTextSecondary : AppColors.textGrey),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Disukai',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                _onlyFavorites ? FontWeight.w700 : FontWeight.w500,
                            color: _onlyFavorites
                                ? (isDark ? const Color(0xFFF472B6) : AppColors.favoritePink)
                                : (isDark ? AppColors.darkText : AppColors.textDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          ..._genres.map((genre) {
            final isSelected =
                _selectedGenre.toLowerCase() == genre.toLowerCase();
            final bgCol = isSelected
                ? (isDark ? AppColors.primaryDark : AppColors.primary)
                : (isDark ? AppColors.darkSurface : Colors.white);
            final textCol = isSelected
                ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                : (isDark ? AppColors.darkText : AppColors.textDark);
            final borderCol = isSelected
                ? (isDark ? AppColors.primaryDark : AppColors.primary)
                : (isDark ? AppColors.darkBorder : AppColors.border);

            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Semantics(
                button: true,
                selected: isSelected,
                label: 'Genre $genre',
                child: Material(
                  color: bgCol,
                  borderRadius: BorderRadius.circular(22),
                  child: InkWell(
                    onTap: () {
                      setState(() => _selectedGenre = genre);
                      _applyFilters();
                    },
                    borderRadius: BorderRadius.circular(22),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: borderCol),
                      ),
                      child: Text(
                        genre,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: textCol,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDark = AppColors.isDark(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : const Color(0xFFF2F4F7),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off_rounded,
              size: 36,
              color: AppColors.subtext(context),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Tidak ada konser yang cocok',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.text(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Belum ada jadwal konser untuk kombinasi tanggal, harga, kota, atau kata kunci yang dipilih.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.subtext(context),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _resetAllFilters,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Reset Semua Filter'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendingConcertCard(ConcertModel concert) {
    final isDark = AppColors.isDark(context);

    return Material(
      color: isDark ? AppColors.darkSurface : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _openConcertDetail(concert),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              ConcertSquareLogo(
                concert: concert,
                size: 52,
                borderRadius: 14,
                fallbackChild: Icon(
                  Icons.music_note_rounded,
                  color: concert.iconColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      concert.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkText : AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${concert.shortDate} · ${concert.venue}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textGrey,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2D3B4F) : const Color(0xFFF2F4F7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            concert.category,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.darkTextSecondary : const Color(0xFF475467),
                            ),
                          ),
                        ),
                        Text(
                          concert.formattedPrice,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.primaryDark : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textGrey,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DatePickerResult {
  final DateTime? date;
  final bool cleared;

  const _DatePickerResult({this.date, this.cleared = false});
}

class _ExploreDatePickerDialog extends StatefulWidget {
  final DateTime? initialDate;
  final Set<DateTime> eventDates;

  const _ExploreDatePickerDialog({
    required this.initialDate,
    required this.eventDates,
  });

  @override
  State<_ExploreDatePickerDialog> createState() => _ExploreDatePickerDialogState();
}

class _ExploreDatePickerDialogState extends State<_ExploreDatePickerDialog> {
  static const List<String> _monthNames = [
    '',
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  static const List<String> _weekdayHeaders = [
    'Min',
    'Sen',
    'Sel',
    'Rab',
    'Kam',
    'Jum',
    'Sab',
  ];

  static const int _minYear = 2024;
  static const int _maxYear = 2030;

  late DateTime _selected;
  late int _focusedMonth;
  late int _focusedYear;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final base = widget.initialDate ?? DateTime(now.year, now.month, now.day);
    final clampedYear = base.year.clamp(_minYear, _maxYear);
    _selected = DateTime(clampedYear, base.month, base.day);
    _focusedMonth = _selected.month;
    _focusedYear = _selected.year;
  }

  void _stepMonth(int delta) {
    var nextMonth = _focusedMonth + delta;
    var nextYear = _focusedYear;
    if (nextMonth < 1) {
      nextMonth = 12;
      nextYear -= 1;
    } else if (nextMonth > 12) {
      nextMonth = 1;
      nextYear += 1;
    }
    if (nextYear < _minYear || nextYear > _maxYear) return;
    setState(() {
      _focusedMonth = nextMonth;
      _focusedYear = nextYear;
    });
  }

  void _selectToday() {
    final now = DateTime.now();
    final clampedYear = now.year.clamp(_minYear, _maxYear);
    final today = DateTime(clampedYear, now.month, now.day);
    setState(() {
      _selected = today;
      _focusedMonth = today.month;
      _focusedYear = today.year;
    });
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstDayOfMonth = DateTime(_focusedYear, _focusedMonth, 1);
    final daysInMonth = DateTime(_focusedYear, _focusedMonth + 1, 0).day;
    final leadingEmpty = firstDayOfMonth.weekday % 7;

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header tanggal terpilih
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pilih Tanggal Konser',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textGrey,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_selected.day} ${_monthNames[_selected.month]} ${_selected.year}',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tutup kalender',
                    onPressed: () => Navigator.pop(context),
                    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                    icon: const Icon(Icons.close_rounded, color: AppColors.textGrey),
                  ),
                ],
              ),
              const Divider(height: 18, color: AppColors.border),

              // Pemilih Bulan & Tahun + navigasi panah
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: AppColors.searchBarBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _focusedMonth,
                          isExpanded: true,
                          icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.textDark),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                          items: List.generate(12, (idx) {
                            final m = idx + 1;
                            return DropdownMenuItem<int>(
                              value: m,
                              child: Text(_monthNames[m]),
                            );
                          }),
                          onChanged: (val) {
                            if (val == null) return;
                            final maxDay = DateTime(_focusedYear, val + 1, 0).day;
                            setState(() {
                              _focusedMonth = val;
                              _selected = DateTime(
                                _focusedYear,
                                _focusedMonth,
                                _selected.day.clamp(1, maxDay),
                              );
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: AppColors.searchBarBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _focusedYear,
                          isExpanded: true,
                          icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.textDark),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                          items: List.generate(_maxYear - _minYear + 1, (idx) {
                            final y = _minYear + idx;
                            return DropdownMenuItem<int>(
                              value: y,
                              child: Text('$y'),
                            );
                          }),
                          onChanged: (val) {
                            if (val == null) return;
                            final maxDay = DateTime(val, _focusedMonth + 1, 0).day;
                            setState(() {
                              _focusedYear = val;
                              _selected = DateTime(
                                _focusedYear,
                                _focusedMonth,
                                _selected.day.clamp(1, maxDay),
                              );
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Bulan sebelumnya',
                    onPressed: () => _stepMonth(-1),
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 44),
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.chevron_left_rounded, color: AppColors.textDark),
                  ),
                  IconButton(
                    tooltip: 'Bulan berikutnya',
                    onPressed: () => _stepMonth(1),
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 44),
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.chevron_right_rounded, color: AppColors.textDark),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Header nama hari
              Row(
                children: _weekdayHeaders
                    .map(
                      (label) => Expanded(
                        child: Center(
                          child: Text(
                            label,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textGrey,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 6),

              // Grid tanggal kalender
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                  childAspectRatio: 1.0,
                ),
                itemCount: leadingEmpty + daysInMonth,
                itemBuilder: (context, index) {
                  if (index < leadingEmpty) {
                    return const SizedBox.shrink();
                  }
                  final day = index - leadingEmpty + 1;
                  final cellDate = DateTime(_focusedYear, _focusedMonth, day);
                  final isSelected = _isSameDay(cellDate, _selected);
                  final isToday = _isSameDay(cellDate, today);
                  final hasConcert = widget.eventDates.contains(cellDate);

                  return Material(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: () => setState(() => _selected = cellDate),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: isToday && !isSelected
                              ? Border.all(color: AppColors.primary, width: 1.4)
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$day',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected || isToday ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? Colors.white : AppColors.textDark,
                              ),
                            ),
                            if (hasConcert)
                              Container(
                                margin: const EdgeInsets.only(top: 2),
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected ? Colors.white : AppColors.accent,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),

              // Baris tombol aksi bawah: Hapus, Today, dan Pilih
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context, const _DatePickerResult(cleared: true));
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textGrey,
                        minimumSize: const Size(44, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: const Text(
                        'Hapus',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _selectToday,
                          icon: const Icon(Icons.today_rounded, size: 16),
                          label: const Text('Today'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            minimumSize: const Size(44, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context, _DatePickerResult(date: _selected));
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            minimumSize: const Size(44, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          child: const Text('Pilih'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
