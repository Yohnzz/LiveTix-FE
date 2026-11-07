import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../models/gate_crew_models.dart';
import '../../models/promoter_models.dart';
import '../../services/data_service.dart';
import '../../services/gate_crew_service.dart';
import '../../services/promoter_data_service.dart';
import '../../utils/file_picker_helper.dart';

class PromoterTeamScreen extends StatefulWidget {
  const PromoterTeamScreen({super.key});

  @override
  State<PromoterTeamScreen> createState() => _PromoterTeamScreenState();
}

class _PromoterTeamScreenState extends State<PromoterTeamScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'Semua';
  final List<String> _filterOptions = [
    'Semua',
    'Ditugaskan',
    'Standby',
    'Menunggu Approval',
  ];

  @override
  void initState() {
    super.initState();
    GateCrewService().loadTeam();
  }

  List<({String id, String title, String venue})> _getAssignableConcerts() {
    final promoterActive = PromoterDataService()
        .activeConcerts
        .where((c) => c.status == ConcertStatus.disetujui)
        .map((c) => (id: c.id, title: c.title, venue: c.venueName))
        .toList();
    if (promoterActive.isNotEmpty) return promoterActive;

    return DataService()
        .rawConcerts
        .map((c) => (id: c.id, title: c.title, venue: c.venue))
        .toList();
  }

  void _showAssignDialog(GateCrewMemberModel member) {
    if (!member.isApproved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Akun Gate Crew ini masih menunggu persetujuan Admin sebelum dapat ditugaskan.'),
          backgroundColor: Color(0xFFD97706),
        ),
      );
      return;
    }

    final concerts = _getAssignableConcerts();
    if (concerts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Belum ada konser aktif untuk penugasan gate crew')),
      );
      return;
    }

    String selectedConcertId = concerts.first.id;
    String selectedGate = 'Gate A';

    showDialog<void>(
      context: context,
      builder: (ctx) => Theme(
        data: ThemeData.light(),
        child: StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final concert =
                concerts.firstWhere((c) => c.id == selectedConcertId);

            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.person_add_alt_1_rounded,
                        color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tugaskan Gate Crew',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          '${member.name} (${member.email})',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF475569),
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
                  const Text(
                    'Pilih Konser:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedConcertId,
                        isExpanded: true,
                        dropdownColor: Colors.white,
                        iconEnabledColor: const Color(0xFF0F172A),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                        items: concerts.map((c) {
                          return DropdownMenuItem(
                            value: c.id,
                            child: Text(
                              c.title,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedConcertId = val);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Pilih Pos Gate:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedGate,
                        isExpanded: true,
                        dropdownColor: Colors.white,
                        iconEnabledColor: const Color(0xFF0F172A),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Gate A',
                            child: Text(
                              'Gate A (VIP & Reguler)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'Gate B',
                            child: Text(
                              'Gate B (Festival Standing)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'Gate C',
                            child: Text(
                              'Gate C (Fast Track)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        ],
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
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Batal',
                    style: TextStyle(
                      color: Color(0xFF475569),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await GateCrewService().inviteCrewToConcert(
                      crewId: member.id,
                      concertId: concert.id,
                      concertTitle: concert.title,
                      venue: concert.venue,
                      gateName: selectedGate,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Berhasil menugaskan ${member.name} ke ${concert.title} ($selectedGate)'),
                          backgroundColor: const Color(0xFF16A34A),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
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

  void _showAddGateCrewDialog() {
    // Mode 0: Input Manual (bisa + Tambah 1 Akun), Mode 1: Upload CSV / Excel Template
    int selectedMode = 0;
    final List<TextEditingController> manualEmailControllers = [
      TextEditingController(),
    ];
    String? uploadedFileName;
    List<String> parsedCsvEmails = [];
    String? errorMessage;
    bool isSubmitting = false;

    showDialog<void>(
      context: context,
      builder: (ctx) => Theme(
        data: ThemeData.light(),
        child: StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.group_add_rounded,
                        color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tambah Gate Crew',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Perlu persetujuan Admin · Password sistem: crewgate123',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF475569),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Pilihan Metode (Manual vs Upload CSV/Excel)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setDialogState(() {
                                  selectedMode = 0;
                                  errorMessage = null;
                                }),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 9),
                                  decoration: BoxDecoration(
                                    color: selectedMode == 0
                                        ? Colors.white
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Input Manual',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: selectedMode == 0
                                          ? const Color(0xFF0F172A)
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setDialogState(() {
                                  selectedMode = 1;
                                  errorMessage = null;
                                }),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 9),
                                  decoration: BoxDecoration(
                                    color: selectedMode == 1
                                        ? Colors.white
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Upload CSV / Excel',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: selectedMode == 1
                                          ? const Color(0xFF0F172A)
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Info Password Default & Unik
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline_rounded,
                                size: 17, color: Color(0xFF1D4ED8)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Password default setiap akun otomatis diatur sistem: crewgate123. Email wajib bersifat unik (tidak boleh sama) dan akan aktif setelah disetujui Admin.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF1E3A8A),
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      if (selectedMode == 0) ...[
                        const Text(
                          'Daftar Email Gate Crew:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...List.generate(manualEmailControllers.length, (idx) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: manualEmailControllers[idx],
                                    keyboardType: TextInputType.emailAddress,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF0F172A),
                                      fontWeight: FontWeight.w600,
                                    ),
                                    decoration: InputDecoration(
                                      hintText:
                                          'Akun #${idx + 1} (contoh: crew${idx + 1}@livetix.com)',
                                      hintStyle: const TextStyle(
                                        fontSize: 12.5,
                                        color: Color(0xFF94A3B8),
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.email_outlined,
                                        size: 18,
                                        color: Color(0xFF475569),
                                      ),
                                      filled: true,
                                      fillColor: const Color(0xFFF8FAFC),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 11),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(11),
                                        borderSide: const BorderSide(
                                            color: Color(0xFFCBD5E1)),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(11),
                                        borderSide: const BorderSide(
                                            color: Color(0xFFCBD5E1)),
                                      ),
                                    ),
                                  ),
                                ),
                                if (manualEmailControllers.length > 1) ...[
                                  const SizedBox(width: 6),
                                  IconButton(
                                    onPressed: () {
                                      setDialogState(() {
                                        manualEmailControllers.removeAt(idx);
                                      });
                                    },
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                      color: Color(0xFFDC2626),
                                      size: 20,
                                    ),
                                    tooltip: 'Hapus baris',
                                  ),
                                ],
                              ],
                            ),
                          );
                        }),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setDialogState(() {
                                manualEmailControllers
                                    .add(TextEditingController());
                              });
                            },
                            icon: const Icon(Icons.add_circle_outline_rounded,
                                size: 17),
                            label: const Text(
                              'Tambah 1 Akun',
                              style: TextStyle(
                                  fontSize: 12.5, fontWeight: FontWeight.w700),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(11)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ] else ...[
                        // Mode 1: Download Template & Upload CSV / Excel
                        const Text(
                          'Langkah 1: Unduh Template Resmi',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await downloadTemplateFile(
                                fileName: 'Template_Gate_Crew_LiveTix.csv',
                                content: GateCrewService.csvTemplateContent,
                                mimeType: 'text/csv',
                              );
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Template CSV/Excel Gate Crew berhasil diunduh. Silakan isi email lalu unggah kembali.'),
                                    backgroundColor: Color(0xFF16A34A),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.download_rounded, size: 18),
                            label: const Text(
                              'Download Template CSV / Excel',
                              style: TextStyle(
                                  fontSize: 12.5, fontWeight: FontWeight.w700),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0F172A),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              backgroundColor: const Color(0xFFF8FAFC),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(11)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Langkah 2: Upload File Template (.csv / .xlsx)',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () async {
                            final picked = await pickNativeFileWithContent();
                            if (picked == null) return;
                            final extracted = GateCrewService
                                .parseEmailsFromCsvOrExcelContent(
                                    picked.content);
                            setDialogState(() {
                              uploadedFileName = picked.name;
                              parsedCsvEmails = extracted;
                              errorMessage = extracted.isEmpty
                                  ? 'Tidak ditemukan format email yang valid di dalam file ${picked.name}.'
                                  : null;
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: uploadedFileName != null
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  uploadedFileName != null
                                      ? Icons.check_circle_rounded
                                      : Icons.upload_file_rounded,
                                  size: 28,
                                  color: uploadedFileName != null
                                      ? const Color(0xFF16A34A)
                                      : AppColors.primary,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  uploadedFileName ??
                                      'Klik untuk pilih file CSV / Excel (.csv, .xlsx)',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                if (parsedCsvEmails.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'Terbaca ${parsedCsvEmails.length} email: ${parsedCsvEmails.join(', ')}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: Color(0xFF15803D),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],

                      if (errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: Text(
                            errorMessage!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFB91C1C),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                  child: const Text(
                    'Batal',
                    style: TextStyle(
                      color: Color(0xFF475569),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final List<String> targetEmails = selectedMode == 0
                              ? manualEmailControllers
                                  .map((c) => c.text.trim())
                                  .where((e) => e.isNotEmpty)
                                  .toList()
                              : parsedCsvEmails;

                          setDialogState(() {
                            isSubmitting = true;
                            errorMessage = null;
                          });

                          final result = await GateCrewService()
                              .requestAddGateCrewsByProducer(
                            rawEmails: targetEmails,
                          );

                          if (!result.isSuccess) {
                            setDialogState(() {
                              isSubmitting = false;
                              errorMessage = result.message;
                            });
                            return;
                          }

                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(result.message),
                                backgroundColor: const Color(0xFF16A34A),
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(isSubmitting ? 'Memproses...' : 'Ajukan ke Admin'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _unassignCrew(GateCrewMemberModel member) async {
    final assignment = member.activeAssignment;
    if (assignment == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Theme(
        data: ThemeData.light(),
        child: AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Lepas Penugasan',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          content: Text(
            'Apakah kamu yakin ingin melepas ${member.name} dari tugas di konser ${assignment.concertTitle}?',
            style: const TextStyle(fontSize: 13.5, color: Color(0xFF475569)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'Batal',
                style: TextStyle(color: Color(0xFF475569)),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
              child: const Text('Lepas'),
            ),
          ],
        ),
      ),
    );

    if (confirm == true && mounted) {
      await GateCrewService().removeCrewFromConcert(
        crewId: member.id,
        concertId: assignment.concertId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${member.name} sekarang berstatus Standby'),
            backgroundColor: const Color(0xFF475569),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final crewService = GateCrewService();

    return ValueListenableBuilder<List<GateCrewMemberModel>>(
      valueListenable: crewService.teamCrewNotifier,
      builder: (context, team, _) {
        final filtered = team.where((member) {
          final matchesQuery = _searchQuery.isEmpty ||
              member.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              member.email.toLowerCase().contains(_searchQuery.toLowerCase());

          if (!matchesQuery) return false;

          if (_selectedFilter == 'Ditugaskan') {
            return member.isAssigned && member.isApproved;
          } else if (_selectedFilter == 'Standby') {
            return !member.isAssigned && member.isApproved;
          } else if (_selectedFilter == 'Menunggu Approval') {
            return member.isPendingApproval;
          }
          return true;
        }).toList();

        final totalCrew = team.length;
        final assignedCount =
            team.where((m) => m.isAssigned && m.isApproved).length;
        final pendingCount = team.where((m) => m.isPendingApproval).length;
        final standbyCount =
            team.where((m) => !m.isAssigned && m.isApproved).length;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0.5,
            title: const Text(
              'Tim Gate Crew',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Center(
                  child: ElevatedButton.icon(
                    onPressed: _showAddGateCrewDialog,
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                    label: const Text(
                      'Tambah Crew Gate',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Banner Informasi Tim
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3E8FF),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.groups_rounded,
                            color: Color(0xFF7C3AED), size: 28),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Staf Tiket & Gate',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Tambahkan Gate Crew secara manual atau via template CSV/Excel (perlu approval Admin) lalu tugaskan ke konser Anda.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF475569),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Metrik Tim
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        'Total Crew',
                        '$totalCrew',
                        const Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetricTile(
                        'Ditugaskan',
                        '$assignedCount',
                        const Color(0xFF16A34A),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetricTile(
                        'Standby',
                        '$standbyCount',
                        const Color(0xFFF59E0B),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetricTile(
                        'Pending',
                        '$pendingCount',
                        const Color(0xFF7C3AED),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Search Bar
                TextField(
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Cari nama atau email gate crew...',
                    hintStyle:
                        const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    prefixIcon: const Icon(Icons.search,
                        size: 20, color: Color(0xFF64748B)),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _filterOptions.map((f) {
                      final isSelected = _selectedFilter == f;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            f,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: AppColors.primary,
                          backgroundColor: Colors.white,
                          onSelected: (val) {
                            if (val) setState(() => _selectedFilter = f);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                // Daftar Staf Gate Crew
                if (filtered.isEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 40, horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.person_off_outlined,
                            size: 40, color: Color(0xFF64748B)),
                        SizedBox(height: 10),
                        Text(
                          'Gate crew tidak ditemukan',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Tambahkan Gate Crew baru atau ubah kata kunci pencarian.',
                          style:
                              TextStyle(color: Color(0xFF64748B), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final member = filtered[index];
                      final isPending = member.isPendingApproval;
                      final isAssigned = member.isAssigned && member.isApproved;
                      final assignment = member.activeAssignment;

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isPending
                                ? const Color(0xFFDDD6FE)
                                : isAssigned
                                    ? const Color(0xFFE2E8F0)
                                    : const Color(0xFFFED7AA),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: isPending
                                      ? const Color(0xFFF3E8FF)
                                      : isAssigned
                                          ? const Color(0xFFECFDF5)
                                          : const Color(0xFFFEF3C7),
                                  child: Text(
                                    member.name.isNotEmpty
                                        ? member.name[0].toUpperCase()
                                        : 'G',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: isPending
                                          ? const Color(0xFF7C3AED)
                                          : isAssigned
                                              ? const Color(0xFF059669)
                                              : const Color(0xFFD97706),
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
                                        member.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        member.email,
                                        style: const TextStyle(
                                          color: Color(0xFF475569),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isPending
                                        ? const Color(0xFFF3E8FF)
                                        : isAssigned
                                            ? const Color(0xFFDCFCE7)
                                            : const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    isPending
                                        ? 'Menunggu Approval'
                                        : isAssigned
                                            ? 'Ditugaskan'
                                            : 'Standby',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isPending
                                          ? const Color(0xFF6D28D9)
                                          : isAssigned
                                              ? const Color(0xFF15803D)
                                              : const Color(0xFFB45309),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 22, color: Color(0xFFF1F5F9)),

                            // Info Penugasan / Status Approval
                            if (isPending) ...[
                              Row(
                                children: [
                                  const Icon(Icons.hourglass_top_rounded,
                                      size: 16, color: Color(0xFF7C3AED)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Menunggu persetujuan Admin · Password default: ${member.defaultPassword}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF6D28D9),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ] else if (isAssigned && assignment != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.music_note_rounded,
                                        size: 18, color: AppColors.primary),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            assignment.concertTitle,
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                          Text(
                                            '${assignment.venue} · ${assignment.gateName}',
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              color: Color(0xFF475569),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => _unassignCrew(member),
                                      style: TextButton.styleFrom(
                                        foregroundColor:
                                            const Color(0xFFDC2626),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8),
                                      ),
                                      child: const Text('Lepas Tugas',
                                          style: TextStyle(fontSize: 12)),
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Belum ada tugas konser',
                                    style: TextStyle(
                                        fontSize: 12.5,
                                        color: Color(0xFF475569)),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: () => _showAssignDialog(member),
                                    icon: const Icon(Icons.add, size: 16),
                                    label: const Text('Tugaskan ke Konser',
                                        style: TextStyle(fontSize: 12)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetricTile(String label, String count, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  const TextStyle(fontSize: 11, color: Color(0xFF475569))),
          const SizedBox(height: 4),
          Text(
            count,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
