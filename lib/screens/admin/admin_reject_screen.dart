import 'package:flutter/material.dart';
import '../../models/approval_models.dart';
import '../../services/admin_service.dart';
import 'admin_result_screen.dart';
import 'widgets/admin_theme.dart';
import 'widgets/admin_widgets.dart';

/// Form alasan penolakan untuk produser maupun konser.
class AdminRejectScreen extends StatefulWidget {
  final ApprovalKind kind;
  final String itemId;

  const AdminRejectScreen(
      {super.key, required this.kind, required this.itemId});

  @override
  State<AdminRejectScreen> createState() => _AdminRejectScreenState();
}

class _AdminRejectScreenState extends State<AdminRejectScreen> {
  static const int _minLength = 10;
  static const int _maxLength = 300;

  final AdminService _service = AdminService();
  final TextEditingController _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  bool get _isValid => _reason.text.trim().length >= _minLength;

  bool get _isProducer => widget.kind == ApprovalKind.producer;

  void _submit() {
    if (!_isValid) return;
    final reason = _reason.text.trim();
    final Widget? result;
    if (_isProducer) {
      final updated = _service.rejectProducer(widget.itemId, reason);
      result = updated == null
          ? null
          : AdminResultScreen(
              kind: ApprovalKind.producer,
              approved: false,
              title: 'Pengajuan Ditolak',
              message:
                  '${updated.companyName} tidak disetujui sebagai produser.',
              rows: [
                ('Produser', updated.companyName),
                ('Email', updated.email),
                ('Status', updated.approvalStatus.label),
              ],
              reason: reason,
            );
    } else {
      final updated = _service.rejectConcert(widget.itemId, reason);
      result = updated == null
          ? null
          : AdminResultScreen(
              kind: ApprovalKind.concert,
              approved: false,
              title: 'Pengajuan Ditolak',
              message: '${updated.title} tidak disetujui untuk tayang.',
              rows: [
                ('Konser', updated.title),
                ('Produser', updated.promoterName),
                ('Status', updated.approvalStatus.label),
              ],
              reason: reason,
            );
    }

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Pengajuan ini sudah diputuskan sebelumnya.')),
      );
      Navigator.of(context).pop();
      return;
    }
    final Widget screen = result;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String name;
    final Widget leading;
    final String caption;
    if (_isProducer) {
      final item = _service.producerById(widget.itemId);
      name = item?.companyName ?? 'Pengajuan tidak ditemukan';
      leading = InitialAvatar(initials: item?.initials ?? '?');
      caption = item?.email ?? '';
    } else {
      final item = _service.concertById(widget.itemId);
      name = item?.title ?? 'Pengajuan tidak ditemukan';
      leading =
          PosterThumb(url: item?.bannerUrl, width: 44, height: 44, radius: 10);
      caption = item?.promoterName ?? '';
    }

    return AdminScope(
      child: Builder(
        builder: (context) {
          final textPri = AdminColors.textPrimaryOf(context);
          final textSec = AdminColors.textSecondaryOf(context);
          final surface = AdminColors.surfaceOf(context);
          final border = AdminColors.borderOf(context);
          final accent = AdminColors.accentOf(context);
          return Scaffold(
            backgroundColor: AdminColors.bgOf(context),
            body: Column(
              children: [
                AdminHeader(
                  title: _isProducer ? 'Tolak Produser' : 'Tolak Konser',
                  subtitle: 'Tulis alasan penolakan',
                  onBack: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    children: [
                      AdminCard(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            leading,
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: textPri,
                                    ),
                                  ),
                                  if (caption.isNotEmpty)
                                    Text(
                                      caption,
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
                      ),
                      const SizedBox(height: 20),
                      const AdminSectionTitle('Alasan penolakan'),
                      ListenableBuilder(
                        listenable: _reason,
                        builder: (context, _) {
                          final length = _reason.text.trim().length;
                          final tooShort = length > 0 && length < _minLength;
                          return TextField(
                            controller: _reason,
                            minLines: 5,
                            maxLines: 8,
                            maxLength: _maxLength,
                            keyboardType: TextInputType.multiline,
                            textCapitalization: TextCapitalization.sentences,
                            style: TextStyle(fontSize: 14, color: textPri),
                            decoration: InputDecoration(
                              hintText: _isProducer
                                  ? 'Contoh: data rekening tidak sesuai dengan nama perusahaan.'
                                  : 'Contoh: izin keramaian belum dilampirkan.',
                              hintStyle: TextStyle(
                                fontSize: 13,
                                color: AdminColors.textMutedOf(context),
                              ),
                              helperText: 'Minimal $_minLength karakter',
                              helperStyle: TextStyle(color: textSec),
                              errorText:
                                  tooShort ? 'Alasan terlalu singkat' : null,
                              filled: true,
                              fillColor: surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: accent,
                                  width: 1.6,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: surface,
                    border: Border(top: BorderSide(color: border)),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: SafeArea(
                    top: false,
                    child: ListenableBuilder(
                      listenable: _reason,
                      builder: (context, _) => FilledButton(
                        onPressed: _isValid ? _submit : null,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor: AdminColors.danger,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              AdminColors.disabledBgOf(context),
                          disabledForegroundColor:
                              AdminColors.disabledFgOf(context),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: const Text('Konfirmasi Penolakan'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
