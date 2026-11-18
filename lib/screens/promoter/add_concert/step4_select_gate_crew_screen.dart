import 'package:flutter/material.dart';
import '../../../models/gate_crew_models.dart';
import '../../../services/gate_crew_service.dart';
import '../../../services/promoter_data_service.dart';
import '../widgets/promoter_step_indicator.dart';

class Step4SelectGateCrewScreen extends StatefulWidget {
  final Map<String, String> selectedCrewWithGate; // crewId -> gateName
  final ValueChanged<Map<String, String>> onCrewAssignmentsChanged;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const Step4SelectGateCrewScreen({
    super.key,
    required this.selectedCrewWithGate,
    required this.onCrewAssignmentsChanged,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<Step4SelectGateCrewScreen> createState() =>
      _Step4SelectGateCrewScreenState();
}

class _Step4SelectGateCrewScreenState extends State<Step4SelectGateCrewScreen> {
  final GateCrewService _gateCrewService = GateCrewService();
  late Map<String, String> _assignments;

  // Daftar Pos Gate yang ditambahkan secara manual oleh Producer.
  // Secara default daftar Gate harus kosong.
  final List<String> _gateOptions = [];

  @override
  void initState() {
    super.initState();
    _assignments = Map<String, String>.from(widget.selectedCrewWithGate);
    // Masukkan gate yang sudah ada dari assignments jika ada
    for (final gate in _assignments.values) {
      if (!_gateOptions.contains(gate)) {
        _gateOptions.add(gate);
      }
    }
  }

  /// Kirim salinan map ke parent supaya state parent tidak berbagi
  /// referensi dengan state lokal.
  void _notify() {
    widget.onCrewAssignmentsChanged(Map<String, String>.from(_assignments));
  }

  void _toggleCrew(String crewId, bool isSelected) {
    if (isSelected && _gateOptions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Tambahkan minimal 1 Pos Gate terlebih dahulu sebelum memilih Crew Gate.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }
    setState(() {
      if (isSelected) {
        _assignments[crewId] = _gateOptions.first;
      } else {
        _assignments.remove(crewId);
      }
    });
    _notify();
  }

  void _validateAndProceed() {
    if (_gateOptions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Daftar Gate masih kosong. Producer wajib menambahkan Gate secara manual.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    // Setiap Gate wajib memiliki minimal 1 Crew Gate
    for (final gate in _gateOptions) {
      final hasCrew = _assignments.values.any((assignedGate) => assignedGate == gate);
      if (!hasCrew) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Pos "$gate" belum memiliki Crew Gate! Setiap Gate wajib memiliki minimal 1 Crew Gate.'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
        return;
      }
    }

    widget.onNext();
  }

  void _changeGate(String crewId, String gateName) {
    setState(() {
      _assignments[crewId] = gateName;
    });
    _notify();
  }

  void _showAddGateDialog(bool isDarkMode) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Theme(
        data: ThemeData.light(),
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Tambah Pos Gate Baru',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Gate VIP, Gate Barat, dll',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                final exists = _gateOptions
                    .any((g) => g.toLowerCase() == text.toLowerCase());
                if (text.isNotEmpty && !exists) {
                  setState(() {
                    _gateOptions.add(text);
                  });
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
      ),
    ).then((_) => controller.dispose());
  }

  /// Dialog "Invite Crewgate": produser memilih crew dari daftar crew yang
  /// sudah ada di akunnya (dropdown), lalu memilih pos gate. Tidak ada input
  /// manual nama / email / nomor HP lagi.
  void _showInviteCrewDialog(
    bool isDarkMode,
    List<GateCrewMemberModel> allCrews,
  ) {
    // Hanya crew yang belum ditugaskan yang bisa dipilih.
    final available =
        allCrews.where((c) => !_assignments.containsKey(c.id)).toList();

    if (_gateOptions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Tambahkan Pos Gate terlebih dahulu sebelum menugaskan Gate Crew.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    if (allCrews.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Belum ada Gate Crew di akun Anda. Tambahkan crew di menu Tim terlebih dahulu.'),
        ),
      );
      return;
    }
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Semua Gate Crew sudah dipilih dan ditugaskan.'),
        ),
      );
      return;
    }

    String? selectedCrewId = available.first.id;
    String selectedGate = _gateOptions.first;

    showDialog(
      context: context,
      builder: (ctx) => Theme(
        data: ThemeData.light(),
        child: StatefulBuilder(
          builder: (ctx, setLocalState) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Text('Tugaskan Gate Crew',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pilih Gate Crew',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCrewId,
                    isExpanded: true,
                    items: available
                        .map(
                          (c) => DropdownMenuItem<String>(
                            value: c.id,
                            child: Text(
                              c.email.isNotEmpty
                                  ? '${c.name} (${c.email})'
                                  : c.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setLocalState(() => selectedCrewId = val);
                      }
                    },
                    decoration: InputDecoration(
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
                    initialValue: selectedGate,
                    isExpanded: true,
                    items: _gateOptions
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
                onPressed: () {
                  final crewId = selectedCrewId;
                  if (crewId == null) return;

                  final crew = available.firstWhere((c) => c.id == crewId);

                  setState(() {
                    _assignments[crewId] = selectedGate;
                  });
                  _notify();
                  Navigator.pop(ctx);

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Gate Crew ${crew.name} berhasil ditugaskan ke $selectedGate'),
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
      ),
    );
  }

  void _autoDistributeEvenly() {
    if (_gateOptions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tambahkan Pos Gate terlebih dahulu.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }
    if (_assignments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Pilih atau centang minimal 1 gate crew terlebih dahulu untuk dibagi merata.'),
        ),
      );
      return;
    }
    setState(() {
      final crewIds = _assignments.keys.toList();
      for (var i = 0; i < crewIds.length; i++) {
        _assignments[crewIds[i]] = _gateOptions[i % _gateOptions.length];
      }
    });
    _notify();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Gate Crew berhasil dibagi merata ke ${_gateOptions.length} pos gate.'),
        backgroundColor: const Color(0xFF16A34A),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = PromoterDataService();

    return ValueListenableBuilder<bool>(
      valueListenable: service.isDarkModeNotifier,
      builder: (context, isDarkMode, _) {
        final textColor = isDarkMode ? Colors.white : const Color(0xFF101828);
        final subtextColor =
            isDarkMode ? Colors.white70 : const Color(0xFF667085);
        final cardBg = isDarkMode ? const Color(0xFF1B2232) : Colors.white;
        final cardBorder =
            isDarkMode ? Colors.white12 : const Color(0xFFE4E7EC);

        return ValueListenableBuilder<List<GateCrewMemberModel>>(
          valueListenable: _gateCrewService.teamCrewNotifier,
          builder: (context, teamCrews, _) {
            final approvedCrews =
                teamCrews.where((c) => c.isApproved).toList();
            // Hitung hanya crew yang memang tampil di daftar.
            final selectedCount = approvedCrews
                .where((c) => _assignments.containsKey(c.id))
                .length;

            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Bar with Kembali and Theme Toggle
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
                          'Pilih & Tugaskan Gate Crew',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Langkah 4 dari 5: Tentukan petugas gate crew untuk pemindaian QR tiket',
                          style: TextStyle(
                            fontSize: 13,
                            color: subtextColor,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Stepper (Steps 1, 2, 3, 4 active)
                        const PromoterStepIndicator(
                            currentStep: 4, totalSteps: 5),

                        const SizedBox(height: 20),

                        // Pos Gate Management & Distribution Card
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Row(
                                      children: [
                                        const Icon(Icons.meeting_room_rounded,
                                            size: 18,
                                            color: Color(0xFF1B2A8C)),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            'Pos Gate Tersedia (${_gateOptions.length})',
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w800,
                                              color: textColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: () =>
                                        _showAddGateDialog(isDarkMode),
                                    icon: const Icon(Icons.add_rounded,
                                        size: 16),
                                    label: const Text('Tambah Gate'),
                                    style: TextButton.styleFrom(
                                      foregroundColor:
                                          const Color(0xFF1B2A8C),
                                      textStyle: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (_gateOptions.isEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12, horizontal: 14),
                                  decoration: BoxDecoration(
                                    color: isDarkMode
                                        ? const Color(0xFF0F172A)
                                        : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isDarkMode
                                          ? Colors.white12
                                          : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.info_outline_rounded,
                                        size: 16,
                                        color: Color(0xFF64748B),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Belum ada Pos Gate. Klik "+ Tambah Gate" untuk menambahkan gate.',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: subtextColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _gateOptions.map((gate) {
                                    return Chip(
                                      label: Text(
                                        gate,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: textColor,
                                        ),
                                      ),
                                      backgroundColor: isDarkMode
                                          ? const Color(0xFF0F172A)
                                          : const Color(0xFFF1F5F9),
                                      deleteIcon: Icon(Icons.close_rounded,
                                          size: 14, color: textColor),
                                      onDeleted: () {
                                        setState(() {
                                          _gateOptions.remove(gate);
                                          _assignments.removeWhere(
                                              (k, v) => v == gate);
                                        });
                                        _notify();
                                      },
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        side: BorderSide(
                                            color: isDarkMode
                                                ? Colors.white24
                                                : const Color(0xFFE2E8F0)),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _showInviteCrewDialog(
                                          isDarkMode, approvedCrews),
                                      icon: const Icon(
                                          Icons.person_add_alt_1_rounded,
                                          size: 16),
                                      label: const Text('Invite Crewgate'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor:
                                            const Color(0xFFC2185B),
                                        side: const BorderSide(
                                            color: Color(0xFFC2185B)),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 10),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _autoDistributeEvenly,
                                      icon: const Icon(Icons.balance_rounded,
                                          size: 16),
                                      label: const Text('Bagi Merata'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF1B2A8C),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 10),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Section Heading with Selected Count
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                'Daftar Gate Crew Terverifikasi',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1B2A8C)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$selectedCount Dipilih',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isDarkMode
                                      ? Colors.white
                                      : const Color(0xFF1B2A8C),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        if (approvedCrews.isEmpty) ...[
                          // Empty State
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: cardBorder),
                            ),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.badge_outlined,
                                  size: 40,
                                  color: Color(0xFF98A2B3),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Belum ada Gate Crew yang disetujui',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Anda tetap dapat mengajukan konser ini sekarang dan menugaskan gate crew nanti di menu Tim setelah kru disetujui Admin.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: subtextColor,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          // Crew List
                          ...approvedCrews.map((crew) {
                            final isAssigned =
                                _assignments.containsKey(crew.id);
                            final currentGate = _assignments[crew.id] ??
                                (_gateOptions.isNotEmpty
                                    ? _gateOptions.first
                                    : '');

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isAssigned
                                      ? const Color(0xFF1B2A8C)
                                      : cardBorder,
                                  width: isAssigned ? 1.5 : 1.0,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Checkbox(
                                        value: isAssigned,
                                        activeColor: const Color(0xFF1B2A8C),
                                        onChanged: (val) =>
                                            _toggleCrew(crew.id, val ?? false),
                                      ),
                                      const SizedBox(width: 4),
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor:
                                            const Color(0xFF1B2A8C),
                                        child: Text(
                                          crew.name.isNotEmpty
                                              ? crew.name[0].toUpperCase()
                                              : 'C',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
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
                                            Text(
                                              crew.email,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                color: subtextColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (isAssigned) ...[
                                    const SizedBox(height: 10),
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          left: 48, right: 8),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Penugasan Pos Gate:',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: subtextColor,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                  color:
                                                      const Color(0xFFD0D5DD)),
                                            ),
                                            child: DropdownButton<String>(
                                              value: _gateOptions
                                                      .contains(currentGate)
                                                  ? currentGate
                                                  : (_gateOptions.isNotEmpty
                                                      ? _gateOptions.first
                                                      : null),
                                              isExpanded: true,
                                              underline: const SizedBox(),
                                              icon: const Icon(
                                                Icons.arrow_drop_down,
                                                color: Color(0xFF0F172A),
                                              ),
                                              dropdownColor: Colors.white,
                                              style: const TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF0F172A),
                                              ),
                                              items: _gateOptions.map((gate) {
                                                return DropdownMenuItem<String>(
                                                  value: gate,
                                                  child: Text(
                                                    gate,
                                                    style: const TextStyle(
                                                      color: Color(0xFF0F172A),
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                              onChanged: (val) {
                                                if (val != null) {
                                                  _changeGate(crew.id, val);
                                                }
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }),
                        ],

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),

                // Bottom Sticky Button
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _validateAndProceed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B2A8C), // Navy
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Lanjut ke Ringkasan & Approval',
                        style: TextStyle(
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
      },
    );
  }
}