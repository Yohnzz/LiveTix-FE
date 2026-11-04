import 'package:flutter/material.dart';

/// Stub implementasi CameraFeedWidget untuk platform VM dan unit testing.
class CameraFeedWidget extends StatefulWidget {
  final bool isTorchOn;
  final bool isFrontCamera;
  final VoidCallback? onCameraReady;
  final ValueChanged<String>? onCameraError;

  const CameraFeedWidget({
    super.key,
    this.isTorchOn = false,
    this.isFrontCamera = false,
    this.onCameraReady,
    this.onCameraError,
  });

  @override
  State<CameraFeedWidget> createState() => _CameraFeedWidgetState();
}

class _CameraFeedWidgetState extends State<CameraFeedWidget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onCameraReady?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0B1120),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF1E293B),
                  widget.isTorchOn ? const Color(0xFF334155) : const Color(0xFF0F172A),
                ],
                radius: 0.8,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Image.asset(
              'assets/images/qrcode.png',
              width: 140,
              height: 140,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.qr_code_2_rounded,
                size: 140,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
