import 'package:flutter/material.dart';
import '../../../services/ai_backend_service.dart';
import '../../../services/promoter_data_service.dart';
import '../widgets/concert_image_widget.dart';
import '../widgets/dashed_border_box.dart';
import '../widgets/promoter_step_indicator.dart';

class Step1DetailPosterScreen extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController dateTimeController;
  final TextEditingController descriptionController;
  final String posterFileName;
  final String? posterDataUrl;
  final String squareLogoFileName;
  final String? squareLogoDataUrl;
  final List<String> highlights;
  final List<String> highlightNames;
  final List<String> shortMessages;
  final ValueChanged<List<String>>? onShortMessagesChanged;
  final VoidCallback onPickPoster;
  final VoidCallback onRemovePoster;
  final VoidCallback onPickSquareLogo;
  final VoidCallback onRemoveSquareLogo;
  final VoidCallback onAddHighlight;
  final Function(int index) onEditHighlight;
  final Function(int index) onRemoveHighlight;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final bool isEditMode;

  const Step1DetailPosterScreen({
    super.key,
    required this.nameController,
    required this.dateTimeController,
    required this.descriptionController,
    required this.posterFileName,
    this.posterDataUrl,
    required this.squareLogoFileName,
    this.squareLogoDataUrl,
    this.highlights = const [],
    this.highlightNames = const [],
    this.shortMessages = const ['Festival • 17+', 'Seru!'],
    this.onShortMessagesChanged,
    required this.onPickPoster,
    required this.onRemovePoster,
    required this.onPickSquareLogo,
    required this.onRemoveSquareLogo,
    required this.onAddHighlight,
    required this.onEditHighlight,
    required this.onRemoveHighlight,
    required this.onNext,
    required this.onBack,
    this.isEditMode = false,
  });

  bool get _hasPoster =>
      (posterDataUrl != null && posterDataUrl!.isNotEmpty) ||
      posterFileName.isNotEmpty;

  bool get _hasSquareLogo =>
      (squareLogoDataUrl != null && squareLogoDataUrl!.isNotEmpty) ||
      squareLogoFileName.isNotEmpty;

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
        final labelColor =
            isDarkMode ? Colors.white70 : const Color(0xFF475467);
        final fieldBg =
            isDarkMode ? const Color(0xFF1B2232) : Colors.white;
        final fieldBorder =
            isDarkMode ? Colors.white12 : const Color(0xFFE4E7EC);
        final cardBg =
            isDarkMode ? const Color(0xFF182032) : const Color(0xFFF8FAFC);

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar with Back and Theme Switcher
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: onBack,
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
                isEditMode ? 'Edit Konser' : 'Tambah Konser Baru',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Langkah 1 dari 5: Detail, Logo Persegi, Poster & Highlights',
                style: TextStyle(
                  fontSize: 13,
                  color: subtextColor,
                ),
              ),

              const SizedBox(height: 16),

              // Stepper Indicator (Step 1 active dari 5 langkah)
              const PromoterStepIndicator(currentStep: 1, totalSteps: 5),

              const SizedBox(height: 24),

              // Form Field 1: NAMA KONSER
              _buildFieldLabel('NAMA KONSER *', labelColor),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: fieldBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: fieldBorder),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    const Icon(
                      Icons.music_note_rounded,
                      size: 20,
                      color: Color(0xFF1B2A8C),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: nameController,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: textColor,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Contoh: Soundwave Fest 2026',
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Form Field 2: TANGGAL & WAKTU (Kalender & Jam Picker)
              _buildFieldLabel('TANGGAL & WAKTU KONSER *', labelColor),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _pickDateTime(context),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: fieldBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: fieldBorder),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_month_rounded,
                        size: 20,
                        color: Color(0xFF1B2A8C),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          dateTimeController.text.trim().isNotEmpty
                              ? dateTimeController.text.trim()
                              : 'Pilih tanggal & jam konser dari kalender...',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: dateTimeController.text.trim().isNotEmpty
                                ? textColor
                                : subtextColor,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_drop_down_rounded,
                          size: 24,
                          color: Color(0xFF667085),
                        ),
                        onPressed: () => _pickDateTime(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Form Field 3: DESKRIPSI ACARA
              _buildFieldLabel('DESKRIPSI ACARA *', labelColor),
              const SizedBox(height: 8),
              _AiDescriptionField(
                descriptionController: descriptionController,
                nameController: nameController,
                dateTimeController: dateTimeController,
                isDarkMode: isDarkMode,
                textColor: textColor,
                fieldBg: fieldBg,
                fieldBorder: fieldBorder,
              ),

              const SizedBox(height: 22),

              // Form Field 4: PESAN SINGKAT / BADGES BANNER (MAKS 3)
              _buildFieldLabel('PESAN SINGKAT / BADGES BANNER (MAKS 3) *', labelColor),
              const SizedBox(height: 4),
              Text(
                'Badge informasi singkat di atas judul banner konser (maksimal 3 badge, maksimal 15 huruf per badge).',
                style: TextStyle(fontSize: 11.5, color: subtextColor),
              ),
              const SizedBox(height: 10),
              _ShortMessagesSection(
                initialMessages: shortMessages,
                onChanged: onShortMessagesChanged ?? (_) {},
                isDarkMode: isDarkMode,
                textColor: textColor,
                subtextColor: subtextColor,
                fieldBg: fieldBg,
                fieldBorder: fieldBorder,
                cardBg: cardBg,
              ),

              const SizedBox(height: 22),

              // Form Field 5: GAMBAR LOGO PERSEGI (1:1)
              _buildFieldLabel('GAMBAR LOGO PERSEGI (1:1) *', labelColor),
              const SizedBox(height: 4),
              Text(
                'Digunakan untuk kartu mini konser di penonton, QR e-tiket, dan avatar panggung.',
                style: TextStyle(fontSize: 11.5, color: subtextColor),
              ),
              const SizedBox(height: 8),

              if (_hasSquareLogo) ...[
                // Preview Card Logo 1:1
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF1B2A8C).withValues(alpha: 0.3),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Preview Box
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 72,
                          height: 72,
                          child: ConcertImageWidget(
                            imageSource: squareLogoDataUrl ?? squareLogoFileName,
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                            fallbackIcon: Icons.crop_square_rounded,
                            fallbackLabel: 'Logo 1:1',
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Logo Terpilih (1:1)',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF027A48),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              squareLogoFileName.isNotEmpty
                                  ? squareLogoFileName
                                  : 'logo_persegi.png',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  onPressed: onPickSquareLogo,
                                  icon: const Icon(Icons.edit_outlined,
                                      size: 13),
                                  label: const Text('Ganti',
                                      style: TextStyle(fontSize: 11.5)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF1B2A8C),
                                    side: const BorderSide(
                                        color: Color(0xFF1B2A8C)),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                TextButton.icon(
                                  onPressed: onRemoveSquareLogo,
                                  icon: const Icon(Icons.delete_outline_rounded,
                                      size: 14),
                                  label: const Text('Hapus',
                                      style: TextStyle(fontSize: 11.5)),
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFFD92D20),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 6),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Dashed Box Upload Logo 1:1
                InkWell(
                  onTap: onPickSquareLogo,
                  borderRadius: BorderRadius.circular(14),
                  child: DashedBorderBox(
                    borderRadius: 14,
                    color: const Color(0xFF1B2A8C), // Navy dashed border
                    backgroundColor: isDarkMode
                        ? const Color(0xFF182032)
                        : const Color(0xFFF8FAFC),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 18, horizontal: 16),
                      child: Row(
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0E7FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.crop_square_rounded,
                              size: 28,
                              color: Color(0xFF1B2A8C),
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pilih Gambar Logo Persegi (1:1)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1B2A8C),
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Rasio 1:1 (cth: 500x500 px). Format JPG / PNG.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF667085),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.file_upload_outlined,
                            size: 22,
                            color: Color(0xFF1B2A8C),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 22),

              // Form Field 5: POSTER HIGHLIGHT KONSER (16:9 / WAJIB)
              _buildFieldLabel('POSTER HIGHLIGHT KONSER (16:9) *', labelColor),
              const SizedBox(height: 4),
              Text(
                'Digunakan untuk banner besar di beranda utama aplikasi dan header halaman detail konser.',
                style: TextStyle(fontSize: 11.5, color: subtextColor),
              ),
              const SizedBox(height: 8),

              if (_hasPoster) ...[
                // Preview Card Poster 16:9
                Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFC2185B).withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ConcertImageWidget(
                              imageSource: posterDataUrl ?? posterFileName,
                              fit: BoxFit.cover,
                              fallbackIcon: Icons.image_outlined,
                              fallbackLabel: 'Poster 16:9',
                            ),
                            Positioned(
                              top: 10,
                              right: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3.5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.aspect_ratio_rounded,
                                        size: 12, color: Colors.white),
                                    SizedBox(width: 4),
                                    Text(
                                      '16:9 Landscape',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                posterFileName.isNotEmpty
                                    ? posterFileName
                                    : 'poster_utama.png',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: onPickPoster,
                              icon: const Icon(Icons.edit_outlined, size: 13),
                              label: const Text('Ganti',
                                  style: TextStyle(fontSize: 11.5)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFC2185B),
                                side: const BorderSide(color: Color(0xFFC2185B)),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: onRemovePoster,
                              icon: const Icon(Icons.delete_outline_rounded,
                                  size: 14),
                              label: const Text('Hapus',
                                  style: TextStyle(fontSize: 11.5)),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFFD92D20),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Dashed Box Upload Poster 16:9
                InkWell(
                  onTap: onPickPoster,
                  borderRadius: BorderRadius.circular(14),
                  child: DashedBorderBox(
                    borderRadius: 14,
                    color: const Color(0xFFC2185B), // Magenta dashed border
                    backgroundColor: isDarkMode
                        ? const Color(0xFF1F1722)
                        : const Color(0xFFFFF7FA),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 22, horizontal: 16),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image_outlined,
                            size: 32,
                            color: Color(0xFFC2185B),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Pilih Poster Highlight Konser (16:9)',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFC2185B),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Maksimal ukuran file 10MB. Format 16:9 (cth: 1920x1080 px).',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF667085),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Form Field 6: HIGHLIGHT KONSER TAMBAHAN (MULTI-IMAGE)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel(
                      'FOTO HIGHLIGHT KONSER (OPSIONAL)', labelColor),
                  const SizedBox(height: 3),
                  Text(
                    'Tambahkan foto suasana panggung, musisi, atau keseruan konser.',
                    style: TextStyle(fontSize: 11.5, color: subtextColor),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: onAddHighlight,
                      icon: const Icon(Icons.add_photo_alternate_outlined,
                          size: 14),
                      label: const Text('+ Tambah',
                          style: TextStyle(
                              fontSize: 11.5, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1B2A8C),
                        side: const BorderSide(color: Color(0xFF1B2A8C)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (highlights.isNotEmpty) ...[
                SizedBox(
                  height: 148,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: highlights.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final highlightSrc = highlights[index];
                      final name = index < highlightNames.length
                          ? highlightNames[index]
                          : 'Highlight #${index + 1}';

                      return Container(
                        width: 180,
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: fieldBorder),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Stack(
                              children: [
                                SizedBox(
                                  width: 180,
                                  height: 94,
                                  child: ConcertImageWidget(
                                    imageSource: highlightSrc,
                                    fit: BoxFit.cover,
                                    fallbackIcon: Icons.photo_library_outlined,
                                    fallbackLabel: 'Highlight #${index + 1}',
                                  ),
                                ),
                                Positioned(
                                  top: 6,
                                  left: 6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.black.withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '#${index + 1}',
                                      style: const TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: textColor,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () => onEditHighlight(index),
                                    borderRadius: BorderRadius.circular(6),
                                    child: const Padding(
                                      padding: EdgeInsets.all(4),
                                      child: Icon(
                                        Icons.edit_outlined,
                                        size: 15,
                                        color: Color(0xFF1B2A8C),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  InkWell(
                                    onTap: () => onRemoveHighlight(index),
                                    borderRadius: BorderRadius.circular(6),
                                    child: const Padding(
                                      padding: EdgeInsets.all(4),
                                      child: Icon(
                                        Icons.delete_outline_rounded,
                                        size: 15,
                                        color: Color(0xFFD92D20),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ] else ...[
                InkWell(
                  onTap: onAddHighlight,
                  borderRadius: BorderRadius.circular(14),
                  child: DashedBorderBox(
                    borderRadius: 14,
                    color: const Color(0xFF94A3B8),
                    backgroundColor: isDarkMode
                        ? const Color(0xFF182032)
                        : const Color(0xFFF8FAFC),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 14),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 20,
                            color: Color(0xFF64748B),
                          ),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Ketuk untuk menambahkan galeri foto highlight',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Bottom Navy Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: onNext,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text(
                    'Lanjut ke Pilih Tempat',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B2A8C), // Navy
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFieldLabel(String label, Color color) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 0.5,
      ),
    );
  }

  Future<void> _pickDateTime(BuildContext context) async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: DateTime(now.year + 5),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1B2A8C),
              onPrimary: Colors.white,
              onSurface: Color(0xFF101828),
            ),
          ),
          child: child!,
        );
      },
    );
    if (pickedDate == null || !context.mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 19, minute: 0),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1B2A8C),
              onPrimary: Colors.white,
              onSurface: Color(0xFF101828),
            ),
          ),
          child: child!,
        );
      },
    );
    if (pickedTime == null) return;

    final dayNames = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    final monthNames = [
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

    final dayName = dayNames[pickedDate.weekday - 1];
    final day = pickedDate.day;
    final monthName = monthNames[pickedDate.month - 1];
    final year = pickedDate.year;
    final hourStr = pickedTime.hour.toString().padLeft(2, '0');
    final minuteStr = pickedTime.minute.toString().padLeft(2, '0');

    dateTimeController.text =
        '$dayName, $day $monthName $year - $hourStr:$minuteStr WIB';

  }
}

