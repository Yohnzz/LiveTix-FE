import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/app_colors.dart';
import '../../models/gate_crew_models.dart';
import '../../models/user_model.dart';
import '../../services/data_service.dart';
import '../../services/gate_crew_service.dart';
import '../../services/promoter_data_service.dart';
import '../../utils/file_picker_helper.dart';
import '../../widgets/notification_bell_button.dart';
import '../auth/login_screen.dart';
import '../promoter/producer_customer_service_screen.dart';

class GateCrewMainScreen extends StatefulWidget {
  const GateCrewMainScreen({super.key});

  static const String routeName = '/gate-crew';

  @override
  State<GateCrewMainScreen> createState() => _GateCrewMainScreenState();
}

class _GateCrewMainScreenState extends State<GateCrewMainScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _laserController;
  late Animation<double> _laserAnimation;
  late MobileScannerController _scannerController;

  String _selectedGate = 'Gate A';
  List<String> _gates = [
    'Gate A',
    'Gate B',
    'Gate C',
  ];

  bool _isTorchOn = false;
  bool _isSoundOn = true;
  bool _isRefreshing = false;
  bool _isProcessingScan = false;

  int _totalCheckedIn = 0;
  int _totalRejected = 0;
  int _targetCapacity = 0;
  List<Map<String, dynamic>> _scanHistory = [];
  String? _loadedConcertId;

  @override
  void initState() {
    super.initState();
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _laserAnimation = Tween<double>(begin: 0.1, end: 0.9).animate(
      CurvedAnimation(parent: _laserController, curve: Curves.easeInOut),
    );

    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _laserController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  /// Mengambil data statistik scan dan riwayat aktivitas asli langsung dari database Supabase
  Future<void> _loadLiveGateData(GateCrewAssignmentModel assignment) async {
    final concertId = assignment.concertId;
    if (concertId.isEmpty) return;

    // Ambil kapasitas konser dari data konser produser jika tersedia
    final promoterConcert = PromoterDataService()
        .concertsNotifier
        .value
        .where((c) =>
            c.id == concertId ||
            c.title.toLowerCase() == assignment.concertTitle.toLowerCase())
        .firstOrNull;
    if (promoterConcert != null && promoterConcert.totalCapacity > 0) {
      _targetCapacity = promoterConcert.totalCapacity;
    }

    // Ambil daftar pos gate yang ditentukan produser
    if (promoterConcert != null && promoterConcert.gates.isNotEmpty) {
      final Set<String> gateSet = {
        ...promoterConcert.gates,
        assignment.gateName,
      };
      _gates = gateSet.toList();
    } else {
      final Set<String> gateSet = {
        'Gate A',
        'Gate B',
        'Gate C',
        assignment.gateName,
      };
      _gates = gateSet.toList();
    }

    if (!_gates.contains(_selectedGate)) {
      _selectedGate = assignment.gateName;
    }

    // Muat metrik statistik dan riwayat check-in dari Supabase
    final stats =
        await GateCrewService().loadGateCheckInStats(concertId: concertId);
    final history = await GateCrewService().loadCheckInHistory(
      concertId: concertId,
      gateName: _selectedGate,
    );

    if (mounted) {
      setState(() {
        _totalCheckedIn = stats['totalCheckedIn'] ?? 0;
        _totalRejected = stats['totalRejected'] ?? 0;
        _scanHistory = history;
      });
    }
  }

  Future<void> _refreshAssignments() async {
    setState(() => _isRefreshing = true);
    final user = DataService().currentUser;
    await GateCrewService().loadTeam();
    if (user != null) {
      final fresh = await GateCrewService().fetchDirectAssignmentForUser(
        userId: user.id,
        userEmail: user.email,
      );
      if (fresh != null) {
        await _loadLiveGateData(fresh);
      }
    }
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) {
      setState(() => _isRefreshing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Status penugasan & statistik gate terbaru berhasil dimuat'),
          backgroundColor: Color(0xFF0F766E),
        ),
      );
    }
  }

  /// Verifikasi tiket nyata dari database Supabase dan memunculkan bottom sheet hasil validasi
  Future<void> _handleTicketVerification({
    required String rawScannedCode,
    required GateCrewAssignmentModel assignment,
  }) async {
    if (_isProcessingScan) return;
    setState(() => _isProcessingScan = true);

    try {
      final result = await GateCrewService().verifyTicketInDatabase(
        scannedCode: rawScannedCode,
        currentConcertId: assignment.concertId,
        currentGate: _selectedGate,
      );

      if (!mounted) return;
      await _showVerificationModal(result, assignment);
    } catch (e) {
      debugPrint('Error _handleTicketVerification: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi kesalahan validasi: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingScan = false);
      }
    }
  }

  Future<void> _showVerificationModal(
    TicketScanValidationResult result,
    GateCrewAssignmentModel assignment,
  ) async {
    final user = DataService().currentUser;
    final crewName =
        user?.name.isNotEmpty == true ? user!.name : 'Petugas Gate';
    final crewEmail = user?.email ?? '';
    final crewId = user?.id ?? '';

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        int currentUsed = result.used;

        // ── Kasus khusus: Waktu scan belum dibuka (H-1 konser) ──
        if (result.isTooEarly) {
          return _TooEarlyModal(result: result);
        }

        return StatefulBuilder(
          builder: (context, setModalState) {
            final remainingQuota = result.quota - currentUsed;
            final isQuotaExhausted = !result.isValid &&
                (result.status.toLowerCase().contains('habis') ||
                    result.status.toLowerCase().contains('kuota') ||
                    (result.invalidReason?.toLowerCase().contains('batas') == true) ||
                    (result.invalidReason?.toLowerCase().contains('kuota') == true) ||
                    currentUsed >= result.quota ||
                    remainingQuota <= 0);
            final isFullyUsed = (result.isValid && remainingQuota <= 0) || isQuotaExhausted;
            final isSuccess = result.isValid && !isFullyUsed;

            return Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: isSuccess
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFFEE2E2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isSuccess
                          ? Icons.check_circle_rounded
                          : result.isWrongGate
                              ? Icons.wrong_location_rounded
                              : isQuotaExhausted
                                  ? Icons.block_rounded
                                  : Icons.cancel_rounded,
                      color: isSuccess
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFDC2626),
                      size: 46,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    isSuccess
                        ? 'TIKET RESMI VALID'
                        : result.isWrongGate
                            ? 'SALAH POS GATE'
                            : isQuotaExhausted
                                ? 'BATAS SCAN TIKET HABIS'
                                : 'TIKET TIDAK VALID',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: isSuccess
                          ? const Color(0xFF15803D)
                          : const Color(0xFFDC2626),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isSuccess
                        ? 'Pengunjung diizinkan masuk melalui $_selectedGate'
                        : isQuotaExhausted
                            ? 'Batas scan tiket ini sudah habis. Pengunjung tidak diperbolehkan masuk lagi.'
                            : result.invalidReason ??
                                'Tiket ini tidak dapat diverifikasi untuk akses masuk.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: result.isWrongGate || isQuotaExhausted
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: result.isWrongGate || isQuotaExhausted
                          ? const Color(0xFFB91C1C)
                          : AppColors.textGrey,
                    ),
                  ),
                  if (isQuotaExhausted) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFCA5A5), width: 1.5),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFEE2E2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.shield_outlined,
                              color: Color(0xFFDC2626),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'PENGAMAN GATE AKTIF: KUOTA HABIS',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    color: Color(0xFF991B1B),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Tiket ini hanya berlaku untuk ${result.quota}x scan dan seluruh kuota telah terpakai (${result.used} dari ${result.quota} tiket telah digunakan). Akses masuk ditolak oleh sistem.',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    height: 1.35,
                                    color: Color(0xFFB91C1C),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        _buildDetailRow('Nama Pemegang', result.attendeeName),
                        if (result.customerEmail != null &&
                            result.customerEmail!.trim().isNotEmpty) ...[
                          const Divider(height: 18, color: Color(0xFFE2E8F0)),
                          _buildDetailRow('Email Pembeli', result.customerEmail!.trim()),
                        ],
                        if (result.customerNik != null &&
                            result.customerNik!.trim().isNotEmpty) ...[
                          const Divider(height: 18, color: Color(0xFFE2E8F0)),
                          _buildDetailRow(
                            'NIK (4 Digit Terakhir)',
                            result.customerNik!.trim().length >= 4
                                ? '•••• •••• •••• ${result.customerNik!.trim().substring(result.customerNik!.trim().length - 4)}'
                                : result.customerNik!.trim(),
                            isBold: true,
                          ),
                        ],
                        const Divider(height: 18, color: Color(0xFFE2E8F0)),
                        _buildDetailRow('Konser', assignment.concertTitle),
                        const Divider(height: 18, color: Color(0xFFE2E8F0)),
                        _buildDetailRow('Kategori Tiket', result.category),
                        const Divider(height: 18, color: Color(0xFFE2E8F0)),
                        _buildDetailRow('Alokasi Gate', result.gateName,
                            isBold: true,
                            highlightColor: result.isWrongGate
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF0F172A)),
                        const Divider(height: 18, color: Color(0xFFE2E8F0)),
                        _buildDetailRow(
                          'Kode Tiket',
                          result.ticketCode.isNotEmpty
                              ? result.ticketCode
                              : result.bookingCode,
                        ),
                        const Divider(height: 18, color: Color(0xFFE2E8F0)),
                        _buildDetailRow(
                          'Sisa Kuota Tiket',
                          isQuotaExhausted || remainingQuota <= 0
                              ? '0 dari ${result.quota} tiket (Habis)'
                              : result.isValid
                                  ? '$remainingQuota dari ${result.quota} tiket tersisa'
                                  : '0 Kuota',
                          isBold: true,
                          highlightColor: isSuccess
                              ? const Color(0xFF0D9488)
                              : const Color(0xFFDC2626),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (isSuccess && remainingQuota > 0) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final navigator = Navigator.of(ctx);
                              final messenger = ScaffoldMessenger.of(context);
                              await GateCrewService().executeCheckIn(
                                ticket: result,
                                countToUse: 1,
                                gateName: _selectedGate,
                                crewId: crewId,
                                crewName: crewName,
                                crewEmail: crewEmail,
                                concertTitle: assignment.concertTitle,
                              );
                              navigator.pop();
                              await _loadLiveGateData(assignment);
                              if (mounted) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Berhasil check-in 1 pengunjung: ${result.attendeeName} (${result.category})'),
                                    backgroundColor: const Color(0xFF16A34A),
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'Check-in 1 Orang',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                          ),
                        ),
                        if (remainingQuota > 1) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                final count = remainingQuota;
                                final navigator = Navigator.of(ctx);
                                final messenger = ScaffoldMessenger.of(context);
                                await GateCrewService().executeCheckIn(
                                  ticket: result,
                                  countToUse: count,
                                  gateName: _selectedGate,
                                  crewId: crewId,
                                  crewName: crewName,
                                  crewEmail: crewEmail,
                                  concertTitle: assignment.concertTitle,
                                );
                                navigator.pop();
                                await _loadLiveGateData(assignment);
                                if (mounted) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Berhasil check-in rombongan $count orang: ${result.attendeeName}'),
                                      backgroundColor: const Color(0xFF0D9488),
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F172A),
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                'Check-in Semua ($remainingQuota)',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () async {
                          final navigator = Navigator.of(ctx);
                          // Catat penolakan scan ke database agar admin/produser tahu
                          await GateCrewService().recordTicketCheckIn(
                            concertId: assignment.concertId,
                            concertTitle: assignment.concertTitle,
                            bookingCode: result.bookingCode.isNotEmpty
                                ? result.bookingCode
                                : result.ticketCode,
                            attendeeName: result.attendeeName,
                            category: result.category,
                            gateName: _selectedGate,
                            crewId: crewId,
                            crewEmail: crewEmail,
                            crewName: crewName,
                            scannedCount: 0,
                            quota: result.quota,
                            status: result.status,
                            notes: result.invalidReason,
                          );
                          navigator.pop();
                          await _loadLiveGateData(assignment);
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          isQuotaExhausted
                              ? 'Tutup & Tolak Pengunjung'
                              : 'Tutup & Lanjutkan Scan',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: isQuotaExhausted
                                ? const Color(0xFFDC2626)
                                : AppColors.textDark,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showManualInputDialog({
    required GateCrewAssignmentModel assignment,
  }) {
    final codeCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.keyboard_alt_outlined, color: AppColors.primary),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Input Kode Tiket',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan kode booking atau nomor tiket penonton jika QR code tidak terbaca kamera:',
              style: TextStyle(fontSize: 13, color: AppColors.textGrey),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: codeCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'Contoh: ORD-127528 / LTX-998822',
                hintStyle:
                    const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal',
                style: TextStyle(color: AppColors.textGrey)),
          ),
          ElevatedButton(
            onPressed: () {
              final code = codeCtrl.text.trim();
              Navigator.pop(ctx);
              if (code.isNotEmpty) {
                _handleTicketVerification(
                  rawScannedCode: code,
                  assignment: assignment,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Validasi Tiket'),
          ),
        ],
      ),
    );
  }

  void _showEditCrewProfileDialog() {
    final user = DataService().currentUser;
    final nameCtrl = TextEditingController(text: user?.name ?? 'Petugas Gate');
    final oldPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    String? selectedPhoto = user?.avatarUrl;

    showDialog<void>(
      context: context,
      builder: (ctx) => Theme(
        data: ThemeData.light(),
        child: StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text(
              'Ubah Profil Gate Crew',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 22,
                        backgroundColor: Color(0xFFE0F2FE),
                        child: Icon(Icons.badge_outlined,
                            color: Color(0xFF0284C7)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          selectedPhoto ?? 'Foto Profil Default',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF475569)),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final picked = await pickNativeFile();
                          if (picked != null) {
                            setDialogState(() => selectedPhoto = picked);
                          }
                        },
                        child: const Text('Pilih Foto'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      labelText: 'Nama Petugas',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: oldPassCtrl,
                    obscureText: true,
                    style: const TextStyle(color: Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      labelText: 'Kata Sandi Lama (Opsional)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: newPassCtrl,
                    obscureText: true,
                    style: const TextStyle(color: Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      labelText: 'Kata Sandi Baru (Min. 6 Karakter)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  final newName = nameCtrl.text.trim();
                  if (newName.isNotEmpty) {
                    DataService().updateProfile(
                      name: newName,
                      avatarUrl: selectedPhoto,
                    );
                  }
                  final newPass = newPassCtrl.text.trim();
                  if (newPass.length >= 6) {
                    DataService().changePassword(
                      oldPassword: oldPassCtrl.text.trim(),
                      newPassword: newPass,
                    );
                  }
                  Navigator.pop(ctx);
                  if (mounted) {
                    setState(() {});
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(
                        content: Text('Profil Gate Crew berhasil diperbarui.'),
                        backgroundColor: Color(0xFF16A34A),
                      ),
                    );
                  }
                },
                child: const Text('Simpan'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Konfirmasi Keluar',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
          'Apakah kamu yakin ingin keluar dari Portal Gate Crew?',
          style: TextStyle(fontSize: 14, color: AppColors.textGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      DataService().logout();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Widget _buildDetailRow(String label, String value,
      {bool isBold = false, Color? highlightColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: highlightColor ?? AppColors.textDark,
            ),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final UserModel? user = DataService().currentUser;
    final String crewName =
        user?.name.isNotEmpty == true ? user!.name : 'Petugas Gate';

    final crewService = GateCrewService();

    return ValueListenableBuilder<List<GateCrewMemberModel>>(
      valueListenable: crewService.teamCrewNotifier,
      builder: (context, team, _) {
        final GateCrewAssignmentModel? assignment =
            crewService.getAssignmentForUser(
          user?.id ?? '',
          userEmail: user?.email,
        );

        // KONDISI 1: Belum memiliki tugas gate
        if (assignment == null) {
          return _buildNoAssignmentScreen(crewName, user?.email ?? '');
        }

        // KONDISI 2: Memiliki tugas gate aktif
        return _buildActiveScannerScreen(crewName, assignment);
      },
    );
  }

  /// Tampilan ketika Gate Crew BELUM di-invite / tidak memiliki tugas konser
  Widget _buildNoAssignmentScreen(String crewName, String email) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF59E0B), // Kuning Amber: Standby
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Flexible(
                  child: Text(
                    'GATE CREW',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              crewName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          const NotificationBellButton(color: Colors.white),
          ValueListenableBuilder<bool>(
            valueListenable: DataService().isDarkModeNotifier,
            builder: (context, isDark, _) => IconButton(
              tooltip: 'Ganti Tema',
              icon: Icon(
                isDark ? Icons.dark_mode_outlined : Icons.wb_sunny_outlined,
                color: Colors.white,
              ),
              onPressed: DataService().toggleDarkMode,
            ),
          ),
          IconButton(
            tooltip: 'Customer Service LiveTix',
            icon: const Icon(Icons.support_agent_rounded, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProducerCustomerServiceScreen(
                    senderRole: 'Gatecrew',
                  ),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Ubah Profil',
            icon:
                const Icon(Icons.manage_accounts_outlined, color: Colors.white),
            onPressed: _showEditCrewProfileDialog,
          ),
          IconButton(
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFF87171)),
            onPressed: _logout,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF0284C7),
          onRefresh: _refreshAssignments,
          child: Center(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.assignment_late_outlined,
                    color: Color(0xFFF87171),
                    size: 48,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Akun anda tidak terinvite event manapun',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Anda belum di-invite ke konser atau event manapun oleh pihak produser. Akses kamera dan pemindaian QR code dinonaktifkan hingga akun Anda ditugaskan ke pos gate konser.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF94A3B8),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.badge_outlined,
                                  color: Color(0xFF38BDF8), size: 16),
                              SizedBox(width: 6),
                              Text(
                                'Status',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Tidak Terinvite',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFB45309),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24, color: Color(0xFF334155)),
                      _buildDarkInfoRow('Nama Staf', crewName),
                      const SizedBox(height: 8),
                      _buildDarkInfoRow('Email Akun', email),
                      const SizedBox(height: 8),
                      _buildDarkInfoRow('Akses Kamera & QR', 'Dinonaktifkan'),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isRefreshing ? null : _refreshAssignments,
                    icon: _isRefreshing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.refresh_rounded, size: 20),
                    label: Text(
                      _isRefreshing
                          ? 'Memeriksa Penugasan...'
                          : 'Periksa Penugasan Baru',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProducerCustomerServiceScreen(
                            senderRole: 'Gatecrew',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.support_agent_rounded,
                        color: Color(0xFF38BDF8), size: 18),
                    label: const Text(
                      'Customer Service LiveTix',
                      style: TextStyle(
                        color: Color(0xFFE2E8F0),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF38BDF8)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton(
                    onPressed: _logout,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF475569)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Keluar dari Akun',
                      style: TextStyle(
                        color: Color(0xFFE2E8F0),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildDarkInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12.5, color: Color(0xFFCBD5E1)),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  /// Tampilan SCANNER AKTIF ketika Gate Crew sudah di-invite oleh produser
  Widget _buildActiveScannerScreen(
      String crewName, GateCrewAssignmentModel assignment) {
    if (_loadedConcertId != assignment.concertId) {
      _loadedConcertId = assignment.concertId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadLiveGateData(assignment);
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF22C55E),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'GATE CREW SCANNER',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '$crewName · ${assignment.concertTitle}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          const NotificationBellButton(color: Colors.white),
          ValueListenableBuilder<bool>(
            valueListenable: DataService().isDarkModeNotifier,
            builder: (context, isDark, _) => IconButton(
              tooltip: 'Ganti Tema',
              icon: Icon(
                isDark ? Icons.dark_mode_outlined : Icons.wb_sunny_outlined,
                color: Colors.white,
              ),
              onPressed: DataService().toggleDarkMode,
            ),
          ),
          IconButton(
            tooltip: 'Customer Service LiveTix',
            icon: const Icon(Icons.support_agent_rounded, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProducerCustomerServiceScreen(
                    senderRole: 'Gatecrew',
                  ),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Ubah Profil',
            icon:
                const Icon(Icons.manage_accounts_outlined, color: Colors.white),
            onPressed: _showEditCrewProfileDialog,
          ),
          IconButton(
            tooltip: 'Input Kode Manual',
            icon: const Icon(Icons.keyboard_alt_outlined, color: Colors.white),
            onPressed: () => _showManualInputDialog(assignment: assignment),
          ),
          IconButton(
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFF87171)),
            onPressed: _logout,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF38BDF8),
          onRefresh: () async {
            await Future.wait([
              _refreshAssignments(),
              _loadLiveGateData(assignment),
            ]);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner Penugasan Konser Aktif
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF38BDF8)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.event_seat_rounded,
                          color: Color(0xFF38BDF8), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            assignment.concertTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${assignment.venue} · Ditugaskan di ${assignment.gateName}',
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Muat Ulang Data',
                      icon: _isRefreshing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF38BDF8),
                              ),
                            )
                          : const Icon(Icons.refresh_rounded,
                              color: Color(0xFF38BDF8), size: 20),
                      onPressed: _isRefreshing ? null : _refreshAssignments,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Selector Gate
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _gates.contains(_selectedGate)
                        ? _selectedGate
                        : (_gates.isNotEmpty ? _gates.first : 'Gate A'),
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1E293B),
                    icon:
                        const Icon(Icons.arrow_drop_down, color: Colors.white),
                    items: _gates.map((g) {
                      final isAssigned = g == assignment.gateName;
                      return DropdownMenuItem(
                        value: g,
                        child: Row(
                          children: [
                            const Icon(Icons.meeting_room_outlined,
                                size: 18, color: Color(0xFF38BDF8)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                isAssigned ? '$g (Penugasan Anda)' : g,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedGate = val);
                        _loadLiveGateData(assignment);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Viewfinder Scanner Kamera HP Asli
              Container(
                height: 270,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      MobileScanner(
                        controller: _scannerController,
                        onDetect: (capture) {
                          if (_isProcessingScan) return;
                          final barcodes = capture.barcodes;
                          for (final barcode in barcodes) {
                            final val = barcode.rawValue;
                            if (val != null && val.trim().isNotEmpty) {
                              _handleTicketVerification(
                                rawScannedCode: val.trim(),
                                assignment: assignment,
                              );
                              break;
                            }
                          }
                        },
                        errorBuilder: (context, error) {
                          return Container(
                            color: const Color(0xFF0F172A),
                            alignment: Alignment.center,
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.camera_alt_outlined,
                                    color: Color(0xFF64748B), size: 40),
                                const SizedBox(height: 10),
                                Text(
                                  'Akses Kamera: ${error.errorCode.name}\n(Gunakan tombol keyboard di kanan atas untuk input kode manual)',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: Color(0xFF94A3B8), fontSize: 12),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      // Kotak Bidik Scanner & Animasi Laser Pemindai
                      Container(
                        width: 190,
                        height: 190,
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: const Color(0xFF38BDF8), width: 2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Stack(
                          children: [
                            AnimatedBuilder(
                              animation: _laserAnimation,
                              builder: (context, child) {
                                return Positioned(
                                  top: 190 * _laserAnimation.value,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    height: 2,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF22C55E),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF22C55E)
                                              .withValues(alpha: 0.8),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      // Label Petunjuk Viewfinder
                      Positioned(
                        bottom: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Arahkan kamera ke QR Code Tiket Penonton',
                            style: TextStyle(
                              color: Color(0xFFE2E8F0),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),

                      // Tombol Lampu Kilat & Audio
                      Positioned(
                        top: 14,
                        right: 14,
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                _isTorchOn
                                    ? Icons.flash_on_rounded
                                    : Icons.flash_off_rounded,
                                color: _isTorchOn
                                    ? const Color(0xFFFBBF24)
                                    : Colors.white,
                                size: 22,
                              ),
                              onPressed: () async {
                                await _scannerController.toggleTorch();
                                setState(() => _isTorchOn = !_isTorchOn);
                              },
                            ),
                            IconButton(
                              icon: Icon(
                                _isSoundOn
                                    ? Icons.volume_up_rounded
                                    : Icons.volume_off_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                              onPressed: () {
                                setState(() => _isSoundOn = !_isSoundOn);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Kartu Ringkasan Metrik Gate Asli Database
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Total Check-in',
                      value: '$_totalCheckedIn',
                      subvalue: _targetCapacity > 0
                          ? 'dari $_targetCapacity kapasitas'
                          : 'pengunjung masuk',
                      color: const Color(0xFF38BDF8),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Scan Ditolak',
                      value: '$_totalRejected',
                      subvalue: 'salah gate / kuota habis',
                      color: const Color(0xFFF87171),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Riwayat Scan Terkini Asli Database
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'AKTIVITAS SCAN TERAKHIR',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                  Text(
                    '${_scanHistory.length} Log',
                    style: const TextStyle(
                      color: Color(0xFFCBD5E1),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (_scanHistory.isEmpty)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.qr_code_scanner_outlined,
                          color: Color(0xFF64748B), size: 38),
                      SizedBox(height: 10),
                      Text(
                        'Belum ada riwayat scan',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Arahkan kamera ke tiket penonton untuk memulai validasi masuk',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _scanHistory.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final log = _scanHistory[index];
                    final isSuccess =
                        log['status'].toString().startsWith('Berhasil');

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSuccess
                              ? const Color(0xFF334155)
                              : const Color(0xFF7F1D1D),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: isSuccess
                                  ? const Color(0xFF064E3B)
                                  : const Color(0xFF450A0A),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isSuccess
                                  ? Icons.check_circle_outline
                                  : Icons.highlight_off,
                              color: isSuccess
                                  ? const Color(0xFF34D399)
                                  : const Color(0xFFF87171),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (log['name'] ?? 'Pengunjung').toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${log['category'] ?? 'Reguler'} · ${(log['bookingCode'] ?? '-').toString()}',
                                  style: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                (log['time'] ?? 'Tervalidasi').toString(),
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                (log['status'] ?? 'Berhasil').toString(),
                                style: TextStyle(
                                  color: isSuccess
                                      ? const Color(0xFF34D399)
                                      : const Color(0xFFF87171),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
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
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subvalue,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subvalue,
            style: const TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Modal khusus: Waktu Scan Belum Dibuka (H-1 konser)
// ─────────────────────────────────────────────────────────────────────────────
class _TooEarlyModal extends StatefulWidget {
  final TicketScanValidationResult result;
  const _TooEarlyModal({required this.result});

  @override
  State<_TooEarlyModal> createState() => _TooEarlyModalState();
}

class _TooEarlyModalState extends State<_TooEarlyModal> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _remaining = widget.result.timeUntilScanOpens;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final now = DateTime.now();
      final opensAt = widget.result.scanOpensAt;
      if (opensAt == null || now.isAfter(opensAt)) {
        _timer?.cancel();
        setState(() => _remaining = Duration.zero);
      } else {
        setState(() => _remaining = opensAt.difference(now));
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final days = _remaining.inDays;
    final hours = _remaining.inHours % 24;
    final minutes = _remaining.inMinutes % 60;
    final seconds = _remaining.inSeconds % 60;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 20),

            // Icon timer
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFBBF24), width: 2),
              ),
              child: const Icon(
                Icons.hourglass_top_rounded,
                color: Color(0xFFD97706),
                size: 44,
              ),
            ),
            const SizedBox(height: 14),

            // Judul
            const Text(
              'WAKTU SCAN BELUM DIBUKA',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: Color(0xFFB45309),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'QR tiket ini baru bisa digunakan mulai H-1 konser (24 jam sebelum konser dimulai).',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF78350F),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),

            // Countdown card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
              ),
              child: Column(
                children: [
                  const Text(
                    'SCAN DIBUKA DALAM',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: Color(0xFF92400E),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _timeUnit('$days', 'HARI'),
                      _colon(),
                      _timeUnit(_pad(hours), 'JAM'),
                      _colon(),
                      _timeUnit(_pad(minutes), 'MENIT'),
                      _colon(),
                      _timeUnit(_pad(seconds), 'DETIK'),
                    ],
                  ),
                  if (widget.result.scanOpensAt != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Scan dibuka: ${_formatOpensAt(widget.result.scanOpensAt!)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF92400E),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Info banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFCD34D), width: 1),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: Color(0xFFD97706), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Informasi Tiket',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF92400E),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Konser: ${widget.result.concertTitle}\n'
                          'Pemegang: ${widget.result.attendeeName}\n'
                          'Kategori: ${widget.result.category}',
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: Color(0xFF92400E),
                          ),
                        ),
                        if (widget.result.customerNik != null &&
                            widget.result.customerNik!.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            'NIK: •••• •••• •••• ${widget.result.customerNik!.trim().length >= 4 ? widget.result.customerNik!.trim().substring(widget.result.customerNik!.trim().length - 4) : widget.result.customerNik!.trim()}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Tombol tutup
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFB45309),
                  side: const BorderSide(color: Color(0xFFFBBF24), width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Tutup — Scan Tiket Lain',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeUnit(String value, String label) {
    return Column(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: Color(0xFF92400E),
          ),
        ),
      ],
    );
  }

  Widget _colon() {
    return const Padding(
      padding: EdgeInsets.only(bottom: 16, left: 4, right: 4),
      child: Text(
        ':',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w900,
          color: Color(0xFFD97706),
        ),
      ),
    );
  }

  String _formatOpensAt(DateTime dt) {
    const hari = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    const bulan = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    final d = hari[dt.weekday - 1];
    final b = bulan[dt.month - 1];
    final jam = '${_pad(dt.hour)}.${_pad(dt.minute)} WIB';
    return '$d, ${dt.day} $b ${dt.year} pukul $jam';
  }
}
