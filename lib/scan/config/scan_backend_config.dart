/// Compile-time backend configuration for real Food/Facial Scan analysis.
/// Read via `--dart-define` at build time — **never** hardcoded, never
/// committed, and never a provider secret (the vision-provider API key
/// lives only as a Supabase Edge Function secret, on the server side —
/// see `supabase/functions/analyze-scan/README.md`).
///
/// [isConfigured] is false by default in every build that doesn't pass
/// these defines, which is exactly what makes
/// [ScanAnalysisProviderSelection] fall back to
/// `UnavailableScanAnalysisProvider` honestly instead of attempting a
/// call that could never succeed.
class ScanBackendConfig {
  const ScanBackendConfig._();

  /// e.g. `https://YOUR-PROJECT-REF.supabase.co` — pass via
  /// `--dart-define=SUPABASE_URL=...`.
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// The project's public **anon** key (safe to ship in a client — this is
  /// the key Supabase's own JS/Flutter SDKs embed by design; it is not
  /// the service-role secret). Pass via
  /// `--dart-define=SUPABASE_ANON_KEY=...`.
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
