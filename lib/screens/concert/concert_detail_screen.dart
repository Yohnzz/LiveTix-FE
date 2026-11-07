import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_colors.dart';
import '../../data/db_dummy.dart';
import '../../models/concert_model.dart';
import '../../services/data_service.dart';
import '../../widgets/concert_media.dart';
import '../auth/login_screen.dart';
import '../checkout/select_ticket_screen.dart';

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

  late List<TicketTierModel> _tiers;

  @override
  void initState() {
    super.initState();
    if (widget.concert.ticketTiers.isNotEmpty) {
      _tiers = List.from(widget.concert.ticketTiers);
    } else {
      _tiers = List.from(DbDummy.concerts.first.ticketTiers);
    }
    _fetchFreshDetail();
  }

  Future<void> _fetchFreshDetail() async {
    final fresh = await DataService().getConcertById(widget.concert.id);
    if (fresh != null && fresh.ticketTiers.isNotEmpty && mounted) {
      setState(() {
        _tiers = List.from(fresh.ticketTiers);
        if (_selectedTierIndex >= _tiers.length) {
          _selectedTierIndex = 0;
        }
      });
    }
  }

  TicketTierModel get _selectedTier => _tiers[_selectedTierIndex];

  void _onOrderTicketPressed() {
    if (widget.isGuest || DataService().isGuest) {
      // Guest dibatasi: wajib login sebelum memesan tiket
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
                backgroundColor: AppColors.primary,
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
      // User terautentikasi: lanjut ke alur pemilihan tiket & pembayaran
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SelectTicketScreen(
            concert: widget.concert,
            initialTier: _selectedTier,
          ),
        ),
      );
    }
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
              // Bagian Paling Atas: Banner Highlight Persegi Panjang (Landscape)
              _buildHighlightHeaderBanner(),

              // Konten Detail
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 18),

                    // Kartu Info Tanggal & Lokasi
                    _buildScheduleLocationCard(),
                    const SizedBox(height: 24),

                    // Kategori Tiket
                    const Text(
                      'Kategori tiket',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Daftar Pilihan Kategori Tiket
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
            ],
          ),
        ),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  /// Menampilkan Banner Highlight Persegi Panjang di bagian paling atas Detail Konser.
  /// Otomatis merender foto banner penuh unggahan Produser jika tersedia,
  /// atau visual panggung highlight persegi panjang milik konser tersebut.
  Widget _buildHighlightHeaderBanner() {
    final viewTop = MediaQuery.of(context).viewPadding.top;
    final topSpacing = viewTop > 0 ? viewTop + 14 : 34.0;
    final bannerHeight = topSpacing + 206.0;

    return SizedBox(
      width: double.infinity,
      height: bannerHeight,
      child: ConcertHighlightBannerSurface(
        concert: widget.concert,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, topSpacing, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Baris Navigasi Atas (Back & Favorite dengan ukuran sentuh 44x44)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Semantics(
                    button: true,
                    label: 'Kembali',
                    child: Tooltip(
                      message: 'Kembali',
                      child: Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: () => Navigator.pop(context),
                          customBorder: const CircleBorder(),
                          child: const SizedBox(
                            width: 44,
                            height: 44,
                            child: Icon(
                              Icons.chevron_left_rounded,
                              color: AppColors.textDark,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  ValueListenableBuilder<Set<String>>(
                    valueListenable: DataService().favoriteConcertIdsNotifier,
                    builder: (context, favIds, _) {
                      final isFav = favIds.contains(widget.concert.id);
                      return Semantics(
                        button: true,
                        label: isFav
                            ? 'Hapus dari favorit'
                            : 'Simpan ke favorit',
                        child: Tooltip(
                          message: isFav
                              ? 'Hapus dari favorit'
                              : 'Simpan ke favorit',
                          child: Material(
                            color: Colors.white,
                            shape: const CircleBorder(),
                            child: InkWell(
                              onTap: () =>
                                  DataService().toggleFavorite(widget.concert.id),
                              customBorder: const CircleBorder(),
                              child: SizedBox(
                                width: 44,
                                height: 44,
                                child: Icon(
                                  isFav
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  color: isFav
                                      ? AppColors.favoritePink
                                      : const Color(0xFF64748B),
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),

              // Bagian Bawah Banner Highlight: Pita Kategori + Judul + Subtitle
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipPath(
                    clipper: _RibbonClipper(),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(10, 6, 18, 6),
                      color: AppColors.bannerYellow,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: Color(0xFF451A03),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              widget.concert.tag,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF451A03),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.concert.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.2,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.concert.subtitle.isNotEmpty
                        ? widget.concert.subtitle
                        : '${widget.concert.category} · Mulai ${widget.concert.formattedPrice}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleLocationCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Baris Tanggal & Waktu
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.concert.date.isNotEmpty
                            ? widget.concert.date
                            : 'Minggu, 12 Oktober 2026',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.concert.time.isNotEmpty
                            ? widget.concert.time
                            : 'Gerbang 17.00 · Mulai 19.00',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Baris Lokasi
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 22,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    widget.concert.venue,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketTierCard(
    TicketTierModel tier,
    bool isSelected,
    int index,
  ) {
    return GestureDetector(
      onTap: tier.isSoldOut
          ? null
          : () {
              setState(() => _selectedTierIndex = index);
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF8FAFC) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tier.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color:
                          tier.isSoldOut ? AppColors.textGrey : AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tier.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: tier.isSoldOut
                          ? const Color(0xFFB91C1C)
                          : AppColors.textGrey,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              tier.formattedPrice,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: tier.isSoldOut ? AppColors.textGrey : AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
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
                    style: TextStyle(fontSize: 12, color: AppColors.textGrey),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _selectedTier.formattedPrice,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _onOrderTicketPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Pesan tiket',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
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

class _RibbonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()
      ..lineTo(size.width - 10, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(size.width - 10, size.height)
      ..lineTo(0, size.height)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
