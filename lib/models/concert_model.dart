import 'dart:typed_data';
import 'package:flutter/material.dart';

class TicketTierModel {
  final String id;
  final String name;
  final String description;
  final int price;
  final bool isSoldOut;

  const TicketTierModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.isSoldOut = false,
  });

  String get formattedPrice {
    final buffer = StringBuffer('Rp');
    final str = price.toString();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }
}

class CityModel {
  final String name;
  final int eventCount;
  final Color bgColor;
  final Color textColor;

  const CityModel({
    required this.name,
    this.eventCount = 0,
    required this.bgColor,
    required this.textColor,
  });
}

class ConcertModel {
  final String id;
  final String title;
  final String subtitle;
  final String date;
  final String time;
  final String venue;
  final int price;
  final String category;
  final String tag;
  final Color badgeColor;
  final Color iconBgColor;
  final Color iconColor;
  final List<TicketTierModel> ticketTiers;

  /// Media unggahan Produser:
  /// 1. Gambar Highlight Persegi Panjang (landscape) untuk Carousel Beranda & Header Detail Konser
  final String? bannerImageUrl;
  final Uint8List? bannerImageBytes;

  /// 2. Gambar Logo/Thumbnail Persegi (1:1) untuk kartu list konser di Beranda & Jelajah
  final String? logoImageUrl;
  final Uint8List? logoImageBytes;

  /// Warna gradien banner highlight persegi panjang saat produser belum mengunggah foto
  final List<Color> highlightGradientColors;

  const ConcertModel({
    required this.id,
    required this.title,
    this.subtitle = '',
    required this.date,
    this.time = '',
    required this.venue,
    required this.price,
    required this.category,
    this.tag = 'Festival • 17+',
    this.badgeColor = const Color(0xFFF7EEF8),
    this.iconBgColor = const Color(0xFFF7EEF8),
    this.iconColor = const Color(0xFFC2185B),
    this.ticketTiers = const [],
    this.bannerImageUrl,
    this.bannerImageBytes,
    this.logoImageUrl,
    this.logoImageBytes,
    this.highlightGradientColors = const [Color(0xFF271C80), Color(0xFF971C91)],
  });

  ConcertModel copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? date,
    String? time,
    String? venue,
    int? price,
    String? category,
    String? tag,
    Color? badgeColor,
    Color? iconBgColor,
    Color? iconColor,
    List<TicketTierModel>? ticketTiers,
    String? bannerImageUrl,
    Uint8List? bannerImageBytes,
    bool clearBannerImage = false,
    String? logoImageUrl,
    Uint8List? logoImageBytes,
    bool clearLogoImage = false,
    List<Color>? highlightGradientColors,
  }) {
    return ConcertModel(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      date: date ?? this.date,
      time: time ?? this.time,
      venue: venue ?? this.venue,
      price: price ?? this.price,
      category: category ?? this.category,
      tag: tag ?? this.tag,
      badgeColor: badgeColor ?? this.badgeColor,
      iconBgColor: iconBgColor ?? this.iconBgColor,
      iconColor: iconColor ?? this.iconColor,
      ticketTiers: ticketTiers ?? this.ticketTiers,
      bannerImageUrl:
          clearBannerImage ? null : (bannerImageUrl ?? this.bannerImageUrl),
      bannerImageBytes:
          clearBannerImage ? null : (bannerImageBytes ?? this.bannerImageBytes),
      logoImageUrl: clearLogoImage ? null : (logoImageUrl ?? this.logoImageUrl),
      logoImageBytes:
          clearLogoImage ? null : (logoImageBytes ?? this.logoImageBytes),
      highlightGradientColors:
          highlightGradientColors ?? this.highlightGradientColors,
    );
  }

  String get formattedPrice {
    final buffer = StringBuffer('Rp');
    final str = price.toString();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  String get formattedPriceShort {
    if (price >= 1000) {
      final rb = (price / 1000).round();
      return 'Rp${rb}rb';
    }
    return formattedPrice;
  }

  static const Map<String, int> _monthMap = {
    'januari': 1,
    'jan': 1,
    'februari': 2,
    'feb': 2,
    'maret': 3,
    'mar': 3,
    'april': 4,
    'apr': 4,
    'mei': 5,
    'juni': 6,
    'jun': 6,
    'juli': 7,
    'jul': 7,
    'agustus': 8,
    'agu': 8,
    'ags': 8,
    'september': 9,
    'sep': 9,
    'oktober': 10,
    'okt': 10,
    'november': 11,
    'nov': 11,
    'desember': 12,
    'des': 12,
  };

  static const List<String> _shortMonthNames = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  DateTime? get parsedDate {
    final cleaned = date.contains(',') ? date.split(',').last.trim() : date.trim();
    final parts = cleaned.split(RegExp(r'\s+'));
    if (parts.length < 3) return null;
    final day = int.tryParse(parts[0]);
    final month = _monthMap[parts[1].toLowerCase()];
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    return DateTime(year, month, day);
  }

  String get shortDate {
    final dt = parsedDate;
    if (dt == null) return date;
    return '${dt.day} ${_shortMonthNames[dt.month]} ${dt.year}';
  }
}
