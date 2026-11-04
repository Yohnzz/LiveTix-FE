import 'package:flutter/material.dart';
import '../../../utils/file_picker_helper.dart';
import '../promoter_main_screen.dart';
import '../widgets/responsive_promoter_wrapper.dart';
import 'approval_rejected_screen.dart';
import 'approval_waiting_screen.dart';
import 'step1_producer_profile_screen.dart';
import 'step2_upload_ktp_screen.dart';

enum ProducerVerificationStage {
  lengkapiProfil,
  unggahDokumen,
  approvalMenunggu,
  approvalDitolak,
}

class ProducerVerificationFlow extends StatefulWidget {
  final ProducerVerificationStage initialStage;
  final String? initialName;
  final String? initialPhone;

  const ProducerVerificationFlow({
    super.key,
    this.initialStage = ProducerVerificationStage.lengkapiProfil,
    this.initialName,
    this.initialPhone,
  });

  @override
  State<ProducerVerificationFlow> createState() =>
      _ProducerVerificationFlowState();
}

class _ProducerVerificationFlowState extends State<ProducerVerificationFlow> {
  late ProducerVerificationStage _currentStage;

  late final TextEditingController _fullNameController;
  late final TextEditingController _birthDateController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;

  String _ktpFileName = 'ktp_rafi_firmansyah.jpg';
  bool _isKtpUploaded = false;

  @override
  void initState() {
    super.initState();
    _currentStage = widget.initialStage;
    _fullNameController = TextEditingController(
      text: widget.initialName?.trim() ?? '',
    );
    _birthDateController = TextEditingController();
    _phoneController = TextEditingController(
      text: widget.initialPhone?.trim() ?? '',
    );
    _addressController = TextEditingController();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _birthDateController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  String get _defaultKtpName {
    final rawName = _fullNameController.text.trim().isNotEmpty
        ? _fullNameController.text
            .trim()
            .toLowerCase()
            .replaceAll(RegExp(r'\s+'), '_')
        : 'rafi_firmansyah';
    return 'ktp_$rawName.jpg';
  }

  Future<void> _showUploadKtpSheet() async {
    final fileNameCtrl = TextEditingController(text: _defaultKtpName);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Unggah Dokumen KTP',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF101828),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Pilih file foto/scan KTP dari perangkat Anda (.jpg, .png, .pdf) atau konfirmasi nama file dokumen:',
              style: TextStyle(
                fontSize: 12.5,
                color: Color(0xFF667085),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),

            // Button 1: Pick file from OS / Browser File Explorer
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final pickedName = await pickNativeFile();
                  if (pickedName != null && pickedName.trim().isNotEmpty) {
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    setState(() {
                      _ktpFileName = pickedName.trim();
                      _isKtpUploaded = true;
                    });
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('Dokumen $_ktpFileName berhasil diunggah'),
                        backgroundColor: const Color(0xFFC2185B),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                icon: const Icon(
                  Icons.folder_open_rounded,
                  size: 20,
                  color: Color(0xFFC2185B),
                ),
                label: const Text(
                  'Pilih File dari Perangkat / Explorer',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFC2185B),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFC2185B), width: 1.2),
                  backgroundColor: const Color(0xFFFFFAFD),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            TextField(
              controller: fileNameCtrl,
              style: const TextStyle(fontSize: 13.5, color: Color(0xFF101828)),
              decoration: InputDecoration(
                labelText: 'Nama File KTP',
                hintText: 'Contoh: ktp_rafi_firmansyah.jpg',
                prefixIcon: const Icon(
                  Icons.description_outlined,
                  size: 19,
                  color: Color(0xFF667085),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B2A8C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  final chosen = fileNameCtrl.text.trim().isNotEmpty
                      ? fileNameCtrl.text.trim()
                      : _defaultKtpName;
                  Navigator.pop(ctx);
                  setState(() {
                    _ktpFileName = chosen;
                    _isKtpUploaded = true;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Dokumen $_ktpFileName berhasil diunggah'),
                      backgroundColor: const Color(0xFFC2185B),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.cloud_upload_outlined, size: 19),
                label: const Text(
                  'Unggah Dokumen KTP',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onDeleteKtp() {
    setState(() {
      _isKtpUploaded = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Dokumen KTP dihapus. Silakan pilih dokumen KTP terlebih dahulu.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _onSubmitVerification() {
    if (!_isKtpUploaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Silakan unggah dokumen KTP terlebih dahulu sebelum mengajukan verifikasi.'),
          backgroundColor: Color(0xFFC2185B),
          duration: Duration(seconds: 2),
        ),
      );
      _showUploadKtpSheet();
      return;
    }
    setState(() {
      _currentStage = ProducerVerificationStage.approvalMenunggu;
    });
  }

  void _showContactAdminDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Hubungi Tim Verifikasi LiveTix',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF101828),
          ),
        ),
        content: const Text(
          'Tim Admin LiveTix siap membantu kendala verifikasi dokumen SIUP & KTP perusahaan Anda melalui layanan prioritas mitra.',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF667085),
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _currentStage = ProducerVerificationStage.lengkapiProfil;
              });
            },
            child: const Text(
              'Isi Ulang Data',
              style: TextStyle(
                color: Color(0xFFC2185B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B2A8C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const PromoterMainScreen(),
                ),
              );
            },
            child: const Text('Buka Dasbor Produser'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget activeScreen;

    switch (_currentStage) {
      case ProducerVerificationStage.lengkapiProfil:
        activeScreen = Step1ProducerProfileScreen(
          fullNameController: _fullNameController,
          birthDateController: _birthDateController,
          phoneController: _phoneController,
          addressController: _addressController,
          onNext: () {
            setState(() {
              _currentStage = ProducerVerificationStage.unggahDokumen;
            });
          },
          onBack: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const PromoterMainScreen(),
                ),
              );
            }
          },
        );
        break;

      case ProducerVerificationStage.unggahDokumen:
        activeScreen = Step2UploadKtpScreen(
          ktpFileName: _ktpFileName,
          isKtpUploaded: _isKtpUploaded,
          onPickOrReplaceKtp: _showUploadKtpSheet,
          onDeleteKtp: _onDeleteKtp,
          onSubmit: _onSubmitVerification,
          onBack: () {
            setState(() {
              _currentStage = ProducerVerificationStage.lengkapiProfil;
            });
          },
        );
        break;

      case ProducerVerificationStage.approvalMenunggu:
        activeScreen = ApprovalWaitingScreen(
          responsiblePersonName: _fullNameController.text,
          onCheckStatus: () {
            setState(() {
              _currentStage = ProducerVerificationStage.approvalDitolak;
            });
          },
        );
        break;

      case ProducerVerificationStage.approvalDitolak:
        activeScreen = ApprovalRejectedScreen(
          onContactAdmin: _showContactAdminDialog,
          onBack: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const PromoterMainScreen(),
                ),
              );
            }
          },
          onResubmit: null,
        );
        break;
    }

    return ResponsivePromoterWrapper(
      child: activeScreen,
    );
  }
}
