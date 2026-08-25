import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/glow_up_app.dart';
import 'auth/config/auth_config.dart';
import 'routing/app_router.dart';

/// Optional debug/QA deep link, e.g.
/// `flutter run --dart-define=QA_ROUTE=/dev/routine-player-qa` — jumps
/// straight past onboarding to a specific dev-only route for manual
/// review. Empty (the default) leaves normal startup at the real splash
/// screen untouched; never read or set anywhere else in the app.
const _qaRoute = String.fromEnvironment('QA_ROUTE');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Only the public anon key ever reaches this client — never the
  // service-role key or any third-party secret. A build with no
  // SUPABASE_URL/SUPABASE_ANON_KEY dart-defines simply skips real auth
  // (AuthController reports unconfigured rather than crashing), matching
  // this app's existing "honestly unavailable, never fabricated" pattern
  // for optional backend features (see `ScanBackendConfig`).
  if (AuthConfig.isConfigured) {
    await Supabase.initialize(
      url: AuthConfig.supabaseUrl,
      publishableKey: AuthConfig.supabaseAnonKey,
    );
  }
  runApp(const ProviderScope(child: GlowUpApp()));
  if (_qaRoute.isNotEmpty) {
    WidgetsBinding.instance.addPostFrameCallback((_) => appRouter.go(_qaRoute));
  }
}
