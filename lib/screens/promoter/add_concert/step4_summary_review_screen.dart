import 'package:flutter/material.dart';
import '../../../models/gate_crew_models.dart';
import '../../../models/promoter_models.dart';
import '../../../services/gate_crew_service.dart';
import '../../../services/promoter_data_service.dart';
import '../widgets/promoter_step_indicator.dart';

class Step4SummaryReviewScreen extends StatefulWidget {
  final String concertTitle;
  final String concertDate;
  final String concertDescription;
  final String posterFileName;
  final String? squareLogoFileName;
  final String venueName;
  final String venueAddress;
  final List<PromoterTicketTier> tiers;
  final Map<String, String>? initialInvitedCrew;
  final void Function(Map<String, String> invitedCrew) onSubmit;
  final VoidCallback onBack;
  final bool isEditMode;

  const Step4SummaryReviewScreen({
    super.key,
    required this.concertTitle,
    required this.concertDate,
    required this.concertDescription,
    required this.posterFileName,
    this.squareLogoFileName,
    required this.venueName,
    required this.venueAddress,
    required this.tiers,
    this.initialInvitedCrew,
    required this.onSubmit,
    required this.onBack,
    this.isEditMode = false,
  });

  @override
  State<Step4SummaryReviewScreen> createState() =>
      _Step4SummaryReviewScreenState();
}

class _Step4SummaryReviewScreenState extends State<Step4SummaryReviewScreen> {
  final Map<String, String> _selectedCrewGates = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialInvitedCrew != null) {
      _selectedCrewGates.addAll(widget.initialInvitedCrew!);
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
                            'MEDIA ACARA (LOGO 1:1 & POSTER 16:9)',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: subtextColor,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE0E7FF),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Logo: ${widget.squareLogoFileName ?? "logo_square.png"}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1B2A8C),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFCE7F3),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Poster: ${widget.posterFileName}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFC2185B),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
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
                                  Text(
                                    '${tier.name} (${PromoterTicketTier.formatNumber(tier.quota)} pax)',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: subtextColor,
                                    ),
                                  ),
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
                                      _selectedCrewGates[crew.id] ?? 'Gate A';

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
                                    child: Row(
                                      children: [
                                        Checkbox(
                                          value: isSelected,
                                          activeColor: const Color(0xFFC2185B),
                                          onChanged: (val) {
                                            setState(() {
                                              if (val == true) {
                                                _selectedCrewGates[crew.id] =
                                                    'Gate A';
                                              } else {
                                                _selectedCrewGates
                                                    .remove(crew.id);
                                              }
                                            });
                                          },
                                        ),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                crew.name,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: textColor,
                                                ),
                                              ),
                                              Text(
                                                crew.email,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: subtextColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isSelected)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8),
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
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: textColor,
                                                ),
                                                dropdownColor: isDarkMode
                                                    ? const Color(0xFF1B2232)
                                                    : Colors.white,
                                                items: const [
                                                  DropdownMenuItem(
                                                      value: 'Gate A',
                                                      child: Text('Gate A')),
                                                  DropdownMenuItem(
                                                      value: 'Gate B',
                                                      child: Text('Gate B')),
                                                  DropdownMenuItem(
                                                      value: 'Gate C',
                                                      child: Text('Gate C')),
                                                ],
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
                  onPressed: () => widget.onSubmit(_selectedCrewGates),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9E1B82), // Magenta-purple
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
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
