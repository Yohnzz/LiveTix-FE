import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/promoter_data_service.dart';
import '../widgets/promoter_step_indicator.dart';

class Step1ProducerProfileScreen extends StatelessWidget {
  final TextEditingController fullNameController;
  final TextEditingController birthDateController;
  final TextEditingController phoneController;
  final TextEditingController addressController;
  final TextEditingController bankNameController;
  final TextEditingController bankAccountNumberController;
  final TextEditingController bankAccountHolderController;
  final String? errorMessage;
  final VoidCallback onPickBirthDate;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const Step1ProducerProfileScreen({
    super.key,
    required this.fullNameController,
    required this.birthDateController,
    required this.phoneController,
    required this.addressController,
    required this.bankNameController,
    required this.bankAccountNumberController,
    required this.bankAccountHolderController,
    this.errorMessage,
    required this.onPickBirthDate,
    required this.onNext,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final service = PromoterDataService();

    return ValueListenableBuilder<bool>(
      valueListenable: service.isDarkModeNotifier,
      builder: (context, isDarkMode, _) {
        final textColor = isDarkMode ? Colors.white : const Color(0xFF101828);
        final subtextColor =
            isDarkMode ? Colors.white70 : const Color(0xFF667085);
        final labelColor =
            isDarkMode ? Colors.white70 : const Color(0xFF667085);
        final fieldBg = isDarkMode ? const Color(0xFF1B2232) : Colors.white;
        final fieldBorder =
            isDarkMode ? Colors.white12 : const Color(0xFFE4E7EC);
        final inputTextColor =
            isDarkMode ? Colors.white : const Color(0xFF667085);

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
                      'Isi data diri Produser',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Langkah 1 dari 3: Informasi dasar penanggung jawab',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: subtextColor,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Field 1: NAMA LENGKAP PENANGGUNG JAWAB
                    _buildFieldLabel(
                        'NAMA LENGKAP PENANGGUNG JAWAB', labelColor),
                    const SizedBox(height: 8),
                    _buildInputContainer(
                      fieldBg: fieldBg,
                      fieldBorder: fieldBorder,
                      icon: Icons.person_outline_rounded,
                      controller: fullNameController,
                      hintText: 'Rafi Firmansyah',
                      textColor: inputTextColor,
                    ),

                    const SizedBox(height: 16),

                    // Field 2: TANGGAL LAHIR
                    _buildFieldLabel('TANGGAL LAHIR', labelColor),
                    const SizedBox(height: 8),
                    _buildInputContainer(
                      fieldBg: fieldBg,
                      fieldBorder: fieldBorder,
                      icon: Icons.calendar_today_outlined,
                      controller: birthDateController,
                      hintText: 'Pilih tanggal lahir',
                      textColor: inputTextColor,
                      readOnly: true,
                      onTap: onPickBirthDate,
                    ),

                    const SizedBox(height: 16),

                    // Field 3: NOMOR TELEPON SELULER
                    _buildFieldLabel('NOMOR TELEPON SELULER', labelColor),
                    const SizedBox(height: 8),
                    _buildInputContainer(
                      fieldBg: fieldBg,
                      fieldBorder: fieldBorder,
                      icon: Icons.phone_outlined,
                      controller: phoneController,
                      hintText: '0812 3456 7890',
                      keyboardType: TextInputType.phone,
                      textColor: inputTextColor,
                    ),

                    const SizedBox(height: 16),

                    // Field 4: ALAMAT KANTOR PUSAT
                    _buildFieldLabel('ALAMAT KANTOR PUSAT', labelColor),
                    const SizedBox(height: 8),
                    _buildInputContainer(
                      fieldBg: fieldBg,
                      fieldBorder: fieldBorder,
                      icon: Icons.location_on_outlined,
                      controller: addressController,
                      hintText: 'Jl. Kayutangan No. 45, Malang',
                      textColor: inputTextColor,
                    ),

                    const SizedBox(height: 22),

                    // Rekening bank penerima dana penjualan tiket
                    Row(
                      children: [
                        Icon(
                          Icons.account_balance_outlined,
                          size: 18,
                          color: textColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Rekening Penerima Dana',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Hasil penjualan tiket akan dicairkan ke rekening ini.',
                      style: TextStyle(fontSize: 12, color: subtextColor),
                    ),
                    const SizedBox(height: 14),

                    _buildFieldLabel('NAMA BANK', labelColor),
                    const SizedBox(height: 8),
                    _buildInputContainer(
                      fieldBg: fieldBg,
                      fieldBorder: fieldBorder,
                      icon: Icons.account_balance_outlined,
                      controller: bankNameController,
                      hintText: 'BCA, Mandiri, BNI, BRI',
                      textColor: inputTextColor,
                      fieldKey: const Key('verification_bank_name_field'),
                    ),

                    const SizedBox(height: 16),

                    _buildFieldLabel('NOMOR REKENING', labelColor),
                    const SizedBox(height: 8),
                    _buildInputContainer(
                      fieldBg: fieldBg,
                      fieldBorder: fieldBorder,
                      icon: Icons.numbers_rounded,
                      controller: bankAccountNumberController,
                      hintText: '1234567890',
                      keyboardType: TextInputType.number,
                      textColor: inputTextColor,
                      digitsOnly: true,
                      fieldKey:
                          const Key('verification_bank_account_number_field'),
                    ),

                    const SizedBox(height: 16),

                    _buildFieldLabel('NAMA PEMILIK REKENING', labelColor),
                    const SizedBox(height: 8),
                    _buildInputContainer(
                      fieldBg: fieldBg,
                      fieldBorder: fieldBorder,
                      icon: Icons.badge_outlined,
                      controller: bankAccountHolderController,
                      hintText: 'Sesuai buku tabungan',
                      textColor: inputTextColor,
                      fieldKey:
                          const Key('verification_bank_account_holder_field'),
                    ),

                    if (errorMessage != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? const Color(0xFF450A0A)
                              : const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDarkMode
                                ? const Color(0xFF991B1B)
                                : const Color(0xFFFECACA),
                          ),
                        ),
                        child: Text(
                          errorMessage!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode
                                ? const Color(0xFFFCA5A5)
                                : const Color(0xFFB91C1C),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 22),

                    // 3-Step Progress Bar below fields
                    const PromoterStepIndicator(
                      currentStep: 1,
                      totalSteps: 3,
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
                  onPressed: onNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B2A8C),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Lanjut ke Unggah Dokumen',
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

  Widget _buildFieldLabel(String label, Color color) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 0.4,
      ),
    );
  }

  Widget _buildInputContainer({
    required Color fieldBg,
    required Color fieldBorder,
    required IconData icon,
    required TextEditingController controller,
    required String hintText,
    required Color textColor,
    TextInputType keyboardType = TextInputType.text,
    bool digitsOnly = false,
    bool readOnly = false,
    VoidCallback? onTap,
    Key? fieldKey,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: fieldBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fieldBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: const Color(0xFF667085),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              key: fieldKey,
              controller: controller,
              keyboardType: keyboardType,
              readOnly: readOnly,
              onTap: onTap,
              inputFormatters:
                  digitsOnly ? [FilteringTextInputFormatter.digitsOnly] : null,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w400,
                color: textColor,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hintText,
                hintStyle: const TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF98A2B3),
                ),
                suffixIcon:
                    readOnly ? const Icon(Icons.arrow_drop_down_rounded) : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
