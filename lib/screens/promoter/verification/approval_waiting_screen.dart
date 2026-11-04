import 'package:flutter/material.dart';
import '../../../services/promoter_data_service.dart';

class ApprovalWaitingScreen extends StatelessWidget {
  final String responsiblePersonName;
  final VoidCallback onCheckStatus;

  const ApprovalWaitingScreen({
    super.key,
    this.responsiblePersonName = 'Rafi Firmansyah',
    required this.onCheckStatus,
  });

  @override
  Widget build(BuildContext context) {
    final service = PromoterDataService();
    final displayName = responsiblePersonName.trim().isNotEmpty
        ? responsiblePersonName.trim()
        : 'Rafi Firmansyah';

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
        final warningBg =
            isDarkMode ? const Color(0xFF2B2312) : const Color(0xFFFFFBEB);
        final warningBorder =
            isDarkMode ? const Color(0xFFD97706) : const Color(0xFFFCD34D);

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
                      'Status Akun Anda',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Kami sedang memproses verifikasi data perusahaan Anda',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: subtextColor,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Warning Banner Card
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: warningBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: warningBorder, width: 1.1),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: Color(0xFFF59E0B),
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Akses akun terbatas sementara. Dasbor lengkap akan terbuka setelah disetujui.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: textColor,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Progres Pendaftaran Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Progres Pendaftaran',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Step 1: Akun Dibuat
                          _buildProgressStep(
                            indicator: Container(
                              width: 26,
                              height: 26,
                              decoration: const BoxDecoration(
                                color: Color(0xFF1B2A8C),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 15,
                              ),
                            ),
                            title: 'Akun Dibuat',
                            titleColor: textColor,
                            subtitle: 'Terverifikasi via email resmi',
                            subtitleColor: subtextColor,
                          ),

                          const SizedBox(height: 14),

                          // Step 2: Profil Dilengkapi
                          _buildProgressStep(
                            indicator: Container(
                              width: 26,
                              height: 26,
                              decoration: const BoxDecoration(
                                color: Color(0xFF1B2A8C),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 15,
                              ),
                            ),
                            title: 'Profil Dilengkapi',
                            titleColor: textColor,
                            subtitle:
                                '$displayName sebagai penanggung jawab',
                            subtitleColor: subtextColor,
                          ),

                          const SizedBox(height: 14),

                          // Step 3: Sedang Ditinjau Admin
                          _buildProgressStep(
                            indicator: Container(
                              width: 26,
                              height: 26,
                              decoration: const BoxDecoration(
                                color: Color(0xFFF59E0B),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: 4,
                                      height: 4,
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            title: 'Sedang Ditinjau Admin',
                            titleColor: const Color(0xFFF59E0B),
                            subtitle:
                                'Estimasi waktu pengerjaan 1-2 hari kerja',
                            subtitleColor: subtextColor,
                          ),

                          const SizedBox(height: 14),

                          // Step 4: Hasil Verifikasi Keluar
                          _buildProgressStep(
                            indicator: Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? Colors.white12
                                    : const Color(0xFFE4E7EC),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF98A2B3),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                            title: 'Hasil Verifikasi Keluar',
                            titleColor: const Color(0xFF98A2B3),
                            subtitle: 'Selesai ditinjau',
                            subtitleColor: const Color(0xFF98A2B3),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Bottom Sticky Outlined Button: Cek Status Akun
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: onCheckStatus,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: cardBg,
                    side: BorderSide(
                      color: isDarkMode
                          ? const Color(0xFF4A6CF7)
                          : const Color(0xFF1B2A8C),
                      width: 1.2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Cek Status Akun',
                    style: TextStyle(
                      fontSize: 14,
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
        );
      },
    );
  }

  Widget _buildProgressStep({
    required Widget indicator,
    required String title,
    required Color titleColor,
    required String subtitle,
    required Color subtitleColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        indicator,
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11.5,
                  color: subtitleColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
