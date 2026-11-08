import 'package:flutter/material.dart';
import '../../../services/promoter_data_service.dart';
import '../widgets/dashed_border_box.dart';
import '../widgets/promoter_step_indicator.dart';

class Step1DetailPosterScreen extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController dateTimeController;
  final TextEditingController descriptionController;
  final String posterFileName;
  final String squareLogoFileName;
  final VoidCallback onPickPoster;
  final VoidCallback onPickSquareLogo;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final bool isEditMode;

  const Step1DetailPosterScreen({
    super.key,
    required this.nameController,
    required this.dateTimeController,
    required this.descriptionController,
    required this.posterFileName,
    required this.squareLogoFileName,
    required this.onPickPoster,
    required this.onPickSquareLogo,
    required this.onNext,
    required this.onBack,
    this.isEditMode = false,
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
        final labelColor =
            isDarkMode ? Colors.white70 : const Color(0xFF475467);
        final fieldBg =
            isDarkMode ? const Color(0xFF1B2232) : Colors.white;
        final fieldBorder =
            isDarkMode ? Colors.white12 : const Color(0xFFE4E7EC);

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar with Back and Sun
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
                'Langkah 1 dari 5: Detail, Logo Persegi & Poster',
                style: TextStyle(
                  fontSize: 13,
                  color: subtextColor,
                ),
              ),

              const SizedBox(height: 16),

              // Stepper (Step 1 active dari 5 langkah)
              const PromoterStepIndicator(currentStep: 1, totalSteps: 5),

              const SizedBox(height: 24),

              // Form Field 1: NAMA KONSER
              _buildFieldLabel('NAMA KONSER', labelColor),
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
                      Icons.edit_outlined,
                      size: 20,
                      color: Color(0xFF667085),
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
                          hintText: 'Masukkan nama konser',
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Form Field 2: TANGGAL & WAKTU (Pemilihan Kalender & Jam)
              _buildFieldLabel('TANGGAL & WAKTU', labelColor),
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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
              _buildFieldLabel('DESKRIPSI ACARA', labelColor),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: fieldBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: fieldBorder),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                child: TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: textColor,
                    height: 1.4,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Deskripsikan kemeriahan acara...',
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Form Field 4: GAMBAR LOGO PERSEGI (1:1) - Sesuai role user
              _buildFieldLabel('GAMBAR LOGO PERSEGI (1:1)', labelColor),
              const SizedBox(height: 4),
              Text(
                'Digunakan untuk kartu konser mini di aplikasi penonton, QR e-tiket, dan avatar panggung.',
                style: TextStyle(fontSize: 11.5, color: subtextColor),
              ),
              const SizedBox(height: 8),
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                squareLogoFileName.isNotEmpty
                                    ? squareLogoFileName
                                    : 'Pilih Gambar Logo Persegi (1:1)',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1B2A8C),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              const Text(
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
                          size: 20,
                          color: Color(0xFF1B2A8C),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Form Field 5: POSTER HIGHLIGHT KONSER (16:9 / WAJIB)
              _buildFieldLabel('POSTER HIGHLIGHT KONSER (16:9)', labelColor),
              const SizedBox(height: 4),
              Text(
                'Digunakan untuk banner besar di beranda utama aplikasi dan halaman detail konser.',
                style: TextStyle(fontSize: 11.5, color: subtextColor),
              ),
              const SizedBox(height: 8),
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
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.image_outlined,
                          size: 32,
                          color: Color(0xFFC2185B),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          posterFileName.isNotEmpty
                              ? posterFileName
                              : 'Pilih Poster Highlight Konser (16:9)',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFC2185B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
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

              const SizedBox(height: 32),

              // Bottom Navy Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: onNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B2A8C), // Navy
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Lanjut ke Pilih Tempat',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
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
