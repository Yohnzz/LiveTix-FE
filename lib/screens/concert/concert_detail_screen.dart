import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_colors.dart';
import '../../models/concert_model.dart';
import '../../services/data_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/concert_media.dart';
import '../auth/login_screen.dart';
import '../checkout/select_ticket_screen.dart';
import '../promoter/widgets/concert_image_widget.dart';

class ConcertDetailScreen extends StatefulWidget {
  final ConcertModel concert;
  final bool isGuest;

  const ConcertDetailScreen({
    super.key,
    required this.concert,
    this.isGuest = false,
  });

  @override
  State<ConcertDetailScreen> createState() => _ConcertDetailScreenState();
}

class _ConcertDetailScreenState extends State<ConcertDetailScreen> {
  int _selectedTierIndex = 0;
  late ConcertModel _currentConcert;
  late List<TicketTierModel> _tiers;

  /// Avatar dan nama produser yang di-fetch langsung dari tabel `profiles`.
  String? _producerAvatarUrlFetched;
  String? _producerNameFetched;

  @override
  void initState() {
    super.initState();
    _currentConcert = widget.concert;
    _tiers = List.from(widget.concert.ticketTiers);
    DataService().stockVersionNotifier.addListener(_onRealtimeStockUpdate);
    _fetchFreshDetail();
    _fetchProducerProfile();
  }

