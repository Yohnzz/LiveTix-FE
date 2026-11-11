import 'package:flutter/material.dart';
import '../../models/promoter_models.dart';
import '../../services/promoter_data_service.dart';
import 'add_concert/add_concert_flow.dart';
import 'concert_status_detail_screen.dart';
import 'promoter_manage_concert_screen.dart';
import 'widgets/concert_image_widget.dart';

class PromoterConcertListScreen extends StatefulWidget {
  final VoidCallback? onAddConcertPressed;

  const PromoterConcertListScreen({
    super.key,
    this.onAddConcertPressed,
  });

  @override
  State<PromoterConcertListScreen> createState() =>
      _PromoterConcertListScreenState();
}

class _PromoterConcertListScreenState extends State<PromoterConcertListScreen> {
  ConcertStatus _selectedStatus = ConcertStatus.semua;
  bool _showCompletedHistory = false; // false = Aktif, true = Selesai (Riwayat)
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    PromoterDataService().fetchPromoterConcertsFromSupabase();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openAddConcertWizard() {
    if (widget.onAddConcertPressed != null) {
      widget.onAddConcertPressed!();
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AddConcertFlow()),
      );
    }
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

        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _openAddConcertWizard,
            backgroundColor: const Color(0xFF1B2A8C),
            elevation: 3,
            icon: const Icon(Icons.add, color: Colors.white, size: 20),
            label: const Text(
              'Tambah Konser',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Daftar Konser',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Kelola seluruh pertunjukan dan pengajuan Anda',
                            style: TextStyle(
                              fontSize: 13,
                              color: subtextColor,
                            ),
                          ),
                        ],
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
                      tooltip: 'Ganti Tema',
                      onPressed: service.toggleTheme,
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Quota Alert Banner (Pink border & pink text)
                ValueListenableBuilder<int>(
                  valueListenable: service.quotaRemainingNotifier,
                  builder: (context, remainingQuota, _) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? const Color(0xFF2A1525)
                            : const Color(0xFFFDF2F8),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFC2185B).withValues(alpha: 0.5),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: Color(0xFFC2185B),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Sisa kuota pengajuan: $remainingQuota dari maksimal ${service.quotaMax} konser per hari.',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFC2185B),
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),

                // Toggle Filter Aktif vs Selesai (Riwayat Konser & Pendapatan)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _showCompletedHistory = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: !_showCompletedHistory
                                  ? const Color(0xFF1B2A8C)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Aktif',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: !_showCompletedHistory
                                    ? Colors.white
                                    : subtextColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _showCompletedHistory = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _showCompletedHistory
                                  ? const Color(0xFF1B2A8C)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Selesai (Riwayat)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _showCompletedHistory
                                    ? Colors.white
                                    : subtextColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Horizontal Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(
                        status: ConcertStatus.semua,
                        label: 'Semua',
                        isDarkMode: isDarkMode,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        status: ConcertStatus.draft,
                        label: 'Draft',
                        isDarkMode: isDarkMode,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        status: ConcertStatus.menunggu,
                        label: 'Menunggu',
                        isDarkMode: isDarkMode,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        status: ConcertStatus.disetujui,
                        label: 'Disetujui',
                        isDarkMode: isDarkMode,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        status: ConcertStatus.ditolak,
                        label: 'Ditolak',
                        isDarkMode: isDarkMode,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Search Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: cardBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                            alpha: isDarkMode ? 0.2 : 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) =>
                        setState(() => _searchQuery = val.trim().toLowerCase()),
                    style: TextStyle(fontSize: 13.5, color: textColor),
                    decoration: InputDecoration(
                      icon: const Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: Color(0xFF667085),
                      ),
                      border: InputBorder.none,
                      hintText: 'Cari konser atau venue Anda...',
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF98A2B3),
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // List of Concert Cards
                ValueListenableBuilder<List<PromoterConcertItem>>(
                  valueListenable: service.concertsNotifier,
                  builder: (context, allConcerts, _) {
                    final filtered = allConcerts.where((item) {
                      if (_showCompletedHistory != item.isCompleted) {
                        return false;
                      }
                      final matchesStatus =
                          _selectedStatus == ConcertStatus.semua ||
                              item.status == _selectedStatus;
                      final matchesSearch = _searchQuery.isEmpty ||
                          item.title.toLowerCase().contains(_searchQuery) ||
                          item.venueName
                              .toLowerCase()
                              .contains(_searchQuery);
                      return matchesStatus && matchesSearch;
                    }).toList();

                    if (filtered.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        alignment: Alignment.center,
                        child: Column(
                          children: [
                            Icon(
                              Icons.event_busy_rounded,
                              size: 48,
                              color: subtextColor.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Tidak ada konser ditemukan',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: subtextColor,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return LayoutBuilder(
                      builder: (context, listConstraints) {
                        final isDesktop = listConstraints.maxWidth >= 900;
                        final isWideDesktop = listConstraints.maxWidth >= 1350;

                        if (isDesktop) {
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: isWideDesktop ? 3 : 2,
                              mainAxisExtent: 185,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                            ),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final concert = filtered[index];
                              return _buildConcertCard(
                                concert: concert,
                                cardBg: cardBg,
                                cardBorder: cardBorder,
                                textColor: textColor,
                                subtextColor: subtextColor,
                                isDarkMode: isDarkMode,
                              );
                            },
                          );
                        }

                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final concert = filtered[index];
                            return _buildConcertCard(
                              concert: concert,
                              cardBg: cardBg,
                              cardBorder: cardBorder,
                              textColor: textColor,
                              subtextColor: subtextColor,
                              isDarkMode: isDarkMode,
                            );
                          },
                        );
                      },
                    );
                  },
                ),

                const SizedBox(height: 70), // Spacing for FAB
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterChip({
    required ConcertStatus status,
    required String label,
    required bool isDarkMode,
  }) {
    final isSelected = _selectedStatus == status;

    return InkWell(
      onTap: () => setState(() => _selectedStatus = status),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1B2A8C) // Active Navy
              : (isDarkMode ? const Color(0xFF1B2232) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF1B2A8C)
                : (isDarkMode ? Colors.white12 : const Color(0xFFE4E7EC)),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF1B2A8C).withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (isDarkMode ? Colors.white70 : const Color(0xFF344054)),
          ),
        ),
      ),
    );
  }

  void _showConcertDetailModal(
      BuildContext context, PromoterConcertItem concert) {
    if (concert.status == ConcertStatus.disetujui) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PromoterManageConcertScreen(
            concert: concert,
          ),
        ),
      );
      return;
    }

    if (concert.status == ConcertStatus.ditolak) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ConcertStatusDetailScreen(
            concertTitle: concert.title,
          ),
        ),
      );
      return;
    }

    final service = PromoterDataService();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    concert.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF101828),
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: concert.status.badgeBgColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    concert.status.badgeText,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: concert.status.badgeTextColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${concert.date} · ${concert.time}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFFC2185B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${concert.venueName}\n${concert.venueAddress}',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF667085),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            const Text(
              'Tier Penjualan Tiket',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF101828),
              ),
            ),
            const SizedBox(height: 8),
            ...concert.tiers.map((t) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${t.name} (${t.formattedQuota})',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF475467))),
                      Text(t.formattedPrice,
                          style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1B2A8C))),
                    ],
                  ),
                )),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  if (concert.status == ConcertStatus.disetujui) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            PromoterManageConcertScreen(concert: concert),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ConcertStatusDetailScreen(
                          concertTitle: concert.title,
                          status: concert.status,
                        ),
                      ),
                    );
                  }
                },
                icon: Icon(
                  concert.status == ConcertStatus.ditolak
                      ? Icons.report_problem_outlined
                      : (concert.status == ConcertStatus.menunggu
                          ? Icons.hourglass_top_rounded
                          : Icons.visibility_outlined),
                  size: 18,
                ),
                label: Text(
                  concert.status == ConcertStatus.ditolak
                      ? 'Lihat Alasan Penolakan & Ajukan Banding'
                      : (concert.status == ConcertStatus.menunggu
                          ? 'Pantau Status Peninjauan'
                          : 'Kelola Informasi & Tim Konser'),
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: concert.status == ConcertStatus.ditolak
                      ? const Color(0xFFC2185B)
                      : const Color(0xFF1B2A8C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Tutup'),
                  ),
                ),
                if (concert.status == ConcertStatus.draft ||
                    concert.status == ConcertStatus.menunggu) ...[
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {
                      service.deleteConcert(concert.id);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content:
                              Text('Konser "${concert.title}" telah dihapus.'),
                          backgroundColor: const Color(0xFFC2185B),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD92D20),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Hapus'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConcertCard({
    required PromoterConcertItem concert,
    required Color cardBg,
    required Color cardBorder,
    required Color textColor,
    required Color subtextColor,
    required bool isDarkMode,
  }) {
    // Status visual mapping with indicator dot
    Color dotColor;
    Color statusBgColor;
    Color statusTextColor;
    String statusLabel;

    if (concert.cancellationStatus == ConcertCancellationStatus.disetujui) {
      dotColor = const Color(0xFFD92D20);
      statusBgColor = const Color(0xFFFEE4E2);
      statusTextColor = const Color(0xFFD92D20);
      statusLabel = 'DIBATALKAN';
    } else if (concert.cancellationStatus ==
        ConcertCancellationStatus.menungguAdmin) {
      dotColor = const Color(0xFF9333EA);
      statusBgColor = const Color(0xFFFDF2FA);
      statusTextColor = const Color(0xFF9333EA);
      statusLabel = 'BATAL: DITINJAU';
    } else {
      switch (concert.status) {
        case ConcertStatus.disetujui:
          dotColor = const Color(0xFF039855);
          statusBgColor = const Color(0xFFECFDF3);
          statusTextColor = const Color(0xFF027A48);
          statusLabel = 'DISETUJUI / TAYANG';
          break;
        case ConcertStatus.menunggu:
          dotColor = const Color(0xFFD97706);
          statusBgColor = const Color(0xFFFFFBEB);
          statusTextColor = const Color(0xFFB45309);
          statusLabel = 'MENUNGGU AUDIT';
          break;
        case ConcertStatus.ditolak:
          dotColor = const Color(0xFFD92D20);
          statusBgColor = const Color(0xFFFEF3F2);
          statusTextColor = const Color(0xFFB42318);
          statusLabel = 'DITOLAK';
          break;
        case ConcertStatus.draft:
          dotColor = const Color(0xFF475467);
          statusBgColor = const Color(0xFFF2F4F7);
          statusTextColor = const Color(0xFF344054);
          statusLabel = 'DRAFT';
          break;
        case ConcertStatus.semua:
          dotColor = const Color(0xFF1B2A8C);
          statusBgColor = const Color(0xFFF0F4FF);
          statusTextColor = const Color(0xFF1B2A8C);
          statusLabel = 'SEMUA';
          break;
      }
    }

    String actionCtaText;
    Color actionCtaColor;
    if (concert.status == ConcertStatus.disetujui) {
      actionCtaText = 'Kelola Konser';
      actionCtaColor = const Color(0xFF1B2A8C); // Navy
    } else if (concert.status == ConcertStatus.ditolak) {
      actionCtaText = 'Lihat Alasan';
      actionCtaColor = const Color(0xFFD92D20); // Red
    } else if (concert.status == ConcertStatus.menunggu) {
      actionCtaText = 'Pantau Review';
      actionCtaColor = const Color(0xFFD97706); // Amber
    } else {
      actionCtaText = 'Lanjut Edit';
      actionCtaColor = const Color(0xFF1B2A8C);
    }

    return InkWell(
      onTap: () {
        if (concert.status == ConcertStatus.disetujui) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PromoterManageConcertScreen(concert: concert),
            ),
          );
          return;
        }
        _showConcertDetailModal(context, concert);
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDarkMode ? 0.25 : 0.04),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Status Pill with Dot + Likes Pill
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: dotColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: statusTextColor,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCE7F3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.favorite_rounded,
                        size: 13,
                        color: Color(0xFFC2185B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        concert.likesCount,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFC2185B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Row 2: Artwork Thumbnail + Metadata
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Real Artwork Logo Box (1:1 aspect)
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF1B2A8C).withValues(alpha: 0.15),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1B2A8C).withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ConcertImageWidget(
                          imageSource: concert.displayLogoSource,
                          width: 62,
                          height: 62,
                          fit: BoxFit.cover,
                          fallbackIcon: Icons.album_rounded,
                          fallbackLabel: 'Logo',
                        ),
                      ),
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '1:1',
                            style: TextStyle(
                              fontSize: 7.5,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 14),

                // Details Column
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
                          fontWeight: FontWeight.w800,
                          color: textColor,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            size: 12,
                            color: Color(0xFFC2185B),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              '${concert.date} · ${concert.time}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFC2185B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            size: 13,
                            color: subtextColor,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              concert.venueName,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: subtextColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Row 3: Footer Divider & Action Bar
            Divider(
              height: 1,
              color: cardBorder.withValues(alpha: 0.8),
            ),
            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.confirmation_number_outlined,
                            size: 13,
                            color: subtextColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            concert.isCompleted
                                ? 'Terjual: ${concert.formattedTicketsSold}'
                                : (concert.ticketsSold > 0
                                    ? '${concert.remainingTickets} / ${concert.totalCapacity} Tiket Tersedia · ${concert.tiers.length} Tier'
                                    : '${concert.totalCapacity} Tiket · ${concert.tiers.length} Tier'),
                            style: TextStyle(
                              fontSize: 11,
                              color: subtextColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      if ((concert.isCompleted || concert.ticketsSold > 0) &&
                          concert.resolvedGrossRevenue > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF3),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Pendapatan: ${concert.formattedGrossRevenue}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF027A48),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      concert.isCompleted ? 'Lihat Riwayat' : actionCtaText,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: actionCtaColor,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: actionCtaColor,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
