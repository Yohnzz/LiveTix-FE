import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../models/concert_model.dart';
import '../../models/user_model.dart';
import '../../services/ai_backend_service.dart';
import '../../services/data_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/notification_bell_button.dart';
import '../../widgets/user_avatar.dart';
import '../auth/login_screen.dart';
import '../common/concert_ai_info_modal.dart';
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

  final AiBackendService _aiBackendService = AiBackendService();

  // ── AI Search State (Fitur AI Search) ─────────────────────────
  bool _isAiSearchMode = false;
  bool _isAiSearching = false;
  AiFilterModel? _activeAiFilter;
  List<ConcertModel> _aiSearchResults = [];
  String _aiSearchMessage = '';

  Future<void> _runAiSearch(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;
    setState(() {
      _isAiSearching = true;
      _aiSearchMessage = '';
      _aiSearchResults = [];
      _activeAiFilter = null;
    });
    final response = await _aiBackendService.searchConcerts(clean);
    if (!mounted) return;
    setState(() {
      _isAiSearching = false;
      _activeAiFilter = response.filter;
      _aiSearchResults = response.results;
      _aiSearchMessage = response.message;
    });
  }

  void _clearAiSearch() {
    setState(() {
      _isAiSearchMode = false;
      _isAiSearching = false;
      _activeAiFilter = null;
      _aiSearchResults = [];
      _aiSearchMessage = '';
      _searchController.clear();
      _searchQuery = '';
    });
  }

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
      await _dataService.fetchConcertsFromSupabase();
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
        settings: const RouteSettings(name: 'ConcertDetailScreen'),
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
          .where(
              (c) => c.category.toLowerCase() == selectedCategory.toLowerCase())
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

  /// Mengambil daftar konser highlight di bagian atas dashboard.
  /// Jika total konser > 7, sistem secara dinamis menyaring Top 4 konser dengan
  /// skor popularitas tertinggi (berdasarkan kombinasi penjualan tiket aktual & like).
  /// Jika konser <= 7, menggunakan konser highlight standar/default.
  List<ConcertModel> get _highlightConcerts {
    if (_concerts.length > 7) {
      final sorted = List<ConcertModel>.from(_concerts);
      sorted.sort((a, b) {
        final scoreA = _dataService.getConcertPopularityScore(a);
        final scoreB = _dataService.getConcertPopularityScore(b);
        if (scoreB != scoreA) return scoreB.compareTo(scoreA);
        final aLikes = _dataService.getConcertLikesCount(a.id) +
            (_dataService.isFavorite(a.id) ? 1 : 0);
        final bLikes = _dataService.getConcertLikesCount(b.id) +
            (_dataService.isFavorite(b.id) ? 1 : 0);
        return bLikes.compareTo(aLikes);
      });
      return sorted.take(4).toList();
    }

    if (_featuredConcerts.isNotEmpty) {
      return _featuredConcerts.take(4).toList();
    }
    return _concerts.take(4).toList();
  }

  /// Menampilkan konser trending yang cocok dengan filter aktif pada dashboard Beranda.
  /// Jika total konser > 7:
  /// - Diurutkan berdasarkan skor popularitas (1 tiket terjual bernilai 10 poin, 1 like bernilai 1 poin tambahan).
  /// - Konser teratas dari Highlight tetap diperbolehkan muncul di Trending.
  /// Jika total konser <= 7:
  /// - Diurutkan berdasarkan jumlah suka/like normal.
  List<ConcertModel> get _trendingConcerts {
    final list = List<ConcertModel>.from(_filteredConcerts);
    if (_concerts.length > 7) {
      list.sort((a, b) {
        final scoreA = _dataService.getConcertPopularityScore(a);
        final scoreB = _dataService.getConcertPopularityScore(b);
        if (scoreB != scoreA) return scoreB.compareTo(scoreA);
        final aLikes = _dataService.getConcertLikesCount(a.id) +
            (_dataService.isFavorite(a.id) ? 1 : 0);
        final bLikes = _dataService.getConcertLikesCount(b.id) +
            (_dataService.isFavorite(b.id) ? 1 : 0);
        return bLikes.compareTo(aLikes);
      });
      final maxDisplay = _concerts.length > 7 ? 8 : _maxTrendingDisplayCount;
      return list.take(maxDisplay).toList();
    }

    list.sort((a, b) {
      final aLikes = _dataService.getConcertLikesCount(a.id) +
          (_dataService.isFavorite(a.id) ? 1 : 0);
      final bLikes = _dataService.getConcertLikesCount(b.id) +
          (_dataService.isFavorite(b.id) ? 1 : 0);
      return bLikes.compareTo(aLikes);
    });
    return list.take(_maxTrendingDisplayCount).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        _dataService.isDarkModeNotifier,
        _dataService.favoriteConcertIdsNotifier,
        _dataService.stockVersionNotifier,
      ]),
      builder: (context, _) {
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
          userName:
              widget.isGuest ? 'Guest' : (currentUser?.name ?? widget.userName),
          userEmail:
              widget.isGuest ? 'Belum masuk akun' : (currentUser?.email ?? ''),
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

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          _loadData(),
          _dataService.fetchUserLikesFromSupabase(),
          _dataService.fetchUserTicketsFromSupabase(),
          NotificationService().load(),
        ]);
      },
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding:
            EdgeInsets.only(left: 20, right: 20, top: topSpacing, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopHeader(),
          const SizedBox(height: 16),

          _buildSearchBarWithAiToggle(),
          const SizedBox(height: 18),

          if (_isAiSearchMode) ...[
            if (_activeAiFilter != null && _activeAiFilter!.hasActiveFilter) ...[
              _buildAiFilterBadges(),
              const SizedBox(height: 10),
            ],
            _buildAiSearchResults(isDark),
          ] else ...[
            _buildCategoryPills(),
            const SizedBox(height: 20),

            // Carousel Highlight Konser yang bisa digeser manual & bergeser otomatis
            if (_highlightConcerts.isNotEmpty) ...[
              FeaturedConcertCarousel(
                concerts: _highlightConcerts,
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
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textGrey,
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
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textGrey,
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
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textGrey,
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
                      foregroundColor:
                          isDark ? AppColors.primaryDark : AppColors.primary,
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
                  foregroundColor:
                      isDark ? AppColors.primaryDark : AppColors.primary,
                  backgroundColor: isDark
                      ? AppColors.darkSurfaceVariant
                      : const Color(0xFFF5F7FF),
                  side: BorderSide(
                    color:
                        isDark ? AppColors.darkBorder : const Color(0xFFDCE3F6),
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
                          color: isDark
                              ? AppColors.primaryDark
                              : AppColors.primary,
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
        ],
        const SizedBox(height: 20),
      ],
    ),
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
                          color:
                              isDark ? AppColors.darkText : AppColors.textDark,
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
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textGrey,
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
                      Expanded(child: loginButton),
                    ],
                  ),
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: identityRow),
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
                  color: isDark
                      ? const Color(0x33000000)
                      : const Color(0x0A101828),
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
                        avatarUrl: activeUser?.avatarUrl,
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
                                color: isDark
                                    ? AppColors.darkText
                                    : AppColors.textDark,
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
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.textGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (!widget.isGuest && _dataService.currentUser != null)
                        const NotificationBellButton()
                      else
                        const SizedBox(width: 44),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 22,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textGrey,
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

  Widget _buildSearchBarWithAiToggle() {
    final isDark = AppColors.isDark(context);
    final borderColor = isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                label: _isAiSearchMode
                    ? 'Pencarian AI: ketik bahasa alami'
                    : 'Cari artis atau venue',
                textField: true,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: _isAiSearchMode
                        ? (isDark
                            ? const Color(0xFF1E1B4B)
                            : const Color(0xFFEEF2FF))
                        : (isDark
                            ? AppColors.darkSurfaceVariant
                            : AppColors.searchBg(context)),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _isAiSearchMode
                          ? const Color(0xFF6366F1)
                          : borderColor,
                      width: _isAiSearchMode ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isAiSearchMode
                            ? Icons.auto_awesome_rounded
                            : Icons.search,
                        size: 20,
                        color: _isAiSearchMode
                            ? const Color(0xFF6366F1)
                            : (isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.textGrey),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) {
                            if (_isAiSearchMode) {
                              setState(() {});
                            } else {
                              setState(() {
                                _searchQuery = val;
                              });
                            }
                          },
                          onSubmitted: _isAiSearchMode
                              ? _runAiSearch
                              : null,
                          textInputAction: _isAiSearchMode
                              ? TextInputAction.search
                              : TextInputAction.done,
                          style: TextStyle(
                            fontSize: 13.5,
                            color: isDark ? AppColors.darkText : AppColors.textDark,
                          ),
                          decoration: InputDecoration(
                            hintText: _isAiSearchMode
                                ? 'Contoh: konser rock di Malang tahun 2027...'
                                : 'Cari artis atau venue',
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.textGrey,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      if (_isAiSearchMode && _isAiSearching)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF6366F1)),
                          ),
                        )
                      else if (_isAiSearchMode && _searchController.text.isNotEmpty)
                        IconButton(
                          tooltip: 'Cari dengan AI',
                          onPressed: _isAiSearching
                              ? null
                              : () => _runAiSearch(_searchController.text),
                          constraints: const BoxConstraints(
                              minWidth: 36, minHeight: 36),
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.send_rounded,
                              size: 18, color: Color(0xFF6366F1)),
                        )
                      else if (!_isAiSearchMode && _searchQuery.isNotEmpty)
                        IconButton(
                          tooltip: 'Hapus kata kunci pencarian',
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                          constraints: const BoxConstraints(
                              minWidth: 36, minHeight: 36),
                          padding: EdgeInsets.zero,
                          icon: Icon(Icons.close_rounded,
                              size: 18,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.textGrey),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // ✨ Tombol Toggle AI Search
            Tooltip(
              message: _isAiSearchMode ? 'Kembali ke pencarian biasa' : 'Aktifkan AI Search',
              child: GestureDetector(
                onTap: () {
                  if (_isAiSearchMode) {
                    _clearAiSearch();
                  } else {
                    setState(() {
                      _isAiSearchMode = true;
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    gradient: _isAiSearchMode
                        ? const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: _isAiSearchMode
                        ? null
                        : (isDark
                            ? AppColors.darkSurface
                            : Colors.white),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _isAiSearchMode
                          ? Colors.transparent
                          : borderColor,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 16,
                        color: _isAiSearchMode
                            ? Colors.white
                            : const Color(0xFF6366F1),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'AI',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _isAiSearchMode
                              ? Colors.white
                              : const Color(0xFF6366F1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAiFilterBadges() {
    if (_activeAiFilter == null) return const SizedBox.shrink();
    final badges = _activeAiFilter!.filterBadges;
    if (badges.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          ...badges.map((b) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFC7D2FE)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome,
                        size: 12, color: Color(0xFF4338CA)),
                    const SizedBox(width: 5),
                    Text(
                      b,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4338CA),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildAiSearchResults(bool isDark) {
    if (_isAiSearching) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.8,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'AI sedang mencari konser yang sesuai...',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textGrey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_activeAiFilter == null && !_isAiSearching) {
      return _buildAiSearchGuide(isDark);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _aiSearchResults.isEmpty
                    ? 'Tidak Ada Hasil'
                    : 'Hasil AI Search (${_aiSearchResults.length})',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkText : AppColors.textDark,
                ),
              ),
            ),
            if (_aiSearchResults.isNotEmpty)
              Text(
                '${_aiSearchResults.length} konser',
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textGrey,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _aiSearchMessage,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.darkTextSecondary : AppColors.textGrey,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        if (_aiSearchResults.isEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 40,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textGrey,
                ),
                const SizedBox(height: 8),
                Text(
                  'Tidak ditemukan konser yang cocok dengan kriteria pencarian AI.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textGrey,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  icon: const Icon(Icons.tune_rounded, size: 16),
                  label: const Text('Reset & Cari Manual'),
                  onPressed: _clearAiSearch,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6366F1),
                    side: const BorderSide(color: Color(0xFF6366F1)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _aiSearchResults.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final concert = _aiSearchResults[index];
              return ConcertCard(
                concert: concert,
                onTap: () => _openDetail(concert),
              );
            },
          ),
        const SizedBox(height: 24),
        _buildAiConcertInfoButton(isDark),
      ],
    );
  }

  Widget _buildAiSearchGuide(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [
                      const Color(0xFF1E1B4B),
                      const Color(0xFF312E81).withValues(alpha: 0.5)
                    ]
                  : [
                      const Color(0xFFEEF2FF),
                      const Color(0xFFF5F3FF)
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF4338CA)
                  : const Color(0xFFC7D2FE),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded,
                      size: 18, color: Color(0xFF6366F1)),
                  const SizedBox(width: 8),
                  Text(
                    'AI Search Aktif',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Ketik dengan bahasa alami, contoh:',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textGrey,
                ),
              ),
              const SizedBox(height: 8),
              ...[
                '"Konser rock di Malang tahun 2027"',
                '"Artis indie tiket di bawah 150rb"',
                '"Konser Hindia atau Barasuara"',
              ].map(
                (ex) => Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.arrow_right_rounded,
                          size: 16, color: Color(0xFF6366F1)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            _searchController.text =
                                ex.replaceAll('"', '');
                            _runAiSearch(ex.replaceAll('"', ''));
                          },
                          child: Text(
                            ex,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontStyle: FontStyle.italic,
                              color: Color(0xFF4338CA),
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildAiConcertInfoButton(isDark),
      ],
    );
  }

  Widget _buildAiConcertInfoButton(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E293B)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.forum_outlined, size: 20, color: Color(0xFF6366F1)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Mau tanya detail konser tertentu?',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.darkText : AppColors.textDark,
              ),
            ),
          ),
          TextButton(
            onPressed: () => ConcertAiInfoModal.show(context),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF6366F1),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            child: const Text(
              'Tanya AI →',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
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
                    ? (isDark
                        ? const Color(0xFF831843)
                        : const Color(0xFFFCE7F3))
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
                            : (isDark
                                ? AppColors.darkBorder
                                : AppColors.border),
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
                              : (isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.textGrey),
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
                                ? (isDark
                                    ? const Color(0xFFF472B6)
                                    : AppColors.favoritePink)
                                : (isDark
                                    ? AppColors.darkText
                                    : AppColors.textDark),
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
              Expanded(
                  child: _buildNavItem(Icons.explore_outlined, 'Jelajah', 1)),
              Expanded(
                child: _buildNavItem(
                    Icons.confirmation_number_outlined, 'Tiket', 2),
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
    final inactiveColor =
        isDark ? AppColors.darkTextSecondary : AppColors.textGrey;

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
