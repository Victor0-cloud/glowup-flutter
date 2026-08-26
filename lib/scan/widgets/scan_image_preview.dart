import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../core/theme/app_text_styles.dart';

/// Cross-platform display for a locally-acquired scan image path (from
/// [ImageAcquisitionProvider]/`PrivateImageStore`) — never touches
/// `dart:io` File APIs on Web, where they are unsupported and previously
/// crashed Food Scan/Facial Scan/Glow Shop Scanner the moment a page with
/// a picked image tried to render (see the Web safety audit that added
/// this widget). On Web, [path] is a `blob:` URL from image_picker's
/// `XFile`, which `Image.network` can load directly — that's the browser's
/// own image loading, not a real network fetch. On every other platform
/// this reads the real file from disk, showing an honest "not found"
/// fallback if it's been deleted since [path] was captured. One shared
/// widget instead of the same `kIsWeb`/`File.existsSync()` branch repeated
/// in every scan screen and history list.
class ScanImagePreview extends StatelessWidget {
  const ScanImagePreview({
    super.key,
    required this.path,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.showNotFoundLabel = true,
  });

  final String path;
  final BoxFit fit;
  final double? width;
  final double? height;

  /// False for small thumbnails (history rows), where "Image not found"
  /// text would overflow a 48x48 box — those just show a tinted square.
  final bool showNotFoundLabel;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Image.network(
        path,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (context, error, stackTrace) => _notFound(),
      );
    }
    if (!File(path).existsSync()) return _notFound();
    return Image.file(File(path), fit: fit, width: width, height: height);
  }

  Widget _notFound() {
    return Container(
      width: width,
      height: height,
      color: Colors.white.withValues(alpha: 0.05),
      alignment: Alignment.center,
      child: showNotFoundLabel
          ? Text('Image not found', style: AppTextStyles.subtitle)
          : null,
    );
  }
}
