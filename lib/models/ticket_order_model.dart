import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'concert_model.dart';

enum PaymentCategory {
  qris,
  ewallet,
  bank,
}

class BankPaymentRule {
  final String code;
  final String displayName;
  final String methodTitle;
  final String badgeText;
  final Color badgeColor;
  final String vaPrefix;
  final String sampleSuffix;
  final String appName;
  final String ruleNote;
  final List<String> steps;

  const BankPaymentRule({
    required this.code,
    required this.displayName,
    required this.methodTitle,
    required this.badgeText,
    required this.badgeColor,
    required this.vaPrefix,
    required this.sampleSuffix,
    required this.appName,
    required this.ruleNote,
    required this.steps,
  });

  String buildVaNumber(String orderId) {
    final digits = orderId.replaceAll(RegExp(r'[^0-9]'), '');
    final tail = (digits.isEmpty ? sampleSuffix : digits.padRight(12, '4'))
        .substring(0, 12);
    return '$vaPrefix ${tail.substring(0, 4)} ${tail.substring(4, 8)} ${tail.substring(8, 12)}';
  }

  static const Map<String, BankPaymentRule> rules = {
    'BCA': BankPaymentRule(
      code: 'BCA',
      displayName: 'BCA Virtual Account',
      methodTitle: 'Virtual Account',
      badgeText: 'BCA',
      badgeColor: Color(0xFF005EAA),
      vaPrefix: '8808',
      sampleSuffix: '123456789012',
      appName: 'BCA Mobile (m-BCA) / myBCA',
      ruleNote:
          'Gunakan menu m-Transfer > BCA Virtual Account. Nominal tagihan terkunci otomatis sesuai pesanan (minimal transaksi Rp10.000).',
      steps: [
        'Buka aplikasi BCA Mobile (pilih m-BCA) atau myBCA, lalu masuk dengan Kode Akses Anda.',
        'Pilih menu m-Transfer > BCA Virtual Account, lalu masukkan Nomor Virtual Account {VA}.',
        'Periksa nama akun LiveTix Official dan nominal otomatis {TOTAL}, kemudian konfirmasi dengan PIN m-BCA 6 digit.',
      ],
    ),
    'Mandiri': BankPaymentRule(
      code: 'Mandiri',
      displayName: 'Mandiri Multipayment (Livin\')',
      methodTitle: 'Virtual Account',
      badgeText: 'MANDIRI',
      badgeColor: Color(0xFF003D79),
      vaPrefix: '89022',
      sampleSuffix: '081256789012',
      appName: 'Livin\' by Mandiri / ATM Mandiri',
      ruleNote:
          'Khusus Bank Mandiri gunakan menu Bayar > Multipayment dengan kode penyedia jasa 89022 (bukan menu Transfer antar rekening).',
      steps: [
        'Buka aplikasi Livin\' by Mandiri, lalu login ke akun Anda.',
        'Pilih menu Bayar > Multipayment / E-Commerce, lalu pilih penyedia jasa LiveTix (Kode 89022).',
        'Masukkan Kode Bayar / Nomor VA {VA}, pastikan nominal tagihan {TOTAL} sesuai, lalu konfirmasi PIN Livin\' 6 digit.',
      ],
    ),
    'BRI': BankPaymentRule(
      code: 'BRI',
      displayName: 'BRI Virtual Account (BRIVA)',
      methodTitle: 'Virtual Account',
      badgeText: 'BRI',
      badgeColor: Color(0xFF00529C),
      vaPrefix: '77889',
      sampleSuffix: '081256789012',
      appName: 'BRImo / ATM BRI',
      ruleNote:
          'Khusus BRI gunakan menu Tagihan > BRIVA (jangan gunakan menu Transfer Sesama BRI agar pembayaran terverifikasi otomatis).',
      steps: [
        'Buka aplikasi BRImo dan login menggunakan username, password, atau sidik jari.',
        'Pilih menu Tagihan > BRIVA, ketuk Pembayaran Baru, lalu masukkan Nomor Tujuan BRIVA {VA}.',
        'Tagihan LiveTix sebesar {TOTAL} akan tampil otomatis. Periksa detail pesanan lalu masukkan PIN BRImo 6 digit.',
      ],
    ),
    'SeaBank': BankPaymentRule(
      code: 'SeaBank',
      displayName: 'SeaBank Virtual Account',
      methodTitle: 'Virtual Account',
      badgeText: 'SEABANK',
      badgeColor: Color(0xFFB43E0A),
      vaPrefix: '7821',
      sampleSuffix: '081256789012',
      appName: 'Aplikasi SeaBank',
      ruleNote:
          'Khusus SeaBank gunakan menu Transfer > Virtual Account pada aplikasi SeaBank. Bebas biaya transfer antar-SeaBank dan verifikasi instan.',
      steps: [
        'Buka aplikasi SeaBank dan masuk ke akun Anda.',
        'Pilih menu Transfer > Virtual Account pada halaman utama aplikasi SeaBank.',
        'Masukkan Nomor Virtual Account {VA}, periksa nominal tagihan otomatis {TOTAL}, lalu masukkan PIN SeaBank 6 digit.',
      ],
    ),
  };

