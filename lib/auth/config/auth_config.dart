/// Real Supabase project configuration and the platform-specific redirect
/// URIs approved for Google/email OAuth callbacks. Values are supplied at
/// build/run time via `--dart-define`, matching the exact convention
/// already established by `lib/scan/config/scan_backend_config.dart` —
/// never hardcoded here, never checked into source.
///
/// Example:
/// `flutter run -d windows --dart-define=SUPABASE_URL=https://xecpoidyghvjsjocquip.supabase.co
/// --dart-define=SUPABASE_ANON_KEY=...`
class AuthConfig {
  AuthConfig._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// Supabase's public "anon" key — safe for a client app; never the
  /// service-role key, which must never appear in Flutter source.
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Android/iOS — approved custom-scheme redirect. Requires the matching
  /// intent-filter (AndroidManifest.xml) / CFBundleURLTypes (Info.plist)
  /// entries, and must be added to Supabase's own Authentication -> URL
  /// Configuration -> Redirect URLs allow-list.
  static const String mobileRedirectUri = 'glowup://auth-callback';

  /// Windows — a real localhost loopback HTTP server this app starts only
  /// for the duration of an OAuth/reset-password flow (see
  /// `WindowsOAuthLoopbackServer`). Never binds publicly (0.0.0.0), only
  /// 127.0.0.1. This exact URL must be added to Supabase's Redirect URLs
  /// allow-list — see `WindowsOAuthLoopbackServer.port` for the fixed port.
  static const int windowsLoopbackPort = 51735;
  static const String windowsRedirectUri =
      'http://127.0.0.1:$windowsLoopbackPort/auth-callback';

  /// Web (dev only) — the app's own hosted URL. Production web URL is not
  /// yet known (no domain/hosting decided) and must never be invented;
  /// this constant intentionally covers development only.
  static const String webDevRedirectUri = 'http://localhost:3000';
}
