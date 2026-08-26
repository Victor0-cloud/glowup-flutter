import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';

/// Shared copy/behavior for the one "camera permission was denied" state
/// every scan screen (Food Scan, Skin & Acne Scan, Glow Shop Scanner)
/// needs to show — see `CameraPermissionDeniedException`. Kept in one
/// place rather than duplicated per screen.
const String cameraPermissionDeniedMessage =
    'Camera access is needed for this. Please allow camera access for Glow '
    'Up in your device settings, then try again.';

/// True only where this app can actually offer a real "Open Settings"
/// deep-link today — iOS's `app-settings:` URL scheme, launchable via the
/// existing `url_launcher` dependency (no new package). Android has no
/// equivalent generic URI scheme reachable this way; rather than fake a
/// button that does nothing there, the UI simply doesn't offer one and
/// relies on Retry (which re-prompts unless the OS has suppressed the
/// dialog after a permanent denial, in which case the explanatory text
/// alone is the honest fallback).
bool get supportsOpenAppSettingsDeepLink {
  if (kIsWeb) return false;
  try {
    return Platform.isIOS;
  } catch (_) {
    return false;
  }
}

/// Opens the OS Settings app (iOS only — see [supportsOpenAppSettingsDeepLink]).
/// Never called on a platform where it isn't supported; a launch failure is
/// silently ignored rather than shown as a second error on top of the
/// permission message already on screen.
Future<void> openAppSettings() async {
  if (!supportsOpenAppSettingsDeepLink) return;
  try {
    await launchUrl(Uri.parse('app-settings:'));
  } catch (_) {
    // Ignored — the permission-denied message is still visible either way.
  }
}
