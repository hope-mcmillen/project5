/// Optional build-time settings, independent of fake mode.
abstract final class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY'),
  );
  static bool get isConfigured => supabaseUrl.isNotEmpty && anonKey.isNotEmpty;
}
