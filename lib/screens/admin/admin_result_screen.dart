import 'package:flutter/material.dart';
import '../../models/approval_models.dart';
import '../../services/admin_service.dart';
import 'admin_concert_detail_screen.dart';
import 'admin_producer_detail_screen.dart';
import 'admin_shell.dart';
import 'widgets/admin_theme.dart';
import 'widgets/admin_widgets.dart';

/// Dialog konfirmasi sebelum menyetujui. Bisa ditutup dengan Escape atau Batal.
Future<bool> showApproveConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      content: Text(message, style: const TextStyle(fontSize: 14)),
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
            backgroundColor: AdminColors.navy,
          ),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Layar hasil keputusan: header ungu untuk disetujui, merah untuk ditolak (Image 1).
class AdminResultScreen extends StatelessWidget {
  final ApprovalKind kind;
  final bool approved;
  final String title;
  final String message;
  final List<(String, String)> rows;
  final String? reason;
  final String? itemId;
  final DateTime? decidedAt;
  final String? topTitle;
  final String? finishLabel;

  const AdminResultScreen({
    super.key,
    required this.kind,
    required this.approved,
    required this.title,
    required this.message,
    required this.rows,
    this.reason,
    this.itemId,
    this.decidedAt,
    this.topTitle,
    this.finishLabel,
  });

  void _finish(BuildContext context) {
    Navigator.of(context).popUntil(
      (route) => route.isFirst || route.settings.name == AdminShell.routeName,
    );
    AdminNavigation.openApproval(kind);
  }

  void _backToHome(BuildContext context) {
    Navigator.of(context).popUntil(
      (route) => route.isFirst || route.settings.name == AdminShell.routeName,
    );
    AdminNavigation.openTab(0);
  }

