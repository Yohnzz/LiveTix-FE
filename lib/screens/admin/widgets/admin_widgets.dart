import 'package:flutter/material.dart';
import '../../../models/approval_models.dart';
import 'admin_theme.dart';

/// Header, tab, dan bottom nav adalah chrome tetap. Skala teksnya dibatasi agar
/// area daftar di bawahnya tetap punya ruang, isi halaman sendiri tetap ikut skala penuh.
const double _maxTextScale = 1.3;

/// Header seluruh halaman Admin yang disamakan desainnya dengan header Beranda:
/// gradien biru-indigo, sudut bawah membulat 24px, lingkaran dekoratif halus,
/// lencana kecil opsional (eyebrow), tombol kembali kontekstual, dan aksi kanan.
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
        decoration: BoxDecoration(
          gradient: AdminColors.gradient,
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1B2A8C).withValues(alpha: 0.22),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -28,
              top: -20,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              right: 48,
              bottom: -36,
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, top + 18, 20, 22),
              child: _content(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (onBack != null) ...[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.24),
              ),
            ),
            child: IconButton(
              onPressed: onBack,
              tooltip: 'Kembali',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 42, minHeight: 42),
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 14),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null && eyebrow!.trim().isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF4ADE80),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          eyebrow!,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.2,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.white.withValues(alpha: 0.85),
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
    final isDark = AdminColors.isDark(context);
    final (Color bg, Color fg) = switch (status) {
      ApprovalStatus.pending => (
          AdminColors.warningBgOf(context),
          AdminColors.warningOf(context),
        ),
      ApprovalStatus.approved => (
          AdminColors.successBgOf(context),
          isDark ? const Color(0xFF86EFAC) : const Color(0xFF166534),
        ),
      ApprovalStatus.rejected => (
          AdminColors.dangerBgOf(context),
          isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
        ),
      ApprovalStatus.deactivated => (
          AdminColors.dangerBgOf(context),
          isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
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
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: fg),
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
    final isDark = AdminColors.isDark(context);
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: _maxTextScale,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AdminColors.avatarBgOf(context),
          shape: BoxShape.circle,
        ),
        child: ExcludeSemantics(
          child: Text(
            initials,
            style: TextStyle(
              fontSize: size * 0.32,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AdminColors.navy,
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
    final radius = BorderRadius.circular(18);
    final isDark = AdminColors.isDark(context);
    final resolvedSurface = color ?? AdminColors.surfaceOf(context);
    final resolvedBorder = borderColor ?? AdminColors.borderOf(context);

    final card = Container(
      decoration: BoxDecoration(
        color: resolvedSurface,
        borderRadius: radius,
        border: Border.all(color: resolvedBorder),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? Padding(padding: padding, child: child)
            : InkWell(
                onTap: onTap,
                child: Padding(padding: padding, child: child),
              ),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: CircularProgressIndicator(
          color: AdminColors.accentOf(context),
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
    final textSec = AdminColors.textSecondaryOf(context);
    final accent = AdminColors.accentOf(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: accent),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AdminColors.textPrimaryOf(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: textSec),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  foregroundColor: accent,
                  side: BorderSide(color: accent),
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
  final int? badgeCount;

  const AdminTabItem(this.label, this.value, {this.badgeCount});
}

/// Baris tab dengan lencana angka opsional dan indikator modern.
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
      child: _bar(context),
    );
  }

  Widget _bar(BuildContext context) {
    final surface = AdminColors.surfaceOf(context);
    final border = AdminColors.borderOf(context);
    final accent = AdminColors.accentOf(context);
    final textSec = AdminColors.textSecondaryOf(context);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: surface,
        border: Border(
          bottom: BorderSide(color: border),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(
          children: [
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Semantics(
                  button: true,
                  selected: item.value == selected,
                  label: item.badgeCount != null && item.badgeCount! > 0
                      ? '${item.label} (${item.badgeCount})'
                      : item.label,
                  excludeSemantics: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => onChanged(item.value),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      constraints:
                          const BoxConstraints(minHeight: 40, minWidth: 44),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: item.value == selected
                            ? accent.withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: item.value == selected
                              ? accent.withValues(alpha: 0.32)
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: item.value == selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: item.value == selected ? accent : textSec,
                            ),
                          ),
                          if (item.badgeCount != null &&
                              item.badgeCount! > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: item.value == selected
                                    ? accent
                                    : const Color(0xFFEF4444),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${item.badgeCount}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
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
    ('Approval', Icons.verified_outlined),
    ('Kelola User', Icons.group_outlined),
    ('Profil', Icons.person_outline_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: _maxTextScale,
      child: _bar(context),
    );
  }

  Widget _bar(BuildContext context) {
    final surface = AdminColors.surfaceOf(context);
    final border = AdminColors.borderOf(context);
    final accent = AdminColors.accentOf(context);
    final textSec = AdminColors.textSecondaryOf(context);

    return Container(
      decoration: BoxDecoration(
        color: surface,
        border: Border(top: BorderSide(color: border)),
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
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: i == currentIndex
                                    ? accent.withValues(alpha: 0.14)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Icon(
                                _items[i].$2,
                                size: 22,
                                color: i == currentIndex ? accent : textSec,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _items[i].$1,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: i == currentIndex
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: i == currentIndex ? accent : textSec,
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
    final dangerCol = AdminColors.dangerOf(context);
    return Container(
      decoration: BoxDecoration(
        color: AdminColors.surfaceOf(context),
        border: Border(top: BorderSide(color: AdminColors.borderOf(context))),
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
                  foregroundColor: dangerCol,
                  side: BorderSide(color: dangerCol),
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
                  backgroundColor: AdminColors.primaryButtonBgOf(context),
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
              style: TextStyle(
                fontSize: 13,
                color: AdminColors.textSecondaryOf(context),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
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
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AdminColors.textPrimaryOf(context),
          ),
        ),
      ),
    );
  }
}
