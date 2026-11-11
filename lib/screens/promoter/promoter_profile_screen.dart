import 'package:flutter/material.dart';
import '../../services/data_service.dart';
import '../../services/promoter_data_service.dart';
import '../../utils/file_picker_helper.dart';
import '../home/home_screen.dart';
import 'producer_customer_service_screen.dart';
import 'promoter_withdrawal_history_screen.dart';
import 'verification/producer_verification_flow.dart';

class PromoterProfileScreen extends StatefulWidget {
  final VoidCallback? onSwitchToUserMode;

  const PromoterProfileScreen({super.key, this.onSwitchToUserMode});

  /// Masukkan nomor WhatsApp Admin di sini (contoh: '6281234567890')
  static const String adminWhatsappNumber = '6282335640458';

  @override
  State<PromoterProfileScreen> createState() => _PromoterProfileScreenState();
}

class _PromoterProfileScreenState extends State<PromoterProfileScreen> {
  Future<void> _openAdminWhatsapp(BuildContext context) async {
    final rawPhone = PromoterProfileScreen.adminWhatsappNumber.trim();
    if (rawPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Silakan isi nomor WhatsApp Admin pada variabel adminWhatsappNumber di PromoterProfileScreen.',
          ),
          backgroundColor: Color(0xFF1B2A8C),
        ),
      );
      return;
    }

    var cleanPhone = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '62${cleanPhone.substring(1)}';
    }
    final message = Uri.encodeComponent(
      'Halo Admin LiveTix, saya Produser (${PromoterDataService().promoterName}) ingin menghubungi Layanan Bantuan / CS.',
    );
    final url = 'https://wa.me/$cleanPhone?text=$message';
    final opened = await openExternalUrl(url);
    if (!opened) {
      await openExternalUrl('whatsapp://send?phone=$cleanPhone&text=$message');
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Mengarahkan ke WhatsApp Admin: +$cleanPhone'),
          backgroundColor: const Color(0xFF039855),
        ),
      );
    }
  }

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

        return ValueListenableBuilder<String>(
          valueListenable: service.promoterNameNotifier,
          builder: (context, promoterName, _) {
            return ValueListenableBuilder<String?>(
              valueListenable: service.pendingNameChangeNotifier,
              builder: (context, pendingName, _) {
                return SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row: Title, Subtitle, & Theme Toggle
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

                      // Profile Card: Avatar + Nama Produser + GOLD Badge + Edit Button
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: cardBorder),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                  alpha: isDarkMode ? 0.2 : 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () => _pickProfilePhoto(context),
                                  child: Stack(
                                    children: [
                                      Container(
                                        width: 58,
                                        height: 58,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFF3E8FF),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            service.promoterInitials,
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF7E22CE),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF1B2A8C),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.camera_alt_rounded,
                                            size: 11,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              promoterName,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                                color: textColor,
                                                letterSpacing: -0.2,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 7, vertical: 2.5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF59E0B),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              service.verificationBadge,
                                              style: const TextStyle(
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
                                IconButton(
                                  tooltip: 'Ubah Profil',
                                  onPressed: () =>
                                      _showEditProfileDialog(context),
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    color: Color(0xFF1B2A8C),
                                  ),
                                ),
                              ],
                            ),
                            if (pendingName != null &&
                                pendingName.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFFAEB),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFFEC84B),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.hourglass_top_rounded,
                                      size: 16,
                                      color: Color(0xFFB54708),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Perubahan nama ke "$pendingName" sedang menunggu persetujuan Admin.',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFFB54708),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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

                      // Item 1: Dokumen Legal (KTP & Lembar Penanggung Jawab)
                      ValueListenableBuilder<String?>(
                        valueListenable: service.pendingKtpFileNameNotifier,
                        builder: (context, pendingKtp, _) {
                          final hasPendingDoc = pendingKtp != null ||
                              service.pendingResponsibilityLetterFileNameNotifier
                                      .value !=
                                  null;
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
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
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      hasPendingDoc
                                          ? 'MENUNGGU APPROVAL'
                                          : 'TERVERIFIKASI',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        color: hasPendingDoc
                                            ? const Color(0xFFB54708)
                                            : const Color(0xFF039855),
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      hasPendingDoc
                                          ? Icons.schedule_rounded
                                          : Icons.check_rounded,
                                      size: 16,
                                      color: hasPendingDoc
                                          ? const Color(0xFFB54708)
                                          : const Color(0xFF039855),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 10),

                      // Item 2: Email Bisnis
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
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
                            Flexible(
                              child: Text(
                                DataService().currentUser?.email ??
                                    service.promoterEmail,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Item 3: Kontak Darurat
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
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
                              service.promoterPhone,
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

                      // Button: Hubungi Bantuan / CS (WhatsApp Admin)
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: () => _openAdminWhatsapp(context),
                          icon: const Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 18,
                            color: Color(0xFF039855),
                          ),
                          label: const Text(
                            'Hubungi Bantuan / CS (WhatsApp Admin)',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1B2A8C),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: Color(0xFF1B2A8C),
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Button: Live Chat Customer Service (Admin LiveTix)
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const ProducerCustomerServiceScreen(
                                  senderRole: 'Produser',
                                ),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.support_agent_rounded,
                            size: 20,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Customer Service Live Chat',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1B2A8C),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Pengaturan Akun & Keamanan
                      Text(
                        'PENGATURAN & KEAMANAN',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: subtextColor,
                          letterSpacing: 0.5,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Ubah Profil, Foto & Kata Sandi
                      _buildMenuItem(
                        icon: Icons.manage_accounts_outlined,
                        title: 'Ubah Profil, Foto & Kata Sandi',
                        subtitle:
                            'Foto & sandi langsung aktif · Ubah nama menunggu approval Admin',
                        cardBg: cardBg,
                        cardBorder: cardBorder,
                        textColor: textColor,
                        subtextColor: subtextColor,
                        onTap: () => _showEditProfileDialog(context),
                      ),

                      const SizedBox(height: 10),

                      // Ganti Dokumen Legalitas (KTP & Lembar Penanggung Jawab)
                      _buildMenuItem(
                        icon: Icons.verified_user_outlined,
                        title: 'Ubah Dokumen Legalitas',
                        subtitle:
                            'Unggah ulang KTP / Lembar Penanggung Jawab (Perlu Approval Admin)',
                        cardBg: cardBg,
                        cardBorder: cardBorder,
                        textColor: textColor,
                        subtextColor: subtextColor,
                        onTap: () => _showUpdateLegalityDialog(context),
                      ),

                      const SizedBox(height: 10),

                      // Bank Account Information
                      _buildMenuItem(
                        icon: Icons.account_balance_outlined,
                        title: 'Rekening Bank Penerima',
                        subtitle: 'Bank BCA - 8820 1928 31 a/n $promoterName',
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
                        title: 'PIN Keamanan 6-Digit',
                        subtitle:
                            'Atur atau ubah PIN keamanan masuk aplikasi & transaksi',
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
                              builder: (_) =>
                                  const PromoterWithdrawalHistoryScreen(),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 10),

                      // Keluar Akun Produser
                      _buildMenuItem(
                        icon: Icons.logout_rounded,
                        title: 'Keluar Akun Produser',
                        subtitle:
                            'Selesaikan sesi dan kembali ke halaman utama sebagai tamu',
                        cardBg: cardBg,
                        cardBorder: cardBorder,
                        textColor: const Color(0xFFD92D20),
                        subtextColor: subtextColor,
                        onTap: () => _showLogoutDialog(context),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _pickProfilePhoto(BuildContext context) async {
    final picked = await pickNativeFile();
    if (picked == null || !context.mounted) return;
    await PromoterDataService().updateProfilePhotoDirectly(picked);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Foto profil berhasil diperbarui ($picked).'),
        backgroundColor: const Color(0xFF039855),
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context) {
    final service = PromoterDataService();
    final nameCtrl = TextEditingController(text: service.promoterName);
    final oldPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    String? selectedPhoto = service.avatarUrlNotifier.value;

    showDialog<void>(
      context: context,
      builder: (ctx) => Theme(
        data: ThemeData.light(),
        child: StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Text(
              'Ubah Profil & Kata Sandi',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Foto Profil (Langsung berubah)
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: const Color(0xFFF3E8FF),
                        child: Text(
                          service.promoterInitials,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF7E22CE),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Foto Profil (Langsung Aktif)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              selectedPhoto ?? 'Belum ada foto baru dipilih',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final file = await pickNativeFile();
                          if (file != null) {
                            setDialogState(() => selectedPhoto = file);
                          }
                        },
                        child: const Text('Pilih Foto'),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  // Nama Produser (Perlu Approval Admin)
                  const Text(
                    'Nama Produser / EO (Menunggu Approval Admin)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Masukkan nama produser / EO baru',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Kata Sandi (Langsung Berubah)
                  const Text(
                    'Ubah Kata Sandi (Langsung Aktif - Opsional)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: oldPassCtrl,
                    obscureText: true,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Kata sandi lama',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: newPassCtrl,
                    obscureText: true,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Kata sandi baru (min. 6 karakter)',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Batal',
                  style: TextStyle(color: Color(0xFF475569)),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B2A8C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () async {
                  final messages = <String>[];
                  if (selectedPhoto != null &&
                      selectedPhoto != service.avatarUrlNotifier.value) {
                    await service.updateProfilePhotoDirectly(selectedPhoto!);
                    messages.add('Foto profil diperbarui');
                  }

                  final newPass = newPassCtrl.text.trim();
                  if (newPass.isNotEmpty) {
                    if (newPass.length < 6) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Kata sandi baru minimal 6 karakter.'),
                            backgroundColor: Color(0xFFD92D20),
                          ),
                        );
                      }
                      return;
                    }
                    final res = await DataService().changePassword(
                      oldPassword: oldPassCtrl.text.trim(),
                      newPassword: newPass,
                    );
                    if (!res.success) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(res.message ?? 'Kata sandi lama tidak sesuai.'),
                            backgroundColor: const Color(0xFFD92D20),
                          ),
                        );
                      }
                      return;
                    }
                    messages.add('Kata sandi berhasil diubah');
                  }

                  final newName = nameCtrl.text.trim();
                  if (newName.isNotEmpty && newName != service.promoterName) {
                    await service.requestProfileOrLegalityChange(
                      newName: newName,
                    );
                    messages.add(
                      'Perubahan nama "$newName" diajukan ke Admin',
                    );
                  }

                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  if (messages.isNotEmpty && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(messages.join(' · ')),
                        backgroundColor: const Color(0xFF039855),
                      ),
                    );
                  }
                },
                child: const Text('Simpan'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUpdateLegalityDialog(BuildContext context) {
    final service = PromoterDataService();
    String? newKtpFile;
    String? newLetterFile;

    showDialog<void>(
      context: context,
      builder: (ctx) => Theme(
        data: ThemeData.light(),
        child: StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Text(
              'Ubah Dokumen Legalitas',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Perubahan dokumen legalitas memerlukan pemeriksaan dan persetujuan Admin sebelum menggantikan dokumen lama.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF475569),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final f = await pickNativeFile();
                      if (f != null) {
                        setDialogState(() => newKtpFile = f);
                      }
                    },
                    icon: const Icon(Icons.badge_outlined, size: 18),
                    label: Text(
                      newKtpFile ?? 'Pilih File KTP Baru',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final f = await pickNativeFile();
                      if (f != null) {
                        setDialogState(() => newLetterFile = f);
                      }
                    },
                    icon: const Icon(Icons.description_outlined, size: 18),
                    label: Text(
                      newLetterFile ??
                          'Pilih Lembar Penanggung Jawab Baru (.doc/.pdf)',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProducerVerificationFlow(
                            initialStage:
                                ProducerVerificationStage.lengkapiProfil,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('Buka Wizard Verifikasi Lengkap'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B2A8C),
                  foregroundColor: Colors.white,
                ),
                onPressed: (newKtpFile == null && newLetterFile == null)
                    ? null
                    : () async {
                        await service.requestProfileOrLegalityChange(
                          newKtpFileName: newKtpFile,
                          newResponsibilityLetterFileName: newLetterFile,
                        );
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Dokumen legalitas baru berhasil dikirim dan menunggu persetujuan Admin.',
                              ),
                              backgroundColor: Color(0xFF039855),
                            ),
                          );
                        }
                      },
                child: const Text('Ajukan ke Admin'),
              ),
            ],
          ),
        ),
      ),
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
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
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
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A))),
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
    final pinCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Theme(
        data: ThemeData.light(),
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.shield_outlined, color: Color(0xFFC2185B), size: 22),
              SizedBox(width: 8),
              Text(
                'PIN Keamanan 6-Digit',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PIN 6-digit digunakan setiap kali Produser masuk ke aplikasi dan saat otorisasi pencairan dana.',
                style: TextStyle(
                    fontSize: 12.5, color: Color(0xFF667085), height: 1.4),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pinCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                obscureText: true,
                style: const TextStyle(color: Color(0xFF0F172A)),
                decoration: InputDecoration(
                  labelText: 'PIN 6-Digit Baru',
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: confirmCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                obscureText: true,
                style: const TextStyle(color: Color(0xFF0F172A)),
                decoration: InputDecoration(
                  labelText: 'Konfirmasi PIN Baru',
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B2A8C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final p = pinCtrl.text.trim();
                final c = confirmCtrl.text.trim();
                if (p.length != 6 || p != c) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'PIN harus 6 digit angka dan konfirmasi harus cocok.'),
                      backgroundColor: Color(0xFFD92D20),
                    ),
                  );
                  return;
                }
                await PromoterDataService().updateProducerPin(p);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('PIN Keamanan 6-Digit berhasil diperbarui.'),
                      backgroundColor: Color(0xFF039855),
                    ),
                  );
                }
              },
              child: const Text('Simpan PIN'),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text(
          'Keluar dari Akun Produser?',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Anda akan keluar dari sesi produser dan kembali ke beranda sebagai tamu.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD92D20),
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true && context.mounted) {
        PromoterDataService().lockPinSession();
        DataService().logout();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen(isGuest: true)),
          (route) => false,
        );
      }
    });
  }
}
