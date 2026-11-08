import 'dart:async';
import 'package:flutter/material.dart';
import '../../../services/promoter_data_service.dart';

class ApprovalRejectedScreen extends StatefulWidget {
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
  State<ApprovalRejectedScreen> createState() => _ApprovalRejectedScreenState();
}

class _ApprovalRejectedScreenState extends State<ApprovalRejectedScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = PromoterDataService();

    return ValueListenableBuilder<bool>(
      valueListenable: service.isDarkModeNotifier,
      builder: (context, isDarkMode, _) {
        final textColor = isDarkMode ? Colors.white : const Color(0xFF101828);
        final subtextColor =
            isDarkMode ? Colors.white70 : const Color(0xFF667085);
        final cardBg = isDarkMode ? const Color(0xFF1B2232) : Colors.white;
        final cardBorder =
            isDarkMode ? Colors.white12 : const Color(0xFFE4E7EC);
        final rejectionBg =
            isDarkMode ? const Color(0xFF281523) : const Color(0xFFFFF5F8);
        final disabledBtnBg =
            isDarkMode ? const Color(0xFF252D3D) : const Color(0xFFE4E7EC);
        final disabledBtnText =
            isDarkMode ? Colors.white38 : const Color(0xFF98A2B3);

        final actualReason = service.rejectionReasonNotifier.value?.trim();
        final displayReason = (actualReason != null && actualReason.isNotEmpty)
            ? actualReason
            : 'Dokumen legalitas profil produser memerlukan perbaikan sesuai catatan kurasi Admin.';

        final DateTime rejectedAt = service.getProducerRejectedAt();
        final unlockAt =
            rejectedAt.add(PromoterDataService.resubmitCooldownDuration);
        final remaining = unlockAt.difference(DateTime.now());
        final bool isCooldownActive = remaining > Duration.zero;

        String countdownDisplay;
        if (isCooldownActive) {
          final days = remaining.inDays;
          final hours = remaining.inHours % 24;
          final minutes = remaining.inMinutes % 60;
          final seconds = remaining.inSeconds % 60;
          countdownDisplay =
              '$days Hari $hours Jam $minutes Menit $seconds Detik';
        } else {
          countdownDisplay = 'Waktu jeda selesai (Dapat diajukan ulang sekarang)';
        }

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

                    // Card 1: Alasan Penolakan (Real dari database)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: rejectionBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color:
                              const Color(0xFFC2185B).withValues(alpha: 0.45),
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
                            '"$displayReason"',
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

                    // Card 2: Cooldown Timer (Realtime Hari, Jam, Menit, Detik)
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
                          Icon(
                            isCooldownActive
                                ? Icons.access_time_rounded
                                : Icons.check_circle_outline,
                            color: isCooldownActive
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF039855),
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
                                Text(
                                  countdownDisplay,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isCooldownActive
                                        ? const Color(0xFFF59E0B)
                                        : const Color(0xFF039855),
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
                  // Button: Ajukan Ulang Verifikasi (Terkunci jika cooldown aktif)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isCooldownActive ? null : widget.onResubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B2A8C),
                        disabledBackgroundColor: disabledBtnBg,
                        foregroundColor: Colors.white,
                        disabledForegroundColor: disabledBtnText,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        isCooldownActive
                            ? 'Ajukan Ulang Verifikasi (Terkunci)'
                            : 'Ajukan Ulang Verifikasi',
                        style: const TextStyle(
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
                            onPressed: widget.onContactAdmin,
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
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 3,
                        child: SizedBox(
                          height: 46,
                          child: OutlinedButton(
                            onPressed: widget.onBack,
                            style: OutlinedButton.styleFrom(
                              backgroundColor: cardBg,
                              side: BorderSide(color: cardBorder, width: 1.2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Kembali',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: textColor,
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
