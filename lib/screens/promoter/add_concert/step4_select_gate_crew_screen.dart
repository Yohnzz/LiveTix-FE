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

  final List<String> _gateOptions = const [
    'Gate A (Utama / VIP)',
    'Gate B (Festival Barat)',
    'Gate C (Tribun Timur)',
    'Gate D (Festival Selatan)',
    'Semua Gate (Supervisor Scan)',
  ];

  @override
  void initState() {
    super.initState();
    _assignments = Map<String, String>.from(widget.selectedCrewWithGate);
  }

  void _toggleCrew(String crewId, bool isSelected) {
    setState(() {
      if (isSelected) {
        _assignments[crewId] = _gateOptions.first;
      } else {
        _assignments.remove(crewId);
      }
    });
    widget.onCrewAssignmentsChanged(_assignments);
  }

  void _changeGate(String crewId, String gateName) {
    setState(() {
      _assignments[crewId] = gateName;
    });
    widget.onCrewAssignmentsChanged(_assignments);
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

                        const SizedBox(height: 24),

                        // Section Heading with Selected Count
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Daftar Gate Crew Terverifikasi',
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
                                color: const Color(0xFF1B2A8C)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${_assignments.length} Dipilih',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1B2A8C),
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
                                _gateOptions.first;

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
                                                  color: const Color(0xFFD0D5DD)),
                                            ),
                                            child: DropdownButton<String>(
                                              value: _gateOptions.contains(currentGate)
                                                  ? currentGate
                                                  : _gateOptions.first,
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
                                                color: Color(0xFF0F172A), // High contrast dark text!
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
                      onPressed: widget.onNext,
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

