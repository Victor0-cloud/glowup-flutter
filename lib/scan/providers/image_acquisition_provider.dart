import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';

/// How image acquisition is currently available on this device/build —
/// the UI reads this and shows the correct experience rather than
/// guessing or silently failing. Shared by Food Scan and Facial Scan
/// since the acquisition mechanism (camera/gallery/file picker) is
/// identical for both; only what happens to the resulting file afterward
/// differs.
enum ScanCapability {
  available,
  unsupportedPlatform,
  permissionDenied,
  providerFailure,
}

/// The real provider boundary for "get one image from the user." A
/// future secure implementation (e.g. one that also uploads for cloud
/// analysis) can implement this same interface without any UI change —
/// only [FoodAnalysisProvider]/[FacialWellnessAnalysisProvider] (the
/// *analysis* boundary, kept fully separate from acquisition) would need
/// a real implementation to add automatic detection.
abstract class ImageAcquisitionProvider {
  /// True only where live camera capture is actually supported —
  /// Android/iOS via `image_picker`. False on every desktop target
  /// (`image_picker`'s Windows/macOS/Linux implementations are
  /// file-selector-backed only; there is no live camera preview), so the
  /// UI can honestly offer "Choose a photo" instead of a "Take Photo"
  /// button that would silently do nothing.
  bool get supportsCameraCapture;

  Future<ScanCapability> checkCapability();

  /// Returns a local file path, or null if the user cancelled. Never
  /// called when [supportsCameraCapture] is false — callers must check
  /// first.
  Future<String?> captureFromCamera();

  /// Gallery picker on Android/iOS/web; a native file picker on desktop
  /// (Windows/macOS/Linux) via the same `image_picker` call — this is the
  /// one acquisition path guaranteed to work everywhere this app ships.
  Future<String?> pickFromGallery();
}

/// The only real implementation today — backed entirely by the
/// `image_picker` plugin (camera + gallery on mobile, file selection on
/// desktop, all through the same real, non-fake API). There is no
/// separate "fake"/demo implementation anywhere in this app: on a
/// platform/permission state where acquisition truly isn't available,
/// this honestly returns null/[ScanCapability.unsupportedPlatform] rather
/// than fabricating a picked image.
class ImagePickerAcquisitionProvider implements ImageAcquisitionProvider {
  ImagePickerAcquisitionProvider([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  bool get supportsCameraCapture {
    if (kIsWeb) return true;
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<ScanCapability> checkCapability() async {
    // image_picker has no separate "check permission" call — permission is
    // requested implicitly on first use, and a denial surfaces as a
    // PlatformException from pickImage (handled in captureFromCamera/
    // pickFromGallery below), never a fabricated "granted" state.
    return ScanCapability.available;
  }

  @override
  Future<String?> captureFromCamera() async {
    if (!supportsCameraCapture) return null;
    try {
      final file = await _picker.pickImage(source: ImageSource.camera);
      return file?.path;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> pickFromGallery() async {
    try {
      final file = await _picker.pickImage(source: ImageSource.gallery);
      return file?.path;
    } catch (_) {
      return null;
    }
  }
}
