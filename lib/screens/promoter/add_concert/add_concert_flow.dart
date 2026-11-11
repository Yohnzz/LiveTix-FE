import 'package:flutter/material.dart';
import '../../../models/promoter_models.dart';
import '../../../services/gate_crew_service.dart';
import '../../../services/promoter_data_service.dart';
import '../../../utils/file_picker_helper.dart';
import '../../../utils/uuid_utils.dart';
import '../concert_status_detail_screen.dart';
import '../widgets/responsive_promoter_wrapper.dart';
import 'step1_detail_poster_screen.dart';
import 'step2_venue_location_screen.dart';
import 'step3_ticket_pricing_screen.dart';
import 'step4_select_gate_crew_screen.dart';
import 'step4_summary_review_screen.dart';

class AddConcertFlow extends StatefulWidget {
  final int initialStep;
  final PromoterConcertItem? editingConcert;

  const AddConcertFlow({
    super.key,
    this.initialStep = 1,
    this.editingConcert,
  });

  @override
  State<AddConcertFlow> createState() => _AddConcertFlowState();
}

class _AddConcertFlowState extends State<AddConcertFlow> {
  late int _currentStep;

  // Step 1 Controllers & State (kosong saat tambah konser baru, terisi saat edit)
  late final TextEditingController _nameController;
  late final TextEditingController _dateTimeController;
  late final TextEditingController _descriptionController;
  late String _posterFileName;
  late String _squareLogoFileName;

  // Step 2 State
  late String _venueName;
  late String _venueAddress;
  late String _venueSearchQuery;

  // Step 3 State
  late List<PromoterTicketTier> _ticketTiers;

  // Step 4 State: Pemilihan Gate Crew
  Map<String, String> _selectedCrewWithGate = {};

  bool get _isEditMode => widget.editingConcert != null;

