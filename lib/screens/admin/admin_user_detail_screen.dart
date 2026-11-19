import 'package:flutter/material.dart';
import '../../models/approval_models.dart';
import '../../services/admin_service.dart';
import 'widgets/admin_theme.dart';
import 'widgets/admin_widgets.dart';

/// Layar Detail Pengguna (Image 5): Menampilkan profil, metrik tiket & konser,
/// info akun, status aktif, riwayat transaksi, dan aksi nonaktifkan akun.
class AdminUserDetailScreen extends StatefulWidget {
  final String userId;

  const AdminUserDetailScreen({super.key, required this.userId});

  @override
  State<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends State<AdminUserDetailScreen> {
  final AdminService _service = AdminService();

  @override
  void initState() {
    super.initState();
    // Status akun harus berasal dari database terbaru, bukan cache lama.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _service.load(force: true);
    });
  }

  /// Menonaktifkan akun User. Alasan wajib diisi sebelum tombol aktif.
  Future<void> _deactivateUser(
      BuildContext context, ManagedUserModel user) async {
    final reason = await _askDeactivationReason(context, user);
    if (reason == null || !context.mounted) return;

    final updated = _service.deactivateUser(user.id, reason);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          updated != null
              ? 'Akun ${user.name} berhasil dinonaktifkan'
              : 'Akun tidak dapat dinonaktifkan. Muat ulang data lalu coba lagi.',
        ),
        backgroundColor:
            updated != null ? const Color(0xFF166534) : const Color(0xFFB91C1C),
      ),
    );
  }

  /// Dialog alasan penonaktifan. Mengembalikan null bila admin membatalkan.
  Future<String?> _askDeactivationReason(
      BuildContext context, ManagedUserModel user) async {
    return showDialog<String>(
      context: context,
      builder: (dialogCtx) => _DeactivateUserDialog(user: user),
    );
  }

  Future<void> _activateUser(
      BuildContext context, ManagedUserModel user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Aktifkan Akun?',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Akun ${user.name} akan diaktifkan kembali, alasan penonaktifan '
          'dikosongkan, dan pengguna dapat login serta bertransaksi seperti biasa.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              minimumSize: const Size(64, 44),
              backgroundColor: const Color(0xFF16A34A),
            ),
            child: const Text('Aktifkan'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    final updated = _service.activateUser(user.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          updated != null
              ? 'Akun ${user.name} berhasil diaktifkan'
              : 'Akun tidak dapat diaktifkan. Muat ulang data lalu coba lagi.',
        ),
        backgroundColor:
            updated != null ? const Color(0xFF166534) : const Color(0xFFB91C1C),
      ),
    );
  }

  Future<void> _showChangeNameDialog(
      BuildContext context, ManagedUserModel user) async {
    final controller = TextEditingController(text: user.name);
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        final textPri = AdminColors.textPrimaryOf(dialogCtx);
        final textSec = AdminColors.textSecondaryOf(dialogCtx);
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Ganti Nama Pengguna',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: textPri,
            ),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ubah nama untuk akun ${user.email}:',
                  style: TextStyle(fontSize: 13, color: textSec),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: controller,
                  autofocus: true,
                  style: TextStyle(fontSize: 14, color: textPri),
                  decoration: InputDecoration(
                    labelText: 'Nama Baru',
                    hintText: 'Masukkan nama pengguna',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Nama tidak boleh kosong';
                    }
                    if (v.trim().length < 2) return 'Nama minimal 2 karakter';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                final newName = controller.text.trim();
                AdminService().updateUserName(user.id, newName);
                Navigator.of(dialogCtx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Nama pengguna berhasil diubah menjadi "$newName"'),
                    backgroundColor: const Color(0xFF166534),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: AdminColors.primaryButtonBgOf(dialogCtx),
                foregroundColor: Colors.white,
              ),
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminScope(
      child: ListenableBuilder(
        listenable: _service.usersNotifier,
        builder: (context, _) {
          final user = _service.userById(widget.userId);
          return Scaffold(
            backgroundColor: AdminColors.bgOf(context),
            body: Column(
              children: [
                AdminHeader(
                  title: 'Detail Pengguna',
                  onBack: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: user == null
                      ? const AdminMessageState(
                          icon: Icons.person_off_outlined,
                          title: 'Pengguna tidak ditemukan',
                          message: 'Data pengguna ini sudah tidak tersedia.',
                        )
                      : _buildBody(context, user),
                ),
              ],
            ),
            bottomNavigationBar:
                user != null ? _buildBottomBar(context, user) : null,
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, ManagedUserModel user) {
    final textPri = AdminColors.textPrimaryOf(context);
    final textSec = AdminColors.textSecondaryOf(context);
    final border = AdminColors.borderOf(context);
    final dividerCol = AdminColors.dividerOf(context);
    final (roleBg, roleFg) = AdminColors.roleBadgeColors(context, user.role);
    final isDark = AdminColors.isDark(context);

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.35,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          // 1. Kartu Profil & Metrik Pengguna
          AdminCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Avatar Bulat Besar
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: roleBg,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    user.initials,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: roleFg,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  user.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textPri,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: roleBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    user.role,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: roleFg,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Divider(height: 1, color: dividerCol),
                const SizedBox(height: 16),
                // 3 Kolom Metrik
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            '${user.ticketsBought}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: textPri,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tiket Dibeli',
                            style: TextStyle(
                              fontSize: 12,
                              color: textSec,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(height: 32, width: 1, color: border),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            '${user.concertsAttended}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: textPri,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Konser Dihadiri',
                            style: TextStyle(
                              fontSize: 12,
                              color: textSec,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(height: 32, width: 1, color: border),
                    Expanded(
                      child: Column(
                        children: [
                          Icon(
                            user.hasFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 22,
                            color: user.hasFavorite
                                ? (isDark
                                    ? const Color(0xFFF472B6)
                                    : const Color(0xFFEC4899))
                                : textSec,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Favorit',
                            style: TextStyle(
                              fontSize: 12,
                              color: textSec,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: dividerCol),
                const SizedBox(height: 10),
                // Tombol Aksi Kelola Akun: Ganti Nama Pengguna
                SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: OutlinedButton.icon(
                    key: const ValueKey('btn_ganti_nama'),
                    onPressed: () => _showChangeNameDialog(context, user),
                    icon: const Icon(Icons.edit_outlined, size: 15),
                    label: const Text(
                      'Ganti Nama',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AdminColors.accentOf(context),
                      side: BorderSide(color: AdminColors.infoBorderOf(context)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 2. Kartu Informasi Akun
          AdminCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              children: [
                _buildInfoRow(context, 'Nomor HP', user.phone),
                Divider(height: 1, color: border),
                _buildInfoRow(context, 'Bergabung Sejak', user.joinedAt),
                Divider(height: 1, color: border),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 120,
                        child: Text(
                          'Status Akun',
                          style: TextStyle(fontSize: 13, color: textSec),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: StatusBadge(
                            status: user.approvalStatus,
                            label: user.approvalStatus.userLabel,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (user.statusReason != null) ...[
            const SizedBox(height: 16),
            AdminCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        user.approvalStatus.icon,
                        size: 18,
                        color: user.approvalStatus.color,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Alasan Penonaktifan',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: textPri,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user.statusReason!,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: textSec,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // 3. Riwayat Transaksi
          const AdminSectionTitle('Riwayat Transaksi'),
          if (user.transactions.isEmpty)
            AdminCard(
              child: Text(
                'Belum ada transaksi.',
                style: TextStyle(fontSize: 13, color: textSec),
              ),
            )
          else
            ...user.transactions.map(
              (tx) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AdminCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tx.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: textPri,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${tx.invoice} · ${ApprovalFormat.rupiah(tx.amount)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: textSec,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AdminColors.successBgOf(context),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          tx.status,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AdminColors.successOf(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: AdminColors.textSecondaryOf(context),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AdminColors.textPrimaryOf(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteGateCrew(
      BuildContext context, ManagedUserModel user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Hapus Gate Crew?',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Akun Gate Crew ${user.name} (${user.email}) akan dihapus permanen beserta penugasan gatenya.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            style: FilledButton.styleFrom(
              minimumSize: const Size(64, 44),
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AdminService().deleteGateCrewByAdmin(
        userId: user.id,
        email: user.email,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Akun Gate Crew ${user.name} berhasil dihapus'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  Widget _buildBottomBar(BuildContext context, ManagedUserModel user) {
    final willDeactivate = user.isActive;
    final isGatecrew = user.role.toLowerCase() == 'gatecrew';
    final toggleButton = SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: () => willDeactivate
            ? _deactivateUser(context, user)
            : _activateUser(context, user),
        style: OutlinedButton.styleFrom(
          backgroundColor: willDeactivate
              ? AdminColors.dangerBgOf(context)
              : AdminColors.successBgOf(context),
          foregroundColor: willDeactivate
              ? AdminColors.dangerOf(context)
              : AdminColors.successOf(context),
          side: BorderSide(
            color: willDeactivate
                ? AdminColors.dangerBorderOf(context)
                : AdminColors.successBorderOf(context),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          willDeactivate ? 'Nonaktifkan Akun' : 'Aktifkan Akun User',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
        ),
      ),
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: isGatecrew
            ? Row(
                children: [
                  Expanded(child: toggleButton),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: FilledButton.icon(
                        key: const ValueKey('btn_hapus_gatecrew'),
                        onPressed: () => _confirmDeleteGateCrew(context, user),
                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                        label: const Text(
                          'Hapus Crew',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : toggleButton,
      ),
    );
  }
}

/// Dialog alasan penonaktifan yang memiliki controller sendiri, sehingga
/// controller tidak dibuang saat animasi dialog masih berjalan.
class _DeactivateUserDialog extends StatefulWidget {
  final ManagedUserModel user;

  const _DeactivateUserDialog({required this.user});

  @override
  State<_DeactivateUserDialog> createState() => _DeactivateUserDialogState();
}

class _DeactivateUserDialogState extends State<_DeactivateUserDialog> {
  final TextEditingController _controller = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Nonaktifkan Akun?',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pengguna ${widget.user.name} tidak akan dapat login atau '
              'bertransaksi selama akun dinonaktifkan. Alasan wajib diisi dan '
              'akan ditampilkan kepada pengguna.',
              style: const TextStyle(fontSize: 13.5, height: 1.45),
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('admin_user_deactivate_reason_input'),
              controller: _controller,
              autofocus: true,
              minLines: 3,
              maxLines: 5,
              maxLength: 300,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                labelText: 'Alasan Penonaktifan',
                hintText: 'Contoh: pelanggaran ketentuan pembelian tiket.',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return 'Alasan wajib diisi';
                if (text.length < 5) return 'Alasan minimal 5 karakter';
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
          child: const Text('Batal'),
        ),
        FilledButton(
          key: const Key('admin_user_deactivate_confirm_button'),
          onPressed: _submit,
          style: FilledButton.styleFrom(
            minimumSize: const Size(64, 44),
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
          ),
          child: const Text('Nonaktifkan'),
        ),
      ],
    );
  }
}
