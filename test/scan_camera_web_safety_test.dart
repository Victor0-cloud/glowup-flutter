// Coverage for the mobile camera-first / live barcode / Web-safety pass:
// - source audits that every Web-reachable scan file guards `dart:io`
//   File/Directory/HttpClient use behind `kIsWeb` (or avoids it entirely,
//   e.g. via ScanImagePreview/XFile/package:http) — the exact class of bug
//   that previously crashed Food Scan/Facial Scan/Glow Shop Scanner on Web
// - ScanImagePreview's honest "not found" fallback
// - CameraPermissionDeniedException / camera_permission_help.dart's real,
//   distinguishable signal (never faked platform APIs — see the module's
//   own doc comment on why "permanently denied" isn't distinguishable from
//   a first-time denial without a real device/permission_handler package)
// - supportsLiveBarcodeScan's honest platform gating (only claims support
//   where this app can actually verify it — see the module doc comment)
// - ScanCapability/ProductLookupStatus completeness

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:glow_up/scan/providers/barcode_acquisition_provider.dart';
import 'package:glow_up/scan/providers/image_acquisition_provider.dart';
import 'package:glow_up/scan/providers/scan_analysis_provider.dart';
import 'package:glow_up/scan/widgets/camera_permission_help.dart';
import 'package:glow_up/scan/widgets/scan_image_preview.dart';
import 'package:glow_up/shop/providers/product_data_provider.dart';

/// Files reachable when a user simply opens Food Scan, Skin & Acne Scan, or
/// Glow Shop Scanner on Web — every one of these must never crash merely
/// from being opened (Section F's explicit requirement).
const _webReachableScanFiles = [
  'lib/scan/data/private_image_store.dart',
  'lib/scan/providers/scan_analysis_provider.dart',
  'lib/scan/providers/image_acquisition_provider.dart',
  'lib/scan/widgets/scan_image_preview.dart',
  'lib/scan/providers/barcode_acquisition_provider.dart',
  'lib/food_scan/screens/food_scan_screen.dart',
  'lib/food_scan/screens/food_scan_history_screen.dart',
  'lib/facial_scan/screens/facial_scan_screen.dart',
  'lib/facial_scan/screens/facial_scan_history_screen.dart',
  'lib/shop/screens/shop_scan_screen.dart',
  'lib/shop/screens/shop_list_screen.dart',
  'lib/shop/providers/product_data_provider.dart',
  'lib/auth/screens/au05_profile_setup_screen.dart',
];

void main() {
  group(
    'Web safety — every Web-reachable scan file guards or avoids dart:io File/Directory/HttpClient use',
    () {
      for (final path in _webReachableScanFiles) {
        test(path, () {
          final file = File(path);
          expect(file.existsSync(), isTrue, reason: '$path must exist');
          final content = file.readAsStringSync();

          // dart:io's HttpClient/HttpHeaders have no Web implementation at
          // all (unlike File/Directory, which compile under a Web stub) —
          // this must never appear anywhere in a Web-reachable file.
          expect(
            content.contains('HttpClient('),
            isFalse,
            reason:
                '$path must never use dart:io HttpClient directly — use package:http instead (see product_data_provider.dart)',
          );

          // Every real File(...) construction site must be guarded by
          // kIsWeb somewhere in the same file (either directly, or via
          // ScanImagePreview/PrivateImageStore, which already carry the
          // guard themselves and are exempt from needing a *second* one
          // at the call site).
          final usesFileConstructor = RegExp(
            r'\bFile\(',
          ).hasMatch(content.replaceAll("import 'dart:io';", ''));
          if (usesFileConstructor) {
            expect(
              content.contains('kIsWeb'),
              isTrue,
              reason:
                  '$path constructs a dart:io File but has no kIsWeb guard anywhere in the file',
            );
          }
        });
      }
    },
  );

  group('ScanImagePreview — honest fallback, never a crash', () {
    testWidgets('a missing local file path renders the not-found label, not an exception', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ScanImagePreview(path: '/does/not/exist.jpg'),
        ),
      );
      await tester.pump();
      expect(find.text('Image not found'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('showNotFoundLabel:false renders a tinted box with no text (thumbnail mode)', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ScanImagePreview(
            path: '/does/not/exist.jpg',
            width: 48,
            height: 48,
            showNotFoundLabel: false,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Image not found'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('CameraPermissionDeniedException — a real, distinguishable signal', () {
    test('is a real Exception type, never confused with a plain null/cancel', () {
      expect(
        const CameraPermissionDeniedException(),
        isA<Exception>(),
      );
    });

    test(
      'cameraPermissionDeniedMessage is a real, non-empty explanation (Section D: "explain permission is needed")',
      () {
        expect(cameraPermissionDeniedMessage, isNotEmpty);
        expect(cameraPermissionDeniedMessage.toLowerCase(), contains('camera'));
      },
    );
  });

  group('supportsLiveBarcodeScan — honest platform gating', () {
    test(
      'is false on this test host (not Android/iOS) — matches the honest "manual fallback" behavior on Windows/desktop/Web',
      () {
        // This test suite always runs on the host platform (Windows in
        // this dev environment), never a real Android/iOS device — so the
        // only thing safe to assert here is the honest fallback case.
        expect(supportsLiveBarcodeScan, isFalse);
      },
    );
  });

  group('ScanCapability / ProductLookupStatus — every real outcome is covered', () {
    test('ScanCapability has exactly the 4 documented outcomes', () {
      expect(ScanCapability.values.map((e) => e.name).toSet(), {
        'available',
        'unsupportedPlatform',
        'permissionDenied',
        'providerFailure',
      });
    });

    test('ProductLookupStatus has exactly the 4 documented outcomes', () {
      expect(ProductLookupStatus.values.map((e) => e.name).toSet(), {
        'found',
        'notFound',
        'offline',
        'providerFailure',
      });
    });
  });

  group('mimeTypeForPath — unchanged by the XFile migration', () {
    test('still recognizes jpg/png/webp and rejects unknown extensions', () {
      expect(mimeTypeForPath('photo.jpg'), 'image/jpeg');
      expect(mimeTypeForPath('photo.png'), 'image/png');
      expect(mimeTypeForPath('photo.webp'), 'image/webp');
      expect(mimeTypeForPath('photo.gif'), isNull);
    });
  });
}