  @override
  void initState() {
    super.initState();
    _currentStep = widget.initialStep;
    final editing = widget.editingConcert;

    if (editing != null) {
      _nameController = TextEditingController(text: editing.title);
      _dateTimeController = TextEditingController(
        text: editing.time.isNotEmpty
            ? '${editing.date} - ${editing.time}'
            : editing.date,
      );
      _descriptionController = TextEditingController(text: editing.description);
      _posterFileName = editing.posterFileName;
      _squareLogoFileName = editing.squareLogoFileName;
      _venueName = editing.venueName;
      _venueAddress = editing.venueAddress;
      _venueSearchQuery = editing.venueName;
      _ticketTiers = List<PromoterTicketTier>.from(editing.tiers);
    } else {
      _nameController = TextEditingController();
      _dateTimeController = TextEditingController();
      _descriptionController = TextEditingController();
      _posterFileName = '';
      _squareLogoFileName = '';
      _venueName = '';
      _venueAddress = '';
      _venueSearchQuery = '';
      _ticketTiers = [];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dateTimeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _onBack() {
    if (_currentStep > 1) {
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  void _onNext() {
    if (_currentStep < 5) {
      setState(() => _currentStep++);
    }
  }

  Future<void> _pickPosterFile() async {
    final picked = await pickNativeFile();
    if (picked != null && picked.trim().isNotEmpty) {
      setState(() => _posterFileName = picked.trim());
    }
    if (!mounted || _posterFileName.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Poster terpilih: $_posterFileName'),
        backgroundColor: const Color(0xFFC2185B),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _pickSquareLogoFile() async {
    final picked = await pickNativeFile();
    if (picked != null && picked.trim().isNotEmpty) {
      setState(() => _squareLogoFileName = picked.trim());
    }
    if (!mounted || _squareLogoFileName.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Logo persegi (1:1) terpilih: $_squareLogoFileName'),
        backgroundColor: const Color(0xFF1B2A8C),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<bool> _showEditConfirmationDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => Theme(
        data: ThemeData.light(),
        child: AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B2A8C).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.admin_panel_settings_rounded,
                  color: Color(0xFF1B2A8C),
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Konfirmasi Perubahan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'Semua yang telah diedit akan terganti setelah Admin menyetujui.',
            style: TextStyle(
              fontSize: 13.5,
              color: Color(0xFF334155),
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF475569),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(
                'Kembali',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B2A8C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(
                'Lanjutkan',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
    return confirmed == true;
  }

  void _submitConcert([Map<String, String>? invitedCrew]) async {
    final service = PromoterDataService();

    if (_isEditMode) {
      final proceed = await _showEditConfirmationDialog();
      if (!proceed || !mounted) return;

      final original = widget.editingConcert!;
      final resolvedTitle = _nameController.text.trim().isNotEmpty
          ? _nameController.text.trim()
          : original.title;
      final resolvedVenue =
          _venueName.trim().isNotEmpty ? _venueName.trim() : original.venueName;
      final resolvedDate = _dateTimeController.text.trim().isNotEmpty
          ? _dateTimeController.text.trim()
          : original.date;

      final updatedConcert = original.copyWith(
        title: resolvedTitle,
        dateAndVenue: '$resolvedDate · $resolvedVenue',
        date: resolvedDate,
        venueName: resolvedVenue,
        venueAddress: _venueAddress.trim().isNotEmpty
            ? _venueAddress.trim()
            : original.venueAddress,
        description: _descriptionController.text.trim(),
        posterFileName: _posterFileName.isNotEmpty
            ? _posterFileName
            : original.posterFileName,
        squareLogoFileName: _squareLogoFileName.isNotEmpty
            ? _squareLogoFileName
            : original.squareLogoFileName,
        status: ConcertStatus.menunggu,
        tiers: _ticketTiers.isNotEmpty ? _ticketTiers : original.tiers,
      );

      service.updateConcert(updatedConcert, requiresAdminApproval: true);

      if (invitedCrew != null && invitedCrew.isNotEmpty) {
        for (final entry in invitedCrew.entries) {
          await GateCrewService().inviteCrewToConcert(
            crewId: entry.key,
            concertId: updatedConcert.id,
            concertTitle: updatedConcert.title,
            venue: updatedConcert.venueName,
            gateName: entry.value,
          );
        }
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ConcertStatusDetailScreen(
            concertTitle: updatedConcert.title,
            status: ConcertStatus.menunggu,
          ),
        ),
      );
      return;
    }

    if (service.quotaRemainingNotifier.value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kuota pengajuan harian Anda telah habis.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final resolvedTitle = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : 'Konser Baru LiveTix';
    final resolvedVenue =
        _venueName.trim().isNotEmpty ? _venueName.trim() : 'Venue Konser';
    final resolvedDate = _dateTimeController.text.trim().isNotEmpty
        ? _dateTimeController.text.trim()
        : 'Jadwal Segera Diumumkan';

    final assignedGates = invitedCrew?.values
            .map((v) => v.trim())
            .where((v) => v.isNotEmpty)
            .toSet()
            .toList() ??
        const <String>[];

    final newConcert = PromoterConcertItem(
      id: UuidUtils.generateV4(),
      title: resolvedTitle,
      dateAndVenue: '$resolvedDate · $resolvedVenue',
      date: resolvedDate,
      venueName: resolvedVenue,
      venueAddress: _venueAddress.trim(),
      description: _descriptionController.text.trim(),
      posterFileName:
          _posterFileName.isNotEmpty ? _posterFileName : 'poster_konser.png',
      squareLogoFileName:
          _squareLogoFileName.isNotEmpty ? _squareLogoFileName : 'logo_1x1.png',
      status: ConcertStatus.menunggu,
      likesCount: '0',
      tiers: _ticketTiers,
      gates: assignedGates,
    );

    final success = service.addConcert(newConcert);
    if (!success) return;

    if (invitedCrew != null && invitedCrew.isNotEmpty) {
      for (final entry in invitedCrew.entries) {
        await GateCrewService().inviteCrewToConcert(
          crewId: entry.key,
          concertId: newConcert.id,
          concertTitle: newConcert.title,
          venue: newConcert.venueName,
          gateName: entry.value,
        );
      }
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ConcertStatusDetailScreen(
          concertTitle: newConcert.title,
          status: ConcertStatus.menunggu,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget activeScreen;

    switch (_currentStep) {
      case 1:
        activeScreen = Step1DetailPosterScreen(
          nameController: _nameController,
          dateTimeController: _dateTimeController,
          descriptionController: _descriptionController,
          posterFileName: _posterFileName,
          squareLogoFileName: _squareLogoFileName,
          onPickPoster: _pickPosterFile,
          onPickSquareLogo: _pickSquareLogoFile,
          onNext: _onNext,
          onBack: _onBack,
          isEditMode: _isEditMode,
        );
        break;
      case 2:
        activeScreen = Step2VenueLocationScreen(
          venueName: _venueName,
          venueAddress: _venueAddress,
          venueSearchQuery: _venueSearchQuery,
          onVenueChanged: (name, address, query) {
            setState(() {
              _venueName = name;
              _venueAddress = address;
              _venueSearchQuery = query;
            });
          },
          onNext: _onNext,
          onBack: _onBack,
        );
        break;
      case 3:
        activeScreen = Step3TicketPricingScreen(
          tiers: _ticketTiers,
          onTiersChanged: (updated) => setState(() => _ticketTiers = updated),
          onNext: _onNext,
          onBack: _onBack,
        );
        break;
      case 4:
        activeScreen = Step4SelectGateCrewScreen(
          selectedCrewWithGate: _selectedCrewWithGate,
          onCrewAssignmentsChanged: (updated) {
            setState(() => _selectedCrewWithGate = updated);
          },
          onNext: _onNext,
          onBack: _onBack,
        );
        break;
      case 5:
      default:
        activeScreen = Step4SummaryReviewScreen(
          concertTitle: _nameController.text.trim(),
          concertDate: _dateTimeController.text.trim(),
          concertDescription: _descriptionController.text.trim(),
          posterFileName: _posterFileName,
          squareLogoFileName: _squareLogoFileName,
          venueName: _venueName,
          venueAddress: _venueAddress,
          tiers: _ticketTiers,
          initialInvitedCrew: _selectedCrewWithGate,
          onSubmit: _submitConcert,
          onBack: _onBack,
          isEditMode: _isEditMode,
        );
        break;
    }

    return ResponsivePromoterWrapper(
      child: activeScreen,
    );
  }
}
