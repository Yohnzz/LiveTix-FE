import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/promoter_models.dart';
import '../../services/promoter_data_service.dart';
import 'producer_customer_service_screen.dart';
import 'widgets/responsive_promoter_wrapper.dart';

class ConcertStatusDetailScreen extends StatefulWidget {
  final String concertTitle;
  final String? concertId;
  final PromoterConcertItem? concert;
  final ConcertStatus status;
  final String? rejectionReason;

  const ConcertStatusDetailScreen({
    super.key,
    this.concertTitle = 'Harmoni Nusantara 2026',
    this.concertId,
    this.concert,
    this.status = ConcertStatus.ditolak,
    this.rejectionReason,
  });

  @override
  State<ConcertStatusDetailScreen> createState() =>
      _ConcertStatusDetailScreenState();
}

class _ConcertStatusDetailScreenState extends State<ConcertStatusDetailScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.status == ConcertStatus.ditolak) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = PromoterDataService();

    return ResponsivePromoterWrapper(
      child: ValueListenableBuilder<bool>(
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
          final pendingBg =
              isDarkMode ? const Color(0xFF2E2211) : const Color(0xFFFFFBEB);
          final approvedBg =
              isDarkMode ? const Color(0xFF0D2818) : const Color(0xFFE8FDF0);
          final disabledBtnBg =
              isDarkMode ? const Color(0xFF252D3D) : const Color(0xFFE4E7EC);
          final disabledBtnText =
              isDarkMode ? Colors.white38 : const Color(0xFF98A2B3);

          final isPending = widget.status == ConcertStatus.menunggu;
          final isApproved = widget.status == ConcertStatus.disetujui;
          final isRejected = widget.status == ConcertStatus.ditolak;

          // Temukan objek konser riil dari PromoterDataService
          PromoterConcertItem? resolvedConcert = widget.concert;
          final concertList = service.concertsNotifier.value;
          if (resolvedConcert == null && widget.concertId != null) {
            final idx =
                concertList.indexWhere((c) => c.id == widget.concertId);
            if (idx != -1) resolvedConcert = concertList[idx];
          }
          if (resolvedConcert == null) {
            final idx = concertList.indexWhere(
              (c) =>
                  c.title.trim().toLowerCase() ==
                  widget.concertTitle.trim().toLowerCase(),
            );
            if (idx != -1) resolvedConcert = concertList[idx];
          }

          final String actualRejectionReason = resolvedConcert != null
              ? service.getConcertRejectionReason(resolvedConcert)
              : (widget.rejectionReason ??
                  'Pengajuan konser ditolak oleh Admin. Silakan periksa kembali kelengkapan informasi konser Anda.');

          final DateTime rejectedAt = resolvedConcert != null
              ? service.getConcertRejectedAt(resolvedConcert)
              : DateTime.now();

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
            countdownDisplay =
                'Waktu jeda selesai (Siap diajukan ulang sekarang)';
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
                      // Top Bar with Kembali and Theme Toggle
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
                            onPressed: service.toggleTheme,
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Title & Subtitle
                      Text(
                        widget.concertTitle,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isPending
                            ? 'Pengajuan baru sedang ditinjau kurasi LiveTix'
                            : (isApproved
                                ? 'Konser telah disetujui & live di katalog publik'
                                : 'Informasi hasil peninjauan kelayakan konser Anda'),
                        style: TextStyle(
                          fontSize: 12.5,
                          color: subtextColor,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // 4-Stage Status Circles
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatusDot(
                              label: 'Draft',
                              color: const Color(0xFF1B2A8C),
                              isActive: true,
                            ),
                            _buildStatusDot(
                              label: 'Diajukan',
                              color: const Color(0xFF1B2A8C),
                              isActive: true,
                            ),
                            _buildStatusDot(
                              label: 'Ditinjau',
                              color: isPending
                                  ? const Color(0xFFD97706)
                                  : const Color(0xFF1B2A8C),
                              isActive: true,
                            ),
                            _buildStatusDot(
                              label: isRejected ? 'Ditolak' : 'Disetujui',
                              color: isRejected
                                  ? const Color(0xFFC2185B)
                                  : (isApproved
                                      ? const Color(0xFF039855)
                                      : const Color(0xFF98A2B3)),
                              isActive: isApproved || isRejected,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 22),

                      if (isPending) ...[
                        // Pending State Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: pendingBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFF59E0B)
                                  .withValues(alpha: 0.5),
                              width: 1.1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.hourglass_top_rounded,
                                    color: Color(0xFFD97706),
                                    size: 22,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Sedang Dalam Peninjauan Admin',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFD97706),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Pengajuan konser "${widget.concertTitle}" telah diterima oleh tim kurasi LiveTix. Kami sedang memverifikasi denah venue, batas izin keramaian, dan tier harga tiket yang didaftarkan.',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: textColor,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.schedule_rounded,
                                        size: 16, color: Color(0xFFD97706)),
                                    SizedBox(width: 6),
                                    Text(
                                      'Estimasi proses: 1x24 jam kerja',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFFD97706),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (isApproved) ...[
                        // Approved State Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: approvedBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFF039855)
                                  .withValues(alpha: 0.5),
                              width: 1.1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: Color(0xFF039855),
                                    size: 22,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Konser Telah Disetujui!',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF039855),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Selamat! Konser "${widget.concertTitle}" telah lulus verifikasi dan sekarang tayang secara resmi di aplikasi pembeli tiket LiveTix.',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: textColor,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        // Rejection State Card (Sinkron dari database)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: rejectionBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFC2185B)
                                  .withValues(alpha: 0.5),
                              width: 1.1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Alasan Penolakan Admin:',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFC2185B),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                actualRejectionReason,
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

                        // Card 2: Jeda Waktu Pengajuan Ulang (Realtime Hari, Jam, Menit, Detik)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: cardBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Jeda Waktu Pengajuan Ulang',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    isCooldownActive
                                        ? Icons.timer_outlined
                                        : Icons.check_circle_outline,
                                    size: 16,
                                    color: isCooldownActive
                                        ? const Color(0xFFC2185B)
                                        : const Color(0xFF039855),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      countdownDisplay,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: isCooldownActive
                                            ? const Color(0xFFC2185B)
                                            : const Color(0xFF039855),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],

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
                    if (isRejected) ...[
                      // Button: Ajukan Ulang Verifikasi (Aktif otomatis setelah waktu cooldown habis)
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: isCooldownActive
                              ? null
                              : () {
                                  if (resolvedConcert != null) {
                                    service.resubmitRejectedConcert(
                                        resolvedConcert.id);
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Konser "${widget.concertTitle}" berhasil diajukan ulang ke kurasi Admin.',
                                      ),
                                      backgroundColor: const Color(0xFF039855),
                                    ),
                                  );
                                  Navigator.pop(context);
                                },
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
                      // Outlined Button: Hubungi Admin Konser
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ProducerCustomerServiceScreen(
                                  subjectTitle:
                                      'Banding Penolakan - ${widget.concertTitle}',
                                ),
                              ),
                            );
                          },
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
                            'Hubungi Admin Konser',
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
                    ] else ...[
                      // Primary Button for Pending & Approved
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1B2A8C),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Kembali ke Daftar Konser',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusDot({
    required String label,
    required Color color,
    required bool isActive,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive ? Colors.transparent : Colors.grey.shade400,
              width: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
