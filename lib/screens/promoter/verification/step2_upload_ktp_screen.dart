import 'package:flutter/material.dart';
import '../../../services/promoter_data_service.dart';
import '../widgets/dashed_border_box.dart';
import '../widgets/promoter_step_indicator.dart';

class Step2UploadKtpScreen extends StatelessWidget {
  final String ktpFileName;
  final bool isKtpUploaded;
  final VoidCallback onPickOrReplaceKtp;
  final VoidCallback onDeleteKtp;
  final VoidCallback onSubmit;
  final VoidCallback onBack;

  const Step2UploadKtpScreen({
    super.key,
    required this.ktpFileName,
    this.isKtpUploaded = false,
    required this.onPickOrReplaceKtp,
    required this.onDeleteKtp,
    required this.onSubmit,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final service = PromoterDataService();

    return ValueListenableBuilder<bool>(
      valueListenable: service.isDarkModeNotifier,
      builder: (context, isDarkMode, _) {
        final textColor =
            isDarkMode ? Colors.white : const Color(0xFF101828);
        final subtextColor =
            isDarkMode ? Colors.white70 : const Color(0xFF667085);
        final cardBg =
            isDarkMode ? const Color(0xFF1B2232) : Colors.white;
        final cardBorder =
            isDarkMode ? Colors.white12 : const Color(0xFFE4E7EC);
        final uploadedCardBg =
            isDarkMode ? const Color(0xFF231729) : const Color(0xFFFFFAFD);

        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Bar with Kembali and Theme Toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        InkWell(
                          onTap: onBack,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 2, vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.chevron_left_rounded,
                                  size: 20,
                                  color: textColor,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  'Kembali',
                                  style: TextStyle(
                                    fontSize: 13,
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

                    const SizedBox(height: 8),

                    // Title & Subtitle
                    Text(
                      'Unggah Dokumen KTP',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Langkah 2 dari 2: Upload KTP penanggung jawab untuk verifikasi akun',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: subtextColor,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 22),

                    // Card 1: Dokumen yang dibutuhkan
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: cardBorder),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFCE7F3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.description_outlined,
                              color: Color(0xFFC2185B),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Dokumen yang dibutuhkan',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'KTP penanggung jawab harus jelas, tidak terpotong, dan masih berlaku.',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: subtextColor,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Card 2: KTP Penanggung Jawab (Empty / Uploaded state)
                    if (isKtpUploaded)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: uploadedCardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color:
                                const Color(0xFFC2185B).withValues(alpha: 0.5),
                            width: 1.1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFCE7F3),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.description_outlined,
                                color: Color(0xFFC2185B),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'KTP Penanggung Jawab',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '$ktpFileName · Berhasil diunggah',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFFC2185B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: onDeleteKtp,
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Icon(
                                  Icons.delete_outline_rounded,
                                  size: 20,
                                  color: subtextColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      InkWell(
                        onTap: onPickOrReplaceKtp,
                        borderRadius: BorderRadius.circular(14),
                        child: DashedBorderBox(
                          borderRadius: 14,
                          color: const Color(0xFFC2185B),
                          backgroundColor: uploadedCardBg,
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFCE7F3),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.upload_file_outlined,
                                    color: Color(0xFFC2185B),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'KTP Penanggung Jawab',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: textColor,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      const Text(
                                        'Belum ada dokumen · Ketuk untuk mengunggah KTP',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFFC2185B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.file_upload_outlined,
                                  size: 20,
                                  color: subtextColor,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 14),

                    // Button: Pilih / Ganti Dokumen KTP
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: OutlinedButton(
                        onPressed: onPickOrReplaceKtp,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: cardBg,
                          side: BorderSide(
                            color: isDarkMode
                                ? const Color(0xFF4A6CF7)
                                : const Color(0xFF1B2A8C),
                            width: 1.2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          isKtpUploaded
                              ? 'Ganti Dokumen KTP'
                              : 'Pilih Dokumen KTP',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: isDarkMode
                                ? Colors.white
                                : const Color(0xFF1B2A8C),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 2-Step Progress Bar (both active)
                    const PromoterStepIndicator(
                      currentStep: 2,
                      totalSteps: 2,
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Bottom Sticky Action Button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: onSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isKtpUploaded
                        ? const Color(0xFF1B2A8C)
                        : const Color(0xFF98A2B3),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Ajukan Approval Verifikasi',
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
  }
}
