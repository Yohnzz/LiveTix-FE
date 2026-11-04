import 'package:flutter/material.dart';
import '../../../models/promoter_models.dart';
import '../../../services/promoter_data_service.dart';
import '../../../utils/file_picker_helper.dart';
import '../concert_status_detail_screen.dart';
import '../widgets/responsive_promoter_wrapper.dart';
import 'step1_detail_poster_screen.dart';
import 'step2_venue_location_screen.dart';
import 'step3_ticket_pricing_screen.dart';
import 'step4_summary_review_screen.dart';

class AddConcertFlow extends StatefulWidget {
  final int initialStep;

  const AddConcertFlow({super.key, this.initialStep = 1});

  @override
  State<AddConcertFlow> createState() => _AddConcertFlowState();
}

class _AddConcertFlowState extends State<AddConcertFlow> {
  late int _currentStep;

  // Step 1 Controllers & State
  final _nameController =
      TextEditingController(text: 'Harmoni Nusantara 2026');
  final _dateTimeController = TextEditingController(
      text: 'Sabtu, 14 November 2026 - 19:00 WIB');
  final _descriptionController = TextEditingController(
      text:
          'Perayaan megah mahakarya musik nusantara bersama musisi papan atas nasional.');
  String _posterFileName = 'poster_harmoni_final.png';
  String _squareLogoFileName = 'logo_harmoni_square.png';

  // Step 2 State (Synced with Maps Data)
  String _venueName = 'Stadion Gajayana';
  String _venueAddress =
      'Jl. Tangkuban Perahu, Kauman, Kec. Klojen, Kota Malang, Jawa Timur 65119';
  String _venueSearchQuery = 'Stadion Gajayana Malang';

  // Step 3 State
  List<PromoterTicketTier> _ticketTiers = const [
    PromoterTicketTier(
      id: 'tier-1',
      name: 'VIP Nusantara',
      price: 750000,
      quota: 200,
      quotaType: 'Kursi',
      accentColor: Color(0xFFC2185B), // Magenta
    ),
    PromoterTicketTier(
      id: 'tier-2',
      name: 'Festival',
      price: 350000,
      quota: 1500,
      quotaType: 'Orang',
      accentColor: Color(0xFF1B2A8C), // Navy
    ),
  ];

  @override
  void initState() {
    super.initState();
    _currentStep = widget.initialStep;
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
    if (_currentStep < 4) {
      setState(() => _currentStep++);
    }
  }

  Future<void> _pickPosterFile() async {
    final picked = await pickNativeFile();
    if (picked != null && picked.trim().isNotEmpty) {
      setState(() => _posterFileName = picked.trim());
    }
    if (!mounted) return;
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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Logo persegi (1:1) terpilih: $_squareLogoFileName'),
        backgroundColor: const Color(0xFF1B2A8C),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _submitConcert() {
    final service = PromoterDataService();
    if (service.quotaRemainingNotifier.value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kuota pengajuan harian Anda telah habis.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final newConcert = PromoterConcertItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: _nameController.text.trim().isNotEmpty
          ? _nameController.text.trim()
          : 'Harmoni Nusantara 2026',
      dateAndVenue: '14 Nov · $_venueName',
      date: _dateTimeController.text.trim(),
      venueName: _venueName,
      venueAddress: _venueAddress,
      description: _descriptionController.text.trim(),
      posterFileName: _posterFileName,
      squareLogoFileName: _squareLogoFileName,
      status: ConcertStatus.menunggu,
      likesCount: '0',
      tiers: _ticketTiers,
    );

    final success = service.addConcert(newConcert);
    if (!success) return;

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
          onSubmit: _submitConcert,
          onBack: _onBack,
        );
        break;
    }

    return ResponsivePromoterWrapper(
      child: activeScreen,
    );
  }
}
