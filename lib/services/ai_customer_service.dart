import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/ai_config.dart';
import 'customer_service_service.dart';

/// Service Kecerdasan Buatan (AI) Customer Service LiveTix.
/// Mendukung 3 peran pengguna:
/// 1. User (Penonton Konser)
/// 2. Produser (Promotor / Event Organizer)
/// 3. Admin (Super Admin / Tim Support LiveTix)
class AiCustomerService {
  static final AiCustomerService _instance = AiCustomerService._internal();
  factory AiCustomerService() => _instance;

  AiCustomerService._internal();

  /// Klien HTTP yang dapat di-inject untuk keperluan pengujian unit
  http.Client? _customClient;
  @visibleForTesting
  set customClient(http.Client? client) => _customClient = client;

  http.Client get _client => _customClient ?? http.Client();

  /// Prompt sistem untuk User (Penonton Konser)
  static const String _userSystemInstruction = '''
Anda adalah "LiveTix AI Assistant", asisten customer service resmi platform pemesanan tiket konser LiveTix.
Tugas Anda adalah melayani dan membantu pengguna/penonton dengan ramah, sopan, ringkas, dan solutif dalam Bahasa Indonesia.

Informasi Resmi LiveTix untuk Penonton:
1. E-Tiket:
   - E-tiket langsung tersedia di tab "Tiket Saya" setelah pembayaran terverifikasi.
   - Menggunakan kode QR dinamis yang dapat langsung di-scan di pintu gerbang/Gate konser.
   - Tidak perlu mencetak tiket fisik; cukup tunjukkan QR dari layar aplikasi.
2. Pembayaran:
   - Didukung oleh gateway Midtrans: QRIS (GoPay, OVO, ShopeePay, Dana, BCA Mobile), Virtual Account (BCA, Mandiri, BNI, BRI).
   - Batas waktu penyelesaian pembayaran adalah 15 menit.
3. Kendala Tiket:
   - Jika pembayaran berhasil namun tiket belum muncul, pengguna disarankan menekan tombol refresh di tab "Tiket Saya" atau melampirkan Order ID (ORD-XXXXXX).
4. Kebijakan Refund & Pembatalan:
   - Jika konser dibatalkan secara resmi oleh promotor, pengembalian dana (refund) 100% diproses penuh ke metode pembayaran pengguna.
   - Tiket yang telah dibeli tidak dapat dibatalkan atau ditukar jika konser tetap berjalan sesuai jadwal.
5. Pintu Masuk / Gate:
   - Penonton disarankan hadir 1-2 jam sebelum acara dimulai dan menyiapkan KTP/identitas sesuai nama pada pesanan jika diminta oleh petugas.

Gaya Komunikasi:
- Berikan salam hangat khas LiveTix.
- Gunakan bahasa Indonesia yang santun, jelas, dan mudah dipahami.
- Hindari kalimat berbelit-belit. Akhiri dengan penawaran bantuan lebih lanjut.
''';

