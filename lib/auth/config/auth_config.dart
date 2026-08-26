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

  /// Web — development redirect. Always available so local `flutter run -d
  /// chrome`/dev builds keep working with zero extra config.
  static const String webDevRedirectUri = 'http://localhost:3000';

  /// Web — production redirect. Empty until the owner explicitly supplies
  /// the real Vercel domain via
  /// `--dart-define=WEB_PROD_REDIRECT_URI=https://<real-domain>/auth-callback`
  /// — the exact same build-time mechanism already used for
  /// SUPABASE_URL/SUPABASE_ANON_KEY. Never invented/guessed here; a
  /// production domain does not exist yet (see the Web deployment
  /// readiness audit that added this split).
  static const String webProdRedirectUri = String.fromEnvironment(
    'WEB_PROD_REDIRECT_URI',
  );

  /// The real Web redirect URI to use right now: [webProdRedirectUri] once
  /// the owner has actually supplied one at build time, [webDevRedirectUri]
  /// otherwise — so an unconfigured production build falls back to a
  /// working (if wrong-for-prod) value rather than an empty redirect
  /// target. This must also be added to Supabase's Authentication -> URL
  /// Configuration -> Redirect URLs allow-list before it will work.
  static String get webRedirectUri =>
      webProdRedirectUri.isNotEmpty ? webProdRedirectUri : webDevRedirectUri;
}