  static BankPaymentRule of(String provider) {
    return rules[provider] ?? rules['BCA']!;
  }
}

class EWalletProviderRule {
  final String code;
  final String displayName;
  final Color brandColor;
  final String tagline;

  const EWalletProviderRule({
    required this.code,
    required this.displayName,
    required this.brandColor,
    required this.tagline,
  });

  static const Map<String, EWalletProviderRule> providers = {
    'GoPay': EWalletProviderRule(
      code: 'GoPay',
      displayName: 'GoPay',
      brandColor: Color(0xFF00684A),
      tagline: 'Pembayaran instan via aplikasi GoPay / Gojek dengan PIN 6 digit',
    ),
    'DANA': EWalletProviderRule(
      code: 'DANA',
      displayName: 'DANA',
      brandColor: Color(0xFF0B5CAD),
      tagline: 'Pembayaran instan via aplikasi DANA dengan PIN DANA 6 digit',
    ),
    'ShopeePay': EWalletProviderRule(
      code: 'ShopeePay',
      displayName: 'ShopeePay',
      brandColor: Color(0xFFB83214),
      tagline: 'Pembayaran instan via aplikasi ShopeePay dengan PIN 6 digit',
    ),
  };

  static EWalletProviderRule of(String provider) {
    return providers[provider] ?? providers['ShopeePay']!;
  }
}

class RefundModel {
  final String refundId;
  final String ticketId;
  final String concertTitle;
  final int totalAmount;
  final String methodType; // 'Bank' atau 'E-wallet'
  final String providerName;
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

  /// Subtitle bersih dan aman dari string 'null'
  String get displaySubtitle {
    String sub = concertSubtitle
        .replaceAll('null · ', '')
        .replaceAll(' · null', '')
        .replaceAll('null', '')
        .trim();
    if (sub.isNotEmpty) return sub;
    final d = date.replaceAll('null', '').trim();
    final v = venue.replaceAll('null', '').trim();
    if (d.isNotEmpty && v.isNotEmpty) return '$d · $v';
    if (v.isNotEmpty) return v;
    if (d.isNotEmpty) return d;
    return 'Jadwal Segera Diumumkan';
  }

  /// URL gambar QR dari backend jika disediakan
  final String? qrCodeUrl;

  /// String data mentah QR dari backend (misal teks QRIS atau signed token tiket) untuk di-render oleh qr_flutter
  final String? qrData;

  /// Byte gambar QR dari backend (opsional)
  final Uint8List? qrCodeBytes;

  /// 1 QR Code berlaku sebanyak jumlah tiket yang dibeli (maksimal 4 kali scan di gate)
  final int qrScanQuota;
  final int qrScansUsed;
  final String paymentMethod;

  /// Data order saat masih dalam mode pembayaran pending
  final OrderModel? pendingOrder;

  /// ID konser terkait di database
  final String? concertId;

  /// URL foto logo/poster konser dari database
  final String? logoImageUrl;

  /// Byte foto logo konser dari database (opsional)
  final Uint8List? logoImageBytes;

  /// Identitas resmi pembeli tiket (Nama, Email, NIK)
  final String? buyerName;
  final String? buyerEmail;
  final String? buyerNik;

