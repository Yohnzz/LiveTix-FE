// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

/// Implementasi CameraFeedWidget menggunakan WebRTC getUserMedia untuk Flutter Web.
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
  static int _viewIdCounter = 0;
  late final String _viewType;
  html.VideoElement? _videoElement;
  html.MediaStream? _mediaStream;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _viewType = 'gate-crew-camera-view-${++_viewIdCounter}';
    _registerViewFactory();
    _startCamera();
  }

  void _registerViewFactory() {
    _videoElement = html.VideoElement()
      ..autoplay = true
      ..muted = true
      ..setAttribute('playsinline', 'true')
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'cover'
      ..style.border = 'none';

    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _videoElement!,
    );
  }

  Future<void> _startCamera() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final facingMode = widget.isFrontCamera ? 'user' : 'environment';
      final constraints = {
        'video': {
          'facingMode': facingMode,
          'width': {'ideal': 1280},
          'height': {'ideal': 720},
        },
        'audio': false,
      };

      final stream = await html.window.navigator.mediaDevices?.getUserMedia(constraints);
      if (!mounted) {
        stream?.getTracks().forEach((track) => track.stop());
        return;
      }

      _mediaStream = stream;
      if (_videoElement != null && stream != null) {
        _videoElement!.srcObject = stream;
        await _videoElement!.play();
      }

      _applyTorch(widget.isTorchOn);

      setState(() {
        _isLoading = false;
      });
      widget.onCameraReady?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Akses kamera tidak diizinkan atau perangkat kamera tidak ditemukan';
      });
      widget.onCameraError?.call(_errorMessage!);
    }
  }

  void _applyTorch(bool enable) {
    if (_mediaStream == null) return;
    try {
      final tracks = _mediaStream!.getVideoTracks();
      if (tracks.isNotEmpty) {
        final track = tracks.first;
        track.applyConstraints({
          'advanced': [
            {'torch': enable}
          ]
        });
      }
    } catch (_) {
      // Fitur senter fisik mungkin tidak didukung peramban/perangkat
    }
  }

  @override
  void didUpdateWidget(covariant CameraFeedWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFrontCamera != widget.isFrontCamera) {
      _stopCamera();
      _startCamera();
    } else if (oldWidget.isTorchOn != widget.isTorchOn) {
      _applyTorch(widget.isTorchOn);
    }
  }

  void _stopCamera() {
    _mediaStream?.getTracks().forEach((track) => track.stop());
    _mediaStream = null;
  }

  @override
  void dispose() {
    _stopCamera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Container(
        color: const Color(0xFF0F172A),
        padding: const EdgeInsets.all(16),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off_rounded, color: Color(0xFFEF4444), size: 36),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _startCamera,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B2A8C),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              child: const Text('Coba Lagi', style: TextStyle(fontSize: 12, color: Colors.white)),
            ),
          ],
        ),
      );
    }

    if (_isLoading) {
      return Container(
        color: const Color(0xFF0F172A),
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFFF59E0B)),
            ),
            SizedBox(height: 10),
            Text(
              'Menghubungkan kamera...',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return HtmlElementView(viewType: _viewType);
  }
}
