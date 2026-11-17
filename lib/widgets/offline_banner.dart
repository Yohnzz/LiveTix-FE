import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../services/network_status_service.dart';

/// Banner peringatan yang muncul otomatis saat perangkat tidak dapat
/// terhubung ke server LiveTix, lengkap dengan tombol "Coba Lagi".
class OfflineBanner extends StatefulWidget {
  final VoidCallback? onRetry;
  final EdgeInsetsGeometry margin;

  const OfflineBanner({
    super.key,
    this.onRetry,
    this.margin = const EdgeInsets.only(bottom: 16),
  });

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  bool _retrying = false;

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    await NetworkStatusService().checkConnection();
    if (!mounted) return;
    setState(() => _retrying = false);
    widget.onRetry?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return ValueListenableBuilder<bool?>(
      valueListenable: NetworkStatusService().isOnlineNotifier,
      builder: (context, online, _) {
        if (online != false) return const SizedBox.shrink();

        final bg = isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2);
        final border =
            isDark ? const Color(0xFF991B1B) : const Color(0xFFFECACA);
        final fg = isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C);

        return Container(
          key: const Key('offline_banner'),
          margin: widget.margin,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              Icon(Icons.wifi_off_rounded, size: 18, color: fg),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              TextButton(
                key: const Key('offline_banner_retry_btn'),
                onPressed: _retrying ? null : _retry,
                style: TextButton.styleFrom(
                  foregroundColor: fg,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: _retrying
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(fg),
                        ),
                      )
                    : const Text(
                        'Coba Lagi',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
