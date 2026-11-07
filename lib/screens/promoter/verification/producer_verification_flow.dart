import 'package:flutter/material.dart';
import '../../../services/data_service.dart';
import '../../../services/promoter_data_service.dart';
import '../../../utils/file_picker_helper.dart';
import '../../auth/login_screen.dart';
import '../promoter_pin_lock_screen.dart';
import '../widgets/responsive_promoter_wrapper.dart';
import 'approval_rejected_screen.dart';
import 'approval_waiting_screen.dart';
import 'step1_producer_profile_screen.dart';
import 'step2_upload_ktp_screen.dart';
import 'step3_create_pin_screen.dart';

enum ProducerVerificationStage {
  lengkapiProfil,
  unggahDokumen,
  buatPin,
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

  String _responsibilityLetterFileName =
      'Lembar_Penanggung_Jawab_Produser.doc';
  bool _isResponsibilityLetterUploaded = false;

  static const String responsibilityWordTemplateDoc = '''
<html xmlns:o='urn:schemas-microsoft-com:office:office'
      xmlns:w='urn:schemas-microsoft-com:office:word'
      xmlns='http://www.w3.org/TR/REC-html40'>
<head><meta charset='utf-8'><title>Lembar Penanggung Jawab Produser LiveTix</title></head>
<body style="font-family: Arial, sans-serif; line-height: 1.6; padding: 24px;">
  <h2 style="text-align: center; text-transform: uppercase;">SURAT PERNYATAAN &amp; LEMBAR PENANGGUNG JAWAB PRODUSER / PROMOTOR</h2>
  <p style="text-align: center;"><strong>PLATFORM TIKET KONSER LIVETIX INDONESIA</strong></p>
  <hr/>
  <p>Saya yang bertanda tangan di bawah ini:</p>
  <table style="width: 100%; border-collapse: collapse;">
    <tr><td style="width: 220px; padding: 4px 0;">Nama Lengkap Penanggung Jawab</td><td>: ............................................................</td></tr>
    <tr><td style="padding: 4px 0;">Nomor Induk Kependudukan (NIK)</td><td>: ............................................................</td></tr>
    <tr><td style="padding: 4px 0;">Jabatan / Peran</td><td>: Penanggung Jawab Utama / Direktur Promotor</td></tr>
    <tr><td style="padding: 4px 0;">Nama Perusahaan / Promotor</td><td>: ............................................................</td></tr>
    <tr><td style="padding: 4px 0;">Nomor Telepon / WhatsApp Aktif</td><td>: ............................................................</td></tr>
    <tr><td style="padding: 4px 0;">Alamat Kantor Pusat</td><td>: ............................................................</td></tr>
  </table>
  <p>Dengan ini menyatakan dengan sesungguhnya bahwa:</p>
  <ol>
    <li>Seluruh data identitas diri (KTP) dan dokumen legalitas promotor yang diunggah ke sistem LiveTix adalah benar, sah, dan dapat dipertanggungjawabkan secara hukum.</li>
    <li>Bersedia mematuhi seluruh kebijakan penyelenggaraan konser, pengaturan kuota/daya tampung venue, serta prosedur persetujuan (approval) dari pihak Admin LiveTix.</li>
    <li>Bertanggung jawab penuh atas pelaksanaan acara konser serta pengembalian dana (refund) kepada pembeli tiket apabila terjadi pembatalan acara.</li>
  </ol>
  <br/>
  <p style="text-align: right;">.........................., Tanggal .... / .... / 2026</p>
  <p style="text-align: right;">Hormat Saya, Penanggung Jawab Promotor</p>
  <br/><br/>
  <p style="text-align: right;"><em>(Materai Rp10.000 &amp; Tanda Tangan)</em></p>
  <p style="text-align: right;"><strong>( ..................................................... )</strong></p>
</body>
</html>
''';

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

  String get _defaultResponsibilityDocName {
    final rawName = _fullNameController.text.trim().isNotEmpty
        ? _fullNameController.text
            .trim()
            .toLowerCase()
            .replaceAll(RegExp(r'\s+'), '_')
        : 'produser';
    return 'lembar_penanggung_jawab_$rawName.doc';
  }

