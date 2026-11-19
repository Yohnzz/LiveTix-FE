import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Konfigurasi Google Generative AI (Gemini) untuk LiveTix Customer Service.
class AiConfig {
  /// Mendapatkan API Key Gemini dari file .env atau --dart-define.
  static String get geminiApiKey {
    try {
      if (dotenv.isInitialized) {
        final fromEnv = dotenv.env['GEMINI_API_KEY'];
        if (fromEnv != null && fromEnv.trim().isNotEmpty) {
          return fromEnv.trim();
        }
      }
    } catch (_) {}
    return const String.fromEnvironment(
      'GEMINI_API_KEY',
      defaultValue: '',
    );
  }

  /// Model utama: stabil, cepat, dan hemat untuk balasan chat customer service.
  static const String primaryModel = 'gemini-3.5-flash-lite';

  /// Daftar model cadangan jika model utama sibuk (503/429).
  /// Semua nama di bawah adalah model stabil/alias resmi Gemini API.
  static const List<String> fallbackModels = [
    'gemini-3.5-flash-lite',
    'gemini-3.6-flash',
    'gemini-flash-lite-latest',
  ];

  /// Base URL Google Generative Language API
  static const String baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';
}