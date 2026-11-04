import 'package:flutter/material.dart';
import '../models/concert_model.dart';
import '../models/ticket_order_model.dart';
import '../models/user_model.dart';
import 'data_service.dart';

/// Adapter kompatibilitas ke DataService.
/// Memastikan seluruh layar yang mengimpor DummyDataService tetap berjalan mulus
/// sambil mengonsumsi data terpusat dari DataService dan DbDummy.
class DummyDataService {
  static final DummyDataService _instance = DummyDataService._internal();
  factory DummyDataService() => _instance;
  DummyDataService._internal();

  final DataService _dataService = DataService();

  ValueNotifier<UserModel?> get currentUserNotifier => _dataService.currentUserNotifier;
  ValueNotifier<List<UserTicketModel>> get userTicketsNotifier => _dataService.userTicketsNotifier;

  UserModel? login(String email, String password) {
    return _dataService.loginSync(email, password);
  }

  UserModel register({
    required String name,
    required String email,
    required String phone,
    required String password,
    String role = 'User',
  }) {
    return _dataService.registerSync(
      name: name,
      email: email,
      phone: phone,
      password: password,
      role: role,
    );
  }

  void logout() {
    _dataService.logout();
  }

  List<ConcertModel> getConcerts() {
    return _dataService.rawConcerts;
  }

  void submitOrder(OrderModel order) {
    _dataService.submitOrder(order);
  }

  void addPurchasedTicket(UserTicketModel ticket) {
    _dataService.addPurchasedTicket(ticket);
  }

  UserTicketModel completeOrderPayment(OrderModel order) {
    return _dataService.completeOrderPayment(order);
  }

  RefundModel submitRefund({
    required String ticketId,
    required String methodType,
    required String providerName,
    required String accountHolderName,
    required String accountNumber,
  }) {
    final tickets = List<UserTicketModel>.from(userTicketsNotifier.value);
    final index = tickets.indexWhere((t) => t.id == ticketId);

    final refundId =
        'RFD-${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}-0042';
    final maskAccount = accountNumber.length >= 4
        ? '••${accountNumber.substring(accountNumber.length - 4)}'
        : '••$accountNumber';

    final ticket = index != -1 ? tickets[index] : null;
    final totalAmount = ticket?.totalPrice ?? 1006500;
    final concertTitle = ticket?.concertTitle ?? 'Soundwave Fest 2026';

    final refund = RefundModel(
      refundId: refundId,
      ticketId: ticketId,
      concertTitle: concertTitle,
      totalAmount: totalAmount,
      methodType: methodType,
      providerName: providerName,
      accountHolderName: accountHolderName,
      accountNumber: accountNumber,
      status: 'Sedang diproses',
      requestedAt: '19 Okt 2026, 14:02',
      verifiedAt: '19 Okt 2026, 16:30',
      maskAccount: maskAccount,
    );

    if (index != -1) {
      tickets[index] = tickets[index].copyWith(
        status: 'Refund Diproses',
        refundData: refund,
      );
      userTicketsNotifier.value = tickets;
    }

    return refund;
  }
}
