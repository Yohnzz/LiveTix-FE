import 'package:flutter/material.dart';
import '../../models/approval_models.dart';
import '../../services/admin_service.dart';
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

  static const List<String> _roles = ['Semua', 'User', 'Produser', 'Admin'];

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

  @override
  Widget build(BuildContext context) {
    return AdminScope(
      child: ListenableBuilder(
        listenable: _service.usersNotifier,
        builder: (context, _) {
          final allUsers = _service.usersNotifier.value;
          final query = _searchController.text.trim().toLowerCase();

          final filtered = allUsers.where((user) {
            final matchesRole = _selectedRole == 'Semua' ||
                user.role.toLowerCase() == _selectedRole.toLowerCase();
            final matchesQuery = query.isEmpty ||
                user.name.toLowerCase().contains(query) ||
                user.email.toLowerCase().contains(query);
            return matchesRole && matchesQuery;
          }).toList();

          return Column(
            children: [
              const AdminHeader(
                title: 'Kelola Pengguna',
                subtitle: 'Daftar seluruh role pengguna terdaftar di Soundwave',
              ),
              // Search Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(fontSize: 14, color: AdminColors.textDark),
                    decoration: InputDecoration(
                      hintText: 'Cari pengguna...',
                      hintStyle: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF94A3B8),
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: Color(0xFF94A3B8),
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
                            color: isSelected
                                ? const Color(0xFF1E3A8A)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF1E3A8A)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Text(
                            role,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
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
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AdminColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user.email,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AdminColors.textGrey,
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
      default:
        return const Color(0xFF2563EB);
    }
  }
}
