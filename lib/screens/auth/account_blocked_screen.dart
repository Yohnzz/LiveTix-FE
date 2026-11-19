import 'package:flutter/material.dart';

import '../../core/account_status.dart';
import '../../services/data_service.dart';
import '../../utils/file_picker_helper.dart';
import '../home/home_screen.dart';

/// Layar blokir untuk akun User yang berstatus `nonaktif` atau `rejected`.
///
/// Alasan diambil langsung dari kolom database (`deactivation_reason` untuk
/// nonaktif, `rejection_reason` untuk ditolak) lewat [AccountStatus.reasonFrom].
class AccountBlockedScreen extends StatelessWidget {
  final String accountName;
  final String email;
  final AccountStatus status;
  final String? reason;
  final String adminWhatsAppNumber;

  const AccountBlockedScreen({
    super.key,
    required this.accountName,
    required this.email,
    required this.status,
    this.reason,
    this.adminWhatsAppNumber = '6281234567890',
  });

  Future<void> _contactAdmin(BuildContext context) async {
    final message = Uri.encodeComponent(
      'Halo Admin LiveTix, akun saya ($email) berstatus '
      '"${status.label}". Mohon informasi mengenai akun saya.',
    );
    try {
      await openExternalUrl('https://wa.me/$adminWhatsAppNumber?text=$message');
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal membuka WhatsApp. Hubungi admin di +$adminWhatsAppNumber',
          ),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  void _logout(BuildContext context) {
    DataService().logout();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const HomeScreen(isGuest: true)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF101828);
    final subtextColor = isDark ? Colors.white70 : const Color(0xFF667085);
    final cardBg = isDark ? const Color(0xFF1B2232) : Colors.white;
    final cardBorder = isDark ? Colors.white12 : const Color(0xFFE4E7EC);
    final reasonBg = isDark ? const Color(0xFF2C1517) : const Color(0xFFFEF2F2);
    final reasonBorder =
        isDark ? const Color(0xFF991B1B) : const Color(0xFFFCA5A5);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF101623) : Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton.icon(
                onPressed: () => _logout(context),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Keluar ke Beranda'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFC2185B),
                  textStyle: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: reasonBg,
                    border: Border.all(color: reasonBorder),
                  ),
                  child: Icon(
                    Icons.lock_outline_rounded,
                    size: 34,
                    color: status.color,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: Text(
                  status.blockedTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Akun $email tidak dapat digunakan saat ini. '
                  'Seluruh fitur LiveTix dinonaktifkan sampai akun diaktifkan kembali oleh Admin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: subtextColor,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(status.icon, size: 18, color: status.color),
                        const SizedBox(width: 8),
                        Text(
                          'Status akun',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: subtextColor,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: status.backgroundColor,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            status.label,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: status.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (reason != null) ...[
                      const SizedBox(height: 14),
                      Divider(height: 1, color: cardBorder),
                      const SizedBox(height: 14),
                      Text(
                        'Alasan dari Admin',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: subtextColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        reason!,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.45,
                          color: textColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () => _contactAdmin(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFC2185B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('Hubungi Admin'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () => _logout(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textColor,
                    side: BorderSide(color: cardBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Keluar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
