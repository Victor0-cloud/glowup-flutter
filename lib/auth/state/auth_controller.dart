import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/auth_config.dart';
import '../windows/windows_foreground.dart';
import '../windows/windows_oauth_loopback_server.dart';

/// Real, truthful outcomes for every auth operation this app performs —
/// callers switch on this rather than guessing from an exception's string.
sealed class AuthResult {
  const AuthResult();
}

class AuthSuccess extends AuthResult {
  const AuthSuccess();
}

/// The user cancelled (e.g. closed the OAuth browser tab, or the Windows
/// loopback timed out waiting for a redirect that never arrived) — never
/// reported as a failure.
class AuthCancelled extends AuthResult {
  const AuthCancelled();
}

class AuthFailure extends AuthResult {
  const AuthFailure(this.message, {this.code});
  final String message;
  final String? code;
}

/// The one real boundary between this app and Supabase Auth. Every method
/// here calls the real `GoTrueClient` — nothing is faked, nothing marks a
/// user "verified" or "signed in" without Supabase itself confirming it.
class AuthController extends StateNotifier<AsyncValue<Session?>> {
  AuthController() : super(const AsyncLoading()) {
    _init();
  }

  StreamSubscription<AuthState>? _sub;

  void _init() {
    if (!AuthConfig.isConfigured) {
      state = const AsyncValue.data(null);
      return;
    }
    final client = Supabase.instance.client;
    state = AsyncValue.data(client.auth.currentSession);
    _sub = client.auth.onAuthStateChange.listen((data) {
      state = AsyncValue.data(data.session);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  bool get isConfigured => AuthConfig.isConfigured;

  Session? get currentSession => AuthConfig.isConfigured
      ? Supabase.instance.client.auth.currentSession
      : null;

  User? get currentUser => currentSession?.user;

  /// True only when Supabase itself has confirmed the email — never
  /// inferred or set locally.
  bool get isEmailVerified => currentUser?.emailConfirmedAt != null;

  String get _redirectUri {
    if (kIsWeb) return AuthConfig.webRedirectUri;
    try {
      if (Platform.isWindows) return AuthConfig.windowsRedirectUri;
    } catch (_) {
      // Platform.isWindows throws on web; kIsWeb above already handles it.
    }
    return AuthConfig.mobileRedirectUri;
  }

  bool get _isWindows {
    if (kIsWeb) return false;
    try {
      return Platform.isWindows;
    } catch (_) {
      return false;
    }
  }

  /// Google OAuth via Supabase. On Android/iOS/web, Supabase's own SDK
  /// launches the browser and (via its internal `app_links` listener)
  /// restores the session automatically once the redirect lands — this
  /// method only needs to await [AsyncValue] resolving via
  /// [onAuthStateChange] above. On Windows, no OS-level scheme is
  /// registered (see `AuthConfig.windowsRedirectUri`'s doc comment), so
  /// this starts a real local loopback listener first and manually
  /// exchanges the code it receives.
  Future<AuthResult> signInWithGoogle() async {
    if (!AuthConfig.isConfigured) {
      return const AuthFailure('Supabase is not configured on this build.');
    }
    final client = Supabase.instance.client;

    if (!_isWindows) {
      try {
        await client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: _redirectUri,
        );
        // The actual session arrives asynchronously via onAuthStateChange
        // (mobile: deep link; web: page reload) — this call only confirms
        // the browser/tab was launched successfully.
        return const AuthSuccess();
      } on AuthException catch (e) {
        return AuthFailure(e.message, code: e.code);
      } catch (e) {
        return AuthFailure('Could not start Google sign-in: $e');
      }
    }

    // Windows: start the loopback listener, then launch the OAuth URL. The
    // real code-for-session exchange happens INSIDE the loopback server's
    // request handler (via `exchange`), before it ever responds to the
    // browser — so "You're signed in to Glow Up" can never be shown before
    // the session genuinely exists. `exchangeResult` captures the real
    // outcome for this method to return once the request completes.
    AuthResult exchangeResult = const AuthCancelled();
    try {
      final callbackFuture = WindowsOAuthLoopbackServer.waitForCallback(
        exchange: (uri) async {
          final error =
              uri.queryParameters['error_description'] ??
              uri.queryParameters['error'];
          if (error != null) {
            exchangeResult = AuthFailure(error);
            return false;
          }
          try {
            await client.auth.getSessionFromUrl(uri);
            exchangeResult = const AuthSuccess();
            // Real session now exists — attempt to bring the existing
            // Glow Up window back to the foreground. Best-effort: if
            // Windows refuses, sign-in still completes; the browser's
            // success page is the fallback the user sees either way.
            // Fired more than once (native side already retries within one
            // call — see BringWindowToForeground in flutter_window.cpp):
            // the OAuth browser can take a moment longer to actually close
            // after this callback fires, and closing can itself steal
            // focus back a beat later than the first attempt covers.
            unawaited(WindowsForeground.bringToFront());
            unawaited(
              Future.delayed(
                const Duration(milliseconds: 800),
                WindowsForeground.bringToFront,
              ),
            );
            unawaited(
              Future.delayed(
                const Duration(milliseconds: 2000),
                WindowsForeground.bringToFront,
              ),
            );
            return true;
          } on AuthException catch (e) {
            exchangeResult = AuthFailure(e.message, code: e.code);
            return false;
          } catch (e) {
            exchangeResult = AuthFailure('Could not complete sign-in: $e');
            return false;
          }
        },
      );
      await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: AuthConfig.windowsRedirectUri,
      );
      final callbackUri = await callbackFuture;
      if (callbackUri == null) return const AuthCancelled();
      return exchangeResult;
    } on AuthException catch (e) {
      return AuthFailure(e.message, code: e.code);
    } catch (e) {
      return AuthFailure('Google sign-in failed: $e');
    } finally {
      await WindowsOAuthLoopbackServer.cancelActive();
    }
  }

  /// Cancels an in-progress Windows loopback wait (e.g. user closed the
  /// browser or backed out of the flow in-app).
  Future<void> cancelWindowsOAuth() =>
      WindowsOAuthLoopbackServer.cancelActive();

  Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    if (!AuthConfig.isConfigured) {
      return const AuthFailure('Supabase is not configured on this build.');
    }
    try {
      await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {'display_name': displayName},
        emailRedirectTo: _redirectUri,
      );
      return const AuthSuccess();
    } on AuthException catch (e) {
      return AuthFailure(e.message, code: e.code);
    } catch (e) {
      return AuthFailure('Sign up failed: $e');
    }
  }

  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (!AuthConfig.isConfigured) {
      return const AuthFailure('Supabase is not configured on this build.');
    }
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return const AuthSuccess();
    } on AuthException catch (e) {
      return AuthFailure(e.message, code: e.code);
    } catch (e) {
      return AuthFailure('Sign in failed: $e');
    }
  }

  Future<AuthResult> resendVerificationEmail(String email) async {
    if (!AuthConfig.isConfigured) {
      return const AuthFailure('Supabase is not configured on this build.');
    }
    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: email,
        emailRedirectTo: _redirectUri,
      );
      return const AuthSuccess();
    } on AuthException catch (e) {
      return AuthFailure(e.message, code: e.code);
    } catch (e) {
      return AuthFailure('Could not resend verification email: $e');
    }
  }

  /// Re-fetches the current session/user from Supabase — used by "I've
  /// verified my email" so the truthful `emailConfirmedAt` value is
  /// re-checked rather than assumed.
  Future<void> refreshSession() async {
    if (!AuthConfig.isConfigured) return;
    try {
      await Supabase.instance.client.auth.refreshSession();
    } catch (_) {
      // A refresh failure just means the truthful state stays whatever it
      // already was — never silently mark verified.
    }
    state = AsyncValue.data(Supabase.instance.client.auth.currentSession);
  }

  Future<AuthResult> sendPasswordResetEmail(String email) async {
    if (!AuthConfig.isConfigured) {
      return const AuthFailure('Supabase is not configured on this build.');
    }
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: _redirectUri,
      );
      return const AuthSuccess();
    } on AuthException catch (e) {
      return AuthFailure(e.message, code: e.code);
    } catch (e) {
      return AuthFailure('Could not send reset email: $e');
    }
  }

  /// Completes a password reset — only valid once Supabase has already
  /// established a `passwordRecovery` session from the reset-link
  /// callback; never changes a password locally without that.
  Future<AuthResult> updatePassword(String newPassword) async {
    if (!AuthConfig.isConfigured) {
      return const AuthFailure('Supabase is not configured on this build.');
    }
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      return const AuthSuccess();
    } on AuthException catch (e) {
      return AuthFailure(e.message, code: e.code);
    } catch (e) {
      return AuthFailure('Could not update password: $e');
    }
  }

  /// Exchanges a received callback [Uri] (Windows loopback, or a manually
  /// routed mobile/web deep link) for a session — e.g. the reset-password
  /// recovery link.
  Future<AuthResult> handleCallbackUri(Uri uri) async {
    // A genuine error in the callback URL is real, reportable information
    // regardless of whether this build is configured — checked first so it
    // is never masked by the unrelated "not configured" message.
    final error =
        uri.queryParameters['error_description'] ??
        uri.queryParameters['error'];
    if (error != null) return AuthFailure(error);
    if (!AuthConfig.isConfigured) {
      return const AuthFailure('Supabase is not configured on this build.');
    }
    try {
      await Supabase.instance.client.auth.getSessionFromUrl(uri);
      return const AuthSuccess();
    } on AuthException catch (e) {
      return AuthFailure(e.message, code: e.code);
    } catch (e) {
      return AuthFailure('Could not complete sign-in: $e');
    }
  }

  Future<void> signOut() async {
    if (!AuthConfig.isConfigured) return;
    await Supabase.instance.client.auth.signOut();
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<Session?>>(
      (ref) => AuthController(),
    );
