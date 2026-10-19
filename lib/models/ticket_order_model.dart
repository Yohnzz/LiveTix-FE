import 'package:flutter/material.dart';
import 'concert_model.dart';

class RefundModel {
  final String refundId;
  final String ticketId;
  final String concertTitle;
  final int totalAmount;
  final String methodType; // 'Bank' atau 'E-wallet'
  final String providerName; // 'BCA', 'Mandiri', 'BNI', 'BRI', 'GoPay', 'OVO', 'DANA', 'ShopeePay'
  final String accountHolderName;
  final String accountNumber;
  final String status; // 'Sedang diproses', 'Refund selesai'
  final String requestedAt;
  final String verifiedAt;
  final String maskAccount;

  const RefundModel({
    required this.refundId,
    required this.ticketId,
    required this.concertTitle,
    required this.totalAmount,
    required this.methodType,
    required this.providerName,
    required this.accountHolderName,
    required this.accountNumber,
    this.status = 'Sedang diproses',
    this.requestedAt = '19 Okt 2026, 14:02',
    this.verifiedAt = '19 Okt 2026, 16:30',
    required this.maskAccount,
  });

  String get formattedTotal {
    final buffer = StringBuffer('Rp');
    final str = totalAmount.toString();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }
}

class UserTicketModel {
  final String id;
  final String bookingCode;
  final String concertTitle;
  final String concertSubtitle;
  final String category;
  final String date;
  final String time;
  final String gate;
  final String block;
  final String venue;
  final int quantity;
  final int totalPrice;
  final String status; // 'Aktif', 'Reffund', 'Selesai', 'Refund Diproses'
  final bool isCompleted;
  final bool isCancelled;
  final int daysLeft;
  final bool hasStar;
  final Color? stripeColor;
  final Color? iconBgColor;
  final Color? iconColor;
  final RefundModel? refundData;

  const UserTicketModel({
    required this.id,
    required this.bookingCode,
    required this.concertTitle,
    required this.concertSubtitle,
    required this.category,
    required this.date,
    required this.time,
    required this.gate,
    required this.block,
    required this.venue,
    required this.quantity,
    required this.totalPrice,
    this.status = 'Aktif',
    this.isCompleted = false,
    this.isCancelled = false,
    this.daysLeft = 26,
    this.hasStar = false,
    this.stripeColor,
    this.iconBgColor,
    this.iconColor,
    this.refundData,
  });

  UserTicketModel copyWith({
    String? status,
    bool? isCancelled,
    RefundModel? refundData,
  }) {
    return UserTicketModel(
      id: id,
      bookingCode: bookingCode,
      concertTitle: concertTitle,
      concertSubtitle: concertSubtitle,
      category: category,
      date: date,
      time: time,
      gate: gate,
      block: block,
      venue: venue,
      quantity: quantity,
      totalPrice: totalPrice,
      status: status ?? this.status,
      isCompleted: isCompleted,
      isCancelled: isCancelled ?? this.isCancelled,
      daysLeft: daysLeft,
      hasStar: hasStar,
      stripeColor: stripeColor,
      iconBgColor: iconBgColor,
      iconColor: iconColor,
      refundData: refundData ?? this.refundData,
    );
  }

  String get formattedPrice {
    final buffer = StringBuffer('Rp');
    final str = totalPrice.toString();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }
}

class OrderModel {
  final String orderId;
  final ConcertModel concert;
  final TicketTierModel tier;
  final int quantity;
  final String customerName;
  final String customerEmail;
  final int ticketPrice;
  final int serviceFee;
  final int taxAndAdmin;
  final int totalAmount;
  final String paymentMethod;
  final String vaNumber;
  final String vaName;

  const OrderModel({
    required this.orderId,
    required this.concert,
    required this.tier,
    required this.quantity,
    required this.customerName,
    required this.customerEmail,
    required this.ticketPrice,
    this.serviceFee = 15000,
    required this.taxAndAdmin,
    required this.totalAmount,
    this.paymentMethod = 'BCA Virtual Account',
    this.vaNumber = '8808 1234 5678 9012',
    this.vaName = 'a.n. Soundwave Fest Official',
  });

  String formatCurrency(int amount) {
    final buffer = StringBuffer('Rp');
    final str = amount.toString();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }
}
