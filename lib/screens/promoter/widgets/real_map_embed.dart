import 'package:flutter/material.dart';
import 'real_map_embed_stub.dart'
    if (dart.library.html) 'real_map_embed_web.dart';

Widget getRealMapEmbed({
  required String viewId,
  required String mapUrl,
  required double width,
  required double height,
}) {
  return buildPlatformMapEmbed(
    viewId: viewId,
    mapUrl: mapUrl,
    width: width,
    height: height,
  );
}

void openGoogleMapsUrl(String url) {
  openExternalMapUrl(url);
}