  /// Rincian komponen harga transparan sesuai rumus server LiveTix
  TransactionPricing get pricing {
    final unit = quantity > 0 ? (totalPrice ~/ quantity) : totalPrice;
    return TransactionPricing.calculate(unit, quantity);
  }

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
    this.qrCodeUrl,
    this.qrData,
    this.qrCodeBytes,
    int? qrScanQuota,
    this.qrScansUsed = 0,
    this.paymentMethod = 'BCA Virtual Account',
    this.pendingOrder,
    this.concertId,
    this.logoImageUrl,
    this.logoImageBytes,
    this.buyerName,
    this.buyerEmail,
    this.buyerNik,
  }) : qrScanQuota = qrScanQuota ?? quantity;

  bool get isPendingPayment =>
      status.toLowerCase().contains('menunggu') ||
      status.toLowerCase().contains('pending');

  /// Menandakan apakah tiket sudah kadaluwarsa (berdasarkan tanggal konser atau status)
  bool get isExpired {
    final s = status.toLowerCase();
    if (s.contains('hangus') || s.contains('expired') || s.contains('kadaluwarsa')) {
      return true;
    }
    try {
      if (date.isNotEmpty && !date.contains('Segera')) {
        final parsed = DateTime.tryParse(date);
        if (parsed != null && parsed.isBefore(DateTime.now().subtract(const Duration(days: 1)))) {
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  /// Menandakan apakah kuota scan tiket sudah habis terpakai semua
  bool get isAllScansUsed => qrScanQuota > 0 && qrScansUsed >= qrScanQuota;

  /// Menentukan apakah tiket masuk ke tab 'Aktif':
  /// - Tiket yang statusnya aktif dan belum kadaluwarsa serta belum habis discan
  /// - KECUALI tiket yang berstatus 'Reffund' (dibatalkan) atau belum dibayar (pending) itu tetap masuk di AKTIF
  bool get isActiveTabTicket {
    // 1. Status Refund / Pending payment selalu masuk di Aktif
    if (isPendingPayment) return true;
    final s = status.toLowerCase();
    if (isCancelled || s == 'reffund' || s == 'refund' || s == 'dibatalkan' || s.contains('batal') || s.contains('pengajuan')) {
      return true;
    }
    // 2. Jika sudah kadaluwarsa atau sudah discan semua atau status selesai, masuk ke Riwayat
    if (isExpired || isAllScansUsed || isCompleted || s.contains('divalidasi') || s == 'selesai') {
      return false;
    }
    // 3. Status aktif biasa
    return true;
  }

  /// Menentukan apakah tiket masuk ke tab 'Riwayat'
  bool get isHistoryTabTicket => !isActiveTabTicket;

  /// Kode ringkas acak di bagian paling akhir untuk tampilan UI penonton
  /// (misal 6-8 karakter acak terakhir), sedangkan kode unik lengkap tetap
  /// tersimpan utuh di dalam QR Code agar tetap scannable oleh gate crew.
  String get displayShortCode {
    final code = bookingCode.trim().isNotEmpty ? bookingCode.trim() : id.trim();
    if (code.isEmpty) return '—';
    if (code.contains('-')) {
      final segments = code.split('-');
      final last = segments.last.trim();
      if (last.isNotEmpty && last.length >= 4) {
        return last.toUpperCase();
      }
    }
    if (code.length > 6) {
      return code.substring(code.length - 6).toUpperCase();
    }
    return code.toUpperCase();
  }

  String get effectiveQrData {
    if (qrData != null && qrData!.trim().isNotEmpty) {
      return qrData!.trim();
    }
    if (bookingCode.trim().isNotEmpty) {
      return bookingCode.trim();
    }
    return 'LTX-$id';
  }

  int get remainingScans => (qrScanQuota - qrScansUsed).clamp(0, qrScanQuota);

  /// Menandakan apakah tiket sudah pernah di-scan / divalidasi oleh Gate Crew
  bool get isValidated =>
      qrScansUsed > 0 ||
      isCompleted ||
      status.toLowerCase().contains('divalidasi') ||
      status.toLowerCase() == 'selesai';

  /// Menandakan apakah tiket telah divalidasi secara penuh sesuai kuota
  bool get isFullyValidated =>
      (qrScanQuota > 0 && qrScansUsed >= qrScanQuota) ||
      isCompleted ||
      status.toLowerCase().contains('divalidasi') ||
      status.toLowerCase() == 'selesai';

  UserTicketModel copyWith({
    String? status,
    bool? isCompleted,
    bool? isCancelled,
    RefundModel? refundData,
    String? qrCodeUrl,
    String? qrData,
    Uint8List? qrCodeBytes,
    int? qrScanQuota,
    int? qrScansUsed,
    String? paymentMethod,
    OrderModel? pendingOrder,
    String? concertId,
    String? logoImageUrl,
    Uint8List? logoImageBytes,
    String? buyerName,
    String? buyerEmail,
    String? buyerNik,
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
      isCompleted: isCompleted ?? this.isCompleted,
      isCancelled: isCancelled ?? this.isCancelled,
      daysLeft: daysLeft,
      hasStar: hasStar,
      stripeColor: stripeColor,
      iconBgColor: iconBgColor,
      iconColor: iconColor,
      refundData: refundData ?? this.refundData,
      qrCodeUrl: qrCodeUrl ?? this.qrCodeUrl,
      qrData: qrData ?? this.qrData,
      qrCodeBytes: qrCodeBytes ?? this.qrCodeBytes,
      qrScanQuota: qrScanQuota ?? this.qrScanQuota,
      qrScansUsed: qrScansUsed ?? this.qrScansUsed,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      pendingOrder: pendingOrder ?? this.pendingOrder,
      concertId: concertId ?? this.concertId,
      logoImageUrl: logoImageUrl ?? this.logoImageUrl,
      logoImageBytes: logoImageBytes ?? this.logoImageBytes,
      buyerName: buyerName ?? this.buyerName,
      buyerEmail: buyerEmail ?? this.buyerEmail,
      buyerNik: buyerNik ?? this.buyerNik,
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bookingCode': bookingCode,
      'concertTitle': concertTitle,
      'concertSubtitle': concertSubtitle,
      'category': category,
      'date': date,
      'time': time,
      'gate': gate,
      'block': block,
      'venue': venue,
      'quantity': quantity,
      'totalPrice': totalPrice,
      'status': status,
      'isCompleted': isCompleted,
      'isCancelled': isCancelled,
      'daysLeft': daysLeft,
      'hasStar': hasStar,
      'qrCodeUrl': qrCodeUrl,
      'qrData': qrData,
      'qrScanQuota': qrScanQuota,
      'qrScansUsed': qrScansUsed,
      'paymentMethod': paymentMethod,
      'concertId': concertId,
      'logoImageUrl': logoImageUrl,
      'buyerName': buyerName,
      'buyerEmail': buyerEmail,
      'buyerNik': buyerNik,
    };
  }

  factory UserTicketModel.fromJson(Map<String, dynamic> json) {
    final q = (json['quantity'] as num?)?.toInt() ?? 1;
    return UserTicketModel(
      id: json['id']?.toString() ?? '',
      bookingCode: json['bookingCode']?.toString() ?? '',
      concertTitle: json['concertTitle']?.toString() ?? 'Konser LiveTix',
      concertSubtitle: (json['concertSubtitle']?.toString() ?? '')
          .replaceAll('null · ', '')
          .replaceAll('null', '')
          .trim(),
      category: json['category']?.toString() ?? 'Reguler',
      date: json['date']?.toString() ?? '',
      time: json['time']?.toString() ?? '19.00 WIB',
      gate: json['gate']?.toString() ?? 'Gate A',
      block: json['block']?.toString() ?? 'FEST-01',
      venue: json['venue']?.toString() ?? '',
      quantity: q,
      totalPrice: (json['totalPrice'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'Aktif',
      isCompleted: (json['isCompleted'] as bool?) ?? false,
      isCancelled: (json['isCancelled'] as bool?) ?? false,
      daysLeft: (json['daysLeft'] as num?)?.toInt() ?? 14,
      hasStar: (json['hasStar'] as bool?) ?? false,
      qrCodeUrl: json['qrCodeUrl']?.toString(),
      qrData: json['qr_payload']?.toString() ?? json['qrData']?.toString(),
      qrScanQuota: (json['qrScanQuota'] as num?)?.toInt() ?? q,
      qrScansUsed: (json['qrScansUsed'] as num?)?.toInt() ?? 0,
      paymentMethod: json['paymentMethod']?.toString() ?? 'QRIS',
      concertId: json['concertId']?.toString() ?? json['concert_id']?.toString(),
      logoImageUrl: json['logoImageUrl']?.toString() ?? json['logo_image_url']?.toString(),
      buyerName: json['buyerName']?.toString() ?? json['customer_name']?.toString(),
      buyerEmail: json['buyerEmail']?.toString() ?? json['customer_email']?.toString(),
      buyerNik: json['buyerNik']?.toString() ?? json['customer_nik']?.toString(),
    );
  }
}

class TransactionPricing {
  final int unitPrice;
  final int quantity;
  final int ticketPrice;
  final int entertainmentTax;
  final int applicationFee;
  final int subtotal;
  final int rounding;
  final int totalPay;
  final int producerShare;
  final int adminShare;

  const TransactionPricing({
    required this.unitPrice,
    required this.quantity,
    required this.ticketPrice,
    required this.entertainmentTax,
    required this.applicationFee,
    required this.subtotal,
    required this.rounding,
    required this.totalPay,
    required this.producerShare,
    required this.adminShare,
  });

  int get hargaSatuan => unitPrice;
  int get jumlah => quantity;
  int get hargaTiket => ticketPrice;
  int get pajakHiburan => entertainmentTax;
  int get biayaAplikasi => applicationFee;
  int get pembulatan => rounding;
  int get totalBayar => totalPay;
  int get produserShare => producerShare;

  /// Harga satuan all-inclusive (harga bersih yang dilihat pembeli)
  int get allInclusiveUnitPrice => quantity > 0 ? (totalPay ~/ quantity) : totalPay;

  /// Kalkulasi harga all-in per 1 satuan tiket:
  /// = harga awal produser + pajak hiburan (10%) + biaya aplikasi (2%) + pembulatan ke kelipatan Rp 1.000
  /// Nominal inilah yang ditampilkan kepada user di seluruh katalog tiket, sehingga user merasa harga tiket
  /// memang sebesar nominal tersebut (bersih tanpa penambahan biaya saat checkout).
  static int calculateUnitAllInclusivePrice(int unitPrice) {
    if (unitPrice <= 0) return 0;
    final tax = (unitPrice * 0.10).round();
    final appFee = (unitPrice * 0.02).round();
    final subtotal = unitPrice + tax + appFee;
    return ((subtotal + 999) ~/ 1000) * 1000;
  }

  /// Kalkulasi rumus resmi transaksi LiveTix (Semua nominal Integer Rupiah)
  /// - harga_tiket = harga x jumlah (maks 4)
  /// - pajak_hiburan = 10% x harga_tiket
  /// - biaya_aplikasi = 2% x harga_tiket (1x per transaksi)
  /// - subtotal = harga_tiket + pajak + biaya_aplikasi
  /// - total_bayar = subtotal dibulatkan KE ATAS kelipatan Rp 1.000 (ratusan 000)
  /// - pembulatan = total_bayar - subtotal
  /// - produser = harga_tiket + pajak_hiburan
  /// - admin = biaya_aplikasi + pembulatan
  factory TransactionPricing.calculate(int unitPrice, int quantity) {
    final qty = quantity.clamp(1, 4);
    final price = unitPrice < 0 ? 0 : unitPrice;
    final ticketPrice = price * qty;
    final tax = (ticketPrice * 0.10).round();
    final appFee = (ticketPrice * 0.02).round();
    final subtotal = ticketPrice + tax + appFee;
    final totalPay = ((subtotal + 999) ~/ 1000) * 1000;
    final rounding = totalPay - subtotal;
    final producer = ticketPrice + tax;
    final admin = appFee + rounding;

    return TransactionPricing(
      unitPrice: price,
      quantity: qty,
      ticketPrice: ticketPrice,
      entertainmentTax: tax,
      applicationFee: appFee,
      subtotal: subtotal,
      rounding: rounding,
      totalPay: totalPay,
      producerShare: producer,
      adminShare: admin,
    );
  }

  factory TransactionPricing.fromJson(Map<String, dynamic> json) {
    return TransactionPricing(
      unitPrice: (json['harga_satuan'] as num?)?.toInt() ?? 0,
      quantity: (json['jumlah'] as num?)?.toInt() ?? 1,
      ticketPrice: (json['harga_tiket'] as num?)?.toInt() ?? 0,
      entertainmentTax: (json['pajak_hiburan'] as num?)?.toInt() ?? 0,
      applicationFee: (json['biaya_aplikasi'] as num?)?.toInt() ?? 0,
      subtotal: (json['subtotal'] as num?)?.toInt() ?? 0,
      rounding: (json['pembulatan'] as num?)?.toInt() ?? 0,
      totalPay: (json['total_bayar'] as num?)?.toInt() ?? 0,
      producerShare: (json['bagian_produser'] as num?)?.toInt() ?? 0,
      adminShare: (json['bagian_admin'] as num?)?.toInt() ?? 0,
    );
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
  final int transactionFee;
  final int totalAmount;

  // Komponen transparan resmi
  final int entertainmentTax;
  final int applicationFee;
  final int rounding;
  final int producerShare;
  final int adminShare;

  final PaymentCategory paymentCategory;
  final String paymentProvider;
  final String paymentMethod;
  final String vaNumber;
  final String vaName;

  /// URL/bytes QR dari backend untuk QRIS maupun tiket jika disediakan
  final String? qrCodeUrl;
  final Uint8List? qrCodeBytes;

  /// String data QR mentah dari Midtrans Core API (00020101...) untuk di-render langsung oleh qr_flutter
  final String? qrString;

  /// Deep link URL langsung ke aplikasi e-wallet (Gojek / Shopee) dari response Midtrans
  final String? deeplinkUrl;

  /// Snap Token & Redirect URL dari Midtrans Snap Sandbox
  final String? snapToken;
  final String? snapRedirectUrl;

  /// Waktu kedaluwarsa pembayaran dari backend Midtrans
  final DateTime? expiresAt;

  int get calculatedEntertainmentTax =>
      entertainmentTax > 0 ? entertainmentTax : (ticketPrice * 0.10).round();
  int get calculatedApplicationFee =>
      applicationFee > 0 ? applicationFee : (ticketPrice * 0.02).round();
  int get calculatedRounding {
    if (rounding > 0) return rounding;
    final sub = ticketPrice + calculatedEntertainmentTax + calculatedApplicationFee;
    return totalAmount > sub ? (totalAmount - sub) : 0;
  }

  const OrderModel({
    required this.orderId,
    required this.concert,
    required this.tier,
    required this.quantity,
    required this.customerName,
    required this.customerEmail,
    required this.ticketPrice,
    this.serviceFee = 0,
    this.taxAndAdmin = 0,
    this.transactionFee = 0,
    required this.totalAmount,
    this.entertainmentTax = 0,
    this.applicationFee = 0,
    this.rounding = 0,
    this.producerShare = 0,
    this.adminShare = 0,
    this.paymentCategory = PaymentCategory.bank,
    this.paymentProvider = 'BCA',
    this.paymentMethod = 'BCA Virtual Account',
    this.vaNumber = '8808 1234 5678 9012',
    this.vaName = 'a.n. LiveTix Official',
    this.qrCodeUrl,
    this.qrCodeBytes,
    this.qrString,
    this.deeplinkUrl,
    this.snapToken,
    this.snapRedirectUrl,
    this.expiresAt,
  });

  OrderModel copyWithPayment({
    String? orderId,
    required PaymentCategory category,
    required String provider,
    int? transactionFee,
    String? qrString,
    String? qrCodeUrl,
    String? deeplinkUrl,
    String? snapToken,
    String? snapRedirectUrl,
    String? vaNumber,
    DateTime? expiresAt,
  }) {
    final activeOrderId = orderId ?? this.orderId;
    final fee = transactionFee ?? this.transactionFee;
    final calculatedTotal = totalAmount + fee;

    switch (category) {
      case PaymentCategory.qris:
        return OrderModel(
          orderId: activeOrderId,
          concert: concert,
          tier: tier,
          quantity: quantity,
          customerName: customerName,
          customerEmail: customerEmail,
          ticketPrice: ticketPrice,
          serviceFee: serviceFee,
          taxAndAdmin: taxAndAdmin,
          transactionFee: fee,
          totalAmount: calculatedTotal,
          entertainmentTax: calculatedEntertainmentTax,
          applicationFee: calculatedApplicationFee,
          rounding: calculatedRounding,
          producerShare: producerShare,
          adminShare: adminShare,
          paymentCategory: PaymentCategory.qris,
          paymentProvider: 'QRIS',
          paymentMethod: 'QRIS',
          vaNumber: vaNumber ?? 'ID1026008891204',
          vaName: 'LiveTix Official',
          qrCodeUrl: qrCodeUrl ?? this.qrCodeUrl,
          qrCodeBytes: qrCodeBytes,
          qrString: qrString ?? this.qrString,
          deeplinkUrl: deeplinkUrl ?? this.deeplinkUrl,
          snapToken: snapToken ?? this.snapToken,
          snapRedirectUrl: snapRedirectUrl ?? this.snapRedirectUrl,
          expiresAt: expiresAt ?? this.expiresAt,
        );
      case PaymentCategory.ewallet:
        final rule = EWalletProviderRule.of(provider);
        return OrderModel(
          orderId: activeOrderId,
          concert: concert,
          tier: tier,
          quantity: quantity,
          customerName: customerName,
          customerEmail: customerEmail,
          ticketPrice: ticketPrice,
          serviceFee: serviceFee,
          taxAndAdmin: taxAndAdmin,
          transactionFee: fee,
          totalAmount: calculatedTotal,
          entertainmentTax: calculatedEntertainmentTax,
          applicationFee: calculatedApplicationFee,
          rounding: calculatedRounding,
          producerShare: producerShare,
          adminShare: adminShare,
          paymentCategory: PaymentCategory.ewallet,
          paymentProvider: rule.code,
          paymentMethod: 'E-Wallet (${rule.displayName})',
          vaNumber: vaNumber ?? activeOrderId,
          vaName: 'LiveTix Official',
          qrCodeUrl: qrCodeUrl,
          qrCodeBytes: qrCodeBytes,
          qrString: qrString ?? this.qrString,
          deeplinkUrl: deeplinkUrl ?? this.deeplinkUrl,
          snapToken: snapToken ?? this.snapToken,
          snapRedirectUrl: snapRedirectUrl ?? this.snapRedirectUrl,
          expiresAt: expiresAt ?? this.expiresAt,
        );
      case PaymentCategory.bank:
        final bankRule = BankPaymentRule.of(provider);
        return OrderModel(
          orderId: activeOrderId,
          concert: concert,
          tier: tier,
          quantity: quantity,
          customerName: customerName,
          customerEmail: customerEmail,
          ticketPrice: ticketPrice,
          serviceFee: serviceFee,
          taxAndAdmin: taxAndAdmin,
          transactionFee: fee,
          totalAmount: calculatedTotal,
          entertainmentTax: calculatedEntertainmentTax,
          applicationFee: calculatedApplicationFee,
          rounding: calculatedRounding,
          producerShare: producerShare,
          adminShare: adminShare,
          paymentCategory: PaymentCategory.bank,
          paymentProvider: bankRule.code,
          paymentMethod: bankRule.displayName,
          vaNumber: vaNumber ??
              (bankRule.code == 'BCA'
                  ? '8808 1234 5678 9012'
                  : bankRule.buildVaNumber(activeOrderId)),
          vaName: 'a.n. LiveTix Official',
          qrCodeUrl: qrCodeUrl,
          qrCodeBytes: qrCodeBytes,
          qrString: qrString ?? this.qrString,
          deeplinkUrl: deeplinkUrl ?? this.deeplinkUrl,
          snapToken: snapToken ?? this.snapToken,
          snapRedirectUrl: snapRedirectUrl ?? this.snapRedirectUrl,
          expiresAt: expiresAt ?? this.expiresAt,
        );
    }
  }

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
