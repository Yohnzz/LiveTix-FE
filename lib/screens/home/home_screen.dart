import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../models/concert_model.dart';
import '../../models/user_model.dart';
import '../../services/data_service.dart';
import '../../widgets/user_avatar.dart';
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
  final int initialNavIndex;

  const HomeScreen({
    super.key,
    this.isGuest = true,
    this.userName = 'Guest',
    this.userInitials = 'G',
    this.initialNavIndex = 0,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const int _maxTrendingDisplayCount = 5;

  final DataService _dataService = DataService();

  int _selectedCategoryIndex = 0;
  bool _isFavoriteFilterActive = false;
  int _currentNavIndex = 0;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<String> _categories = const ['Semua', 'Pop', 'Rock', 'Indie'];

  List<ConcertModel> _featuredConcerts = [];
  List<ConcertModel> _concerts = [];
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _currentNavIndex = widget.initialNavIndex.clamp(0, 3);
    _loadData();
    if (widget.isGuest && !_dataService.hasAcceptedAgreement) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showInitialAgreementIfNeeded();
      });
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final featuredList = await _dataService.getFeaturedEvents();
      final events = await _dataService.getEvents();
      if (!mounted) return;
      setState(() {
        _featuredConcerts = featuredList;
        _concerts = events;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Gagal memuat jadwal konser. Coba muat ulang halaman.';
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showInitialAgreementIfNeeded() {
    if (!_dataService.hasAcceptedAgreement && mounted) {
      // AgreementDialog menutup dirinya sendiri lewat Navigator.pop() di tombol "Lanjutkan",
      // lalu status persetujuan disimpan ke penyimpanan lokal & sesi DataService.
      AgreementDialog.show(
        context,
        onAccepted: () {
          _dataService.acceptAgreement();
          if (mounted) setState(() {});
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

    // 1. Dual filter jika 'Disukai' aktif
    if (_isFavoriteFilterActive) {
      list = list.where((c) => _dataService.isFavorite(c.id)).toList();
    }

    // 2. Filter Kategori Genre jika bukan 'Semua'
    if (_selectedCategoryIndex != 0) {
      final selectedCategory = _categories[_selectedCategoryIndex];
      list = list
          .where((c) =>
              c.category.toLowerCase() == selectedCategory.toLowerCase())
          .toList();
    }

    // 3. Filter Search query jika diisi
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      list = list
          .where((c) =>
              c.title.toLowerCase().contains(q) ||
              c.subtitle.toLowerCase().contains(q) ||
              c.venue.toLowerCase().contains(q) ||
              c.category.toLowerCase().contains(q))
          .toList();
    }

    // Batasi maksimal 10 konser jika filtering menghasilkan lebih dari 10 konser
    if (list.length > 10) {
      list = list.take(10).toList();
    }
    return list;
  }

  /// Menampilkan maksimal 5 konser yang cocok dengan filter aktif pada dashboard Beranda
  List<ConcertModel> get _trendingConcerts =>
      _filteredConcerts.take(_maxTrendingDisplayCount).toList();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _dataService.isDarkModeNotifier,
      builder: (context, isDark, _) {
        return Scaffold(
          backgroundColor: AppColors.bg(context),
          body: _buildCurrentTabBody(),
          bottomNavigationBar: _buildBottomNav(),
        );
      },
    );
  }

  Widget _buildCurrentTabBody() {
    switch (_currentNavIndex) {
      case 1:
        return ExploreScreen(isGuest: widget.isGuest);
      case 2:
        return TicketScreen(isGuest: widget.isGuest);
      case 3:
        final currentUser = _dataService.currentUser;
        return ProfileScreen(
          isGuest: widget.isGuest,
          userName: widget.isGuest
              ? 'Guest'
              : (currentUser?.name ?? widget.userName),
          userEmail: widget.isGuest
              ? 'Belum masuk akun'
              : (currentUser?.email ?? ''),
          userInitials: widget.isGuest
              ? 'G'
              : (currentUser?.initials ?? widget.userInitials),
          onLogout: () {
            _dataService.logout();
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => const HomeScreen(
                  isGuest: true,
                  userName: 'Guest',
                  userInitials: 'G',
                ),
              ),
            );
          },
        );
      case 0:
      default:
        return _buildHomeTab();
    }
  }

  Widget _buildHomeTab() {
    final isDark = AppColors.isDark(context);
    final viewTop = MediaQuery.of(context).viewPadding.top;
    final topSpacing = viewTop > 0 ? viewTop + 14 : 28.0;
    final trendingList = _trendingConcerts;

    return SingleChildScrollView(
      padding: EdgeInsets.only(left: 20, right: 20, top: topSpacing, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopHeader(),
          const SizedBox(height: 16),

          _buildSearchBar(),
          const SizedBox(height: 18),

          _buildCategoryPills(),
          const SizedBox(height: 20),

          // Carousel Highlight Konser yang bisa digeser manual & bergeser otomatis
          if (_featuredConcerts.isNotEmpty) ...[
            FeaturedConcertCarousel(
              concerts: _featuredConcerts,
              onConcertTap: _openDetail,
            ),
            const SizedBox(height: 18),
          ],

          Text(
            'Konser Trending',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkText : AppColors.textDark,
            ),
          ),
          const SizedBox(height: 12),

          if (_isLoading)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: AppColors.primary),
                    const SizedBox(height: 10),
                    Text(
                      'Memuat jadwal konser...',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textGrey,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (_loadError != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
              alignment: Alignment.center,
              child: Column(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 38,
                    color: Color(0xFFB91C1C),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _loadError!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.darkText : AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: _loadData,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Coba Lagi'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (trendingList.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    size: 40,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textGrey,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _searchQuery.trim().isNotEmpty
                        ? 'Tidak ada konser untuk "${_searchQuery.trim()}". Coba kata kunci lain.'
                        : (_isFavoriteFilterActive
                            ? 'Belum ada konser favorit yang sesuai filter.'
                            : 'Belum ada konser untuk kategori ini.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textGrey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                        _selectedCategoryIndex = 0;
                        _isFavoriteFilterActive = false;
                      });
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: isDark ? AppColors.primaryDark : AppColors.primary,
                      minimumSize: const Size(44, 44),
                    ),
                    child: const Text('Tampilkan Semua Konser'),
                  ),
                ],
              ),
            )
          else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: trendingList.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return ConcertCard(
                  concert: trendingList[index],
                  onTap: () => _openDetail(trendingList[index]),
                );
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton(
                onPressed: () {
                  setState(() => _currentNavIndex = 1);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? AppColors.primaryDark : AppColors.primary,
                  backgroundColor: isDark ? AppColors.darkSurfaceVariant : const Color(0xFFF5F7FF),
                  side: BorderSide(
                    color: isDark ? AppColors.darkBorder : const Color(0xFFDCE3F6),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        'Lihat Semua konser yang ada',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.primaryDark : AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 17,
                      color: isDark ? AppColors.primaryDark : AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildTopHeader() {
    final isDark = AppColors.isDark(context);

    if (widget.isGuest) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.border,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? const Color(0x33000000) : const Color(0x0A101828),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isUltraCompact = constraints.maxWidth < 280;
            final loginButton = SizedBox(
              height: 44,
              width: isUltraCompact ? double.infinity : null,
              child: ElevatedButton(
                onPressed: _goToLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(76, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Masuk',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );

            final notifButton = _buildNotificationBadgeButton(isDark);

            final identityRow = Row(
              children: [
                const GuestAvatarIcon(size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Guest',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkText : AppColors.textDark,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ID : -',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );

            if (isUltraCompact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  identityRow,
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      notifButton,
                      const SizedBox(width: 8),
                      Expanded(child: loginButton),
                    ],
                  ),
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: identityRow),
                const SizedBox(width: 6),
                notifButton,
                const SizedBox(width: 8),
                loginButton,
              ],
            );
          },
        ),
      );
    }

    return ValueListenableBuilder<UserModel?>(
      valueListenable: _dataService.currentUserNotifier,
      builder: (context, activeUser, _) {
        final fullName =
            (activeUser != null && activeUser.name.trim().isNotEmpty)
                ? activeUser.name.trim()
                : widget.userName;
        final userId = activeUser != null
            ? activeUser.displayId
            : UserModel.generateSixCharId(fullName);
        final initials = activeUser?.initials ?? widget.userInitials;

        return Semantics(
          button: true,
          label: 'Buka profil akun $fullName',
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.border,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark ? const Color(0x33000000) : const Color(0x0A101828),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                onTap: () {
                  setState(() => _currentNavIndex = 3);
                },
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      UserAvatar(
                        initials: initials,
                        imageBytes: activeUser?.profileImageBytes,
                        colorIndex: activeUser?.avatarColorIndex ?? -1,
                        size: 48,
                        fontSize: 15,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.darkText : AppColors.textDark,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'ID : $userId',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.textGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Ikon Notifikasi dengan badge angka 1 2 3 di sebelah kiri tanda >
                      _buildNotificationBadgeButton(isDark),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 22,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textGrey,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Tombol notifikasi interaktif dengan badge penomoran di atas titik
  Widget _buildNotificationBadgeButton(bool isDark) {
    return Semantics(
      button: true,
      label: 'Notifikasi, 3 pesan belum dibaca',
      child: Tooltip(
        message: 'Notifikasi',
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: _showNotificationsSheet,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.notifications_outlined,
                      size: 24,
                      color: isDark ? AppColors.darkText : AppColors.textDark,
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(1.5),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE11D48),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? AppColors.darkSurface : Colors.white,
                            width: 1.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          '3',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Membuka lembar notifikasi interaktif saat ikon lonceng diklik
  void _showNotificationsSheet() {
    final isDark = AppColors.isDark(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF475569) : const Color(0xFFD0D5DD),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Notifikasi',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkText : AppColors.textDark,
                      ),
                    ),
                    Text(
                      '3 baru',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.primaryDark : AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildNotificationItem(
                  icon: Icons.confirmation_number_outlined,
                  title: 'Tiket Konser Terbit',
                  desc: 'E-tiket resmi dan QR Code gate kamu sudah aktif dan siap digunakan.',
                  time: '10 menit lalu',
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _buildNotificationItem(
                  icon: Icons.event_available_rounded,
                  title: 'Pengingat Konser',
                  desc: 'Konser Soundwave Fest 2026 di Malang akan berlangsung dalam 14 hari.',
                  time: '1 jam lalu',
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _buildNotificationItem(
                  icon: Icons.local_offer_outlined,
                  title: 'Promo Spesial Presale',
                  desc: 'Dapatkan potongan biaya admin transaksi untuk metode e-wallet pilihan minggu ini.',
                  time: '3 jam lalu',
                  isDark: isDark,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotificationItem({
    required IconData icon,
    required String title,
    required String desc,
    required String time,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : const Color(0xFFF8F9FC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE0EAFF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 20,
              color: isDark ? AppColors.primaryDark : AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkText : AppColors.textDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textGrey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textGrey,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final isDark = AppColors.isDark(context);

    return Semantics(
      label: 'Cari artis atau venue',
      textField: true,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.searchBg(context),
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
                  setState(() {
                    _searchQuery = val;
                  });
                },
                style: TextStyle(
                  fontSize: 13.5,
                  color: isDark ? AppColors.darkText : AppColors.textDark,
                ),
                decoration: InputDecoration(
                  hintText: 'Cari artis atau venue',
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
                tooltip: 'Hapus pencarian',
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                  });
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

  Widget _buildCategoryPills() {
    final isDark = AppColors.isDark(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Tombol Filter Disukai (dapat dikombinasikan dengan genre lain atau berdiri sendiri)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Semantics(
              button: true,
              selected: _isFavoriteFilterActive,
              label: 'Filter Disukai',
              child: Material(
                color: _isFavoriteFilterActive
                    ? (isDark ? const Color(0xFF831843) : const Color(0xFFFCE7F3))
                    : (isDark ? AppColors.darkSurface : Colors.white),
                borderRadius: BorderRadius.circular(22),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _isFavoriteFilterActive = !_isFavoriteFilterActive;
                    });
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
                        color: _isFavoriteFilterActive
                            ? AppColors.favoritePink
                            : (isDark ? AppColors.darkBorder : AppColors.border),
                        width: _isFavoriteFilterActive ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isFavoriteFilterActive
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 16,
                          color: _isFavoriteFilterActive
                              ? AppColors.favoritePink
                              : (isDark ? AppColors.darkTextSecondary : AppColors.textGrey),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Disukai',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: _isFavoriteFilterActive
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: _isFavoriteFilterActive
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
          ...List.generate(_categories.length, (index) {
            final isSelected = _selectedCategoryIndex == index;
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
                excludeSemantics: true,
                label: 'Kategori ${_categories[index]}',
                child: Material(
                  color: bgCol,
                  borderRadius: BorderRadius.circular(22),
                  child: InkWell(
                    onTap: () => setState(() => _selectedCategoryIndex = index),
                    borderRadius: BorderRadius.circular(22),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 10,
                      ),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: borderCol),
                      ),
                      child: Text(
                        _categories[index],
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

  Widget _buildBottomNav() {
    final isDark = AppColors.isDark(context);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.border,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Expanded(child: _buildNavItem(Icons.home_filled, 'Beranda', 0)),
              Expanded(child: _buildNavItem(Icons.explore_outlined, 'Jelajah', 1)),
              Expanded(
                child: _buildNavItem(Icons.confirmation_number_outlined, 'Tiket', 2),
              ),
              Expanded(
                child: _buildNavItem(Icons.person_outline_rounded, 'Akun', 3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isDark = AppColors.isDark(context);
    final isSelected = _currentNavIndex == index;
    final activeColor = isDark ? AppColors.primaryDark : AppColors.primary;
    final inactiveColor = isDark ? AppColors.darkTextSecondary : AppColors.textGrey;

    return Semantics(
      button: true,
      selected: isSelected,
      excludeSemantics: true,
      label: 'Tab $label',
      child: InkWell(
        onTap: () => _onBottomNavTapped(index),
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: isSelected ? activeColor : inactiveColor,
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? activeColor : inactiveColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