  Future<void> _downloadResponsibilityTemplate() async {
    await downloadTemplateFile(
      fileName: 'Template_Lembar_Penanggung_Jawab_Produser_LiveTix.doc',
      content: responsibilityWordTemplateDoc,
      mimeType: 'application/msword',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Template Word (.doc) Lembar Penanggung Jawab berhasil diunduh. Silakan isi lalu unggah ke kolom di bawah.'),
        backgroundColor: Color(0xFF1B2A8C),
        duration: Duration(seconds: 3),
      ),
    );
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
      builder: (ctx) => Theme(
        data: ThemeData.light(),
        child: Padding(
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
                    icon: const Icon(Icons.close,
                        size: 20, color: Color(0xFF101828)),
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
                    side:
                        const BorderSide(color: Color(0xFFC2185B), width: 1.2),
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
                style:
                    const TextStyle(fontSize: 13.5, color: Color(0xFF101828)),
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
                        content:
                            Text('Dokumen $_ktpFileName berhasil diunggah'),
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
      ),
    );
  }

  Future<void> _showUploadResponsibilitySheet() async {
    final fileNameCtrl =
        TextEditingController(text: _defaultResponsibilityDocName);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Theme(
        data: ThemeData.light(),
        child: Padding(
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
                    'Unggah Lembar Penanggung Jawab',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF101828),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        size: 20, color: Color(0xFF101828)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Pilih file Word (.doc / .docx) atau PDF Lembar Penanggung Jawab yang telah diisi sesuai template:',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF667085),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
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
                        _responsibilityLetterFileName = pickedName.trim();
                        _isResponsibilityLetterUploaded = true;
                      });
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Lembar Penanggung Jawab $_responsibilityLetterFileName berhasil diunggah'),
                          backgroundColor: const Color(0xFF1B2A8C),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  icon: const Icon(
                    Icons.folder_open_rounded,
                    size: 20,
                    color: Color(0xFF1B2A8C),
                  ),
                  label: const Text(
                    'Pilih File Word / PDF dari Perangkat',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1B2A8C),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side:
                        const BorderSide(color: Color(0xFF1B2A8C), width: 1.2),
                    backgroundColor: const Color(0xFFF0F4FF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: fileNameCtrl,
                style:
                    const TextStyle(fontSize: 13.5, color: Color(0xFF101828)),
                decoration: InputDecoration(
                  labelText: 'Nama File Lembar Penanggung Jawab',
                  prefixIcon: const Icon(
                    Icons.article_outlined,
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
                        : _defaultResponsibilityDocName;
                    Navigator.pop(ctx);
                    setState(() {
                      _responsibilityLetterFileName = chosen;
                      _isResponsibilityLetterUploaded = true;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Lembar Penanggung Jawab $_responsibilityLetterFileName berhasil diunggah'),
                        backgroundColor: const Color(0xFF1B2A8C),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.cloud_upload_outlined, size: 19),
                  label: const Text(
                    'Unggah Lembar Penanggung Jawab',
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

  void _onDeleteResponsibilityLetter() {
    setState(() {
      _isResponsibilityLetterUploaded = false;
    });
  }

  void _onProceedFromDocumentsToPin() {
    if (!_isKtpUploaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Silakan unggah dokumen KTP terlebih dahulu sebelum melanjutkan.'),
          backgroundColor: Color(0xFFC2185B),
          duration: Duration(seconds: 2),
        ),
      );
      _showUploadKtpSheet();
      return;
    }
    setState(() {
      _currentStage = ProducerVerificationStage.buatPin;
    });
  }

  Future<void> _onCompletePinAndSubmitVerification(String pinCode) async {
    final fullName = _fullNameController.text.trim().isNotEmpty
        ? _fullNameController.text.trim()
        : (DataService().currentUser?.name ?? 'Produser LiveTix');

    await PromoterDataService().submitInitialVerification(
      fullName: fullName,
      birthDate: _birthDateController.text.trim(),
      phone: _phoneController.text.trim(),
      address: _addressController.text.trim(),
      ktpFileName: _ktpFileName,
      responsibilityLetterFileName: _responsibilityLetterFileName,
      pinCode: pinCode,
    );

    if (!mounted) return;
    setState(() {
      _currentStage = ProducerVerificationStage.approvalMenunggu;
    });
  }

  void _showContactAdminDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Theme(
        data: ThemeData.light(),
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text(
            'Hubungi Tim Verifikasi LiveTix',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF101828),
            ),
          ),
          content: const Text(
            'Tim Admin LiveTix siap membantu kendala verifikasi dokumen Lembar Penanggung Jawab & KTP perusahaan Anda melalui layanan prioritas mitra.',
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
                DataService().logout();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LoginScreen(),
                  ),
                  (route) => false,
                );
              },
              child: const Text('Kembali ke Login'),
            ),
          ],
        ),
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
              DataService().logout();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const LoginScreen(),
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
          responsibilityLetterFileName: _responsibilityLetterFileName,
          isResponsibilityLetterUploaded: _isResponsibilityLetterUploaded,
          onPickOrReplaceResponsibilityLetter: _showUploadResponsibilitySheet,
          onDeleteResponsibilityLetter: _onDeleteResponsibilityLetter,
          onDownloadResponsibilityWordTemplate: _downloadResponsibilityTemplate,
          onSubmit: _onProceedFromDocumentsToPin,
          onBack: () {
            setState(() {
              _currentStage = ProducerVerificationStage.lengkapiProfil;
            });
          },
        );
        break;

      case ProducerVerificationStage.buatPin:
        activeScreen = Step3CreatePinScreen(
          onSubmitPin: _onCompletePinAndSubmitVerification,
          onBack: () {
            setState(() {
              _currentStage = ProducerVerificationStage.unggahDokumen;
            });
          },
        );
        break;

      case ProducerVerificationStage.approvalMenunggu:
        activeScreen = ApprovalWaitingScreen(
          responsiblePersonName: _fullNameController.text,
          onCheckStatus: () async {
            await PromoterDataService().loadProducerProfileFromSupabase();
            if (!context.mounted) return;
            final currentStatus = PromoterDataService()
                .verificationStatusNotifier
                .value
                .toLowerCase();
            if (currentStatus == 'approved') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const PromoterPinLockScreen(),
                ),
              );
            } else if (currentStatus == 'rejected') {
              setState(() {
                _currentStage = ProducerVerificationStage.approvalDitolak;
              });
            } else {
              setState(() {
                _currentStage = ProducerVerificationStage.approvalDitolak;
              });
            }
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
              DataService().logout();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const LoginScreen(),
                ),
              );
            }
          },
          onResubmit: () {
            setState(() {
              _currentStage = ProducerVerificationStage.lengkapiProfil;
            });
          },
        );
        break;
    }

    return ResponsivePromoterWrapper(
      child: activeScreen,
    );
  }
}
