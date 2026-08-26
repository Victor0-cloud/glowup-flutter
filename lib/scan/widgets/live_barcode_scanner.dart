import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// A reusable live barcode scanner: camera preview + scan-frame overlay +
/// flashlight toggle (silently ignored if the device has no torch — never
/// a crash). Fires [onDetected] exactly once per newly-recognized barcode
/// value, then locks (ignores further detections) until the caller calls
/// [LiveBarcodeScannerState.reset] — e.g. after showing a "not found"
/// result and offering another attempt — so a barcode sitting in frame
/// never fires duplicate lookups. This widget is acquisition only (camera
/// in, barcode string out) — it never performs the product lookup itself,
/// mirroring the same acquisition/analysis separation already used for
/// photo-based scans (see `ImageAcquisitionProvider`/`ScanAnalysisProvider`).
class LiveBarcodeScanner extends StatefulWidget {
  const LiveBarcodeScanner({super.key, required this.onDetected});

  final ValueChanged<String> onDetected;

  @override
  State<LiveBarcodeScanner> createState() => LiveBarcodeScannerState();
}

class LiveBarcodeScannerState extends State<LiveBarcodeScanner> {
  late final MobileScannerController _controller = MobileScannerController();
  String? _lockedCode;
  bool _torchOn = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Re-arms detection after the caller is done with a previous result.
  void reset() {
    if (mounted) setState(() => _lockedCode = null);
  }

  void _onDetect(BarcodeCapture capture) {
    if (_lockedCode != null) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;
    setState(() => _lockedCode = code);
    widget.onDetected(code);
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
      if (mounted) setState(() => _torchOn = !_torchOn);
    } catch (_) {
      // Torch unsupported on this device — silently ignored, never a crash.
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(controller: _controller, onDetect: _onDetect),
            IgnorePointer(
              child: Center(
                child: Container(
                  width: 220,
                  height: 140,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.8),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Semantics(
                button: true,
                label: _torchOn ? 'Turn off flashlight' : 'Turn on flashlight',
                child: Material(
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _toggleTorch,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Icon(
                        _torchOn ? Icons.flash_on : Icons.flash_off,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
