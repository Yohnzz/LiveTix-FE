import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../models/concert_model.dart';
import '../auth/login_screen.dart';
import '../concert/concert_detail_screen.dart';
import '../explore/explore_screen.dart';
import '../profile/profile_screen.dart';
import '../ticket/ticket_screen.dart';
import 'widgets/agreement_dialog.dart';
import 'widgets/concert_card.dart';
import 'widgets/featured_concert_card.dart';

class HomeScreen extends StatefulWidget {
  final bool isGuest;
  final String userName;
  final String userInitials;

  const HomeScreen({
    super.key,
    this.isGuest = true,
    this.userName = 'Rafi',
    this.userInitials = 'RF',
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedCategoryIndex = 0;
  int _currentNavIndex = 0;
  bool _agreementAccepted = false;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<String> _categories = const ['Semua', 'Pop', 'Rock', 'Indie'];

  static const _soundwaveConcert = ConcertModel(
    id: 'featured-1',
    title: 'Soundwave Fest 2026',
    subtitle: 'Panggung utama, 12 jam nonstop',
    date: 'Minggu, 12 Oktober 2026',
    time: 'Gerbang 17.00 · Mulai 19.00',
    venue: 'Stadion Gajayana, Malang',
    price: 350000,
    category: 'Pop',
    tag: 'Festival • 17+',
    ticketTiers: [
      TicketTierModel(
        id: '1',
        name: 'Festival',
        description: 'Berdiri, area depan panggung',
        price: 350000,
      ),
      TicketTierModel(
        id: '2',
        name: 'Tribun',
        description: 'Tempat duduk bernomor',
        price: 220000,
      ),
      TicketTierModel(
        id: '3',
        name: 'VIP Lounge',
        description: 'Sold out',
        price: 750000,
        isSoldOut: true,
      ),
    ],
  );

  final List<ConcertModel> _concerts = const [
    ConcertModel(
      id: '1',
      title: 'Nadin Amizah',
      subtitle: 'Konser Selamat Ulang Tahun & Rayuan Perempuan Gila',
      date: '20 Okt',
      time: 'Gerbang 18.00 · Mulai 19.30',
      venue: 'Sasana Krida',
      price: 250000,
      category: 'Pop',
      tag: 'Konser Tunggal · Semua Umur',
      iconBgColor: Color(0xFFF7EEF8),
      iconColor: Color(0xFFC2185B),
      ticketTiers: [
        TicketTierModel(
          id: 'n1',
          name: 'Festival A',
          description: 'Berdiri depan panggung',
          price: 250000,
        ),
        TicketTierModel(
          id: 'n2',
          name: 'Tribun',
          description: 'Tempat duduk bebas',
          price: 175000,
        ),
      ],
    ),
    ConcertModel(
      id: '2',
      title: 'Feast Live Session',
      subtitle: 'Tur Membangun & Menghancurkan Malang',
      date: '28 Okt',
      time: 'Gerbang 17.30 · Mulai 19.00',
      venue: 'Kayutangan',
      price: 180000,
      category: 'Rock',
      tag: 'Rock Session · 17+',
      iconBgColor: Color(0xFFE9EEF8),
      iconColor: Color(0xFF1B2A8C),
      ticketTiers: [
        TicketTierModel(
          id: 'f1',
          name: 'General Admission',
          description: 'Akses seluruh arena',
          price: 180000,
        ),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.isGuest) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showInitialAgreementIfNeeded();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showInitialAgreementIfNeeded() {
    if (!_agreementAccepted && mounted) {
      AgreementDialog.show(
        context,
        onAccepted: () {
          setState(() {
            _agreementAccepted = true;
          });
        },
      );
    }
  }

  void _goToLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _openDetail(ConcertModel concert) {
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

  void _onBottomNavTapped(int index) {
    setState(() {
      _currentNavIndex = index;
    });
  }

  List<ConcertModel> get _filteredConcerts {
    var list = _concerts;
    if (_selectedCategoryIndex != 0) {
      final selectedCategory = _categories[_selectedCategoryIndex];
      list = list.where((c) => c.category == selectedCategory).toList();
    }
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      list = list
          .where((c) =>
              c.title.toLowerCase().contains(q) ||
              c.venue.toLowerCase().contains(q) ||
              c.category.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _buildCurrentTabBody(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildCurrentTabBody() {
    switch (_currentNavIndex) {
      case 1:
        return ExploreScreen(isGuest: widget.isGuest);
      case 2:
        return TicketScreen(isGuest: widget.isGuest);
      case 3:
        return ProfileScreen(
          isGuest: widget.isGuest,
          userName: widget.userName.contains(' ')
              ? widget.userName
              : '${widget.userName} Firmansyah',
          userEmail: 'rafi@email.com',
          userInitials: widget.userInitials,
          onLogout: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen(isGuest: true)),
            );
          },
        );
      case 0:
      default:
        return _buildHomeTab();
    }
  }

  Widget _buildHomeTab() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Bagian Atas
            _buildTopHeader(),
            const SizedBox(height: 20),

            // Search Bar Interaktif
            _buildSearchBar(),
            const SizedBox(height: 18),

            // Category Filter Pills
            _buildCategoryPills(),
            const SizedBox(height: 20),

            // Featured Concert Banner ("Soundwave Fest 2026")
            FeaturedConcertCard(
              onTap: () => _openDetail(_soundwaveConcert),
            ),
            const SizedBox(height: 24),

            // Section Segera Hadir
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Segera hadir',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() => _currentNavIndex = 1);
                  },
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

            // Daftar Konser / Empty State Pencarian
            if (_filteredConcerts.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 36),
                alignment: Alignment.center,
                child: Column(
                  children: [
                    const Icon(Icons.search_off_rounded, size: 40, color: AppColors.textGrey),
                    const SizedBox(height: 8),
                    Text(
                      'Tidak ada konser untuk "$_searchQuery"',
                      style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredConcerts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return ConcertCard(
                    concert: _filteredConcerts[index],
                    onTap: () => _openDetail(_filteredConcerts[index]),
                  );
                },
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Halo, ${widget.userName}',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textGrey,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Malam ini ada apa?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),

        // Action di kanan atas
        if (widget.isGuest)
          // Tampilan Guest: Tombol bulat dengan ikon profil outline -> navigasi ke Login
          GestureDetector(
            onTap: _goToLogin,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
              child: const Icon(
                Icons.person_outline_rounded,
                size: 22,
                color: AppColors.textDark,
              ),
            ),
          )
        else
          // Tampilan User yang sudah login: Ikon Sun/Tema + Avatar RF
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.wb_sunny_outlined, size: 22, color: AppColors.textDark),
                onPressed: () {
                  // Toggle tema atau preferensi
                },
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () {
                  setState(() => _currentNavIndex = 3);
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.avatarBg,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      widget.userInitials,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.avatarText,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.searchBarBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 20, color: Color(0xFF98A2B3)),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              style: const TextStyle(fontSize: 13.5, color: AppColors.textDark),
              decoration: const InputDecoration(
                hintText: 'Cari artis atau venue',
                hintStyle: TextStyle(fontSize: 13, color: Color(0xFF98A2B3)),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                });
              },
              child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF98A2B3)),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryPills() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(_categories.length, (index) {
          final isSelected = _selectedCategoryIndex == index;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () => setState(() => _selectedCategoryIndex = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF1D2024) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: isSelected
                      ? null
                      : Border.all(color: AppColors.chipBorder, width: 1.2),
                ),
                child: Text(
                  _categories[index],
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
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, Icons.home_outlined, Icons.home, 'Beranda'),
            _buildNavItem(1, Icons.search_outlined, Icons.search, 'Jelajah'),
            _buildNavItem(2, Icons.confirmation_number_outlined, Icons.confirmation_number, 'Tiket'),
            _buildNavItem(3, Icons.person_outline, Icons.person, 'Akun'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData outlineIcon, IconData filledIcon, String label) {
    final isSelected = _currentNavIndex == index;
    final color = isSelected ? AppColors.primary : AppColors.textGrey;

    return GestureDetector(
      onTap: () => _onBottomNavTapped(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSelected ? filledIcon : outlineIcon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
