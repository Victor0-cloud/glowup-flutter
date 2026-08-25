import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// Thin wrapper over the real native `glow_up/window_foreground` channel
/// registered in `windows/runner/flutter_window.cpp`. That channel calls
/// the real Win32 `SetForegroundWindow` (via `AttachThreadInput` so it
/// works even when the OS-launched OAuth browser currently owns
/// foreground focus) on the existing app window — it never launches a
/// second app instance, since it only ever acts on this process's own
/// `HWND`.
///
/// A no-op (returns `false`) on every platform other than Windows.
class WindowsForeground {
  WindowsForeground._();

  static const MethodChannel _channel = MethodChannel(
    'glow_up/window_foreground',
  );

  static bool get _isWindows {
    if (kIsWeb) return false;
    try {
      return Platform.isWindows;
    } catch (_) {
      return false;
    }
  }

  /// Best-effort: if Windows refuses the foreground request (which the OS
  /// is allowed to do), this simply returns `false` rather than throwing —
  /// callers must not treat this as blocking authentication completion.
  static Future<bool> bringToFront() async {
    if (!_isWindows) return false;
    try {
      final result = await _channel.invokeMethod<bool>('bringToFront');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}
