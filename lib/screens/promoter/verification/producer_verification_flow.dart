import 'package:flutter/material.dart';
import '../../../core/account_status.dart';
import '../../../services/data_service.dart';
import '../../../services/promoter_data_service.dart';
import '../../../utils/file_picker_helper.dart';
import '../../auth/login_screen.dart';
import '../promoter_pin_lock_screen.dart';
import '../widgets/responsive_promoter_wrapper.dart';
import 'approval_rejected_screen.dart';
import 'approval_waiting_screen.dart';
import 'producer_deactivated_screen.dart';
import 'step1_producer_profile_screen.dart';
import 'step2_upload_ktp_screen.dart';
import 'step3_create_pin_screen.dart';

enum ProducerVerificationStage {
  lengkapiProfil,
  unggahDokumen,
  buatPin,
  approvalMenunggu,
  approvalDitolak,
  akunDinonaktifkan,
}

class ProducerVerificationFlow extends StatefulWidget {
  final ProducerVerificationStage initialStage;
  final String? initialName;
  final String? initialPhone;
  final Future<String?> Function(String accept)? filePicker;

  const ProducerVerificationFlow({
    super.key,
    this.initialStage = ProducerVerificationStage.lengkapiProfil,
    this.initialName,
    this.initialPhone,
    this.filePicker,
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
  late final TextEditingController _bankNameController;
  late final TextEditingController _bankAccountNumberController;
  late final TextEditingController _bankAccountHolderController;
  String? _profileError;
  bool _isSubmittingVerification = false;
  String _ktpFileName = '';
  bool _isKtpUploaded = false;

  String _responsibilityLetterFileName = '';
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
    _bankNameController = TextEditingController();
    _bankAccountNumberController = TextEditingController();
    _bankAccountHolderController = TextEditingController();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _birthDateController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _bankNameController.dispose();
    _bankAccountNumberController.dispose();
    _bankAccountHolderController.dispose();
    super.dispose();
  }

  static const List<String> _monthNames = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  String _formatBirthDate(DateTime date) =>
      '${date.day} ${_monthNames[date.month - 1]} ${date.year}';

  DateTime? _parseBirthDate(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = _monthNames.indexOf(parts[1]) + 1;
    final year = int.tryParse(parts[2]);
    if (day == null || month == 0 || year == null) return null;
    return DateTime(year, month, day);
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final current = _parseBirthDate(_birthDateController.text);
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(1940),
      lastDate: now,
      helpText: 'Pilih tanggal lahir',
    );
    if (picked == null) return;
    setState(() {
      _birthDateController.text = _formatBirthDate(picked);
    });
  }

  void _onProceedFromProfileToDocuments() {
    final name = _fullNameController.text.trim();
    final birthDate = _birthDateController.text.trim();
    final bank = _bankNameController.text.trim();
    final accNo =
        _bankAccountNumberController.text.replaceAll(RegExp(r'[^0-9]'), '');
    String? error;
    if (name.length < 2) {
      error = 'Nama lengkap penanggung jawab wajib diisi.';
    } else if (_parseBirthDate(birthDate) == null) {
      error = 'Tanggal lahir wajib dipilih.';
    } else if (bank.isEmpty) {
      error = 'Nama bank wajib diisi.';
    } else if (accNo.length < 8 || accNo.length > 20) {
      error = 'Nomor rekening harus 8 sampai 20 digit angka.';
    }
    if (error != null) {
      setState(() => _profileError = error);
      return;
    }
    setState(() {
      _profileError = null;
      _currentStage = ProducerVerificationStage.unggahDokumen;
    });
  }

  Future<String?> _pickVerificationFile(String accept) {
    final picker = widget.filePicker;
    return picker == null
        ? pickNativeFile(accept: accept)
        : picker(accept);
  }

