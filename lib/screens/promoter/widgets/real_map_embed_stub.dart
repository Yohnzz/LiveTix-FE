import 'package:flutter/material.dart';

/// Stub implementasi embed peta untuk lingkungan VM / flutter test.
Widget buildPlatformMapEmbed({
  required String viewId,
  required String mapUrl,
  required double width,
  required double height,
}) {
  return Container(
    width: width,
    height: height,
    color: const Color(0xFFE5E9F0),
    alignment: Alignment.center,
    child: const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.map_rounded, size: 36, color: Color(0xFF1B2A8C)),
        SizedBox(height: 8),
        Text(
          'Google Maps Embed (Pratinjau Aktif di Web)',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF475467),
          ),
        ),
      ],
    ),
  );
}

/// Stub untuk membuka URL Google Maps di peramban luar.
void openExternalMapUrl(String url) {
  // Stub pada lingkungan VM / pengujian.
}
