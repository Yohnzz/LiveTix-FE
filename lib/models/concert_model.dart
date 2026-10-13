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
    required this.eventCount,
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

  String get formattedPriceShort {
    if (price >= 1000) {
      final rb = (price / 1000).round();
      return 'Rp${rb}rb';
    }
    return formattedPrice;
  }
}
