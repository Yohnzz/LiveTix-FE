import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../models/concert_model.dart';
import '../concert/concert_detail_screen.dart';

class ExploreScreen extends StatefulWidget {
  final bool isGuest;

  const ExploreScreen({super.key, this.isGuest = false});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  int _selectedGenreIndex = 0;
  final List<String> _genres = const ['Semua', 'Pop', 'Rock', 'Indie', 'EDM'];

  final List<CityModel> _popularCities = const [
    CityModel(
      name: 'Malang',
      eventCount: 128,
      bgColor: Color(0xFFE8EEFB),
      textColor: Color(0xFF2563EB),
    ),
    CityModel(
      name: 'Jakarta',
      eventCount: 342,
      bgColor: Color(0xFFFCE7F3),
      textColor: Color(0xFFDB2777),
    ),
    CityModel(
      name: 'Bandung',
      eventCount: 210,
      bgColor: Color(0xFFFEF3C7),
      textColor: Color(0xFFD97706),
    ),
    CityModel(
      name: 'Surabaya',
      eventCount: 96,
      bgColor: Color(0xFFF3E8FF),
      textColor: Color(0xFF9333EA),
    ),
  ];

  final List<ConcertModel> _trendingConcerts = const [
    ConcertModel(
      id: 't1',
      title: 'Hindia — Pulang Tour',
      subtitle: 'Konser penutup album Menari Dengan Bayangan',
      date: '15 Nov',
      venue: 'Britama Arena, Jakarta',
      price: 350000,
      category: 'Indie',
      tag: 'Tur Solo · 17+',
      iconBgColor: Color(0xFFFCE7F3),
      iconColor: Color(0xFFDB2777),
    ),
    ConcertModel(
      id: 't2',
      title: 'Reality Club Akustik',
      subtitle: 'Sesi live intim dan bincang karya',
      date: '22 Nov',
      venue: 'Amphitheater UB',
      price: 150000,
      category: 'Indie',
      tag: 'Akustik · Semua Umur',
      iconBgColor: Color(0xFFFEF3C7),
      iconColor: Color(0xFFD97706),
    ),
    ConcertModel(
      id: 't3',
      title: 'Sheila On 7 Reunion',
      subtitle: 'Nostalgia lagu-lagu legendaris tanah air',
      date: '2 Des',
      venue: 'GOR Ken Arok',
      price: 275000,
      category: 'Pop',
      tag: 'Reuni Akbar · 17+',
      iconBgColor: Color(0xFFE0F2FE),
      iconColor: Color(0xFF2563EB),
    ),
  ];

  void _openConcertDetail(ConcertModel concert) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConcertDetailScreen(
          concert: concert,
          isGuest: widget.isGuest,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Jelajah
              const Text(
                'Jelajah',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Temukan konser & artis favoritmu',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textGrey,
                ),
              ),
              const SizedBox(height: 18),

              // Search Bar + Filter Button
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.searchBarBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.search, size: 20, color: Color(0xFF98A2B3)),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Cari artis, venue, atau kota',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF98A2B3),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.searchBarBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.tune_rounded,
                      color: AppColors.textDark,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Filter Chips Dropdown (Kota, Tanggal, Genre, dll.)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterDropdown(
                      label: 'Kota',
                      icon: Icons.location_on_outlined,
                    ),
                    const SizedBox(width: 10),
                    _buildFilterDropdown(
                      label: 'Tanggal',
                      icon: Icons.calendar_today_outlined,
                    ),
                    const SizedBox(width: 10),
                    _buildFilterDropdown(
                      label: 'Genre',
                    ),
                    const SizedBox(width: 10),
                    _buildFilterDropdown(
                      label: 'Harga',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Bagian Kota Populer
              const Text(
                'Kota populer',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _popularCities.map((city) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: _buildCityCard(city),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),

              // Bagian Genre
              const Text(
                'Genre',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(_genres.length, (index) {
                    final isSelected = _selectedGenreIndex == index;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedGenreIndex = index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF4C6FFF) : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: isSelected
                                ? null
                                : Border.all(color: AppColors.chipBorder, width: 1.2),
                          ),
                          child: Text(
                            _genres[index],
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              color: isSelected ? Colors.white : const Color(0xFF344054),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 24),

              // Bagian Trending Minggu Ini
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Trending minggu ini',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: const Text(
                      'Lihat semua',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Daftar Konser Trending
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _trendingConcerts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final concert = _trendingConcerts[index];
                  return _buildTrendingConcertCard(concert);
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterDropdown({required String label, IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.chipBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: AppColors.textGrey),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textGrey),
        ],
      ),
    );
  }

  Widget _buildCityCard(CityModel city) {
    return Column(
      children: [
        Container(
          width: 96,
          height: 64,
          decoration: BoxDecoration(
            color: city.bgColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text(
              city.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: city.textColor,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${city.eventCount} event',
          style: const TextStyle(
            fontSize: 11.5,
            color: AppColors.textGrey,
          ),
        ),
      ],
    );
  }

  Widget _buildTrendingConcertCard(ConcertModel concert) {
    return InkWell(
      onTap: () => _openConcertDetail(concert),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // Ikon Nada Musik Berlatar Pastel
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: concert.iconBgColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Icon(
                  Icons.music_note_rounded,
                  size: 26,
                  color: concert.iconColor,
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Info Konser
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    concert.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${concert.date} · ${concert.venue}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textGrey,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Harga Singkat (mis. Rp350rb)
            Text(
              concert.formattedPriceShort,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF4C6FFF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