  @override
  void dispose() {
    DataService().stockVersionNotifier.removeListener(_onRealtimeStockUpdate);
    super.dispose();
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(fn);
      });
    } else {
      setState(fn);
    }
  }

  void _applyConcert(ConcertModel? concert) {
    if (concert == null || !mounted) return;
    _safeSetState(() {
      _currentConcert = concert;
      if (concert.ticketTiers.isNotEmpty) {
        _tiers = List.from(concert.ticketTiers);
        if (_selectedTierIndex >= _tiers.length) {
          _selectedTierIndex = 0;
        }
      }
    });
  }

  void _onRealtimeStockUpdate() {
    _applyConcert(DataService().cachedConcertById(widget.concert.id));
  }

  Future<void> _fetchFreshDetail() async {
    final fresh = await DataService().getConcertById(widget.concert.id);
    _applyConcert(fresh);
  }

  /// Ambil foto & nama produser langsung dari tabel `profiles` berdasarkan `producer_id`.
  Future<void> _fetchProducerProfile() async {
    final producerId = widget.concert.producerId;
    if (producerId == null || producerId.isEmpty) return;
    if (!SupabaseService.isInitialized) return;
    try {
      final row = await Supabase.instance.client
          .from('profiles')
          .select('name, full_name, url_foto, avatar_url')
          .eq('id', producerId)
          .maybeSingle();
      if (row != null && mounted) {
        final avatar =
            (row['url_foto'] ?? row['avatar_url'])?.toString();
        final name =
            (row['name'] ?? row['full_name'])?.toString();
        _safeSetState(() {
          if (avatar?.isNotEmpty == true) _producerAvatarUrlFetched = avatar;
          if (name?.isNotEmpty == true) _producerNameFetched = name;
        });
      }
    } catch (e) {
      debugPrint('_fetchProducerProfile error: $e');
    }
  }

  TicketTierModel? get _selectedTier =>
      _tiers.isNotEmpty && _selectedTierIndex < _tiers.length
          ? _tiers[_selectedTierIndex]
          : null;

  void _onOrderTicketPressed() {
    final activeTier = _selectedTier;
    if (activeTier == null || activeTier.isEffectivelySoldOut) return;

    if (widget.isGuest || DataService().isGuest) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Wajib Masuk',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          content: const Text(
            'Untuk memesan tiket konser ini, silakan masuk dengan akun LiveTix terlebih dahulu.',
            style: TextStyle(
              fontSize: 13.5,
              color: AppColors.textGrey,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Nanti saja',
                style: TextStyle(color: AppColors.textGrey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B2A8C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Masuk Sekarang'),
            ),
          ],
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SelectTicketScreen(
            concert: _currentConcert.copyWith(ticketTiers: _tiers),
            initialTier: _selectedTier,
          ),
        ),
      );
    }
  }

  void _onFavoritePressed() {
    if (widget.isGuest || DataService().isGuest) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Wajib Masuk',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          content: const Text(
            'Untuk menyimpan konser ke favorit Anda, silakan masuk dengan akun LiveTix terlebih dahulu.',
            style: TextStyle(
              fontSize: 13.5,
              color: AppColors.textGrey,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Nanti saja',
                style: TextStyle(color: AppColors.textGrey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B2A8C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Masuk Sekarang'),
            ),
          ],
        ),
      );
      return;
    }
    DataService().toggleFavorite(_currentConcert.id);
  }

  void _showHighlightPreview(BuildContext context, String imageUrl, int index) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black.withValues(alpha: 0.9),
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ConcertImageWidget(
                  imageSource: imageUrl,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        },
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Hero Banner Atas dengan Foto, Badges, Judul & Metadata
              _buildHeroBanner(),

              // 2. Lembar Konten Utama (Berlatar Putih dengan Rounded Corners Atas)
              Transform.translate(
                offset: const Offset(0, -26),
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Kartu Informasi Produser (Foto, Badge 👑 Produser, Nama)
                      _buildProducerCard(),
                      const SizedBox(height: 20),

                      // Galeri Highlights Panggung (Jika produser menambahkan foto highlight)
                      if (_currentConcert.highlights.isNotEmpty) ...[
                        _buildHighlightGallery(),
                        const SizedBox(height: 24),
                      ],

                      // Bagian Deskripsi Konser
                      _buildDescriptionSection(),
                      const SizedBox(height: 24),

                      // Bagian Kategori Tiket
                      const Text(
                        'Kategori tiket',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Daftar Pilihan Kategori Tiket
                      if (_tiers.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline, color: AppColors.textGrey, size: 20),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Kategori tiket untuk konser ini sedang disiapkan oleh promotor.',
                                  style: TextStyle(fontSize: 13, color: AppColors.textGrey),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ...List.generate(_tiers.length, (index) {
                          final tier = _tiers[index];
                          final isSelected = _selectedTierIndex == index;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildTicketTierCard(tier, isSelected, index),
                          );
                        }),

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  /// Menampilkan Hero Banner Penuh di bagian atas dengan foto konser, tombol kembali,
  /// tombol favorit, pesan singkat badges, judul tebal, serta tanggal & lokasi.
  Widget _buildHeroBanner() {
    final viewTop = MediaQuery.of(context).viewPadding.top;
    final topPadding = viewTop > 0 ? viewTop + 12 : 36.0;

    final shortMessages = _currentConcert.shortMessages.isNotEmpty
        ? _currentConcert.shortMessages
        : const ['Festival • 17+', 'Seru!'];

    final rawDate = _currentConcert.date.isNotEmpty
        ? _currentConcert.date
        : 'Rabu, 25 November 2026';
    final cleanDate = rawDate.replaceAll(
      RegExp(r'(\s*[-–—·•|]\s*\d{1,2}[:.]\d{2}(\s*WIB)?)+', caseSensitive: false),
      '',
    ).trim();
    final displayDate = cleanDate.isNotEmpty ? cleanDate : rawDate;
    final displayTime = _currentConcert.time.isNotEmpty
        ? _currentConcert.time
        : '19:00 WIB';
    final displayVenue = _currentConcert.venue.isNotEmpty
        ? _currentConcert.venue
        : 'Lapangan Tumapel';

    return SizedBox(
      width: double.infinity,
      child: Stack(
        children: [
          // Banner Image & Gradient Scrim Surface
          Positioned.fill(
            child: ConcertHighlightBannerSurface(
              concert: _currentConcert,
              child: const SizedBox.expand(),
            ),
          ),

          // Lapisan Gradien Hitam Halus dari Bawah agar teks putih dan badges kontras
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.25),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.55),
                    Colors.black.withValues(alpha: 0.85),
                  ],
                  stops: const [0.0, 0.35, 0.70, 1.0],
                ),
              ),
            ),
          ),

          // Konten Header Banner
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, topPadding > 40 ? 12 : 16, 20, 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Baris Navigasi Atas (Kembali & Favorit)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Tombol Kembali Putih
                      Semantics(
                        button: true,
                        label: 'Kembali',
                        child: Material(
                          color: Colors.white,
                          shape: const CircleBorder(),
                          elevation: 2,
                          child: InkWell(
                            onTap: () => Navigator.pop(context),
                            customBorder: const CircleBorder(),
                            child: const SizedBox(
                              width: 44,
                              height: 44,
                              child: Icon(
                                Icons.chevron_left_rounded,
                                color: Color(0xFF0F172A),
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Tombol Favorit Putih
                      ValueListenableBuilder<Set<String>>(
                        valueListenable: DataService().favoriteConcertIdsNotifier,
                        builder: (context, favIds, _) {
                          final isFav = favIds.contains(_currentConcert.id);
                          return Semantics(
                            button: true,
                            label: isFav ? 'Hapus dari favorit' : 'Simpan ke favorit',
                            child: Material(
                              color: Colors.white,
                              shape: const CircleBorder(),
                              elevation: 2,
                              child: InkWell(
                                onTap: _onFavoritePressed,
                                customBorder: const CircleBorder(),
                                child: SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: Icon(
                                    isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                    color: isFav ? AppColors.favoritePink : const Color(0xFF64748B),
                                    size: 22,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 70),

                  // Baris Pesan Singkat / Badges Kuning (Maks 3, misal: ★ Festival • 17+, 🔥 Seru!)
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: List.generate(shortMessages.length, (idx) {
                      final msg = shortMessages[idx];
                      final icon = idx == 0
                          ? Icons.star_rounded
                          : (idx == 1 ? Icons.local_fire_department_rounded : Icons.campaign_rounded);
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFBBF24), // Warm yellow pill from design
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 14, color: const Color(0xFF1E1B4B)),
                            const SizedBox(width: 4),
                            Text(
                              msg,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E1B4B),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 10),

                  // Judul Konser (Teks Tebal Putih)
                  Text(
                    _currentConcert.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                      height: 1.15,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Baris Tanggal, Waktu & Lokasi Konser
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 15,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$displayDate – $displayTime',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const Text(
                        '|',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 14,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 17,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            displayVenue,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Kartu Produser (Foto Profil di kiri, badge 👑 Produser di atas nama produser tebal)
  Widget _buildProducerCard() {
    final producerName = (_producerNameFetched?.isNotEmpty == true)
        ? _producerNameFetched!
        : ((_currentConcert.producerName?.isNotEmpty == true)
            ? _currentConcert.producerName!.trim()
            : 'Java Promotor');

    final avatarSource = _producerAvatarUrlFetched ??
        _currentConcert.producerAvatarUrl ??
        _currentConcert.logoImageUrl ??
        '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF6F8FE),
            Color(0xFFEFF3FF),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE2E8F8),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          // Foto Profil / Avatar Produser (persegi rounded 76x76)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 76,
              height: 76,
              child: ConcertImageWidget(
                imageSource: avatarSource.isNotEmpty ? avatarSource : null,
                fit: BoxFit.cover,
                fallbackIcon: Icons.person_rounded,
                fallbackLabel: 'Produser',
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Detail Produser (Badge 👑 Produser + Nama Produser)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Badge Pill 👑 Produser
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B2A8C), // Royal blue matching image
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('👑', style: TextStyle(fontSize: 11)),
                      SizedBox(width: 5),
                      Text(
                        'Produser',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                // Nama Produser Tebal
                Text(
                  producerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Galeri Highlights Panggung Konser (Disusun responsif: 3 gambar bersisian pada layar lebar / scroll horizontal rapi pada hp)
  Widget _buildHighlightGallery() {
    final highlights = _currentConcert.highlights;
    if (highlights.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;

        // Tampilan Desktop / Tablet: 3 Foto Bersisian Penuh
        if (isWide && highlights.length >= 3) {
          return Row(
            children: List.generate(3, (index) {
              final img = highlights[index];
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: index < 2 ? 12.0 : 0.0,
                  ),
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: InkWell(
                      onTap: () => _showHighlightPreview(context, img, index),
                      borderRadius: BorderRadius.circular(16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: ConcertImageWidget(
                          imageSource: img,
                          fit: BoxFit.cover,
                          fallbackIcon: Icons.photo_camera_back_outlined,
                          fallbackLabel: 'Highlight #${index + 1}',
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          );
        }

        // Tampilan Responsif Smartphone / Layar Ponsel: Horizontal scrollable cards dengan tap preview
        final cardWidth = constraints.maxWidth * 0.75 > 280 ? 280.0 : constraints.maxWidth * 0.75;
        const cardHeight = 150.0;

        return SizedBox(
          height: cardHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: highlights.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final img = highlights[index];
              return SizedBox(
                width: cardWidth,
                child: InkWell(
                  onTap: () => _showHighlightPreview(context, img, index),
                  borderRadius: BorderRadius.circular(16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: ConcertImageWidget(
                      imageSource: img,
                      width: cardWidth,
                      height: cardHeight,
                      fit: BoxFit.cover,
                      fallbackIcon: Icons.photo_camera_back_outlined,
                      fallbackLabel: 'Highlight #${index + 1}',
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// Bagian Deskripsi Konser yang ditaruh di bawah galeri highlight
  Widget _buildDescriptionSection() {
    final descriptionText = _currentConcert.description.isNotEmpty
        ? _currentConcert.description
        : 'Nikmati pertunjukan musik spektakuler dengan penampilan langsung memukau, tata panggung megah, dan pengalaman festival tak terlupakan bersama ribuan penonton.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Deskripsi',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          descriptionText,
          style: const TextStyle(
            fontSize: 14,
            height: 1.55,
            color: Color(0xFF475569),
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  /// Kartu Kategori Tiket dengan Nama Kategori, Green Tag Tiket Tersedia, dan Harga Rp
  Widget _buildTicketTierCard(
    TicketTierModel tier,
    bool isSelected,
    int index,
  ) {
    final soldOut = tier.isEffectivelySoldOut;
    final available = tier.availableStock;

    return GestureDetector(
      onTap: soldOut
          ? null
          : () {
              setState(() => _selectedTierIndex = index);
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: soldOut
              ? const Color(0xFFF3F4F6)
              : (isSelected ? const Color(0xFFF8FAFC) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: soldOut
                ? const Color(0xFFE5E7EB)
                : (isSelected ? const Color(0xFF1B2A8C) : const Color(0xFFCBD5E1)),
            width: isSelected && !soldOut ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Wrap(
                spacing: 10,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    tier.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: soldOut ? AppColors.textGrey : const Color(0xFF0F172A),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: soldOut
                          ? const Color(0xFFFEE2E2)
                          : const Color(0xFFE8FDF0), // Mint green from design
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      soldOut
                          ? 'Tiket Habis'
                          : 'Tiket Tersedia: $available',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: soldOut
                            ? const Color(0xFFB91C1C)
                            : const Color(0xFF039855), // Emerald green from design
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              tier.formattedPrice,
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                color: soldOut ? AppColors.textGrey : const Color(0xFF1B2A8C),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Bar Navigasi Bawah Sticky (Total Harga di kiri, Tombol Pesan tiket di kanan)
  Widget _buildBottomBar() {
    final tier = _selectedTier;
    final hasTier = tier != null;
    final soldOut = hasTier && tier.isEffectivelySoldOut;

    final totalPriceText = hasTier
        ? tier.formattedPrice
        : (_currentConcert.price > 0
            ? _currentConcert.formattedPrice
            : 'Rp 0');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    totalPriceText,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1B2A8C),
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: hasTier && !soldOut ? _onOrderTicketPressed : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B2A8C), // Deep blue from screenshot
                  foregroundColor: Colors.white,
                  elevation: 0,
                  disabledBackgroundColor: const Color(0xFFE2E8F0),
                  disabledForegroundColor: const Color(0xFF94A3B8),
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  !hasTier
                      ? 'Tiket Belum Tersedia'
                      : (soldOut ? 'Tiket Habis' : 'Pesan tiket'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
