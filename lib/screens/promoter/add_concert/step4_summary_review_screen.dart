import 'package:flutter/material.dart';
import '../../../models/gate_crew_models.dart';
import '../../../models/promoter_models.dart';
import '../../../services/gate_crew_service.dart';
import '../../../services/promoter_data_service.dart';
import '../widgets/concert_image_widget.dart';
import '../widgets/promoter_step_indicator.dart';

class Step4SummaryReviewScreen extends StatefulWidget {
  final String concertTitle;
  final String concertDate;
  final String concertDescription;
  final String posterFileName;
  final String? posterDataUrl;
  final String? squareLogoFileName;
  final String? squareLogoDataUrl;
  final List<String> highlights;
  final List<String> highlightNames;
  final List<String> shortMessages;
  final bool isBadgesLoading;
  final ValueChanged<List<String>>? onShortMessagesChanged;
  final String venueName;
  final String venueAddress;
  final List<PromoterTicketTier> tiers;
  final List<String> gateOptions;
  final Map<String, String>? initialInvitedCrew;
  final void Function(Map<String, String> invitedCrew) onSubmit;
  final VoidCallback onBack;
  final bool isEditMode;
  final bool isSubmitting;

  const Step4SummaryReviewScreen({
    super.key,
    required this.concertTitle,
    required this.concertDate,
    required this.concertDescription,
    required this.posterFileName,
    this.posterDataUrl,
    this.squareLogoFileName,
    this.squareLogoDataUrl,
    this.highlights = const [],
    this.highlightNames = const [],
    this.shortMessages = const [],
    this.isBadgesLoading = false,
    this.onShortMessagesChanged,
    required this.venueName,
    required this.venueAddress,
    required this.tiers,
    this.gateOptions = const [],
    this.initialInvitedCrew,
    required this.onSubmit,
    required this.onBack,
    this.isEditMode = false,
    this.isSubmitting = false,
  });

  @override
  State<Step4SummaryReviewScreen> createState() =>
      _Step4SummaryReviewScreenState();
}

class _Step4SummaryReviewScreenState extends State<Step4SummaryReviewScreen> {
  final Map<String, String> _selectedCrewGates = {};

  List<String> get _gateOptions {
    if (widget.gateOptions.isNotEmpty) {
      return widget.gateOptions;
    }
    if (widget.initialInvitedCrew != null &&
        widget.initialInvitedCrew!.isNotEmpty) {
      final list = widget.initialInvitedCrew!.values
          .map((g) => g.trim())
          .where((g) => g.isNotEmpty)
          .toSet()
          .toList();
      if (list.isNotEmpty) return list;
    }
    return const ['Gate 1 (Utama)', 'Gate 2'];
  }

