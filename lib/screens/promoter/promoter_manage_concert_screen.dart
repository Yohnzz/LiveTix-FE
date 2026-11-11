import 'package:flutter/material.dart';
import '../../models/gate_crew_models.dart';
import '../../models/promoter_models.dart';
import '../../services/gate_crew_service.dart';
import '../../services/promoter_data_service.dart';
import 'cancellation/promoter_cancel_concert_screen.dart';
import 'cancellation/promoter_cancellation_approved_screen.dart';
import 'cancellation/promoter_cancellation_status_screen.dart';
import 'add_concert/add_concert_flow.dart';
import 'widgets/concert_image_widget.dart';
import 'widgets/interactive_map_view.dart';
import 'widgets/responsive_promoter_wrapper.dart';

class PromoterManageConcertScreen extends StatefulWidget {
  final PromoterConcertItem concert;

  const PromoterManageConcertScreen({
    super.key,
    required this.concert,
  });

  @override
  State<PromoterManageConcertScreen> createState() =>
      _PromoterManageConcertScreenState();
}

class _PromoterManageConcertScreenState
    extends State<PromoterManageConcertScreen> {
  final bool _hasPendingChangeRequest = false;
  final String _pendingChangeSummary = '';

  void _showAddGateDialog(PromoterConcertItem concert, bool isDarkMode) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Tambah Pos Gate Baru',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Contoh: Gate VIP, Gate Barat, dll',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty && !concert.gates.contains(text)) {
                final updatedGates = [...concert.gates, text];
                final list = List<PromoterConcertItem>.from(
                    PromoterDataService().concertsNotifier.value);
                final idx = list.indexWhere((c) => c.id == concert.id);
                if (idx != -1) {
                  list[idx] = concert.copyWith(gates: updatedGates);
                  PromoterDataService().concertsNotifier.value = list;
                }
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B2A8C),
              foregroundColor: Colors.white,
            ),
            child: const Text('Tambah Gate'),
          ),
        ],
      ),
    );
  }

  void _showInviteCrewDialog(PromoterConcertItem concert, bool isDarkMode) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String selectedGate =
        concert.gates.isNotEmpty ? concert.gates.first : 'Gate A';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Invite / Tambah Gate Crew',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nama Lengkap Crew',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    hintText: 'Contoh: Agus Pratama',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Email Crew',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'crew@livetix.com',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Nomor HP (WhatsApp)',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: '08123456789',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Pos Gate Penugasan',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: concert.gates.contains(selectedGate)
                      ? selectedGate
                      : (concert.gates.isNotEmpty
                          ? concert.gates.first
                          : 'Gate A'),
                  items: concert.gates
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setLocalState(() => selectedGate = val);
                  },
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final email = emailCtrl.text.trim();
                final name = nameCtrl.text.trim();
                if (email.isEmpty) return;

                final newMember =
                    await GateCrewService().inviteAndAssignCrewByProducer(
                  concertId: concert.id,
                  concertTitle: concert.title,
                  email: email,
                  name: name.isNotEmpty ? name : 'Crew Gate',
                  phone: phoneCtrl.text.trim(),
                  gateName: selectedGate,
                );

                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Gate Crew ${newMember.name} berhasil di-invite dan ditugaskan ke $selectedGate'),
                      backgroundColor: const Color(0xFF16A34A),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B2A8C),
                foregroundColor: Colors.white,
              ),
              child: const Text('Simpan & Tugaskan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _autoDistributeEvenly(PromoterConcertItem concert) async {
    await GateCrewService().autoDistributeCrewAcrossGates(
      concertId: concert.id,
      concertTitle: concert.title,
      gates: concert.gates,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Gate Crew berhasil dibagi merata ke ${concert.gates.length} pos gate.'),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
    }
  }

  void _showAssignGateCrewDialog(
      PromoterConcertItem concert, bool isDarkMode) {
    final allCrew = GateCrewService().teamCrewNotifier.value;
    final availableCrew = allCrew
        .where((c) =>
            c.isApproved &&
            (c.activeAssignment == null ||
                (c.activeAssignment!.concertId != concert.id &&
                    c.activeAssignment!.concertTitle.toLowerCase() !=
                        concert.title.toLowerCase())))
        .toList();

    if (availableCrew.isEmpty) {
      _showInviteCrewDialog(concert, isDarkMode);
      return;
    }

    String selectedCrewId = availableCrew.first.id;
    String selectedGate =
        concert.gates.isNotEmpty ? concert.gates.first : 'Gate A';

    final dialogBgColor =
        isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final dialogTextColor =
        isDarkMode ? Colors.white : const Color(0xFF0F172A);
    final dialogSubColor =
        isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    final fieldBgColor =
        isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final fieldBorderColor =
        isDarkMode ? const Color(0xFF334155) : const Color(0xFFCBD5E1);

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => Theme(
        data: isDarkMode
            ? ThemeData.dark().copyWith(
                dialogTheme: DialogThemeData(backgroundColor: dialogBgColor),
                scaffoldBackgroundColor: dialogBgColor,
              )
            : ThemeData.light().copyWith(
                dialogTheme:
                    const DialogThemeData(backgroundColor: Colors.white),
                scaffoldBackgroundColor: Colors.white,
              ),
        child: StatefulBuilder(
          builder: (dialogStateCtx, setDialogState) {
            final selectedMember =
                availableCrew.firstWhere((c) => c.id == selectedCrewId);

            return AlertDialog(
              backgroundColor: dialogBgColor,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC2185B).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.person_add_alt_1_rounded,
                        color: Color(0xFFC2185B), size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tugaskan Gate Crew',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: dialogTextColor,
                          ),
                        ),
                        Text(
                          'Pilih petugas & pos gate validasi',
                          style: TextStyle(
                            fontSize: 12,
                            color: dialogSubColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pilih Gate Crew:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: dialogTextColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: fieldBgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: fieldBorderColor),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedCrewId,
                        isExpanded: true,
                        dropdownColor: dialogBgColor,
                        iconEnabledColor: dialogTextColor,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: dialogTextColor,
                        ),
                        items: availableCrew.map((c) {
                          return DropdownMenuItem(
                            value: c.id,
                            child: Text(
                              '${c.name} (${c.email})',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: dialogTextColor,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedCrewId = val);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Pilih Pos Gate:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: dialogTextColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: fieldBgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: fieldBorderColor),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: concert.gates.contains(selectedGate)
                            ? selectedGate
                            : (concert.gates.isNotEmpty ? concert.gates.first : 'Gate A'),
                        isExpanded: true,
                        dropdownColor: dialogBgColor,
                        iconEnabledColor: dialogTextColor,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: dialogTextColor,
                        ),
                        items: concert.gates.map((g) {
                          return DropdownMenuItem(
                            value: g,
                            child: Text(
                              g,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: dialogTextColor,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedGate = val);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text(
                    'Batal',
                    style: TextStyle(
                      color: dialogSubColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(dialogCtx);
                    await GateCrewService().inviteCrewToConcert(
                      crewId: selectedMember.id,
                      concertId: concert.id,
                      concertTitle: concert.title,
                      venue: concert.venueName,
                      gateName: selectedGate,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Berhasil menugaskan ${selectedMember.name} ke ${concert.title} ($selectedGate)'),
                          backgroundColor: const Color(0xFF16A34A),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC2185B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Tugaskan'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = PromoterDataService();

    return ResponsivePromoterWrapper(
      child: ValueListenableBuilder<bool>(
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

          return ValueListenableBuilder<List<PromoterConcertItem>>(
            valueListenable: service.concertsNotifier,
            builder: (context, concertsList, _) {
              final concert = concertsList.firstWhere(
                (c) => c.id == widget.concert.id,
                orElse: () => widget.concert,
              );

              return Scaffold(
                backgroundColor: Colors.transparent,
                body: SafeArea(
                  child: SingleChildScrollView(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    // Top App Bar: Kembali & Theme Toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 2, vertical: 4),
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
                          tooltip: 'Ganti Tema',
                          onPressed: service.toggleTheme,
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // Header Title
                    Text(
                      'Kelola Konser',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manajemen konser resmi & pengajuan revisi ke admin',
                      style: TextStyle(
                        fontSize: 13,
                        color: subtextColor,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Pending Change Request Banner (If submitted)
                    if (_hasPendingChangeRequest) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB), // Soft amber
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFF59E0B),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.pending_actions_rounded,
                              color: Color(0xFFD97706),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Pengajuan Perubahan Sedang Ditinjau Admin',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF92400E),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _pendingChangeSummary,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFFB45309),
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Section 1: Media Showcase (Highlight Banner 16:9 + Square Logo 1:1)
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: cardBorder),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                                alpha: isDarkMode ? 0.2 : 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Highlight Banner (16:9 Aspect Ratio)
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(18)),
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  // Real Poster Image (16:9 Landscape)
                                  ConcertImageWidget(
                                    imageSource: concert.displayPosterSource,
                                    fit: BoxFit.cover,
                                    fallbackIcon: Icons.music_note_rounded,
                                    fallbackLabel: concert.title,
                                  ),
                                  // Status Badge
                                  Positioned(
                                    top: 12,
                                    right: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF039855),
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.2),
                                            blurRadius: 6,
                                          ),
                                        ],
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.check_circle_rounded,
                                            size: 13,
                                            color: Colors.white,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'DISETUJUI / TAYANG',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // 16:9 Label
                                  Positioned(
                                    bottom: 10,
                                    right: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.black
                                            .withValues(alpha: 0.6),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'Highlight Poster (16:9)',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Overlap Section with Square Logo (1:1) & Concert Identity
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Square Logo (1:1 Aspect Ratio)
                                Container(
                                  width: 76,
                                  height: 76,
                                  decoration: BoxDecoration(
                                    color: isDarkMode
                                        ? const Color(0xFF242E42)
                                        : const Color(0xFFF3E8FF),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFFC2185B)
                                          .withValues(alpha: 0.3),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.08),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: ConcertImageWidget(
                                    imageSource: concert.displayLogoSource,
                                    width: 76,
                                    height: 76,
                                    fit: BoxFit.cover,
                                    fallbackIcon: Icons.album_rounded,
                                    fallbackLabel: 'Logo 1:1',
                                  ),
                                ),

                                const SizedBox(width: 14),

                                // Title, Date & Time, Venue
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        concert.title,
                                        style: TextStyle(
                                          fontSize: 17,
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
                                            size: 13,
                                            color: Color(0xFFC2185B),
                                          ),
                                          const SizedBox(width: 5),
                                          Expanded(
                                            child: Text(
                                              '${concert.date} · ${concert.time}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFFC2185B),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.location_on_rounded,
                                            size: 14,
                                            color: subtextColor,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              concert.venueName,
                                              style: TextStyle(
                                                fontSize: 12,
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
                          ),
                        ],
                      ),
                    ),

                    if (concert.highlights.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Text(
                        'HIGHLIGHT KONSER (${concert.highlights.length} FOTO)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: subtextColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 120,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: concert.highlights.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 10),
                          itemBuilder: (context, idx) {
                            final caption = idx < concert.highlightNames.length
                                ? concert.highlightNames[idx]
                                : 'Highlight #${idx + 1}';
                            return Container(
                              width: 160,
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: cardBorder),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: ConcertImageWidget(
                                      imageSource: concert.highlights[idx],
                                      fit: BoxFit.cover,
                                      fallbackIcon:
                                          Icons.photo_library_outlined,
                                      fallbackLabel: '#${idx + 1}',
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 5),
                                    child: Text(
                                      caption,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: textColor,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],

                    const SizedBox(height: 18),

                    // Admin Change Notice Card with CTA Button (Requested by User)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? const Color(0xFF131D33)
                            : const Color(0xFFF0F4FF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF1B2A8C).withValues(alpha: 0.25),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.admin_panel_settings_rounded,
                                size: 20,
                                color: Color(0xFF1B2A8C),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Prosedur Edit Konser Aktif',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1B2A8C),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Karena konser ini sudah berstatus disetujui & tayang ke publik, segala perubahan data memerlukan pengajuan resmi kepada admin platform demi melindungi kepastian pembeli tiket.',
                            style: TextStyle(
                              fontSize: 12,
                              color: subtextColor,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Tombol Edit Konser (Tampilan 4 Langkah mirip Tambah Konser + Konfirmasi Admin)
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AddConcertFlow(
                                      editingConcert: concert,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.edit_note_rounded,
                                size: 19,
                              ),
                              label: const Text(
                                'Ajukan Perubahan Informasi Konser',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1B2A8C), // Navy
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),

                          if (!concert.isCompleted) ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  PromoterDataService()
                                      .markConcertCompleted(concert.id);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Konser "${concert.title}" ditandai Selesai dan disimpan ke Riwayat Konser beserta pendapatannya.'),
                                      backgroundColor: const Color(0xFF039855),
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.task_alt_rounded,
                                  size: 18,
                                  color: Color(0xFF039855),
                                ),
                                label: const Text(
                                  'Tandai Acara Selesai (Simpan ke Riwayat)',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF039855),
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: Color(0xFFA6F4C5),
                                    width: 1.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 10),

                          // Tombol Batalkan Konser (Underneath Ajukan Perubahan Informasi Konser)
                          if (concert.cancellationStatus ==
                              ConcertCancellationStatus.none) ...[
                            SizedBox(
                              width: double.infinity,
                              height: 46,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          PromoterCancelConcertScreen(
                                        concert: concert,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.cancel_outlined,
                                  size: 19,
                                  color: Color(0xFFD92D20), // Red
                                ),
                                label: const Text(
                                  'Batalkan Konser',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFD92D20),
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: Color(0xFFFDA29B),
                                    width: 1.5,
                                  ),
                                  backgroundColor: isDarkMode
                                      ? const Color(0xFF281518)
                                      : const Color(0xFFFEF3F2),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ] else if (concert.cancellationStatus ==
                              ConcertCancellationStatus.menungguAdmin) ...[
                            SizedBox(
                              width: double.infinity,
                              height: 46,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          PromoterCancellationStatusScreen(
                                        concert: concert,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.pending_actions_rounded,
                                  size: 19,
                                  color: Color(0xFF9333EA),
                                ),
                                label: const Text(
                                  'Status Pengajuan Pembatalan (Menunggu Admin)',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF9333EA),
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: Color(0xFFE9D7FE),
                                    width: 1.5,
                                  ),
                                  backgroundColor: isDarkMode
                                      ? const Color(0xFF28182E)
                                      : const Color(0xFFFDF2FA),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ] else if (concert.cancellationStatus ==
                              ConcertCancellationStatus.disetujui) ...[
                            SizedBox(
                              width: double.infinity,
                              height: 46,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          PromoterCancellationApprovedScreen(
                                        concert: concert,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.verified_rounded,
                                  size: 19,
                                  color: Color(0xFF039855),
                                ),
                                label: const Text(
                                  'Rincian Pembatalan Disetujui',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF039855),
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: Color(0xFFA6F4C5),
                                    width: 1.5,
                                  ),
                                  backgroundColor: isDarkMode
                                      ? const Color(0xFF0D2818)
                                      : const Color(0xFFE8FDF0),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    // Section 2: Detail Informasi Konser
                    Text(
                      'DESKRIPSI ACARA',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: subtextColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: cardBorder),
                      ),
                      child: Text(
                        concert.description.isNotEmpty
                            ? concert.description
                            : 'Konser musik spektakuler yang menghadirkan pertunjukan memukau dengan standar produksi panggung terbaik.',
                        style: TextStyle(
                          fontSize: 13,
                          color: textColor,
                          height: 1.45,
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    // Section 3: Tempat Konser (Maps Data)
                    Text(
                      'TEMPAT KONSER & PETA VENUE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: subtextColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.stadium_rounded,
                                      size: 18,
                                      color: Color(0xFF1B2A8C),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      concert.venueName,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: textColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  concert.venueAddress,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: subtextColor,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Integrated Interactive Map View
                          InteractiveMapView(
                            venueName: concert.venueName,
                            fullAddress: concert.venueAddress,
                            searchQuery:
                                '${concert.venueName} ${concert.venueAddress}',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    // Section 4: Kategori Tiket dan Harga
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'KATEGORI TIKET & HARGA',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: subtextColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          concert.formattedTotalCapacity,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFC2185B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: concert.tiers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final tier = concert.tiers[index];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: cardBorder),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: tier.accentColor,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tier.name,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: textColor,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Kuota: ${tier.formattedQuota} ${tier.quotaType}',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: subtextColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    tier.formattedPrice,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Per Tiket',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: Color(0xFF98A2B3),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // Section 5: Tim Gate Crew Bertugas
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'TIM GATE CREW BERTUGAS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: subtextColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _showAssignGateCrewDialog(
                              concert, isDarkMode),
                          icon: const Icon(Icons.person_add_alt_1_rounded,
                              size: 16, color: Color(0xFFC2185B)),
                          label: const Text(
                            '+ Tugaskan Crew',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFC2185B),
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Pos Gate Management & Distribution Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.meeting_room_rounded,
                                      size: 16, color: Color(0xFFC2185B)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Pos Gate Tersedia (${concert.gates.length})',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: textColor,
                                    ),
                                  ),
                                ],
                              ),
                              TextButton.icon(
                                onPressed: () =>
                                    _showAddGateDialog(concert, isDarkMode),
                                icon: const Icon(Icons.add_rounded, size: 15),
                                label: const Text('Tambah Gate'),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFFC2185B),
                                  textStyle: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700),
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: concert.gates.map((g) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? const Color(0xFF0F172A)
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: isDarkMode
                                          ? Colors.white24
                                          : const Color(0xFFE2E8F0)),
                                ),
                                child: Text(
                                  g,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      _showInviteCrewDialog(concert, isDarkMode),
                                  icon: const Icon(Icons.person_add_alt_1_rounded,
                                      size: 15),
                                  label: const Text('Invite Crewgate'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFC2185B),
                                    side: const BorderSide(
                                        color: Color(0xFFC2185B)),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _autoDistributeEvenly(concert),
                                  icon: const Icon(Icons.balance_rounded,
                                      size: 15),
                                  label: const Text('Bagi Merata'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1B2A8C),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    ValueListenableBuilder<List<GateCrewMemberModel>>(
                      valueListenable: GateCrewService().teamCrewNotifier,
                      builder: (context, teamList, _) {
                        final assignedCrews = teamList.where((m) =>
                            m.activeAssignment?.concertId == concert.id ||
                            (m.activeAssignment != null &&
                                (m.activeAssignment!.concertTitle
                                        .toLowerCase() ==
                                    concert.title.toLowerCase()))).toList();

                        if (assignedCrews.isEmpty) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: cardBorder),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.qr_code_scanner_rounded,
                                    size: 36,
                                    color: subtextColor.withValues(alpha: 0.5)),
                                const SizedBox(height: 8),
                                Text(
                                  'Belum ada Gate Crew ditugaskan',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Tugaskan gate crew agar dapat melakukan validasi/scan QR tiket penonton di pintu masuk konser ini.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: subtextColor,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: () => _showAssignGateCrewDialog(
                                      concert, isDarkMode),
                                  icon: const Icon(
                                      Icons.person_add_alt_1_rounded,
                                      size: 16),
                                  label: const Text(
                                      'Tugaskan Gate Crew Sekarang'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFC2185B),
                                    foregroundColor: Colors.white,
                                    textStyle: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return Column(
                          children: assignedCrews.map((crew) {
                            final assignment = crew.activeAssignment;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: cardBorder),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: const Color(0xFFC2185B)
                                        .withValues(alpha: 0.12),
                                    child: const Icon(Icons.badge_rounded,
                                        color: Color(0xFFC2185B), size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          crew.name,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
                                            color: textColor,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
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
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: concert.gates.contains(assignment?.gateName)
                                            ? assignment!.gateName
                                            : (concert.gates.isNotEmpty
                                                ? concert.gates.first
                                                : 'Gate A'),
                                        isDense: true,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF16A34A),
                                        ),
                                        icon: const Icon(Icons.arrow_drop_down,
                                            size: 16,
                                            color: Color(0xFF16A34A)),
                                        items: concert.gates.map((g) {
                                          return DropdownMenuItem(
                                            value: g,
                                            child: Text(g),
                                          );
                                        }).toList(),
                                        onChanged: (newGate) async {
                                          if (newGate != null) {
                                            await GateCrewService()
                                                .updateCrewGateAssignment(
                                              crewId: crew.id,
                                              concertId: concert.id,
                                              newGateName: newGate,
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  IconButton(
                                    icon: const Icon(Icons.close_rounded,
                                        size: 18, color: Colors.redAccent),
                                    tooltip: 'Lepas Tugas',
                                    onPressed: () async {
                                      await GateCrewService()
                                          .removeCrewFromConcert(
                                        crewId: crew.id,
                                        concertId: concert.id,
                                      );
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                'Penugasan ${crew.name} berhasil dilepas'),
                                            backgroundColor: Colors.redAccent,
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  ),
);
}
}
