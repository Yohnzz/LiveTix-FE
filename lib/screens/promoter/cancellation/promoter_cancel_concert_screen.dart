import 'package:flutter/material.dart';
import '../../../models/promoter_models.dart';
import '../../../services/promoter_data_service.dart';
import '../widgets/dashed_border_box.dart';
import '../widgets/responsive_promoter_wrapper.dart';
import 'promoter_cancellation_status_screen.dart';

class PromoterCancelConcertScreen extends StatefulWidget {
  final PromoterConcertItem concert;

  const PromoterCancelConcertScreen({
    super.key,
    required this.concert,
  });

  @override
  State<PromoterCancelConcertScreen> createState() =>
      _PromoterCancelConcertScreenState();
}

class _PromoterCancelConcertScreenState
    extends State<PromoterCancelConcertScreen> {
  final List<String> _categories = [
    'Perizinan',
    'Venue',
    'Keamanan',
    'Lainnya',
  ];
  late String _selectedCategory;

  late TextEditingController _reasonController;
  final int _maxReasonLength = 500;

  String? _attachedFileName;
  bool _isAgreed = true;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.concert.cancellationCategory.isNotEmpty
        ? widget.concert.cancellationCategory
        : 'Perizinan';

    final initialReason = widget.concert.cancellationReason.isNotEmpty
        ? widget.concert.cancellationReason
        : 'izin keramaian dari kepolisian belum terbit sehingga acara tidak dapat dilaksanakan sesuai jadwal. Kami memutuskan membatalkan konser.';

    _reasonController = TextEditingController(text: initialReason);
    _attachedFileName = widget.concert.cancellationAttachment;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _pickAttachment() {
    setState(() {
      _attachedFileName = 'Surat_Pemberitahuan_Pembatalan_Kepolisian.pdf';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Dokumen bukti perizinan berhasil dilampirkan'),
        backgroundColor: Color(0xFF1B2A8C),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _removeAttachment() {
    setState(() {
      _attachedFileName = null;
    });
  }

  void _showConfirmationBottomSheet(BuildContext context, bool isDarkMode) {
    final ticketsSold = widget.concert.ticketsSold;
    final formattedRefund = widget.concert.formattedTotalRefund;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDarkMode ? const Color(0xFF1B2232) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final modalTextColor =
            isDarkMode ? Colors.white : const Color(0xFF101828);
        final modalSubtextColor =
            isDarkMode ? Colors.white70 : const Color(0xFF667085);

        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 14,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top grey handle bar
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Title
              Text(
                'Ajukan pembatalan konser?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: modalTextColor,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 18),

              // Detail Row: Tiket terjual
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tiket terjual',
                    style: TextStyle(
                      fontSize: 13,
                      color: modalSubtextColor,
                    ),
                  ),
                  Text(
                    '${PromoterTicketTier.formatNumber(ticketsSold)} tiket',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: modalTextColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Detail Row: Dana dikembalikan ke pembeli
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Dana dikembalikan ke pembeli',
                    style: TextStyle(
                      fontSize: 13,
                      color: modalSubtextColor,
                    ),
                  ),
                  Text(
                    formattedRefund,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: modalTextColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Detail Row: Persetujuan admin
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Persetujuan admin',
                    style: TextStyle(
                      fontSize: 13,
                      color: modalSubtextColor,
                    ),
                  ),
                  Text(
                    'Maks. 1x24 jam',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: modalTextColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Warning alert box (light pink/red)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE4E2), // Light red
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFECDCA)),
                ),
                child: const Text(
                  'Pembatalan tidak dapat diurungkan setelah disetujui. Seluruh pembeli menerima refund 100%.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFB42318),
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 22),

              // Solid Red Button: Ya, Ajukan Pembatalan
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx); // Close modal

                    // Submit to service
                    PromoterDataService().submitConcertCancellation(
                      concertId: widget.concert.id,
                      category: _selectedCategory,
                      reason: _reasonController.text.trim(),
                      attachmentName: _attachedFileName,
                    );

                    // Navigate to Cancellation Status Screen
                    final updatedConcert = widget.concert.copyWith(
                      cancellationStatus:
                          ConcertCancellationStatus.menungguAdmin,
                      cancellationCategory: _selectedCategory,
                      cancellationReason: _reasonController.text.trim(),
                      cancellationAttachment: _attachedFileName,
                      cancellationSubmissionDate: '19 Okt 2026, 14:02',
                    );

                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PromoterCancellationStatusScreen(
                          concert: updatedConcert,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD92D20), // Red
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Ya, Ajukan Pembatalan',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Outlined Button: Kembali
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF1B2A8C), width: 1.5),
                    foregroundColor: const Color(0xFF1B2A8C),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Kembali',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1B2A8C),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = PromoterDataService();

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

          final reasonText = _reasonController.text;
          final isSubmitEnabled =
              _isAgreed && reasonText.trim().isNotEmpty;

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Bar with < Kembali
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

                      const SizedBox(height: 12),

                      // Title
                      Text(
                        'Batalkan Konser',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Isi alasan pembatalan untuk diajukan ke admin',
                        style: TextStyle(
                          fontSize: 13,
                          color: subtextColor,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Concert Summary Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: cardBorder),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.concert.title,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${widget.concert.date} · ${PromoterTicketTier.formatNumber(widget.concert.ticketsSold)} tiket sudah terjual',
                              style: TextStyle(
                                fontSize: 12,
                                color: subtextColor,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Section: Kategori alasan
                      Text(
                        'Kategori alasan',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _categories.map((cat) {
                            final isSelected = _selectedCategory == cat;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: InkWell(
                                onTap: () {
                                  setState(() => _selectedCategory = cat);
                                },
                                borderRadius: BorderRadius.circular(22),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF1B2A8C) // Navy
                                        : cardBg,
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(
                                      color: isSelected
                                        ? const Color(0xFF1B2A8C)
                                        : cardBorder,
                                    ),
                                  ),
                                  child: Text(
                                    cat,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? Colors.white
                                          : (isDarkMode
                                              ? Colors.white70
                                              : const Color(0xFF344054)),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Section: Alasan pembatalan
                      Text(
                        'Alasan pembatalan',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: cardBorder),
                        ),
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            TextField(
                              controller: _reasonController,
                              maxLines: 4,
                              maxLength: _maxReasonLength,
                              onChanged: (_) => setState(() {}),
                              style: TextStyle(
                                fontSize: 13,
                                color: textColor,
                                height: 1.45,
                              ),
                              decoration: InputDecoration(
                                hintText:
                                    'Jelaskan alasan pembatalan konser secara rinci...',
                                hintStyle: TextStyle(
                                  fontSize: 12.5,
                                  color: subtextColor,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                                counterText: '',
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${_reasonController.text.length}/$_maxReasonLength',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF98A2B3),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Section: Lampiran bukti (opsional)
                      Text(
                        'Lampiran bukti (opsional)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 8),

                      if (_attachedFileName == null) ...[
                        DashedBorderBox(
                          color: const Color(0xFFD946EF), // Magenta / Purple
                          dashLength: 6,
                          dashGap: 4,
                          borderRadius: 14,
                          backgroundColor: isDarkMode
                              ? const Color(0xFF1B2232)
                              : Colors.white,
                          child: InkWell(
                            onTap: _pickAttachment,
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 22),
                              child: const Center(
                                child: Text(
                                  'Unggah surat izin / dokumen pendukung',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF9333EA), // Purple text
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? const Color(0xFF1B2232)
                                : const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: cardBorder),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.description_rounded,
                                color: Color(0xFF9333EA),
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _attachedFileName!,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded,
                                    size: 18, color: Colors.red),
                                onPressed: _removeAttachment,
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Info banner: Uang tiket akan dikembalikan
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? const Color(0xFF1A1F36)
                              : const Color(0xFFEEF2FF), // Light periwinkle
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Uang tiket akan dikembalikan',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1B2A8C),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Jika konser dibatalkan, uang tiket dikembalikan 100% kepada seluruh pembeli.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDarkMode
                                    ? Colors.white70
                                    : const Color(0xFF475467),
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Estimasi dana refund: ${widget.concert.formattedTotalRefund}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1B2A8C),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Checkbox agreement
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: _isAgreed,
                              onChanged: (val) {
                                setState(() => _isAgreed = val ?? false);
                              },
                              activeColor: const Color(0xFF1B2A8C),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _isAgreed = !_isAgreed);
                              },
                              child: Text(
                                'Saya memahami pembatalan akan ditinjau admin dan tidak dapat diubah setelah disetujui.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: textColor,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Action Button: Ajukan Pembatalan (Red)
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: isSubmitEnabled
                              ? () => _showConfirmationBottomSheet(
                                  context, isDarkMode)
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD92D20), // Red
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: isDarkMode
                                ? const Color(0xFF2E2224)
                                : const Color(0xFFF3D2D0),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Ajukan Pembatalan',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