  void _viewDetail(BuildContext context) {
    String? id = itemId;
    if (id == null || id.isEmpty) {
      if (rows.isNotEmpty) {
        final name = rows.first.$2;
        final found = AdminService()
            .producersNotifier
            .value
            .where((p) => p.companyName == name)
            .firstOrNull;
        if (found != null) id = found.id;
      }
    }
    if (id == null || id.isEmpty) return;
    final Widget screen = kind == ApprovalKind.producer
        ? AdminProducerDetailScreen(producerId: id)
        : AdminConcertDetailScreen(concertId: id);
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return AdminScope(
      child: Builder(
        builder: (context) => PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _finish(context);
          },
          child: Scaffold(
            backgroundColor: AdminColors.bgOf(context),
            body: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Header gradien atas
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: approved
                                ? AdminColors.gradient
                                : AdminColors.dangerGradient,
                          ),
                          padding: EdgeInsets.fromLTRB(24, top + 24, 24, 32),
                          child: Column(
                            children: [
                              if (approved) ...[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.star_rounded,
                                        size: 14, color: Color(0xFFFBBF24)),
                                    const SizedBox(width: 6),
                                    Text(
                                      topTitle ?? 'Approval Sukses',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(Icons.star_rounded,
                                        size: 14, color: Color(0xFFFBBF24)),
                                  ],
                                ),
                                const SizedBox(height: 20),
                              ] else ...[
                                Text(
                                  topTitle ?? 'Approval Ditolak',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],
                              Container(
                                width: approved ? 76 : 68,
                                height: approved ? 76 : 68,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0x2A000000),
                                      blurRadius: 10,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  approved
                                      ? Icons.check_rounded
                                      : Icons.arrow_back_rounded,
                                  color: approved
                                      ? const Color(0xFF1E3A8A)
                                      : const Color(0xFFDC2626),
                                  size: approved ? 40 : 32,
                                  semanticLabel:
                                      approved ? 'Disetujui' : 'Ditolak',
                                ),
                              ),
                              const SizedBox(height: 16),
                              Semantics(
                                header: true,
                                child: Text(
                                  title,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              if (message.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  message,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white.withValues(alpha: 0.92),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Kartu Rincian Keputusan
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                          child: !approved
                              ? _buildRejectionCard(context)
                              : _buildApprovalCard(context),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bar tombol navigasi bawah
                _buildBottomActions(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRejectionCard(BuildContext context) {
    final itemName = rows.isNotEmpty ? rows.first.$2 : '-';
    final labelName =
        kind == ApprovalKind.producer ? 'Nama Produser' : 'Nama Konser';
    final dateText =
        ApprovalFormat.dayFullMonthYear(decidedAt ?? DateTime(2026, 10, 24));
    final reasonText = (reason != null && reason!.isNotEmpty)
        ? reason!
        : 'Dokumen legalitas tidak lengkap. Silakan lengkapi dan ajukan kembali.';
    final textPri = AdminColors.textPrimaryOf(context);
    final textSec = AdminColors.textSecondaryOf(context);
    final border = AdminColors.borderOf(context);

    return AdminCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            labelName,
            style: TextStyle(fontSize: 12, color: textSec),
          ),
          const SizedBox(height: 4),
          Text(
            itemName,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: textPri,
            ),
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: border),
          const SizedBox(height: 14),
          Text(
            'Tanggal Penolakan',
            style: TextStyle(fontSize: 12, color: textSec),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  dateText,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textPri,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AdminColors.dangerBgOf(context),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Ditolak',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AdminColors.dangerOf(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: border),
          const SizedBox(height: 14),
          Text(
            'Alasan Penolakan',
            style: TextStyle(fontSize: 12, color: textSec),
          ),
          const SizedBox(height: 4),
          Text(
            reasonText,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: textPri,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalCard(BuildContext context) {
    final itemName = rows.isNotEmpty ? rows.first.$2 : '-';
    final dateText =
        ApprovalFormat.dayFullMonthYear(decidedAt ?? DateTime(2026, 10, 24));
    final textPri = AdminColors.textPrimaryOf(context);
    final textSec = AdminColors.textSecondaryOf(context);
    final border = AdminColors.borderOf(context);

    return AdminCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            kind == ApprovalKind.producer ? 'Nama Produser' : 'Nama Konser',
            style: TextStyle(fontSize: 12, color: textSec),
          ),
          const SizedBox(height: 4),
          Text(
            itemName,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: textPri,
            ),
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: border),
          const SizedBox(height: 14),
          Text(
            'Tanggal Approval',
            style: TextStyle(fontSize: 12, color: textSec),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  dateText,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textPri,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AdminColors.successBgOf(context),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Terverifikasi',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AdminColors.successOf(context),
                  ),
                ),
              ),
            ],
          ),
          if (kind == ApprovalKind.producer) ...[
            const SizedBox(height: 14),
            Divider(height: 1, color: border),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Suka dengan produser ini?',
                    style: TextStyle(
                      fontSize: 13,
                      color: textSec,
                    ),
                  ),
                ),
                const _FavoriteButton(),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomActions(BuildContext context) {
    final effectiveFinishLabel = finishLabel ?? 'Kembali ke Beranda';
    final accent = AdminColors.accentOf(context);
    return Container(
      decoration: BoxDecoration(
        color: AdminColors.surfaceOf(context),
        border: Border(top: BorderSide(color: AdminColors.borderOf(context))),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton(
              onPressed: () => _viewDetail(context),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: accent,
                side: BorderSide(color: accent, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Lihat Detail'),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: () {
                if (effectiveFinishLabel == 'Kembali ke Approval') {
                  _finish(context);
                } else {
                  _backToHome(context);
                }
              },
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: AdminColors.primaryButtonBgOf(context),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(effectiveFinishLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoriteButton extends StatefulWidget {
  const _FavoriteButton();

  @override
  State<_FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<_FavoriteButton> {
  bool _isFavorite = false;

  @override
  Widget build(BuildContext context) {
    final pink = AdminColors.pinkAccentOf(context);
    return InkWell(
      onTap: () => setState(() => _isFavorite = !_isFavorite),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: _isFavorite ? pink.withValues(alpha: 0.14) : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: pink,
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Icon(
          _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: pink,
          size: 18,
        ),
      ),
    );
  }
}
