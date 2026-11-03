import 'package:flutter/material.dart';
import '../../models/promoter_models.dart';
import '../../services/promoter_data_service.dart';
import 'widgets/responsive_promoter_wrapper.dart';

class PromoterWithdrawalStatusScreen extends StatelessWidget {
  final PromoterWithdrawalRecord? record;

  const PromoterWithdrawalStatusScreen({
    super.key,
    this.record,
  });

  @override
  Widget build(BuildContext context) {
    final service = PromoterDataService();

    final dateStr = record?.dateTimeStr ?? '20 Okt 2026 · 09:12 WIB';
    final isDone = record?.status == WithdrawalStatus.berhasil;
    final isRejected = record?.status == WithdrawalStatus.ditolak;

    return ResponsivePromoterWrapper(
      child: ValueListenableBuilder<bool>(
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
              isDarkMode ? const Color(0xFF2C2415) : const Color(0xFFFFFBEB);
          final warningBorder =
              isDarkMode ? const Color(0xFFD97706) : const Color(0xFFFDE68A);

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Bar with Kembali & Theme Toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.chevron_left_rounded,
                              size: 22,
                              color: textColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Kembali',
                              style: TextStyle(
                                fontSize: 13.5,
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
                      tooltip: 'Ganti Tema',
                      onPressed: service.toggleTheme,
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Title & Subtitle
                Text(
                  'Status Penarikan',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Detail pelacakan pengajuan dana Anda',
                  style: TextStyle(
                    fontSize: 13,
                    color: subtextColor,
                  ),
                ),

                const SizedBox(height: 20),

                // Card 1: Alert Box "Sedang Ditinjau" (Yellow/Cream)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: warningBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: warningBorder, width: 1.1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isDone
                            ? 'Penarikan Berhasil'
                            : (isRejected
                                ? 'Pengajuan Ditolak'
                                : 'Sedang Ditinjau'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isDone
                              ? const Color(0xFF039855)
                              : (isRejected
                                  ? const Color(0xFFD92D20)
                                  : textColor),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isDone
                            ? 'Dana telah berhasil ditransfer ke rekening bank resmi Anda.'
                            : (isRejected
                                ? (record?.rejectionReason ??
                                    'Pengajuan ditolak oleh admin karena ketidaksesuaian data.')
                                : 'Permintaan Anda sedang dalam proses audit admin.'),
                        style: TextStyle(
                          fontSize: 12.5,
                          color: subtextColor,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Card 2: Riwayat Proses Verifikasi (Stepper Box)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Riwayat Proses Verifikasi',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Step 1: Permintaan Diajukan (Magenta)
                      _buildTimelineStep(
                        isFirst: true,
                        isLast: false,
                        dotColor: const Color(0xFFC2185B), // Magenta
                        title: 'Permintaan Diajukan',
                        subtitle: dateStr,
                        textColor: textColor,
                        subtextColor: subtextColor,
                        isFinished: true,
                      ),

                      // Step 2: Proses Peninjauan Administrasi (Orange/Amber)
                      _buildTimelineStep(
                        isFirst: false,
                        isLast: false,
                        dotColor: isDone
                            ? const Color(0xFF039855)
                            : (isRejected
                                ? const Color(0xFFD92D20)
                                : const Color(0xFFF59E0B)), // Orange/Amber
                        title: isRejected
                            ? 'Verifikasi Ditolak Admin'
                            : 'Proses Peninjauan Administrasi',
                        subtitle: isDone
                            ? 'Audit selesai disetujui'
                            : (isRejected
                                ? 'Pemeriksaan rekening tidak lolos'
                                : 'Sedang berjalan (estimasi 1x24 jam)'),
                        textColor: textColor,
                        subtextColor: subtextColor,
                        isFinished: isDone || !isRejected,
                      ),

                      // Step 3: Dana Ditransfer (Grey or Green)
                      _buildTimelineStep(
                        isFirst: false,
                        isLast: true,
                        dotColor: isDone
                            ? const Color(0xFF039855)
                            : const Color(0xFF98A2B3), // Grey
                        title: 'Dana Ditransfer',
                        subtitle: isDone ? 'Dana masuk ke rekening' : 'Belum Selesai',
                        textColor: isDone ? textColor : subtextColor,
                        subtextColor: subtextColor,
                        isFinished: isDone,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimelineStep({
    required bool isFirst,
    required bool isLast,
    required Color dotColor,
    required String title,
    required String subtitle,
    required Color textColor,
    required Color subtextColor,
    required bool isFinished,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Dot & Vertical Line
        Column(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 48,
                color: isFinished ? dotColor.withValues(alpha: 0.35) : const Color(0xFFE4E7EC),
              ),
          ],
        ),
        const SizedBox(width: 14),

        // Right Column: Title & Subtitle
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11.5,
                  color: subtextColor,
                ),
              ),
              if (!isLast) const SizedBox(height: 18),
            ],
          ),
        ),
      ],
    );
  }
}
