import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Whether LIVE barcode camera scanning (continuous detection via
/// `mobile_scanner`) is supported on this platform/build — a separate
/// concern from [ImageAcquisitionProvider.supportsCameraCapture] (a single
/// still photo). Only Android/iOS are treated as confidently supported
/// here: mobile_scanner also ships Web/desktop targets, but this build
/// environment has no physical device or browser camera available to
/// verify live detection actually works reliably there, so every other
/// platform (Windows/macOS/Linux/Web) honestly falls back to manual
/// barcode entry rather than claiming untested behavior works — see the
/// mobile camera-first audit that added this.
bool get supportsLiveBarcodeScan {
  if (kIsWeb) return false;
  try {
    return Platform.isAndroid || Platform.isIOS;
  } catch (_) {
    return false;
  }
}
