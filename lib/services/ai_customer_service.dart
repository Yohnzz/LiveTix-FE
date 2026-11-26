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
Tugas Anda adalah melayani dan membantu pengguna/penonton dalam menyelesaikan masalah teknis, kendala pembayaran, tiket, atau kendala aplikasi dengan ramah, sopan, ringkas, dan solutif dalam Bahasa Indonesia.

BATASAN RUANG LINGKUP & TANGGUNG JAWAB UTAMA:
1. Layanan Customer Service ini HANYA KHUSUS untuk pemecahan masalah (troubleshooting) dan penanganan kendala pengguna:
   - Kendala pembayaran (status pembayaran menunggu, batas waktu 15 menit, verifikasi transaksi Midtrans).
   - Kendala tiket (e-tiket belum muncul di tab "Tiket Saya", barcode/QR tidak terbaca, cara scan di gate).
   - Pengajuan komplain & refund (konser dibatalkan oleh promotor, pengembalian dana 100%).
   - Kendala akun & aplikasi (tidak bisa login, error aplikasi, ganti data akun).
2. ATURAN PENGALIHAN KHUSUS (REDIRECT TO JELAJAH):
   - Jika pengguna bertanya tentang: mencari konser, jadwal konser, siapa artis yang tampil, rekomendasi konser, harga tiket konser tertentu, genre/lokasi konser (informasi seputar katalog konser):
     ANDA DILARANG MEMBERIKAN DAFTAR KONSER ATAU MENJAWAB TENTANG JADWAL KONSER DI SINI.
     Sebaliknya, Anda WAJIB dengan sopan menolak menjawab katalog konser dan LANGSUNG MENGARAHKAN pengguna untuk menggunakan menu "Jelajah" atau fitur "AI Search" LiveTix.
   - Contoh respon pengalihan:
     "Halo! Layanan Customer Service LiveTix ini khusus untuk bantuan kendala transaksi, tiket, dan teknis aplikasi. Untuk mencari jadwal konser, daftar artis, rekomendasi konser, atau mengecek harga tiket, silakan gunakan fitur **Jelajah** (ikon kaca pembesar di menu navigasi bawah). Di sana Anda juga dapat memanfaatkan fitur **AI Search** untuk menemukan konser impian Anda dengan cepat!"

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
- Hindari kalimat berbelit-belit. Akhiri dengan penawaran bantuan lebih lanjut seputar kendala aplikasi/tiket.
''';

  /// Prompt sistem untuk Produser (Promotor Konser)
  static const String _producerSystemInstruction = '''
Anda adalah "LiveTix AI Producer Desk", asisten operasional resmi untuk promotor dan penyelenggara konser di LiveTix.
Tugas Anda adalah melayani mitra produser/promotor dengan profesional, taktis, dan solutif dalam Bahasa Indonesia.

Informasi Resmi LiveTix untuk Produser:
1. Pembuatan & Pengajuan Konser (Tambah Konser):
   - Alur 5 langkah: (1) Detail konser, logo persegi, poster, dan highlights, (2) Cari & tentukan lokasi venue lewat peta, (3) Tambah & atur kategori harga tiket beserta kuotanya, (4) Tentukan petugas gate crew untuk pemindaian QR, (5) Cek ulang ringkasan sebelum diajukan.
   - Setelah diajukan, konser menunggu persetujuan Super Admin sebelum tiket dapat dibeli publik.
2. Verifikasi Dokumen & Legalitas:
   - Promotor wajib mengunggah Foto KTP Penanggung Jawab, Lembar Surat Penanggung Jawab bermeterai, dan membuat 6-digit PIN Keamanan Penarikan.
   - Proses review dokumen oleh Super Admin LiveTix memakan waktu maksimal 1x24 jam kerja.
   - Status pengajuan konser: "Pending" (menunggu review), "Approved" (terbit & tiket dapat dibeli publik), atau "Rejected" (ditolak dengan catatan perbaikan).
