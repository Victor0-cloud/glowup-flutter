/// Compile-time backend configuration for the real AI Coach Brain. Read via
/// `--dart-define` at build time — **never** hardcoded, never committed,
/// and never a provider secret (the coach-provider API key lives only as a
/// Supabase Edge Function secret, on the server side — see
/// `supabase/functions/coach-chat/README.md`). Mirrors
/// `lib/scan/config/scan_backend_config.dart`'s convention exactly: reuses
/// the same `SUPABASE_URL`/`SUPABASE_ANON_KEY` defines (one Supabase
/// project for this app), duplicated per-module rather than imported
/// cross-module, matching the established pattern.
///
/// [isConfigured] is false by default in every build that doesn't pass
/// these defines, which is exactly what makes [selectCoachBrainService]
/// fall back to `UnconnectedCoachBrainService` honestly instead of
/// attempting a call that could never succeed.
class CoachBackendConfig {
  const CoachBackendConfig._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
