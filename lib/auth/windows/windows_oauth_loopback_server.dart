import 'dart:async';
import 'dart:io';

import '../config/auth_config.dart';

/// A real, minimal localhost HTTP server used only to receive Supabase's
/// OAuth/password-recovery redirect on Windows, where no custom URL scheme
/// is registered with the OS (see `AuthConfig.windowsRedirectUri` for why).
///
/// Security properties, all real (never simulated):
/// - Binds `InternetAddress.loopbackIPv4` (127.0.0.1) only — never
///   `0.0.0.0`, so nothing outside this machine can ever reach it.
/// - Started only when an OAuth/reset flow begins, and always stopped
///   afterward (success, cancellation, or timeout) — never left listening
///   in the background.
/// - A single in-flight listener at a time — starting a second one while
///   one is already active reuses/rejects rather than binding a
///   conflicting second socket on the same port.
class WindowsOAuthLoopbackServer {
  WindowsOAuthLoopbackServer._(this._server);

  final HttpServer _server;
  static WindowsOAuthLoopbackServer? _active;

  static int get port => AuthConfig.windowsLoopbackPort;

  /// Starts listening on `127.0.0.1:<port>` and, once Supabase redirects
  /// the browser back here, calls [exchange] with the full callback [Uri]
  /// — the caller performs the REAL code-for-session exchange inside that
  /// callback and returns whether it actually succeeded. The browser's
  /// HTML response is written only after [exchange] resolves, so
  /// "You're signed in to Glow Up" is never shown before the session
  /// genuinely exists; a `false` result renders an honest failure page
  /// instead. Returns the received [Uri], or `null` if [timeout] elapses
  /// first (the caller treats that as "cancelled") or no callback ever
  /// arrives. Throws [StateError] if a listener is already active, rather
  /// than silently binding a second conflicting socket. [exchange] is
  /// invoked at most once per call, even if the callback path is hit more
  /// than once (e.g. a browser retry/favicon request never triggers it a
  /// second time).
  static Future<Uri?> waitForCallback({
    required Future<bool> Function(Uri callbackUri) exchange,
    Duration timeout = const Duration(minutes: 5),
  }) async {
    if (_active != null) {
      throw StateError(
        'A Windows OAuth loopback listener is already active on port $port.',
      );
    }

    final server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      port,
      shared: false,
    );
    final instance = WindowsOAuthLoopbackServer._(server);
    _active = instance;

    final completer = Completer<Uri?>();
    var exchanged = false;
    late final StreamSubscription<HttpRequest> subscription;
    subscription = server.listen((request) async {
      final uri = request.uri;
      final isCallback = uri.path == '/auth-callback';
      var success = false;
      if (isCallback && !exchanged) {
        exchanged = true;
        success = await exchange(uri);
      }
      request.response.headers.contentType = ContentType.html;
      request.response.write(
        isCallback ? _callbackReceivedHtml(success: success) : _notFoundHtml,
      );
      await request.response.close();

      if (isCallback && !completer.isCompleted) {
        completer.complete(uri);
      }
    });

    final result = await completer.future.timeout(
      timeout,
      onTimeout: () => null,
    );
    await subscription.cancel();
    await instance.close();
    return result;
  }

  /// Stops the listener. Idempotent — safe to call even if already closed.
  Future<void> close() async {
    if (_active == this) _active = null;
    await _server.close(force: true);
  }

  /// Cancels any currently-active listener (e.g. the user backed out of
  /// the flow before the browser redirected back) — always closes cleanly,
  /// never leaves a stray bound socket.
  static Future<void> cancelActive() async {
    await _active?.close();
    _active = null;
  }

  static String _callbackReceivedHtml({required bool success}) =>
      '''
<!DOCTYPE html>
<html><head><title>Glow Up</title></head>
<body style="font-family: sans-serif; text-align: center; padding-top: 80px; background:#0B0C24; color:#fff;">
  <h2>${success ? 'You\'re signed in to Glow Up' : 'Sign-in did not complete'}</h2>
  <p>You can close this window and return to the app.</p>
</body></html>
''';

  static const _notFoundHtml =
      '<!DOCTYPE html><html><body>Not found</body></html>';
}
