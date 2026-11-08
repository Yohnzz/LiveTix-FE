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
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Ganti Nama Pengguna',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ubah nama untuk akun ${user.email}:',
                style: const TextStyle(fontSize: 13, color: AdminColors.textGrey),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(fontSize: 14, color: AdminColors.textDark),
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
              backgroundColor: const Color(0xFF1E3A8A),
            ),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showAddGateCrewDialog() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.badge_outlined, color: Color(0xFF0F766E)),
            SizedBox(width: 8),
            Text(
              'Tambah Gate Crew',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Admin mendaftarkan email Gate Crew dengan password default gatecrew123. Petugas dapat mengganti kata sandi setelah masuk.',
                style: TextStyle(fontSize: 12.5, color: AdminColors.textGrey, height: 1.3),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Nama Petugas',
                  hintText: 'Contoh: Ahmad Gate Crew',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Nama wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email Petugas',
                  hintText: 'Contoh: ahmad.gate@livetix.com',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email wajib diisi';
                  if (!v.contains('@')) return 'Format email tidak valid';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'No. Telepon (Opsional)',
                  hintText: 'Contoh: 081234567890',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
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
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx);
              final newMember = await GateCrewService().createGateCrewByAdmin(
                name: nameCtrl.text.trim(),
                email: emailCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
              );

              final adminService = AdminService();
              final currentList =
                  List<ManagedUserModel>.from(adminService.usersNotifier.value);
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
                  password: 'gatecrew123',
                ),
              );
              adminService.usersNotifier.value = currentList;

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Gate Crew ${newMember.name} berhasil didaftarkan (Password: gatecrew123)',
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
      ),
    );
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
          final allUsers = _service.usersNotifier.value;
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
                              icon: const Icon(Icons.clear_rounded, size: 18),
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
                        onTap: () => setState(() => _selectedRole = role),
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

              // Action bar: Total Pengguna & Tombol Tambah Gate Crew
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${filtered.length} Pengguna Terdaftar',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _showAddGateCrewDialog,
                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 14),
                      label: const Text(
                        'Tambah Crew',
                        style: TextStyle(
                            fontSize: 11.5, fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (pendingGateCrews.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF5FF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFD8B4FE)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pengajuan Gate Crew Produser (${pendingGateCrews.length} Menunggu Approval)',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF581C87),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...pendingGateCrews.map((crew) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${crew.email} (Password: ${crew.defaultPassword})',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0F172A),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                TextButton(
                                  onPressed: () async {
                                    await GateCrewService()
                                        .rejectGateCrewByAdmin(crew.id);
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFFDC2626),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'Tolak',
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                ElevatedButton(
                                  onPressed: () async {
                                    final approved = await GateCrewService()
                                        .approveGateCrewByAdmin(crew.id);
                                    if (approved != null) {
                                      final currentList =
                                          List<ManagedUserModel>.from(
                                              _service.usersNotifier.value);
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
                                          password: approved.defaultPassword,
                                        ),
                                      );
                                      _service.usersNotifier.value =
                                          currentList;
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Gate Crew ${approved.email} disetujui (Password: ${approved.defaultPassword})',
                                            ),
                                            backgroundColor:
                                                const Color(0xFF16A34A),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF16A34A),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'Setujui',
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              // User List
              Expanded(
                child: filtered.isEmpty
                    ? const AdminMessageState(
                        icon: Icons.person_search_outlined,
                        title: 'Pengguna tidak ditemukan',
                        message: 'Tidak ada pengguna yang cocok dengan filter atau kata kunci.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final user = filtered[index];
                          return _UserCard(
                            user: user,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      AdminUserDetailScreen(userId: user.id),
                                ),
                              );
                            },
                            onEditName: () => _showChangeNameDialog(user),
                          );
                        },
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

  const _UserCard({
    required this.user,
    required this.onTap,
    required this.onEditName,
  });

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      onTap: onTap,
      child: Row(
        children: [
          // Avatar Initial
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _roleBg(user.role),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              user.initials,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _roleTextColor(user.role),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AdminColors.textPrimaryOf(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user.email,
                  style: TextStyle(
                    fontSize: 12,
                    color: AdminColors.textSecondaryOf(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Role Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _roleBg(user.role),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              user.role,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _roleTextColor(user.role),
              ),
            ),
          ),
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
              icon: const Icon(
                Icons.more_vert_rounded,
                size: 18,
                color: Color(0xFF94A3B8),
              ),
              onSelected: (val) {
                if (val == 'name') {
                  onEditName();
                } else if (val == 'detail') {
                  onTap();
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'name',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined,
                          size: 18, color: Color(0xFF1E3A8A)),
                      SizedBox(width: 8),
                      Text('Ganti Nama',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'detail',
                  child: Row(
                    children: [
                      Icon(Icons.visibility_outlined,
                          size: 18, color: AdminColors.textGrey),
                      SizedBox(width: 8),
                      Text('Lihat Detail', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Color _roleBg(String role) {
    switch (role.toLowerCase()) {
      case 'produser':
        return const Color(0xFFF3E8FF);
      case 'admin':
        return const Color(0xFFEFF6FF);
      case 'gatecrew':
        return const Color(0xFFECFDF5);
      default:
        return const Color(0xFFEFF6FF);
    }
  }

  static Color _roleTextColor(String role) {
    switch (role.toLowerCase()) {
      case 'produser':
        return const Color(0xFF7C3AED);
      case 'admin':
        return const Color(0xFF1E3A8A);
      case 'gatecrew':
        return const Color(0xFF059669);
      default:
        return const Color(0xFF2563EB);
    }
  }
}