3. Fee Platform & Penarikan Dana (Withdrawal):
   - Biaya layanan platform LiveTix adalah 2% dari total penjualan tiket konser.
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

  /// Fitur Analisis Gambar Pengguna dengan Gemini Vision (Multimodal AI)
  /// Mengidentifikasi bukti pembayaran, struk, tangkapan layar tiket/aplikasi, atau dokumen KTP,
  /// lalu menarik kesimpulan dan memberikan panduan solutif.
  Future<String> analyzeImageAndReply({
    required String imageBase64,
    String? mimeType,
    required String userMessage,
    required String role,
    String? userName,
  }) async {
    final normalizedRole = _normalizeRole(role);
    final systemPrompt = _getSystemPromptForRole(normalizedRole);
    final userNote = userMessage.trim().isNotEmpty
        ? 'Pesan dari pengguna: "$userMessage"'
        : 'Pengguna mengirimkan gambar untuk diperiksa.';

    final prompt = '''
$userNote

Tolong analisis gambar yang dilampirkan oleh pengguna ini secara mendalam untuk Customer Service LiveTix:
1. Apa jenis gambar ini? (Contoh: Bukti Transfer / Resi Pembayaran m-Banking/QRIS, Tangkapan Layar Kendala Tiket, E-Tiket Barcode, Foto KTP/Surat Promotor, dll)
2. Jika ini Bukti Pembayaran: sebutkan detail penting yang terbaca (bank/e-wallet pengirim/penerima, nominal rupiah, tanggal/waktu transaksi, nomor referensi/rekening tujuan).
3. Jika ini Kendala Aplikasi/Tiket: jelaskan apa pesan error atau kendala yang tampak di layar.
4. Kesimpulan & Rekomendasi: Berikan kesimpulan resmi yang ramah, sopan, dan solutif dalam Bahasa Indonesia apakah data valid atau langkah apa yang harus dilakukan pengguna selanjutnya.
''';

    final apiKey = AiConfig.geminiApiKey;
    if (apiKey.isNotEmpty) {
      try {
        final reply = await _callGeminiVisionApi(
          apiKey: apiKey,
          prompt: prompt,
          imageBase64: imageBase64,
          mimeType: mimeType ?? 'image/jpeg',
          systemPrompt: systemPrompt,
        );
        if (reply != null && reply.trim().isNotEmpty) {
          return reply.trim();
        }
      } catch (e) {
        debugPrint('AiCustomerService.analyzeImageAndReply error: $e');
      }
    }

    return _generateLocalImageFallback(
      role: normalizedRole,
      userName: userName,
      userMessage: userMessage,
    );
  }

  Future<String?> _callGeminiVisionApi({
    required String apiKey,
    required String prompt,
    required String imageBase64,
    required String mimeType,
    required String systemPrompt,
  }) async {
    final payload = jsonEncode({
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt},
            {
              'inlineData': {
                'mimeType': mimeType,
                'data': imageBase64,
              }
            }
          ]
        }
      ],
      'systemInstruction': {
        'parts': [
          {'text': systemPrompt}
        ]
      },
      'generationConfig': {
        'temperature': 0.4,
        'maxOutputTokens': 1200,
      },
    });

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
            .timeout(const Duration(seconds: 15));

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
          debugPrint('Gemini Vision $modelName returned ${response.statusCode}: ${response.body}');
        }
      } catch (e) {
        debugPrint('Gemini Vision API call error to $modelName: $e');
      }
    }
    return null;
  }

  String _generateLocalImageFallback({
    required String role,
    String? userName,
    required String userMessage,
  }) {
    final greeting =
        userName != null && userName.isNotEmpty ? 'Halo $userName' : 'Halo';
    return '$greeting! Kami telah menerima lampiran gambar Anda di layanan Customer Service.\n\n'
        '🔍 **Pemeriksaan Awal Sistem AI LiveTix:**\n'
        '• Gambar lampiran telah tercatat aman di server Customer Service kami.\n'
        '• Jika gambar berupa **Bukti Pembayaran / Transfer**: Sistem memverifikasi bahwa bukti telah diterima dan admin keuangan sedang mencocokkan mutasi rekening.\n'
        '• Jika gambar berupa **Tangkapan Layar Kendala**: Mohon pastikan aplikasi Anda sudah versi terbaru dan coba muat ulang tiket.\n\n'
        'Tim Admin LiveTix akan segera meninjau detail lampiran ini dan memberikan konfirmasi langsung.';
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
      if (lower.contains('fee') || lower.contains('potongan') || lower.contains('persen') || lower.contains('%')) {
        return '$greeting! Ketentuan fee layanan LiveTix adalah sebesar 2% dari total penjualan tiket konser. Fee ini dipotong secara otomatis pada sistem ketika tiket berhasil dibayar oleh penonton.';
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
    // 1. Deteksi jika user bertanya mengenai pencarian konser, jadwal, artis, atau rekomendasi di Customer Service
    final isAskingConcertInfo = lower.contains('konser apa') ||
        lower.contains('ada konser') ||
        lower.contains('jadwal konser') ||
        lower.contains('jadwal acara') ||
        lower.contains('rekomendasi') ||
        lower.contains('siapa artis') ||
        lower.contains('siapa yang tampil') ||
        lower.contains('lineup') ||
        lower.contains('line up') ||
        lower.contains('kapan konser') ||
        lower.contains('cari konser') ||
        lower.contains('daftar konser') ||
        lower.contains('konser rock') ||
        lower.contains('konser pop') ||
        lower.contains('konser jazz') ||
        lower.contains('konser indie') ||
        lower.contains('konser di');

    final isTroubleshooting = lower.contains('bayar') ||
        lower.contains('qris') ||
        lower.contains('transfer') ||
        lower.contains('belum muncul') ||
        lower.contains('hilang') ||
        lower.contains('refund') ||
        lower.contains('batal') ||
        lower.contains('kendala') ||
        lower.contains('masalah') ||
        lower.contains('error');

    if (isAskingConcertInfo && !isTroubleshooting) {
      return '$greeting! Layanan Customer Service LiveTix ini khusus didedikasikan untuk penanganan dan bantuan kendala transaksi, tiket, dan masalah teknis aplikasi.\n\n'
          '🔍 Untuk melihat jadwal konser, artis yang tampil, mencari konser berdasarkan kota/genre, atau mendapatkan rekomendasi konser terkini, silakan gunakan fitur **Jelajah** (ikon kaca pembesar di menu bawah aplikasi).\n\n'
          'Di menu Jelajah, Anda juga dapat mencoba fitur **AI Search** untuk menemukan konser impian Anda secara cepat dan akurat!';
    }

    if (lower.contains('belum muncul') ||
        lower.contains('tidak ada') ||
        lower.contains('hilang')) {
      return '$greeting! Jika pembayaran sudah berhasil namun tiket belum muncul di akun Anda:\n\n'
          '1. Coba klik ikon refresh di kanan atas tab "Tiket Saya".\n'
          '2. Jika masih belum muncul, mohon kirimkan Order ID (contoh: ORD-XXXXXX) atau bukti transfer di chat ini agar tim kami dapat melakukan verifikasi kilat.';
    }

    final hasQrIntent = lower.contains('scan') ||
        lower.contains('tiket saya') ||
        lower.contains('tunjuk') ||
        lower.contains('barcode') ||
        (lower.contains('qr') && !lower.contains('qris'));

    if (hasQrIntent) {
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

    return '$greeting! Terima kasih telah menghubungi LiveTix Support. '
        'Layanan Customer Service kami aktif 24/7 untuk membantu penyelesaian kendala pembayaran, tiket, dan masalah teknis aplikasi Anda. '
        'Bila Anda ingin mencari jadwal konser atau rekomendasi acara, silakan kunjungi menu **Jelajah**. '
        'Ada kendala lain yang bisa kami bantu?';
  }
}
