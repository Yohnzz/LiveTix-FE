import 'package:flutter/material.dart';
import '../../../services/promoter_data_service.dart';
import '../../../utils/file_picker_helper.dart';

class ProducerDeactivatedScreen extends StatelessWidget {
  final String responsiblePersonName;
  final VoidCallback? onContactAdmin;
  final VoidCallback? onLogout;
  final String adminWhatsAppNumber;

  const ProducerDeactivatedScreen({
    super.key,
    this.responsiblePersonName = 'Produser LiveTix',
    this.onContactAdmin,
    this.onLogout,
    this.adminWhatsAppNumber = '6281234567890',
  });

  Future<void> _redirectToWhatsApp(BuildContext context) async {
    final service = PromoterDataService();
    final name = responsiblePersonName.trim().isNotEmpty
        ? responsiblePersonName.trim()
        : service.promoterName;
    final message = Uri.encodeComponent(
      'Halo Admin LiveTix, akun produser saya ($name) dinonaktifkan oleh Admin. Mohon informasi dan bantuan pengaktifan kembali.',
    );
    final url = 'https://wa.me/$adminWhatsAppNumber?text=$message';
    try {
      await openExternalUrl(url);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal membuka WhatsApp. Silakan hubungi admin di +$adminWhatsAppNumber',
            ),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = PromoterDataService();
    final displayName = responsiblePersonName.trim().isNotEmpty
        ? responsiblePersonName.trim()
        : (service.promoterName.isNotEmpty ? service.promoterName : 'Produser LiveTix');

    final reason = service.deactivationReasonNotifier.value?.trim();

    return ValueListenableBuilder<bool>(
      valueListenable: service.isDarkModeNotifier,
      builder: (context, isDarkMode, _) {
        final textColor = isDarkMode ? Colors.white : const Color(0xFF101828);
        final subtextColor =
            isDarkMode ? Colors.white70 : const Color(0xFF667085);
        final cardBg = isDarkMode ? const Color(0xFF1B2232) : Colors.white;
        final cardBorder =
            isDarkMode ? Colors.white12 : const Color(0xFFE4E7EC);

        // Warna merah untuk status dinonaktifkan
        const redAccent = Color(0xFFDC2626);
        final redBannerBg =
            isDarkMode ? const Color(0xFF2C1517) : const Color(0xFFFEF2F2);
        final redBannerBorder =
            isDarkMode ? const Color(0xFF991B1B) : const Color(0xFFFCA5A5);

        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Bar with Logout & Theme Toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (onLogout != null)
                          TextButton.icon(
                            onPressed: onLogout,
                            icon: const Icon(Icons.arrow_back_rounded, size: 18),
                            label: const Text('Keluar ke Login'),
                            style: TextButton.styleFrom(
                              foregroundColor: redAccent,
                              textStyle: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        else
                          const SizedBox.shrink(),
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
                      'Pemberitahuan status keanggotaan Produser LiveTix',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: subtextColor,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Red Warning Banner Card: Akun Dinonaktifkan oleh Admin
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: redBannerBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: redBannerBorder, width: 1.2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: redAccent.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.block_rounded,
                                  color: redAccent,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Akun dinonaktifkan oleh admin',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: redAccent,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Akses akun produser Anda dinonaktifkan sementara',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: isDarkMode
                                            ? Colors.white70
                                            : const Color(0xFF7F1D1D),
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (reason != null && reason.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? Colors.black26
                                    : Colors.white.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: redBannerBorder.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Text(
                                'Catatan Admin: "$reason"',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isDarkMode
                                      ? Colors.white
                                      : const Color(0xFF991B1B),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Card: Progres & Riwayat Akun
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
                            'Status & Informasi Akun',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Step 1: Akun Terdaftar
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
                            subtitle: 'Terverifikasi via akun resmi',
                            subtitleColor: subtextColor,
                          ),

                          const SizedBox(height: 14),

                          // Step 2: Profil & Dokumen
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
                            title: 'Profil & Dokumen Lengkap',
                            titleColor: textColor,
                            subtitle: '$displayName sebagai penanggung jawab',
                            subtitleColor: subtextColor,
                          ),

                          const SizedBox(height: 14),

                          // Step 3: Status Terkini (Dinonaktifkan oleh Admin)
                          _buildProgressStep(
                            indicator: Container(
                              width: 26,
                              height: 26,
                              decoration: const BoxDecoration(
                                color: redAccent,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                            title: 'Akun Dinonaktifkan oleh Admin',
                            titleColor: redAccent,
                            subtitle:
                                'Hubungi admin melalui WhatsApp untuk bantuan aktivasi',
                            subtitleColor: redAccent.withValues(alpha: 0.85),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Bottom Sticky Buttons: Hubungi Admin (WhatsApp) & Keluar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Button 1: Hubungi Admin (Redirect ke WhatsApp)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (onContactAdmin != null) {
                          onContactAdmin!();
                        } else {
                          _redirectToWhatsApp(context);
                        }
                      },
                      icon: const Icon(
                        Icons.chat_outlined,
                        size: 20,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Hubungi Admin via WhatsApp',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A), // Hijau WhatsApp
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),

                  if (onLogout != null) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton(
                        onPressed: onLogout,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: cardBg,
                          side: BorderSide(color: cardBorder, width: 1.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Keluar ke Login',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: textColor,
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
