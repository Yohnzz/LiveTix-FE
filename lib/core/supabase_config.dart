import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Konfigurasi URL dan Kunci Publik Supabase untuk LiveTix.
/// Mengambil nilai secara dinamis dari file .env (atau runtime environment).
class SupabaseConfig {
  /// URL Project Supabase
  static String get url {
    if (dotenv.isInitialized) {
      final envUrl = dotenv.env['SUPABASE_URL'];
      if (envUrl != null && envUrl.isNotEmpty) return envUrl;
    }
    return const String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://arvydukozxjvwwhqnbth.supabase.co',
    );
  }

  /// Anon / Publishable API Key untuk client Flutter
  static String get publishableKey {
    if (dotenv.isInitialized) {
      final envKey = dotenv.env['SUPABASE_ANON_KEY'] ??
          dotenv.env['SUPABASE_PUBLISHABLE_KEY'];
      if (envKey != null && envKey.isNotEmpty) return envKey;
    }
    return const String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFydnlkdWtvenhqdnd3aHFuYnRoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE5MjQ1NjIsImV4cCI6MjEwNzUwMDU2Mn0.KN3YCrdKlI4BWFpSUtiNZip1O07nglxgC9FvEeUaWlg',
    );
  }

  /// Alias kompatibilitas
  static String get anonKey => publishableKey;
}
