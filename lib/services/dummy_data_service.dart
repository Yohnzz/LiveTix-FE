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

  void _initData() {
    // 1. Data Akun Default
    const defaultUser = UserModel(
      name: 'Rafi Firmansyah',
      email: 'rafi@email.com',
      phone: '081234567890',
      password: '123456',
      role: 'User',
      ticketsBought: 12,
      concertsAttended: 9,
      reviewsCount: 4,
    );

    const produserDefault = UserModel(
      name: 'Rafi Firmansyah',
      email: 'produser@livetix.com',
      phone: '081234567890',
      password: 'produser123',
      role: 'Produser',
    );

    const producerUser = UserModel(
      name: 'Soundwave Productions',
      email: 'producer@soundwave.com',
      phone: '081399998888',
      password: 'producer123',
      role: 'Produser',
    );

    _users[defaultUser.email.toLowerCase()] = defaultUser;
    _users[produserDefault.email.toLowerCase()] = produserDefault;
    _users[producerUser.email.toLowerCase()] = producerUser;

    // 2. Data Tiket Awal Pengguna (Sesuai Desain Figma Tiket Saya)
    userTicketsNotifier.value = [
      const UserTicketModel(
        id: 'TKT-001',
        bookingCode: 'SWF-8891-2A',
        concertTitle: 'Soundwave Fest 2026',
        concertSubtitle: '12 Okt · Stadion Gajayana',
        category: 'Festival',
        date: '12 Okt 2026',
        time: '17.00 WIB',
        gate: 'Gate B',
        block: 'FEST-04',
        venue: 'Stadion Gajayana, Malang',
        quantity: 2,
        totalPrice: 1006500,
        status: 'Aktif',
        isCompleted: false,
        daysLeft: 26,
        hasStar: true,
        stripeColor: Color(0xFF1B2A8C),
        iconBgColor: Color(0xFFE0EAFF),
        iconColor: Color(0xFF1B2A8C),
      ),
      const UserTicketModel(
        id: 'TKT-002',
        bookingCode: 'NDN-3341-8X',
        concertTitle: 'Nadin Amizah Live',
        concertSubtitle: '20 Okt · Sasana Krida',
        category: 'Tribun',
        date: '20 Okt 2026',
        time: '19.30 WIB',
        gate: 'Gate A',
        block: 'TRI-02',
        venue: 'Sasana Krida, Malang',
        quantity: 1,
        totalPrice: 1006500,
        status: 'Reffund',
        isCompleted: false,
        isCancelled: true,
        daysLeft: 34,
        hasStar: false,
        stripeColor: Color(0xFFC2185B),
        iconBgColor: Color(0xFFFCE7F3),
        iconColor: Color(0xFFC2185B),
      ),
    ];

    // 3. Data Konser Lengkap
    _concerts.addAll([
      const ConcertModel(
        id: 'c1',
        title: 'Soundwave Fest 2026',
        subtitle: 'Panggung utama, 12 jam nonstop',
        date: 'Minggu, 12 Oktober 2026',
        time: 'Gerbang 17.00 · Mulai 19.00',
        venue: 'Stadion Gajayana, Malang',
        price: 350000,
        category: 'Pop',
        tag: 'Festival • 17+',
        iconBgColor: Color(0xFFF7EEF8),
        iconColor: Color(0xFFC2185B),
        ticketTiers: [
          TicketTierModel(
            id: 't-fest',
            name: 'Festival',
            description: 'Berdiri, area depan panggung',
            price: 350000,
          ),
          TicketTierModel(
            id: 't-tribun',
            name: 'Tribun',
            description: 'Tempat duduk bernomor',
            price: 220000,
          ),
          TicketTierModel(
            id: 't-vip',
            name: 'VIP Lounge',
            description: 'Sold out',
            price: 750000,
            isSoldOut: true,
          ),
        ],
      ),
      const ConcertModel(
        id: 'c2',
        title: 'Nadin Amizah',
        subtitle: 'Konser Selamat Ulang Tahun & Rayuan Perempuan Gila',
        date: '20 Okt',
        time: 'Gerbang 18.00 · Mulai 19.30',
        venue: 'Sasana Krida',
        price: 250000,
        category: 'Pop',
        tag: 'Konser Tunggal · Semua Umur',
        iconBgColor: Color(0xFFF7EEF8),
        iconColor: Color(0xFFC2185B),
        ticketTiers: [
          TicketTierModel(
            id: 'n1',
            name: 'Festival A',
            description: 'Berdiri depan panggung',
            price: 250000,
          ),
          TicketTierModel(
            id: 'n2',
            name: 'Tribun',
            description: 'Tempat duduk bebas',
            price: 175000,
          ),
        ],
      ),
      const ConcertModel(
        id: 'c3',
        title: 'Feast Live Session',
        subtitle: 'Tur Membangun & Menghancurkan Malang',
        date: '28 Okt',
        time: 'Gerbang 17.30 · Mulai 19.00',
        venue: 'Kayutangan',
        price: 180000,
        category: 'Rock',
        tag: 'Rock Session · 17+',
        iconBgColor: Color(0xFFE9EEF8),
        iconColor: Color(0xFF1B2A8C),
        ticketTiers: [
          TicketTierModel(
            id: 'f1',
            name: 'General Admission',
            description: 'Akses seluruh arena',
            price: 180000,
          ),
        ],
      ),
    ]);
  }
  final DataService _dataService = DataService();

  ValueNotifier<UserModel?> get currentUserNotifier => _dataService.currentUserNotifier;
  ValueNotifier<List<UserTicketModel>> get userTicketsNotifier => _dataService.userTicketsNotifier;

  UserModel? login(String email, String password) {
    final user = _users[email.trim().toLowerCase()];
    if (user != null && user.password == password) {
      currentUserNotifier.value = user;
      return user;
    }
    // Jika belum terdaftar, buat akun dinamis agar pengguna mudah mencoba
    final lowerEmail = email.trim().toLowerCase();
    final isProducer = lowerEmail.contains('produser') ||
        lowerEmail.contains('producer') ||
        lowerEmail.contains('promotor') ||
        lowerEmail.contains('promoter');

    final newUser = UserModel(
      name: email.split('@').first.replaceFirst(
            email[0],
            email[0].toUpperCase(),
          ),
      email: email.trim(),
      phone: '08123456789',
      password: password,
      role: isProducer ? 'Produser' : 'User',
    );
    _users[email.trim().toLowerCase()] = newUser;
    currentUserNotifier.value = newUser;
    return newUser;
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
