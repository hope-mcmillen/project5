/// Build-time configuration from `--dart-define-from-file=env/dev.json`.
///
/// Only the Supabase URL and the anon (publishable) key belong here. Gemini
/// and service-role keys are server-side secrets and never ship in the app
/// (PRD §9.7).
abstract final class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// True when both values were supplied at build time.
  static bool get isConfigured => supabaseUrl.isNotEmpty && anonKey.isNotEmpty;
}
