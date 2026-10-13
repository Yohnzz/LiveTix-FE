import 'package:flutter/material.dart';
import '../../../core/app_colors.dart';
import '../../../widgets/custom_checkbox.dart';

class AgreementDialog extends StatefulWidget {
  final VoidCallback onAccepted;

  const AgreementDialog({super.key, required this.onAccepted});

  static Future<void> show(BuildContext context, {required VoidCallback onAccepted}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AgreementDialog(onAccepted: onAccepted),
    );
  }

  @override
  State<AgreementDialog> createState() => _AgreementDialogState();
}

class _AgreementDialogState extends State<AgreementDialog> {
  bool _agreed = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ikon Tameng dengan centang + badge oranye
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.verified_user_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: AppColors.bannerYellow,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Judul
            const Text(
              'Permohonan dan persetujuan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 16),

            // Kontainer Scrollable dengan scrollbar kuning
            Container(
              height: 240,
              decoration: BoxDecoration(
                color: AppColors.modalBoxBg,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
              child: RawScrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                thickness: 4,
                radius: const Radius.circular(4),
                thumbColor: AppColors.bannerYellow,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(right: 12),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionItem(
                        title: 'Permohonan maaf',
                        body:
                            'Kami minta maaf atas gangguan yang pernah terjadi. Kepercayaanmu penting bagi kami, dan kami terus memperbaiki layanan ini.',
                      ),
                      SizedBox(height: 14),
                      _SectionItem(
                        title: 'Persetujuan',
                        body:
                            'Dengan melanjutkan, kamu setuju data yang kamu berikan digunakan hanya untuk menjalankan fitur aplikasi. Kami tidak menjual datamu kepada pihak mana pun.',
                      ),
                      SizedBox(height: 14),
                      _SectionItem(
                        title: 'Komitmen kami',
                        body:
                            'Kamu bisa menarik persetujuan dan menghapus akunmu kapan saja lewat menu Pengaturan.',
                      ),
                      SizedBox(height: 14),
                      _SectionItem(
                        title: 'Data yang kami simpan',
                        body:
                            'Kami hanya menyimpan data transaksi dan preferensi konsermu guna menghadirkan pengalaman pemesanan yang optimal dan aman.',
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Kotak Persetujuan
            AppCheckbox(
              value: _agreed,
              onChanged: (val) => setState(() => _agreed = val ?? false),
              label: const Text(
                'Saya sudah membaca dan setuju dengan permohonan maaf serta persetujuan di atas.',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Tombol Lanjutkan
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _agreed
                    ? () {
                        Navigator.of(context).pop();
                        widget.onAccepted();
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: const Color(0x591B2A8C),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white70,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Lanjutkan',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Keterangan di bawah tombol
            const Center(
              child: Text(
                'Tombol aktif setelah kotak persetujuan dicentang.',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textGrey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionItem extends StatelessWidget {
  final String title;
  final String body;

  const _SectionItem({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.accent,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          body,
          style: const TextStyle(
            fontSize: 12,
            height: 1.45,
            color: Color(0xFF344054),
          ),
        ),
      ],
    );
  }
}
