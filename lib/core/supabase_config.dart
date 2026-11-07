import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Konfigurasi URL dan Kunci Publik Supabase untuk LiveTix.
/// Mengambil nilai secara dinamis dari file .env (atau runtime environment).
class SupabaseConfig {
  /// URL Project Supabase
  static String get url {
    return dotenv.env['SUPABASE_URL'] ??
        const String.fromEnvironment(
          'SUPABASE_URL',
          defaultValue: 'https://ljjnbovuihyymdmrikuq.supabase.co',
        );
  }

  /// Anon / Publishable API Key untuk client Flutter
  static String get publishableKey {
    return dotenv.env['SUPABASE_ANON_KEY'] ??
        dotenv.env['SUPABASE_PUBLISHABLE_KEY'] ??
        const String.fromEnvironment(
          'SUPABASE_ANON_KEY',
          defaultValue:
              'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imxqam5ib3Z1aWh5eW1kbXJpa3VxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTM3NDIxOTAsImV4cCI6MjEwOTMxODE5MH0.yIyqPVDKzLQeIamn4MxyNm6NfFauiFmS673tuUxuxNU',
        );
  }

  /// Alias kompatibilitas
  static String get anonKey => publishableKey;
}