// ============================================================================
// _AiDescriptionField — Fitur 3: Tombol [✨ AI Assistant] di field Deskripsi
// ============================================================================
/// Widget StatefulWidget yang membungkus field deskripsi beserta tombol AI Assistant.
/// Produser bisa mengetik poin-poin singkat lalu menekan [✨ AI Assistant] untuk
/// mendapatkan deskripsi 2-3 paragraf profesional dari AI, dengan opsi Undo.
class _AiDescriptionField extends StatefulWidget {
  final TextEditingController descriptionController;
  final TextEditingController nameController;
  final TextEditingController dateTimeController;
  final bool isDarkMode;
  final Color textColor;
  final Color fieldBg;
  final Color fieldBorder;

  const _AiDescriptionField({
    required this.descriptionController,
    required this.nameController,
    required this.dateTimeController,
    required this.isDarkMode,
    required this.textColor,
    required this.fieldBg,
    required this.fieldBorder,
  });

  @override
  State<_AiDescriptionField> createState() => _AiDescriptionFieldState();
}

class _AiDescriptionFieldState extends State<_AiDescriptionField> {
  final AiBackendService _aiService = AiBackendService();
  bool _isLoading = false;
  String? _previousText; // untuk Undo

  Future<void> _runAiAssistant() async {
    final draft = widget.descriptionController.text.trim();
    if (draft.length < 10) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Tuliskan poin-poin atau instruksi deskripsi (minimal 10 karakter) terlebih dahulu.'),
          backgroundColor: Color(0xFFD97706),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final saved = widget.descriptionController.text;
    setState(() {
      _isLoading = true;
      _previousText = saved;
    });

    try {
      final result = await _aiService.generateDescription(
        draft: draft,
        title: widget.nameController.text.trim(),
        genre: null,
        date: widget.dateTimeController.text.trim(),
        venue: null,
        artists: null,
      );
      if (!mounted) return;
      widget.descriptionController.text = result;
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✨ Deskripsi berhasil dibuat oleh AI!'),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Undo',
            textColor: Colors.white,
            onPressed: () {
              widget.descriptionController.text = saved;
              if (mounted) setState(() => _previousText = null);
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      // Jika error, kembalikan teks lama (teks tidak boleh hilang)
      widget.descriptionController.text = saved;
      setState(() {
        _isLoading = false;
        _previousText = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('AI gagal: $e'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _handleUndo() {
    if (_previousText != null) {
      widget.descriptionController.text = _previousText!;
      setState(() => _previousText = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderColor =
        _isLoading ? const Color(0xFF6366F1) : widget.fieldBorder;
    final aiButtonBg = widget.isDarkMode
        ? const Color(0xFF1E1B4B)
        : const Color(0xFFEEF2FF);
    final aiButtonTextColor = widget.isDarkMode
        ? const Color(0xFFC7D2FE)
        : const Color(0xFF4338CA);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Field deskripsi
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: widget.fieldBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
              width: _isLoading ? 1.5 : 1.0,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: TextField(
            controller: widget.descriptionController,
            maxLines: 4,
            enabled: !_isLoading,
            style: TextStyle(
              fontSize: 13.5,
              color: widget.textColor,
              height: 1.4,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText:
                  'Tulis poin-poin konser, lalu tekan "✨ AI Assistant" untuk membuat deskripsi otomatis...',
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Baris tombol AI Assistant + Undo
        Row(
          children: [
            // Tombol AI Assistant
            Expanded(
              child: Material(
                color: _isLoading ? const Color(0xFF6366F1) : aiButtonBg,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: _isLoading ? null : _runAiAssistant,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 40,
                    alignment: Alignment.center,
                    child: _isLoading
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'AI sedang menulis...',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.auto_awesome_rounded,
                                  size: 15, color: aiButtonTextColor),
                              const SizedBox(width: 6),
                              Text(
                                '✨ AI Assistant',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: aiButtonTextColor,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),

            // Tombol Undo — hanya muncul setelah AI berhasil menulis
            if (_previousText != null) ...[
              const SizedBox(width: 8),
              Material(
                color: widget.isDarkMode
                    ? const Color(0xFF1F2937)
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: _handleUndo,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.undo_rounded,
                          size: 15,
                          color: widget.isDarkMode
                              ? Colors.white70
                              : const Color(0xFF374151),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Undo',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: widget.isDarkMode
                                ? Colors.white70
                                : const Color(0xFF374151),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),

        // Petunjuk kecil di bawah tombol
        if (!_isLoading)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Ketik poin-poin konser lalu tekan tombol AI untuk membuat deskripsi otomatis. Gunakan Undo untuk kembali ke teks asli.',
              style: TextStyle(
                fontSize: 11,
                color: widget.isDarkMode
                    ? Colors.white38
                    : const Color(0xFF9CA3AF),
                height: 1.4,
              ),
            ),
          ),
      ],
    );
  }
}

class _ShortMessagesSection extends StatefulWidget {
  final List<String> initialMessages;
  final ValueChanged<List<String>> onChanged;
  final bool isDarkMode;
  final Color textColor;
  final Color subtextColor;
  final Color fieldBg;
  final Color fieldBorder;
  final Color cardBg;

  const _ShortMessagesSection({
    required this.initialMessages,
    required this.onChanged,
    required this.isDarkMode,
    required this.textColor,
    required this.subtextColor,
    required this.fieldBg,
    required this.fieldBorder,
    required this.cardBg,
  });

  @override
  State<_ShortMessagesSection> createState() => _ShortMessagesSectionState();
}

class _ShortMessagesSectionState extends State<_ShortMessagesSection> {
  late List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    final source = widget.initialMessages.isNotEmpty
        ? widget.initialMessages.take(3).toList()
        : ['Festival • 17+', 'Seru!'];
    _controllers = source.map((m) => TextEditingController(text: m)).toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _notifyChange() {
    final list = _controllers
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    widget.onChanged(list.isNotEmpty ? list : ['Festival • 17+', 'Seru!']);
    setState(() {});
  }

  void _addMessage() {
    if (_controllers.length >= 3) return;
    setState(() {
      _controllers.add(TextEditingController());
    });
    _notifyChange();
  }

  void _removeMessage(int index) {
    if (_controllers.length <= 1) return;
    setState(() {
      final removed = _controllers.removeAt(index);
      removed.dispose();
    });
    _notifyChange();
  }

  @override
  Widget build(BuildContext context) {
    final currentValues = _controllers
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Daftar input pesan singkat (maks 3)
        ...List.generate(_controllers.length, (index) {
          final ctrl = _controllers[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: widget.fieldBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: widget.fieldBorder),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    child: Row(
                      children: [
                        Text(
                          '#${index + 1}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1B2A8C),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: ctrl,
                            maxLength: 15,
                            onChanged: (_) => _notifyChange(),
                            style: TextStyle(
                              fontSize: 13.5,
                              color: widget.textColor,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              hintText: index == 0
                                  ? 'Contoh: Festival • 17+'
                                  : (index == 1 ? 'Contoh: Seru!' : 'Contoh: Outdoor'),
                              hintStyle: TextStyle(
                                fontSize: 13,
                                color: widget.subtextColor.withValues(alpha: 0.6),
                              ),
                              border: InputBorder.none,
                              counterText: '',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: ctrl,
                          builder: (context, val, _) {
                            final len = val.text.characters.length;
                            return Text(
                              '$len/15',
                              style: TextStyle(
                                fontSize: 11,
                                color: len >= 15
                                    ? Colors.red
                                    : widget.subtextColor.withValues(alpha: 0.7),
                                fontWeight: len >= 15 ? FontWeight.w700 : FontWeight.w500,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                if (_controllers.length > 1) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
                    onPressed: () => _removeMessage(index),
                    tooltip: 'Hapus pesan singkat',
                  ),
                ],
              ],
            ),
          );
        }),

        // Tombol Tambah Pesan Singkat (jika < 3)
        if (_controllers.length < 3)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _addMessage,
              icon: const Icon(Icons.add_rounded, size: 18, color: Color(0xFF1B2A8C)),
              label: Text(
                'Tambah Pesan Singkat (${_controllers.length}/3)',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1B2A8C),
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: const Color(0xFF1B2A8C).withValues(alpha: 0.3)),
                ),
              ),
            ),
          ),

        // Live Preview Badges di Banner
        if (currentValues.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.isDarkMode
                  ? const Color(0xFF0F172A)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: widget.fieldBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pratinjau Badge pada Banner Konser:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: widget.subtextColor,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: List.generate(currentValues.length, (idx) {
                    final msg = currentValues[idx];
                    final icon = idx == 0
                        ? Icons.star_rounded
                        : (idx == 1 ? Icons.local_fire_department_rounded : Icons.campaign_rounded);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBBF24), // Warm yellow from design
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 13, color: const Color(0xFF1E1B4B)),
                          const SizedBox(width: 4),
                          Text(
                            msg,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E1B4B),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

