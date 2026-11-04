import 'package:flutter/material.dart';
import '../../../models/approval_models.dart';
import 'admin_theme.dart';

/// Header, tab, dan bottom nav adalah chrome tetap. Skala teksnya dibatasi agar
/// area daftar di bawahnya tetap punya ruang, isi halaman sendiri tetap ikut skala penuh.
const double _maxTextScale = 1.3;

class AdminHeader extends StatelessWidget {
  final String title;
  final String? eyebrow;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onBack;

  const AdminHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.trailing,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: _maxTextScale,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(gradient: AdminColors.gradient),
        padding: EdgeInsets.fromLTRB(20, top + 24, 20, 24),
        child: _content(),
      ),
    );
  }

  Widget _content() {
    return Row(
      children: [
        if (onBack != null) ...[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: onBack,
              tooltip: 'Kembali',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null)
                Text(
                  eyebrow!,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                ),
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.25,
                  ),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ],
    );
  }
}

class StatusBadge extends StatelessWidget {
  final ApprovalStatus status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (status) {
      ApprovalStatus.pending => (
          const Color(0xFFFEF3C7),
          const Color(0xFF92400E)
        ),
      ApprovalStatus.approved => (
          const Color(0xFFDCFCE7),
          const Color(0xFF166534)
        ),
      ApprovalStatus.rejected => (
          const Color(0xFFFEE2E2),
          const Color(0xFFB91C1C)
        ),
      ApprovalStatus.deactivated => (
          const Color(0xFFFEE2E2),
          const Color(0xFFB91C1C)
        ),
    };
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: _maxTextScale,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          status.label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
        ),
      ),
    );
  }
}

class InitialAvatar extends StatelessWidget {
  final String initials;
  final double size;

  const InitialAvatar({super.key, required this.initials, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: _maxTextScale,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AdminColors.avatarBg,
          shape: BoxShape.circle,
        ),
        child: ExcludeSemantics(
          child: Text(
            initials,
            style: TextStyle(
              fontSize: size * 0.32,
              fontWeight: FontWeight.w700,
              color: AdminColors.navy,
            ),
          ),
        ),
      ),
    );
  }
}

/// Poster konser. Belum ada gambar nyata dari produser, jadi tampil sebagai placeholder.
class PosterThumb extends StatelessWidget {
  final String? url;
  final double width;
  final double height;
  final double radius;

  const PosterThumb({
    super.key,
    this.url,
    this.width = 60,
    this.height = 60,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: width,
      height: height,
      decoration: const BoxDecoration(gradient: AdminColors.gradient),
      child: Icon(
        Icons.music_note_rounded,
        color: Colors.white.withValues(alpha: 0.9),
        size: height * 0.42,
      ),
    );
    return Semantics(
      image: true,
      label: url == null ? 'Poster belum tersedia' : 'Poster konser',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: url == null
            ? placeholder
            : Image.network(
                url!,
                width: width,
                height: height,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => placeholder,
              ),
      ),
    );
  }
}

class AdminCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final String? semanticLabel;
  final Color? color;
  final Color? borderColor;

  const AdminCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.semanticLabel,
    this.color,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    final card = Material(
      color: color ?? AdminColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: borderColor ?? AdminColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : InkWell(
              onTap: onTap,
              child: Padding(padding: padding, child: child),
            ),
    );
    if (onTap == null) return card;
    return Semantics(button: true, label: semanticLabel, child: card);
  }
}

class AdminLoadingState extends StatelessWidget {
  const AdminLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(48),
        child: CircularProgressIndicator(
          color: AdminColors.navy,
          semanticsLabel: 'Memuat data',
        ),
      ),
    );
  }
}

class AdminMessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AdminMessageState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AdminColors.textGrey),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AdminColors.textGrey),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  foregroundColor: AdminColors.navy,
                  side: const BorderSide(color: AdminColors.navy),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AdminTabItem<T> {
  final String label;
  final T value;

  const AdminTabItem(this.label, this.value);
}

/// Baris tab teks dengan garis tipis di atas dan bawah, sesuai desain.
class AdminTextTabs<T> extends StatelessWidget {
  final List<AdminTabItem<T>> items;
  final T selected;
  final ValueChanged<T> onChanged;

  const AdminTextTabs({
    super.key,
    required this.items,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: _maxTextScale,
      child: _bar(),
    );
  }

  Widget _bar() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AdminColors.surface,
        border: Border(
          top: BorderSide(color: AdminColors.border),
          bottom: BorderSide(color: AdminColors.border),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            for (final item in items)
              Semantics(
                button: true,
                selected: item.value == selected,
                label: item.label,
                excludeSemantics: true,
                child: InkWell(
                  onTap: () => onChanged(item.value),
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(minHeight: 48, minWidth: 44),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Center(
                        child: Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: item.value == selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: item.value == selected
                                ? AdminColors.navy
                                : AdminColors.textGrey,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class AdminBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AdminBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const List<(String, IconData)> _items = [
    ('Beranda', Icons.home_outlined),
    ('Approval', Icons.check_rounded),
    ('Kelola User', Icons.group_outlined),
    ('Profil', Icons.person_outline_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: _maxTextScale,
      child: _bar(),
    );
  }

  Widget _bar() {
    return Container(
      decoration: const BoxDecoration(
        color: AdminColors.surface,
        border: Border(top: BorderSide(color: AdminColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (var i = 0; i < _items.length; i++)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: i == currentIndex,
                  label: _items[i].$1,
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: () => onTap(i),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 64),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _items[i].$2,
                              size: 24,
                              color: i == currentIndex
                                  ? AdminColors.navy
                                  : AdminColors.textGrey,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _items[i].$1,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: i == currentIndex
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: i == currentIndex
                                    ? AdminColors.navy
                                    : AdminColors.textGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Dua tombol aksi di dasar layar detail: tolak (merah, garis) dan setujui (navy).
class AdminDecisionBar extends StatelessWidget {
  final String rejectLabel;
  final String approveLabel;
  final VoidCallback onReject;
  final VoidCallback onApprove;

  const AdminDecisionBar({
    super.key,
    required this.rejectLabel,
    required this.approveLabel,
    required this.onReject,
    required this.onApprove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AdminColors.surface,
        border: Border(top: BorderSide(color: AdminColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onReject,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: AdminColors.danger,
                  side: const BorderSide(color: AdminColors.danger),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text(rejectLabel, textAlign: TextAlign.center),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: onApprove,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: AdminColors.navy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text(approveLabel, textAlign: TextAlign.center),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Satu baris label dan nilai pada kartu detail.
class AdminInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const AdminInfoRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: AdminColors.textGrey),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class AdminSectionTitle extends StatelessWidget {
  final String text;

  const AdminSectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