  Future<void> _downloadResponsibilityTemplate() async {
    final saved = await downloadTemplateFile(
      fileName: 'Template_Lembar_Penanggung_Jawab_Produser_LiveTix.doc',
      content: responsibilityWordTemplateDoc,
      mimeType: 'application/msword',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(saved
            ? 'Template Word berhasil disimpan.'
            : 'Template tidak berhasil disimpan.'),
        backgroundColor:
            saved ? const Color(0xFF1B2A8C) : const Color(0xFFB91C1C),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _showUploadKtpSheet() async {
    final manualKtpController = TextEditingController();
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
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD0D5DD),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Unggah Dokumen KTP',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF101828),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        size: 20, color: Color(0xFF101828)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Pilih file foto/scan KTP dari perangkat Anda (.jpg, .jpeg, .png, .pdf):',
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
                    final pickedName = await _pickVerificationFile(
                      '.jpg,.jpeg,.png,.pdf',
                    );
                    final fileName = pickedName?.trim() ?? '';
                    if (fileName.isEmpty) return;
                    final extension = fileName.contains('.')
                        ? fileName.split('.').last.toLowerCase()
                        : '';
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    if (!const {'jpg', 'jpeg', 'png', 'pdf'}
                        .contains(extension)) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Format dokumen KTP harus .jpg, .jpeg, .png, atau .pdf.'),
                          backgroundColor: Color(0xFFB91C1C),
                          duration: Duration(seconds: 3),
                        ),
                      );
                      return;
                    }
                    setState(() {
                      _ktpFileName = fileName;
                      _isKtpUploaded = true;
                    });
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Dokumen $_ktpFileName berhasil diunggah'),
                        backgroundColor: const Color(0xFFC2185B),
                        duration: const Duration(seconds: 2),
                      ),
                    );
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
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      'ATAU ISI NAMA FILE SECARA MANUAL',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: manualKtpController,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Contoh: ktp_penanggung_jawab.jpg',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final fileName = manualKtpController.text.trim();
                      if (fileName.isEmpty) return;
                      final extension = fileName.contains('.')
                          ? fileName.split('.').last.toLowerCase()
                          : '';
                      if (!const {'jpg', 'jpeg', 'png', 'pdf'}
                          .contains(extension)) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Format dokumen KTP harus .jpg, .jpeg, .png, atau .pdf.'),
                            backgroundColor: Color(0xFFB91C1C),
                            duration: Duration(seconds: 3),
                          ),
                        );
                        return;
                      }
                      Navigator.pop(ctx);
                      setState(() {
                        _ktpFileName = fileName;
                        _isKtpUploaded = true;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content:
                              Text('Dokumen $_ktpFileName berhasil disimpan'),
                          backgroundColor: const Color(0xFFC2185B),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC2185B),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      'Simpan',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showUploadResponsibilitySheet() async {
    final manualLetterController = TextEditingController();
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
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD0D5DD),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Unggah Lembar Penanggung Jawab',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF101828),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        size: 20, color: Color(0xFF101828)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
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
                    final pickedName = await _pickVerificationFile('.doc,.docx,.pdf,application/msword,application/vnd.openxmlformats-officedocument.wordprocessingml.document,application/pdf');
                    final fileName = pickedName?.trim() ?? '';
                    if (fileName.isEmpty) return;
                    final extension = fileName.contains('.')
                        ? fileName.split('.').last.toLowerCase()
                        : '';
                    if (!const {'doc', 'docx', 'pdf'}.contains(extension)) {
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Format lembar penanggung jawab harus .doc, .docx, atau .pdf.'),
                          backgroundColor: Color(0xFFB91C1C),
                          duration: Duration(seconds: 3),
                        ),
                      );
                      return;
                    }
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    setState(() {
                      _responsibilityLetterFileName = fileName;
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
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      'ATAU ISI NAMA FILE SECARA MANUAL',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: manualLetterController,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Contoh: lembar_penanggung_jawab.docx',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final fileName = manualLetterController.text.trim();
                      if (fileName.isEmpty) return;
                      final extension = fileName.contains('.')
                          ? fileName.split('.').last.toLowerCase()
                          : '';
                      if (!const {'doc', 'docx', 'pdf'}.contains(extension)) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Format lembar penanggung jawab harus .doc, .docx, atau .pdf.'),
                            backgroundColor: Color(0xFFB91C1C),
                            duration: Duration(seconds: 3),
                          ),
                        );
                        return;
                      }
                      Navigator.pop(ctx);
                      setState(() {
                        _responsibilityLetterFileName = fileName;
                        _isResponsibilityLetterUploaded = true;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Lembar Penanggung Jawab $_responsibilityLetterFileName berhasil disimpan'),
                          backgroundColor: const Color(0xFF1B2A8C),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B2A8C),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      'Simpan',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
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
    if (!_isKtpUploaded || !_isResponsibilityLetterUploaded) {
      final missingKtp = !_isKtpUploaded;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(missingKtp
              ? 'Silakan unggah dokumen KTP terlebih dahulu sebelum melanjutkan.'
              : 'Silakan unggah Lembar Penanggung Jawab terlebih dahulu sebelum melanjutkan.'),
          backgroundColor: const Color(0xFFC2185B),
          duration: const Duration(seconds: 2),
        ),
      );
      if (missingKtp) {
        _showUploadKtpSheet();
      } else {
        _showUploadResponsibilitySheet();
      }
      return;
    }
    setState(() {
      _currentStage = ProducerVerificationStage.buatPin;
    });
  }

  Future<void> _onCompletePinAndSubmitVerification(String pinCode) async {
    if (_isSubmittingVerification) return;
    setState(() => _isSubmittingVerification = true);

    final fullName = _fullNameController.text.trim().isNotEmpty
        ? _fullNameController.text.trim()
        : (DataService().currentUser?.name ?? 'Produser LiveTix');

    final result = await PromoterDataService().submitInitialVerification(
      fullName: fullName,
      birthDate: _birthDateController.text.trim(),
      phone: _phoneController.text.trim(),
      address: _addressController.text.trim(),
      ktpFileName: _ktpFileName,
      responsibilityLetterFileName: _responsibilityLetterFileName,
      pinCode: pinCode,
      bankName: _bankNameController.text.trim(),
      bankAccountNumber: _bankAccountNumberController.text,
      bankAccountHolder: _bankAccountHolderController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSubmittingVerification = false);

    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.errorMessage ?? 'Gagal menyimpan verifikasi ke database.',
          ),
          backgroundColor: const Color(0xFFB91C1C),
        ),
      );
      return;
    }

    // Verifikasi tersimpan: alihkan ke layar menunggu persetujuan (approval) admin
    setState(() {
      _currentStage = ProducerVerificationStage.approvalMenunggu;
    });
  }

  Future<void> _contactAdminViaWhatsApp() async {
    const adminWhatsAppNumber = '6281234567890';
    final service = PromoterDataService();
    final name = _fullNameController.text.trim().isNotEmpty
        ? _fullNameController.text.trim()
        : service.promoterName;
    final message = Uri.encodeComponent(
      'Halo Admin LiveTix, akun produser saya ($name) dinonaktifkan oleh Admin. Mohon informasi dan bantuan pengaktifan kembali.',
    );
    final url = 'https://wa.me/$adminWhatsAppNumber?text=$message';
    try {
      await openExternalUrl(url);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Gagal membuka WhatsApp. Silakan hubungi admin di +$adminWhatsAppNumber',
            ),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
      }
    }
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
          bankNameController: _bankNameController,
          bankAccountNumberController: _bankAccountNumberController,
          bankAccountHolderController: _bankAccountHolderController,
          errorMessage: _profileError,
          onPickBirthDate: _pickBirthDate,
          onNext: _onProceedFromProfileToDocuments,
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
          isSubmitting: _isSubmittingVerification,
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
            if (currentStatus == AccountStatus.approved.value) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const PromoterPinLockScreen(),
                ),
              );
            } else if (currentStatus == AccountStatus.nonaktif.value) {
              setState(() {
                _currentStage = ProducerVerificationStage.akunDinonaktifkan;
              });
            } else if (currentStatus == AccountStatus.rejected.value) {
              setState(() {
                _currentStage = ProducerVerificationStage.approvalDitolak;
              });
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Pengajuan Anda masih ditinjau Admin.'),
                ),
              );
            }
          },
          onLogout: () {
            DataService().logout();
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
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

      case ProducerVerificationStage.akunDinonaktifkan:
        activeScreen = ProducerDeactivatedScreen(
          responsiblePersonName: _fullNameController.text.trim(),
          onContactAdmin: _contactAdminViaWhatsApp,
          onLogout: () {
            DataService().logout();
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
          },
        );
        break;
    }

    return ResponsivePromoterWrapper(
      child: activeScreen,
    );
  }
}
