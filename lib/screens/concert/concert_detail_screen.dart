import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../models/concert_model.dart';
import '../auth/login_screen.dart';

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
  bool _isFavorite = false;

  late final List<TicketTierModel> _tiers;

  @override
  void initState() {
    super.initState();
    if (widget.concert.ticketTiers.isNotEmpty) {
      _tiers = widget.concert.ticketTiers;
    } else {
      // Default tiers sesuai desain Figma Soundwave Fest 2026
      _tiers = const [
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
      ];
    }
  }

  TicketTierModel get _selectedTier => _tiers[_selectedTierIndex];

  void _onOrderTicketPressed() {
    if (widget.isGuest) {
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
            style: TextStyle(fontSize: 13.5, color: AppColors.textGrey, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Nanti saja', style: TextStyle(color: AppColors.textGrey)),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Masuk Sekarang'),
            ),
          ],
        ),
      );
    } else {
      // User terautentikasi: lanjut ke alur pembayaran
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Tiket ${_selectedTier.name} (${_selectedTier.formattedPrice}) dipilih! Siap lanjut ke pembayaran.',
          ),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Konser Bergradasi Ungu-Magenta
            _buildHeaderBanner(),

            // Konten Detail
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),

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

                  const SizedBox(height: 100), // Spacing untuk bottom bar
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildHeaderBanner() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Baris Navigasi Atas (Back & Favorite)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chevron_left_rounded,
                        color: AppColors.textDark,
                        size: 28,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _isFavorite = !_isFavorite),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isFavorite ? Icons.favorite : Icons.favorite_border_rounded,
                        color: _isFavorite ? AppColors.accent : AppColors.accent,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Pita Kuning "★ Festival • 17+"
              ClipPath(
                clipper: _RibbonClipper(),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 6, 18, 6),
                  color: AppColors.bannerYellow,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, size: 14, color: Color(0xFF78350F)),
                      const SizedBox(width: 4),
                      Text(
                        widget.concert.tag,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF78350F),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Judul Konser
              Text(
                widget.concert.title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 4),

              // Subtitle
              Text(
                widget.concert.subtitle.isNotEmpty
                    ? widget.concert.subtitle
                    : 'Panggung utama, 12 jam nonstop',
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white70,
                ),
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
                        widget.concert.date.contains('Oktober')
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
                    widget.concert.venue.contains('Malang')
                        ? widget.concert.venue
                        : '${widget.concert.venue}, Malang',
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

  Widget _buildTicketTierCard(TicketTierModel tier, bool isSelected, int index) {
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tier.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: tier.isSoldOut ? AppColors.textGrey : AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tier.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: tier.isSoldOut ? Colors.redAccent : AppColors.textGrey,
                  ),
                ),
              ],
            ),
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
            Column(
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
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _onOrderTicketPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 32),
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