  /// Prompt sistem untuk Produser (Promotor Konser)
  static const String _producerSystemInstruction = '''
Anda adalah "LiveTix AI Producer Desk", asisten operasional resmi untuk promotor dan penyelenggara konser di LiveTix.
Tugas Anda adalah melayani mitra produser/promotor dengan profesional, taktis, dan solutif dalam Bahasa Indonesia.

Informasi Resmi LiveTix untuk Produser:
1. Pembuatan & Pengajuan Konser (Add Concert):
   - Alur 4 langkah: (1) Informasi Konser, (2) Upload Media/Poster, (3) Pembuatan Tier Tiket & Kuota, (4) Jadwal, Venue & Lokasi Peta.
2. Verifikasi Dokumen & Legalitas:
   - Promotor wajib mengunggah Foto KTP Penanggung Jawab, Lembar Surat Penanggung Jawab bermeterai, dan membuat 6-digit PIN Keamanan Penarikan.
   - Proses review dokumen oleh Super Admin LiveTix memakan waktu maksimal 1x24 jam kerja.
   - Status pengajuan konser: "Pending" (menunggu review), "Approved" (terbit & tiket dapat dibeli publik), atau "Rejected" (ditolak dengan catatan perbaikan).
3. Fee Platform & Penarikan Dana (Withdrawal):
   - Biaya layanan platform LiveTix adalah 3% dari total penjualan tiket konser.
   - Saldo penjualan dapat ditarik dengan nominal minimal Rp 50.000 ke rekening bank terdaftar promotor (BCA, Mandiri, BRI, BNI).
   - Penarikan memerlukan konfirmasi 6-digit PIN Keamanan dan diproses 1-3 hari kerja.
4. Manajemen Gate Crew:
   - Promotor dapat mendaftarkan staf gate crew, mengirim undangan akses melalui email/kode, dan membagi penugasan pintu masuk (Gate A, Gate B, VIP).

Gaya Komunikasi:
- Nada bicara profesional, percaya diri, dan berorientasi pada solusi bisnis konser.
- Sebutkan langkah konkret dan jelas sesuai alur dashboard produser.
''';

  /// Prompt sistem untuk Super Admin (Admin Copilot)
  static const String _adminSystemInstruction = '''
Anda adalah "LiveTix AI Admin Copilot", asisten intelijen operasional untuk Super Admin platform LiveTix.
Tugas Anda adalah memberikan ringkasan keluhan pelanggan, menyusun draf balasan resmi yang solutif, dan menjawab pertanyaan SOP operasional.

SOP Operasional Admin LiveTix:
1. Verifikasi Konser Promotor:
   - Periksa kejelasan KTP, surat izin venue, rekening pencairan, dan rincian kuota tiket sebelum menyetujui.
2. Penanganan Komplain Penonton:
   - Kasus pembayaran tertunda: verifikasi status transaksi di dashboard pembayaran Midtrans.
   - Kasus QR tidak terbaca di gate: verifikasi status tiket di database `tickets` dan pandu gate crew melakukan validasi manual via nomor tiket.
3. Pembatalan Acara & Refund:
   - Jika promotor mengajukan pembatalan konser, pantau saldo refund dan koordinasikan pengembalian dana 100% kepada pembeli tiket.

Gaya Komunikasi:
- Objektif, padat, berbasis data dan alur SOP LiveTix.
''';

  /// Menghasilkan balasan otomatis dari AI untuk pesan yang dikirim oleh User, Produser, atau Admin.
  Future<String> generateCustomerServiceReply({
    required String userMessage,
    required String role,
    List<Map<String, String>> chatHistory = const [],
    String? userName,
  }) async {
    final trimmedMessage = userMessage.trim();
    if (trimmedMessage.isEmpty) {
      return 'Halo! Ada yang bisa kami bantu seputar tiket atau konser LiveTix?';
    }

    final normalizedRole = _normalizeRole(role);
    final systemPrompt = _getSystemPromptForRole(normalizedRole);

    // Coba memanggil Google Gemini API
    try {
      final apiKey = AiConfig.geminiApiKey;
      if (apiKey.isNotEmpty) {
        final reply = await _callGeminiApi(
          apiKey: apiKey,
          systemPrompt: systemPrompt,
          userMessage: trimmedMessage,
          chatHistory: chatHistory,
        );
        if (reply != null && reply.trim().isNotEmpty) {
          return reply.trim();
        }
      }
    } catch (e) {
      debugPrint('AiCustomerService.generateCustomerServiceReply exception: $e');
    }

    // Fallback cerdas lokal (offline / bila API limit tercapai)
    return _generateLocalFallbackReply(
      message: trimmedMessage,
      role: normalizedRole,
      userName: userName,
    );
  }