  String _resolveGate(String? current) {
    final options = _gateOptions;
    if (current == null || current.trim().isEmpty) return options.first;
    final trimmed = current.trim();
    if (options.contains(trimmed)) return trimmed;
    for (final opt in options) {
      if (opt.toLowerCase().startsWith(trimmed.toLowerCase()) ||
          trimmed.toLowerCase().startsWith(opt.toLowerCase())) {
        return opt;
      }
    }
    return options.first;
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialInvitedCrew != null) {
      widget.initialInvitedCrew!.forEach((crewId, gate) {
        _selectedCrewGates[crewId] = _resolveGate(gate);
      });
    }
  }

  String _formatShortPrice(int price) {
    if (price >= 1000 && price % 1000 == 0) {
      final kValue = price ~/ 1000;
      return 'Rp ${PromoterTicketTier.formatNumber(kValue)}k';
    }
    return 'Rp ${PromoterTicketTier.formatNumber(price)}';
  }

  String _formatVenueAndDate() {
    final cleanVenue = widget.venueName.trim().isNotEmpty
        ? widget.venueName.trim()
        : 'Stadion Gajayana';
    if (widget.concertDate.contains('14 November 2026') ||
        widget.concertDate.contains('14 Nov 2026') ||
        widget.concertDate.trim().isEmpty) {
      return '$cleanVenue · 14 Nov 2026';
    }
    return '$cleanVenue · ${widget.concertDate.trim()}';
  }

  Future<void> _showEditBadgesDialog() async {
    final result = await showDialog<List<String>>(
      context: context,
      builder: (_) => _EditBadgesDialog(initial: widget.shortMessages),
    );
    if (result != null) {
      widget.onShortMessagesChanged?.call(result);
    }
  }

  Widget _buildBadgePill(String message, int index) {
    final icon = index == 0
        ? Icons.star_rounded
        : (index == 1 ? Icons.local_fire_department_rounded : Icons.campaign_rounded);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFBBF24),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF1E1B4B)),
          const SizedBox(width: 4),
          Text(
            message,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E1B4B),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = PromoterDataService();
    final displayTitle = widget.concertTitle.trim().isNotEmpty
        ? widget.concertTitle.trim()
        : 'Harmoni Nusantara 2026';

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

        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Bar with Back and Sun
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
                      'Ringkasan Pengajuan',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Langkah 5 dari 5: Cek ulang sebelum mengajukan approval',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: subtextColor,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Stepper (All 5 steps active)
                    const PromoterStepIndicator(currentStep: 5, totalSteps: 5),

                    const SizedBox(height: 22),

                    // Card 1: Detail Konser
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Detail Konser',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'NAMA KONSER',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: subtextColor,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            displayTitle,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Divider(height: 1, color: cardBorder),
                          ),
                          Text(
                            'WAKTU & TEMPAT',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: subtextColor,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatVenueAndDate(),
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Divider(height: 1, color: cardBorder),
                          ),
                          Text(
                            'MEDIA ACARA (POSTER 16:9, LOGO 1:1 & HIGHLIGHTS)',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: subtextColor,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 10),
                          // 16:9 Poster Preview
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  ConcertImageWidget(
                                    imageSource: widget.posterDataUrl ??
                                        widget.posterFileName,
                                    fit: BoxFit.cover,
                                    fallbackIcon: Icons.image_outlined,
                                    fallbackLabel: 'Poster 16:9',
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.black
                                            .withValues(alpha: 0.65),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'Poster 16:9',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Logo 1:1 Preview
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? const Color(0xFF1E283E)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: SizedBox(
                                    width: 52,
                                    height: 52,
                                    child: ConcertImageWidget(
                                      imageSource: widget.squareLogoDataUrl ??
                                          (widget.squareLogoFileName ?? ''),
                                      width: 52,
                                      height: 52,
                                      fit: BoxFit.cover,
                                      fallbackIcon: Icons.crop_square_rounded,
                                      fallbackLabel: 'Logo 1:1',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Logo Konser (1:1)',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: subtextColor,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        widget.squareLogoFileName?.isNotEmpty ==
                                                true
                                            ? widget.squareLogoFileName!
                                            : 'logo_soundwave_square.png',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: textColor,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (widget.highlights.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              'Galeri Highlights (${widget.highlights.length} foto):',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: subtextColor,
                              ),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 64,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: widget.highlights.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (context, idx) {
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: SizedBox(
                                      width: 90,
                                      height: 64,
                                      child: ConcertImageWidget(
                                        imageSource: widget.highlights[idx],
                                        fit: BoxFit.cover,
                                        fallbackIcon:
                                            Icons.photo_library_outlined,
                                        fallbackLabel: '#${idx + 1}',
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Card 1b: Badge Banner Otomatis dari Deskripsi (AI)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Pesan Singkat / Badge Banner',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: textColor,
                                  ),
                                ),
                              ),
                              if (!widget.isBadgesLoading)
                                TextButton.icon(
                                  onPressed: _showEditBadgesDialog,
                                  icon: const Icon(Icons.edit_rounded, size: 15),
                                  label: const Text(
                                    'Edit',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF9E1B82),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Dibuat otomatis oleh AI dari deskripsi konser. Badge hanya muncul jika deskripsi memuat kata kunci yang menarik.',
                            style: TextStyle(
                              fontSize: 11,
                              color: subtextColor,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (widget.isBadgesLoading)
                            Row(
                              children: [
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF9E1B82),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'AI sedang menyusun badge dari deskripsi...',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: subtextColor,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else if (widget.shortMessages.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? const Color(0xFF141A29)
                                    : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: cardBorder),
                              ),
                              child: Text(
                                'AI tidak menemukan kata kunci yang cukup kuat, jadi badge dibiarkan kosong. Anda tetap bisa menambahkannya lewat tombol Edit.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: subtextColor,
                                  height: 1.4,
                                ),
                              ),
                            )
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: List.generate(
                                widget.shortMessages.length,
                                (idx) => _buildBadgePill(
                                  widget.shortMessages[idx],
                                  idx,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Card 2: Paket Tiket Terpilih
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Paket Tiket Terpilih',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...List.generate(widget.tiers.length, (index) {
                            final tier = widget.tiers[index];
                            return Padding(
                              padding: EdgeInsets.only(
                                bottom: index < widget.tiers.length - 1 ? 10 : 0,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${tier.name} (${PromoterTicketTier.formatNumber(tier.quota)} pax)',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: subtextColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatShortPrice(tier.price),
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: textColor,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Card 3: Tugaskan Staf Gate Crew (Opsional)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Tugaskan Staf Gate Crew',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFC2185B)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${_selectedCrewGates.length} Dipilih',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFC2185B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Kru yang dipilih dapat langsung melakukan scan QR tiket di pintu masuk konser.',
                            style:
                                TextStyle(fontSize: 11.5, color: subtextColor),
                          ),
                          const SizedBox(height: 12),
                          ValueListenableBuilder<List<GateCrewMemberModel>>(
                            valueListenable:
                                GateCrewService().teamCrewNotifier,
                            builder: (context, teamList, _) {
                              if (teamList.isEmpty) {
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDarkMode
                                        ? const Color(0xFF141A29)
                                        : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'Belum ada Gate Crew yang didaftarkan Admin. Anda tetap dapat mengajukan konser ini dan menugaskan kru nanti di menu Kelola Konser.',
                                    style: TextStyle(
                                        fontSize: 12, color: subtextColor),
                                  ),
                                );
                              }

                              return Column(
                                children: teamList.map((crew) {
                                  final isSelected =
                                      _selectedCrewGates.containsKey(crew.id);
                                  final gateName =
                                      _resolveGate(_selectedCrewGates[crew.id]);
                                  final availableItems =
                                      _gateOptions.contains(gateName)
                                          ? _gateOptions
                                          : [gateName, ..._gateOptions];

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFFC2185B)
                                              .withValues(alpha: 0.05)
                                          : (isDarkMode
                                              ? const Color(0xFF141A29)
                                              : const Color(0xFFF8FAFC)),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFFC2185B)
                                                .withValues(alpha: 0.4)
                                            : cardBorder,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Checkbox(
                                              value: isSelected,
                                              activeColor:
                                                  const Color(0xFFC2185B),
                                              onChanged: (val) {
                                                setState(() {
                                                  if (val == true) {
                                                    _selectedCrewGates[
                                                            crew.id] =
                                                        _gateOptions.first;
                                                  } else {
                                                    _selectedCrewGates
                                                        .remove(crew.id);
                                                  }
                                                });
                                              },
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    crew.name,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: textColor,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    crew.email,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: subtextColor,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (isSelected) ...[
                                          const SizedBox(height: 8),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isDarkMode
                                                  ? const Color(0xFF1B2232)
                                                  : Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border:
                                                  Border.all(color: cardBorder),
                                            ),
                                            child: DropdownButtonHideUnderline(
                                              child: DropdownButton<String>(
                                                value: gateName,
                                                isDense: true,
                                                isExpanded: true,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: textColor,
                                                ),
                                                dropdownColor: isDarkMode
                                                    ? const Color(0xFF1B2232)
                                                    : Colors.white,
                                                items: availableItems.map((gate) {
                                                  return DropdownMenuItem<String>(
                                                    value: gate,
                                                    child: Text(
                                                      gate,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: textColor,
                                                      ),
                                                    ),
                                                  );
                                                }).toList(),
                                                onChanged: (newGate) {
                                                  if (newGate != null) {
                                                    setState(() {
                                                      _selectedCrewGates[
                                                          crew.id] = newGate;
                                                    });
                                                  }
                                                },
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Notice text below Card 3
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'Pemberitahuan: Batas sisa verifikasi harian Anda otomatis terpotong saat pengajuan dikirim.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: subtextColor,
                          height: 1.4,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Bottom Sticky Magenta Button: Kirim untuk Approval Admin
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: widget.isSubmitting
                      ? null
                      : () => widget.onSubmit(_selectedCrewGates),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9E1B82), // Magenta-purple
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF7B1465),
                    disabledForegroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: widget.isSubmitting
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Menyimpan ke Database...',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          widget.isEditMode
                              ? 'Simpan Perubahan Konser'
                              : 'Kirim untuk Approval Admin',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EditBadgesDialog extends StatefulWidget {
  final List<String> initial;

  const _EditBadgesDialog({required this.initial});

  @override
  State<_EditBadgesDialog> createState() => _EditBadgesDialogState();
}

class _EditBadgesDialogState extends State<_EditBadgesDialog> {
  late List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    final source = widget.initial.take(3).toList();
    _controllers = source.map((m) => TextEditingController(text: m)).toList();
    if (_controllers.isEmpty) {
      _controllers.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addMessage() {
    if (_controllers.length >= 3) return;
    setState(() => _controllers.add(TextEditingController()));
  }

  void _removeMessage(int index) {
    setState(() {
      _controllers.removeAt(index).dispose();
      if (_controllers.isEmpty) {
        _controllers.add(TextEditingController());
      }
    });
  }

  void _save() {
    final values = _controllers
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    Navigator.pop(context, values);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text(
        'Edit Badge Banner',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Maksimal 3 badge, 15 karakter per badge. Kosongkan semua jika tidak ingin menampilkan badge.',
              style: TextStyle(
                fontSize: 11.5,
                color: Color(0xFF667085),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(_controllers.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controllers[index],
                        maxLength: 15,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: index == 0
                              ? 'Contoh: Festival Musik'
                              : (index == 1 ? 'Contoh: 17+' : 'Contoh: Outdoor'),
                          hintStyle: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF98A2B3),
                          ),
                          counterText: '',
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    if (_controllers.length > 1)
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 20,
                          color: Colors.redAccent,
                        ),
                        onPressed: () => _removeMessage(index),
                        tooltip: 'Hapus badge',
                      ),
                  ],
                ),
              );
            }),
            if (_controllers.length < 3)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addMessage,
                  icon: const Icon(
                    Icons.add_rounded,
                    size: 18,
                    color: Color(0xFF9E1B82),
                  ),
                  label: Text(
                    'Tambah Badge (${_controllers.length}/3)',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF9E1B82),
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF9E1B82),
            foregroundColor: Colors.white,
          ),
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
