// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

final Set<String> _registeredViewIds = <String>{};
final Map<String, html.IFrameElement> _iframeMap =
    <String, html.IFrameElement>{};

/// Implementasi nyata Google Maps Embed via HtmlElementView & IFrameElement di Flutter Web.
Widget buildPlatformMapEmbed({
  required String viewId,
  required String mapUrl,
  required double width,
  required double height,
}) {
  if (!_registeredViewIds.contains(viewId)) {
    _registeredViewIds.add(viewId);
    ui_web.platformViewRegistry.registerViewFactory(
      viewId,
      (int id) {
        final iframe = html.IFrameElement()
          ..src = mapUrl
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.borderRadius = '14px'
          ..allowFullscreen = true;
        _iframeMap[viewId] = iframe;
        return iframe;
      },
    );
  } else {
    final existing = _iframeMap[viewId];
    if (existing != null && existing.src != mapUrl) {
      existing.src = mapUrl;
    }
  }

  return HtmlElementView(viewType: viewId);
}

/// Membuka tautan Google Maps di tab baru peramban web.
void openExternalMapUrl(String url) {
  html.window.open(url, '_blank');
}