  /// Khusus Admin: Meringkas riwayat percakapan dalam suatu thread CS
  Future<String> summarizeThread({
    required List<CsMessageModel> messages,
    required String userRole,
    required String userName,
  }) async {
    if (messages.isEmpty) {
      return 'Tidak ada pesan dalam percakapan ini untuk diringkas.';
    }

    final conversationText = messages
        .map((m) =>
            '${m.isFromAdmin ? "Admin" : m.senderName} (${m.senderRole}): ${m.message}')
        .join('\n');

    final prompt = '''
Berikut adalah riwayat percakapan Customer Service LiveTix dengan $userName ($userRole):
"""
$conversationText
"""

Tolong buatkan ringkasan singkat dalam 2-3 poin untuk Super Admin:
1. Pokok Permasalahan / Pertanyaan Utama:
2. Status Penanganan Terkini:
3. Rekomendasi Tindak Lanjut Admin:
''';

    try {
      final apiKey = AiConfig.geminiApiKey;
      if (apiKey.isNotEmpty) {
        final summary = await _callGeminiApi(
          apiKey: apiKey,
          systemPrompt: _adminSystemInstruction,
          userMessage: prompt,
        );
        if (summary != null && summary.trim().isNotEmpty) {
          return summary.trim();
        }
      }
    } catch (e) {
      debugPrint('AiCustomerService.summarizeThread exception: $e');
    }

    // Fallback ringkasan lokal
    final lastMsg = messages.last.message;
    return '📌 Ringkasan Percakapan CS ($userRole: $userName)\n'
        '• Jumlah pesan: ${messages.length} pesan tercatat.\n'
        '• Pesan terakhir: "$lastMsg"\n'
        '• Rekomendasi: Periksa status transaksi / tiket dan berikan konfirmasi langsung ke pengguna.';
  }

  /// Khusus Admin: Membuat draf balasan untuk dikirimkan Admin ke pengguna/produser
  Future<String> generateAdminDraftReply({
    required List<CsMessageModel> messages,
    required String userRole,
    required String userName,
    String? adminInstruction,
  }) async {
    final recentMessages = messages.length > 5
        ? messages.sublist(messages.length - 5)
        : messages;

    final conversationText = recentMessages
        .map((m) =>
            '${m.isFromAdmin ? "Admin" : m.senderName}: ${m.message}')
        .join('\n');

    final prompt = '''
Anda adalah Super Admin LiveTix. Buatkan draf balasan pesan yang ramah, sopan, dan solutif untuk membalas percakapan berikut:
Pihak Lawan Bicara: $userName ($userRole)
Riwayat Percakapan Terbaru:
"""
$conversationText
"""
${adminInstruction != null && adminInstruction.trim().isNotEmpty ? "Instruksi Khusus Admin: $adminInstruction" : ""}

Buatlah draf balasan langsung tanpa tanda kutip pembuka atau penjelas berlebih.
''';

    try {
      final apiKey = AiConfig.geminiApiKey;
      if (apiKey.isNotEmpty) {
        final draft = await _callGeminiApi(
          apiKey: apiKey,
          systemPrompt: _adminSystemInstruction,
          userMessage: prompt,
        );
        if (draft != null && draft.trim().isNotEmpty) {
          return draft.trim();
        }
      }
    } catch (e) {
      debugPrint('AiCustomerService.generateAdminDraftReply exception: $e');
    }

    // Fallback draf lokal
    return 'Halo $userName, terima kasih telah menghubungi Tim Support LiveTix. '
        'Laporan Anda terkait kendala tersebut sedang kami telusuri bersama tim teknis. '
        'Mohon kesediaannya menunggu konfirmasi dalam waktu singkat. Terima kasih!';
  }

