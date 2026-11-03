import 'package:flutter/material.dart';
import '../../services/promoter_data_service.dart';
import '../home/home_screen.dart';
import 'producer_customer_service_screen.dart';
import 'promoter_withdrawal_history_screen.dart';
import 'verification/producer_verification_flow.dart';

class PromoterProfileScreen extends StatelessWidget {
  final VoidCallback? onSwitchToUserMode;

  const PromoterProfileScreen({super.key, this.onSwitchToUserMode});

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

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Title, Subtitle, & Theme Toggle (Figma Image 2)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Profil Produser',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Kelola data identitas dan pengaturan EO Anda',
                          style: TextStyle(
                            fontSize: 13,
                            color: subtextColor,
                          ),
                        ),
                      ],
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

              const SizedBox(height: 20),

              // Profile Card: Avatar JP + Java Promotor + GOLD Badge + ID Produser (Figma Image 2)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: cardBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF3E8FF), // Soft purple-pink circle
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text(
                          'JP',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF7E22CE), // Bold purple/magenta
                          ),
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
                              Text(
                                'Java Promotor',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: textColor,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B), // Gold/Amber pill
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'GOLD',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'ID Produser: #JP-8089312',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: subtextColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Section Label: INFORMASI AKUN
              Text(
                'INFORMASI AKUN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: subtextColor,
                  letterSpacing: 0.5,
                ),
              ),

              const SizedBox(height: 12),

              // Item 1: Dokumen Legal (KTP) -> TERVERIFIKASI ✓
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cardBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Dokumen Legal (KTP)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'TERVERIFIKASI',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF039855), // Green
                            letterSpacing: 0.2,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: Color(0xFF039855),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Item 2: Email Bisnis -> official@javapromotor.com
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cardBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Email Bisnis',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                    Text(
                      'official@javapromotor.com',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Item 3: Kontak Darurat -> +62 812-9908-1120
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cardBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Kontak Darurat',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                    Text(
                      '+62 812-9908-1120',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Button: Hubungi Bantuan / CS (Figma Image 2)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ProducerCustomerServiceScreen(),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: Color(0xFF1B2A8C), // Navy
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Hubungi Bantuan / CS',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1B2A8C),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Additional Functional Modules for Full Ecosystem Support
              Text(
                'AKSI LAINNYA',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: subtextColor,
                  letterSpacing: 0.5,
                ),
              ),

              const SizedBox(height: 12),

              // Switch to User Mode
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? const Color(0xFF131D33)
                      : const Color(0xFFF0F4FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF1B2A8C).withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFF1B2A8C),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.swap_horiz_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Mode Penonton (Attendee)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1B2A8C),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Beli tiket konser sebagai penonton',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: subtextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B2A8C),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        if (onSwitchToUserMode != null) {
                          onSwitchToUserMode!();
                        } else {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const HomeScreen(isGuest: false),
                            ),
                          );
                        }
                      },
                      child: const Text(
                        'Beralih',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Bank Account Information
              _buildMenuItem(
                icon: Icons.account_balance_outlined,
                title: 'Rekening Bank Penerima',
                subtitle: 'Bank BCA - 8820 1928 31 a/n Java Promotor',
                cardBg: cardBg,
                cardBorder: cardBorder,
                textColor: textColor,
                subtextColor: subtextColor,
                onTap: () => _showBankAccountDialog(context),
              ),

              const SizedBox(height: 10),

              // PIN Keamanan
              _buildMenuItem(
                icon: Icons.shield_outlined,
                title: 'PIN Keamanan Transaksi',
                subtitle: 'PIN 6-digit aktif untuk otorisasi pencairan dana',
                cardBg: cardBg,
                cardBorder: cardBorder,
                textColor: textColor,
                subtextColor: subtextColor,
                onTap: () => _showPinSettingsDialog(context),
              ),

              const SizedBox(height: 10),

              // Riwayat Penarikan Dana
              _buildMenuItem(
                icon: Icons.receipt_long_outlined,
                title: 'Riwayat Penarikan Dana',
                subtitle: 'Daftar audit dan status pengajuan dana',
                cardBg: cardBg,
                cardBorder: cardBorder,
                textColor: textColor,
                subtextColor: subtextColor,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PromoterWithdrawalHistoryScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 10),

              // Dokumen Legalitas & Verifikasi Perusahaan
              _buildMenuItem(
                icon: Icons.verified_user_outlined,
                title: 'Dokumen Legalitas & Status Verifikasi',
                subtitle: 'SIUP, NIB, & KTP Terverifikasi Escrow',
                cardBg: cardBg,
                cardBorder: cardBorder,
                textColor: textColor,
                subtextColor: subtextColor,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ProducerVerificationFlow(
                        initialStage: ProducerVerificationStage.lengkapiProfil,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color cardBg,
    required Color cardBorder,
    required Color textColor,
    required Color subtextColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cardBorder),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF1B2A8C), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: subtextColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: subtextColor,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showBankAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.account_balance_outlined,
                color: Color(0xFF1B2A8C), size: 22),
            SizedBox(width: 8),
            Text(
              'Rekening Penerima Dana',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Rekening bank ini telah divalidasi dan digunakan untuk menerima pencairan hasil penjualan tiket konser:',
              style: TextStyle(
                  fontSize: 12.5, color: Color(0xFF667085), height: 1.4),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE4E7EC)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bank Tujuan: Bank Central Asia (BCA)',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  SizedBox(height: 4),
                  Text('Nomor Rekening: 8820 1928 31',
                      style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF1B2A8C),
                          fontWeight: FontWeight.w700)),
                  SizedBox(height: 4),
                  Text('Pemilik Rekening: PT Harmoni Java Promosindo',
                      style: TextStyle(fontSize: 12, color: Color(0xFF667085))),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE8FDF0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_user_outlined,
                      size: 16, color: Color(0xFF039855)),
                  SizedBox(width: 6),
                  Text(
                    'Status Rekening: Terverifikasi Escrow',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF039855),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B2A8C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  void _showPinSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: Color(0xFFC2185B), size: 22),
            SizedBox(width: 8),
            Text(
              'PIN Keamanan 6-Digit',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PIN 6-digit Anda aktif dan siap melindungi setiap aksi kritikal (pencairan dana escrow & pembatalan konser).',
              style: TextStyle(
                  fontSize: 12.5, color: Color(0xFF667085), height: 1.4),
            ),
            SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    size: 18, color: Color(0xFF039855)),
                SizedBox(width: 8),
                Text(
                  'PIN Default Pengujian: 123456',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF101828)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B2A8C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Selesai'),
          ),
        ],
      ),
    );
  }
}
