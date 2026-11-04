import 'package:flutter/material.dart';
import '../../../services/promoter_data_service.dart';

class ApprovalRejectedScreen extends StatelessWidget {
  final VoidCallback onContactAdmin;
  final VoidCallback onBack;
  final VoidCallback? onResubmit;

  const ApprovalRejectedScreen({
    super.key,
    required this.onContactAdmin,
    required this.onBack,
    this.onResubmit,
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
        final rejectionBg =
            isDarkMode ? const Color(0xFF281523) : const Color(0xFFFFF5F8);
        final disabledBtnBg =
            isDarkMode ? const Color(0xFF252D3D) : const Color(0xFFE4E7EC);
        final disabledBtnText =
            isDarkMode ? Colors.white38 : const Color(0xFF98A2B3);

        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Bar with Theme Toggle on the right
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        icon: Icon(
                          isDarkMode
                              ? Icons.dark_mode_outlined
                              : Icons.wb_sunny_outlined,
                          size: 22,
                          color: textColor,
                        ),
                        onPressed: service.toggleTheme,
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Title & Subtitle
                    Text(
                      'Status Verifikasi',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sayang sekali, pengajuan verifikasi ditolak',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: subtextColor,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Card 1: Alasan Penolakan
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: rejectionBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFC2185B).withValues(alpha: 0.45),
                          width: 1.1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.cancel_outlined,
                                color: Color(0xFFC2185B),
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Alasan Penolakan',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFC2185B),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '"Alamat kantor tidak sesuai dengan dokumen SIUP resmi yang diunggah. Mohon untuk memverifikasi ulang alamat kantor pusat Anda dan unggah dokumen SIUP terbaru yang aktif."',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: textColor,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Card 2: Cooldown Timer
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: cardBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            color: Color(0xFFF59E0B),
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Anda dapat mengajukan ulang dalam jeda:',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: subtextColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  '3 Hari 0 Jam 0 Menit',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFF59E0B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Bottom Sticky Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Disabled Button: Ajukan Ulang Verifikasi
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: onResubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: disabledBtnBg,
                        disabledBackgroundColor: disabledBtnBg,
                        foregroundColor: disabledBtnText,
                        disabledForegroundColor: disabledBtnText,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Ajukan Ulang Verifikasi',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Row: Hubungi Admin Kami & Kembali
                  Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: SizedBox(
                          height: 46,
                          child: OutlinedButton(
                            onPressed: onContactAdmin,
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
                              'Hubungi Admin Kami',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDarkMode
                                    ? Colors.white
                                    : const Color(0xFF1B2A8C),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: SizedBox(
                          height: 46,
                          child: OutlinedButton(
                            onPressed: onBack,
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
                              'Kembali',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDarkMode
                                    ? Colors.white
                                    : const Color(0xFF1B2A8C),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