  /// Memanggil endpoint Gemini REST API dengan fallback multi-model
  Future<String?> _callGeminiApi({
    required String apiKey,
    required String systemPrompt,
    required String userMessage,
    List<Map<String, String>> chatHistory = const [],
  }) async {
    // Siapkan riwayat percakapan (contents)
    final contents = <Map<String, dynamic>>[];

    for (final item in chatHistory) {
      final role = item['role'] == 'assistant' ? 'model' : 'user';
      final text = item['text'] ?? '';
      if (text.trim().isNotEmpty) {
        contents.add({
          'role': role,
          'parts': [
            {'text': text.trim()}
          ],
        });
      }
    }

    // Tambahkan pesan pengguna saat ini
    contents.add({
      'role': 'user',
      'parts': [
        {'text': userMessage}
      ],
    });

    final payload = jsonEncode({
      'contents': contents,
      'systemInstruction': {
        'parts': [
          {'text': systemPrompt}
        ]
      },
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 1000,
      },
    });

    // Iterasi model-model yang didukung jika model utama mengalami kendala
    for (final modelName in AiConfig.fallbackModels) {
      try {
        final url = Uri.parse(
          '${AiConfig.baseUrl}/$modelName:generateContent?key=$apiKey',
        );

        final response = await _client
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: payload,
            )
            .timeout(const Duration(seconds: 12));

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          final candidates = decoded['candidates'] as List<dynamic>?;
          if (candidates != null && candidates.isNotEmpty) {
            final firstCandidate = candidates.first as Map<String, dynamic>;
            final content = firstCandidate['content'] as Map<String, dynamic>?;
            final parts = content?['parts'] as List<dynamic>?;
            if (parts != null && parts.isNotEmpty) {
              final text = parts.first['text'] as String?;
              if (text != null && text.trim().isNotEmpty) {
                return text.trim();
              }
            }
          }
        } else {
          debugPrint(
            'Gemini API model $modelName returned status ${response.statusCode}: ${response.body}',
          );
        }
      } catch (e) {
        debugPrint('Gemini API call to $modelName error: $e');
      }
    }

    return null;
  }

  String _normalizeRole(String rawRole) {
    final lower = rawRole.trim().toLowerCase();
    if (lower == 'produser' || lower == 'promoter') return 'Produser';
    if (lower == 'admin') return 'Admin';
    if (lower == 'gatecrew') return 'Gatecrew';
    return 'User';
  }

  String _getSystemPromptForRole(String role) {
    switch (role) {
      case 'Produser':
        return _producerSystemInstruction;
      case 'Admin':
        return _adminSystemInstruction;
      case 'Gatecrew':
        return '$_userSystemInstruction\nPeran Pengguna: Gate Crew LiveTix. Bantu terkait scan barcode, koneksi scanner kamera, dan validasi tiket gerbang.';
      case 'User':
      default:
        return _userSystemInstruction;
    }
  }

  /// Penjawab cerdas lokal berbasis pengetahuan resmi LiveTix jika offline atau kuota habis
  String _generateLocalFallbackReply({
    required String message,
    required String role,
    String? userName,
  }) {
    final lower = message.toLowerCase();
    final greeting =
        userName != null && userName.isNotEmpty ? 'Halo $userName' : 'Halo';

    if (role == 'Produser') {
      if (lower.contains('status') ||
          lower.contains('verifikasi') ||
          lower.contains('dokumen') ||
          lower.contains('ktp')) {
        return '$greeting! Untuk status verifikasi konser dan dokumen legalitas promotor:\n\n'
            '1. Dokumen wajib meliputi Foto KTP Penanggung Jawab dan Lembar Surat Penanggung Jawab bermeterai.\n'
            '2. Tim Super Admin kami meninjau pengajuan dalam waktu maksimal 1x24 jam kerja.\n'
            '3. Anda dapat memantau status secara langsung di menu "Konser Saya". Jika status masih "Pending", pengajuan Anda sedang dalam antrean verifikasi.';
      }
      if (lower.contains('cair') ||
          lower.contains('tarik') ||
          lower.contains('saldo') ||
          lower.contains('rekening') ||
          lower.contains('withdraw')) {
        return '$greeting! Terkait pencairan saldo penjualan tiket:\n\n'
            '1. Minimal penarikan saldo adalah Rp 50.000.\n'
            '2. Penarikan memerlukan 6-digit PIN Keamanan Penarikan yang telah Anda atur.\n'
            '3. Dana akan ditransfer ke rekening bank terdaftar promotor dalam 1-3 hari kerja setelah pengajuan disetujui.';
      }
      if (lower.contains('fee') || lower.contains('potongan') || lower.contains('3%')) {
        return '$greeting! Ketentuan fee layanan LiveTix adalah sebesar 3% dari total penjualan tiket konser. Fee ini dipotong secara otomatis pada sistem ketika tiket berhasil dibayar oleh penonton.';
      }
      if (lower.contains('gate') || lower.contains('crew') || lower.contains('kru')) {
        return '$greeting! Untuk pengelolaan Gate Crew konser:\n\n'
            '1. Anda dapat menambahkan staf gate crew melalui menu Manajemen Kru pada konser yang aktif.\n'
            '2. Petugas yang didaftarkan dapat login ke aplikasi Gate Crew untuk memindai QR tiket penonton di pintu masuk.';
      }
      return '$greeting! Terima kasih telah menghubungi LiveTix Producer Support. '
          'Pertanyaan Anda telah kami catat. Tim Customer Service LiveTix akan segera meninjau dan membantu kendala operasional konser Anda.';
    }

    if (role == 'Admin') {
      return 'Draf balasan otomatis disiapkan: Silakan periksa status transaksi pada database dan hubungi pengguna terkait dengan solusi yang sesuai SOP LiveTix.';
    }

    // Role User
    if (lower.contains('qr') ||
        lower.contains('scan') ||
        lower.contains('tiket saya') ||
        lower.contains('tunjuk')) {
      return '$greeting! E-tiket konser Anda dapat diakses di menu "Tiket Saya".\n\n'
          '• Di sana terdapat barcode / QR Code resmi yang dapat langsung di-scan oleh petugas di gerbang venue konser.\n'
          '• Anda tidak perlu mencetak tiket fisik, cukup tunjukkan layar ponsel Anda dengan kecerahan yang cukup.';
    }
    if (lower.contains('refund') ||
        lower.contains('batal') ||
        lower.contains('kembali uang')) {
      return '$greeting! Mengenai kebijakan pengembalian dana (refund):\n\n'
          '• Jika konser dibatalkan secara resmi oleh penyelenggara/promotor, dana tiket Anda akan dikembalikan 100% penuh.\n'
          '• Pengembalian dana akan otomatis diproses ke rekening atau dompet digital yang digunakan saat pembayaran.';
    }
    if (lower.contains('bayar') ||
        lower.contains('qris') ||
        lower.contains('transfer') ||
        lower.contains('metode')) {
      return '$greeting! LiveTix mendukung berbagai metode pembayaran aman via Midtrans:\n\n'
          '1. QRIS: GoPay, OVO, ShopeePay, Dana, BCA Mobile, dll.\n'
          '2. Virtual Account: BCA, Mandiri, BNI, BRI.\n'
          'Batas waktu penyelesaian pembayaran adalah 15 menit sejak pesanan dibuat.';
    }
    if (lower.contains('belum muncul') ||
        lower.contains('tidak ada') ||
        lower.contains('hilang')) {
      return '$greeting! Jika pembayaran sudah berhasil namun tiket belum muncul di akun Anda:\n\n'
          '1. Coba klik ikon refresh di kanan atas tab "Tiket Saya".\n'
          '2. Jika masih belum muncul, mohon kirimkan Order ID (contoh: ORD-XXXXXX) atau bukti transfer di chat ini agar tim kami dapat melakukan verifikasi kilat.';
    }

    return '$greeting! Terima kasih telah menghubungi LiveTix AI Support. '
        'Layanan bantuan kami aktif 24/7 untuk membantu pembelian tiket, QR scan di gerbang venue, dan informasi konser. '
        'Ada yang bisa kami bantu lebih lanjut?';
  }
}
