import 'package:flutter/material.dart';
import '../../models/approval_models.dart';
import '../../services/admin_service.dart';
import '../../services/gate_crew_service.dart';
import 'admin_user_detail_screen.dart';
import 'widgets/admin_theme.dart';
import 'widgets/admin_widgets.dart';

/// Layar Kelola Pengguna (Image 4): Menampilkan daftar pengguna dengan pencarian,
/// filter role (Semua, User, Produser, Admin), dan kartu pengguna interaktif.
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final AdminService _service = AdminService();
  final TextEditingController _searchController = TextEditingController();
  String _selectedRole = 'Semua';

  static const List<String> _roles = ['Semua', 'User', 'Produser', 'Admin', 'Gatecrew'];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showChangeNameDialog(ManagedUserModel user) async {
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
                    hintText: 'Masukkan nama baru',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
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
                _service.updateUserName(user.id, newName);
                Navigator.of(dialogCtx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text('Nama pengguna berhasil diubah menjadi "$newName"'),
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

  void _showAddGateCrewDialog() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    const defaultPwd = GateCrewService.defaultSystemCrewPassword;

    showDialog<void>(
      context: context,
      builder: (ctx) {
        final isDark = AdminColors.isDark(ctx);
        final textPri = AdminColors.textPrimaryOf(ctx);
        final textSec = AdminColors.textSecondaryOf(ctx);
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                Icons.badge_outlined,
                color: isDark
                    ? const Color(0xFF2DD4BF)
                    : const Color(0xFF0F766E),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tambah Gate Crew',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: textPri,
                  ),
                ),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Admin mendaftarkan email Gate Crew dengan password default $defaultPwd. Petugas dapat mengganti kata sandi setelah masuk.',
                    style: TextStyle(
                        fontSize: 12.5, color: textSec, height: 1.3),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: nameCtrl,
                    style: TextStyle(fontSize: 14, color: textPri),
                    decoration: InputDecoration(
                      labelText: 'Nama Petugas',
                      hintText: 'Contoh: Ahmad Gate Crew',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Nama wajib diisi'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailCtrl,
                    style: TextStyle(fontSize: 14, color: textPri),
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email Petugas',
                      hintText: 'Contoh: ahmad.gate@livetix.com',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Email wajib diisi';
                      }
                      if (!v.contains('@')) return 'Format email tidak valid';
                      final candidate = v.trim().toLowerCase();
                      final existsInUsers = _service.usersNotifier.value
                          .any((u) => u.email.trim().toLowerCase() == candidate);
                      final existsInCrews = GateCrewService()
                          .teamCrewNotifier
                          .value
                          .any((c) => c.email.trim().toLowerCase() == candidate);
                      if (existsInUsers || existsInCrews) {
                        return 'Email sudah terdaftar';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneCtrl,
                    style: TextStyle(fontSize: 14, color: textPri),
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'No. Telepon (Opsional)',
                      hintText: 'Contoh: 081234567890',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(ctx);
                final newMember = await GateCrewService().createGateCrewByAdmin(
                  name: nameCtrl.text.trim(),
                  email: emailCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                );

                final adminService = AdminService();
                final currentList = List<ManagedUserModel>.from(
                    adminService.usersNotifier.value);
                currentList.removeWhere((u) =>
                    u.id == newMember.id ||
                    u.email.trim().toLowerCase() ==
                        newMember.email.trim().toLowerCase());
                currentList.insert(
                  0,
                  ManagedUserModel(
                    id: newMember.id,
                    name: newMember.name,
                    email: newMember.email,
                    role: 'Gatecrew',
                    phone: newMember.phone,
                    joinedAt: 'Baru saja',
                    isActive: true,
                    password: defaultPwd,
                  ),
                );
                adminService.usersNotifier.value = currentList;

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Gate Crew ${newMember.name} berhasil didaftarkan (Password: $defaultPwd)',
                      ),
                      backgroundColor: const Color(0xFF0F766E),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
              ),
              child: const Text('Daftarkan'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDeleteGateCrew(ManagedUserModel user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Hapus Gate Crew?',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AdminColors.textPrimaryOf(dialogCtx),
          ),
        ),
        content: Text(
          'Akun Gate Crew ${user.name} (${user.email}) akan dihapus permanen beserta penugasan gatenya.',
          style: TextStyle(
            fontSize: 13.5,
            color: AdminColors.textSecondaryOf(dialogCtx),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _service.deleteGateCrewByAdmin(userId: user.id, email: user.email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Akun Gate Crew ${user.name} berhasil dihapus'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gateCrewService = GateCrewService();
    return AdminScope(
      child: ListenableBuilder(
        listenable: Listenable.merge([
          _service.usersNotifier,
          gateCrewService.teamCrewNotifier,
        ]),
        builder: (context, _) {
          final baseUsers = _service.usersNotifier.value;
          final existingIds = baseUsers.map((u) => u.id).toSet();
          final existingEmails =
              baseUsers.map((u) => u.email.trim().toLowerCase()).toSet();
          final allUsers = <ManagedUserModel>[
            ...baseUsers,
            for (final crew in gateCrewService.teamCrewNotifier.value)
              if (crew.isApproved &&
                  !existingIds.contains(crew.id) &&
                  !existingEmails.contains(crew.email.trim().toLowerCase()))
                ManagedUserModel(
                  id: crew.id,
                  name: crew.name,
                  email: crew.email,
                  role: 'Gatecrew',
                  phone: crew.phone,
                  joinedAt: 'Terdaftar',
                  isActive: true,
                  password: crew.defaultPassword,
                ),
          ];
          final pendingGateCrews = gateCrewService.teamCrewNotifier.value
              .where((c) => c.isPendingApproval)
              .toList();
          final query = _searchController.text.trim().toLowerCase();

          final filtered = allUsers.where((user) {
            final matchesRole = _selectedRole == 'Semua' ||
                user.role.toLowerCase() == _selectedRole.toLowerCase();
            final matchesQuery = query.isEmpty ||
                user.name.toLowerCase().contains(query) ||
                user.email.toLowerCase().contains(query);
            return matchesRole && matchesQuery;
          }).toList();

          final surface = AdminColors.surfaceOf(context);
          final border = AdminColors.borderOf(context);
          final textPri = AdminColors.textPrimaryOf(context);
          final textSec = AdminColors.textSecondaryOf(context);
          final accent = AdminColors.accentOf(context);

          return Column(
            children: [
              const AdminHeader(
                eyebrow: 'MANAJEMEN AKUN & PERAN',
                title: 'Kelola Pengguna',
                subtitle: 'Daftar seluruh role pengguna terdaftar di LiveTix',
              ),
              // Seluruh konten di bawah header (Search, Filter Chips, Action Bar, Pending & List) dalam satu scroll view agar responsif di layar kecil / text scale besar
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    // Search Bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: border),
                        ),
                        child: TextField(
                          controller: _searchController,
                          style: TextStyle(fontSize: 14, color: textPri),
                          decoration: InputDecoration(
                            hintText: 'Cari pengguna...',
                            hintStyle: TextStyle(
                              fontSize: 14,
                              color: textSec,
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: textSec,
                              size: 20,
                            ),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded,
                                        size: 18),
                                    onPressed: () => _searchController.clear(),
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Filter Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: _roles.map((role) {
                          final isSelected = _selectedRole == role;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkWell(
                              key: ValueKey('filter_chip_$role'),
                              onTap: () =>
                                  setState(() => _selectedRole = role),
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected ? accent : surface,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: isSelected ? accent : border,
                                  ),
                                ),
                                child: Text(
                                  role,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected ? Colors.white : textSec,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Action bar: Total Pengguna & Tombol Tambah Gate Crew (khusus di bagian Gatecrew)
                    MediaQuery.withClampedTextScaling(
                      maxScaleFactor: 1.35,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _selectedRole == 'Gatecrew'
                                    ? '${filtered.length} Gate Crew Terdaftar'
                                    : '${filtered.length} Pengguna Terdaftar',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: textSec,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_selectedRole == 'Gatecrew') ...[
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                key: const ValueKey('btn_tambah_gatecrew'),
                                onPressed: _showAddGateCrewDialog,
                                icon: const Icon(
                                    Icons.person_add_alt_1_rounded,
                                    size: 14),
                                label: const Text(
                                  'Tambah Crew',
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F766E),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
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
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (pendingGateCrews.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: MediaQuery.withClampedTextScaling(
                          maxScaleFactor: 1.35,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AdminColors.purpleBgOf(context),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AdminColors.isDark(context)
                                    ? const Color(0xFF7E22CE)
                                    : const Color(0xFFD8B4FE),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pengajuan Gate Crew Produser (${pendingGateCrews.length} Menunggu Approval)',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: AdminColors.purpleOf(context),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ...pendingGateCrews.map((crew) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Wrap(
                                      alignment: WrapAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        Text(
                                          '${crew.email} (Password: ${crew.defaultPassword})',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: textPri,
                                          ),
                                        ),
                                        Wrap(
                                          spacing: 4,
                                          runSpacing: 4,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            TextButton(
                                              onPressed: () async {
                                                await GateCrewService()
                                                    .rejectGateCrewByAdmin(
                                                        crew.id);
                                              },
                                              style: TextButton.styleFrom(
                                                foregroundColor:
                                                    AdminColors.dangerOf(
                                                        context),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4),
                                                minimumSize: Size.zero,
                                                tapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                              ),
                                              child: const Text(
                                                'Tolak',
                                                style: TextStyle(
                                                    fontSize: 11.5,
                                                    fontWeight:
                                                        FontWeight.w700),
                                              ),
                                            ),
                                            ElevatedButton(
                                              onPressed: () async {
                                                final approved =
                                                    await GateCrewService()
                                                        .approveGateCrewByAdmin(
                                                            crew.id);
                                                if (approved != null) {
                                                  final currentList = List<
                                                          ManagedUserModel>.from(
                                                      _service
                                                          .usersNotifier.value);
                                                  currentList.removeWhere((u) =>
                                                      u.id == approved.id ||
                                                      u.email
                                                              .trim()
                                                              .toLowerCase() ==
                                                          approved.email
                                                              .trim()
                                                              .toLowerCase());
                                                  currentList.insert(
                                                    0,
                                                    ManagedUserModel(
                                                      id: approved.id,
                                                      name: approved.name,
                                                      email: approved.email,
                                                      role: 'Gatecrew',
                                                      phone: approved.phone,
                                                      joinedAt: 'Baru saja',
                                                      isActive: true,
                                                      password: approved
                                                          .defaultPassword,
                                                    ),
                                                  );
                                                  _service.usersNotifier.value =
                                                      currentList;
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          'Gate Crew ${approved.email} disetujui (Password: ${approved.defaultPassword})',
                                                        ),
                                                        backgroundColor:
                                                            const Color(
                                                                0xFF16A34A),
                                                      ),
                                                    );
                                                  }
                                                }
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    const Color(0xFF16A34A),
                                                foregroundColor: Colors.white,
                                                elevation: 0,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 5),
                                                minimumSize: Size.zero,
                                                tapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                              ),
                                              child: const Text(
                                                'Setujui',
                                                style: TextStyle(
                                                    fontSize: 11.5,
                                                    fontWeight:
                                                        FontWeight.w700),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (filtered.isEmpty)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
                        child: AdminMessageState(
                          icon: Icons.person_search_outlined,
                          title: 'Pengguna tidak ditemukan',
                          message:
                              'Tidak ada pengguna yang cocok dengan filter atau kata kunci.',
                        ),
                      )
                    else
                      for (var i = 0; i < filtered.length; i++)
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            20,
                            i > 0 ? 10 : 0,
                            20,
                            0,
                          ),
                          child: _UserCard(
                            user: filtered[i],
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => AdminUserDetailScreen(
                                      userId: filtered[i].id),
                                ),
                              );
                            },
                            onEditName: () =>
                                _showChangeNameDialog(filtered[i]),
                            onDelete:
                                filtered[i].role.toLowerCase() == 'gatecrew'
                                    ? () => _confirmDeleteGateCrew(filtered[i])
                                    : null,
                          ),
                        ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final ManagedUserModel user;
  final VoidCallback onTap;
  final VoidCallback onEditName;
  final VoidCallback? onDelete;

  const _UserCard({
    required this.user,
    required this.onTap,
    required this.onEditName,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final (roleBg, roleFg) = AdminColors.roleBadgeColors(context, user.role);
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.35,
      child: AdminCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        onTap: onTap,
        child: Row(
          children: [
            // Avatar Initial
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: roleBg,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                user.initials,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: roleFg,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // User Info + Role Badge (wrap agar tidak overflow di 320px)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AdminColors.textPrimaryOf(context),
                        ),
                      ),
                      // Role Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
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
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: AdminColors.textSecondaryOf(context),
                    ),
                  ),
                ],
              ),
            ),
            if (onDelete != null) ...[
              const SizedBox(width: 4),
              SizedBox(
                width: 28,
                height: 28,
                child: IconButton(
                  key: ValueKey('btn_delete_gatecrew_${user.id}'),
                  tooltip: 'Hapus Gate Crew',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: onDelete,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: AdminColors.dangerOf(context),
                  ),
                ),
              ),
            ],
            const SizedBox(width: 2),
            // Action Menu
            SizedBox(
              width: 24,
              height: 24,
              child: PopupMenuButton<String>(
                tooltip: 'Menu Akun',
                padding: EdgeInsets.zero,
                iconSize: 18,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                icon: Icon(
                  Icons.more_vert_rounded,
                  size: 18,
                  color: AdminColors.textSecondaryOf(context),
                ),
                onSelected: (val) {
                  if (val == 'name') {
                    onEditName();
                  } else if (val == 'detail') {
                    onTap();
                  } else if (val == 'delete') {
                    onDelete?.call();
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'name',
                    child: _buildPopupRow(
                      ctx: ctx,
                      icon: Icons.edit_outlined,
                      iconColor: AdminColors.accentOf(ctx),
                      label: 'Ganti Nama',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'detail',
                    child: _buildPopupRow(
                      ctx: ctx,
                      icon: Icons.visibility_outlined,
                      iconColor: AdminColors.textSecondaryOf(ctx),
                      label: 'Lihat Detail',
                    ),
                  ),
                  if (onDelete != null)
                    PopupMenuItem(
                      value: 'delete',
                      child: _buildPopupRow(
                        ctx: ctx,
                        icon: Icons.delete_outline_rounded,
                        iconColor: AdminColors.dangerOf(ctx),
                        label: 'Hapus Gate Crew',
                        fontWeight: FontWeight.w600,
                        textColor: AdminColors.dangerOf(ctx),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildPopupRow({
    required BuildContext ctx,
    required IconData icon,
    required Color iconColor,
    required String label,
    FontWeight fontWeight = FontWeight.w400,
    Color? textColor,
  }) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.35,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: fontWeight,
                color: textColor ?? AdminColors.textPrimaryOf(ctx),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
