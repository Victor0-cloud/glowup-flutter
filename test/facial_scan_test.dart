// Covers the Facial Scan module: real provider-ready architecture,
// explicit consent required before any processing, non-diagnostic
// language throughout, no fabricated observation, private image
// deletion, raw images never entering Coach prompts, and the Windows
// camera-unsupported -> file-picker fallback.

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:glow_up/brain/events/learning_event.dart';
import 'package:glow_up/brain/events/learning_event_controller.dart';
import 'package:glow_up/facial_scan/state/facial_scan_controller.dart';
import 'package:glow_up/scan/providers/image_acquisition_provider.dart';
import 'package:glow_up/scan/models/scan_analysis_models.dart';
import 'package:glow_up/scan/providers/scan_analysis_provider.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.dir);
  final Directory dir;

  @override
  Future<String?> getApplicationSupportPath() async => dir.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('facial_scan_test_');
    PathProviderPlatform.instance = _FakePathProvider(tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('UnavailableScanAnalysisProvider never fabricates a result', () {
    test(
      'checkCapability is always unavailable, analyzeFacial always returns null — no score, no diagnostic label',
      () async {
        const provider = UnavailableScanAnalysisProvider();
        expect(
          await provider.checkCapability(),
          ScanProviderCapability.unavailable,
        );
        expect(await provider.analyzeFacial('/some/path.jpg'), isNull);
      },
    );
  });

  group(
    'RemoteScanAnalysisProvider — real network behavior, no fabricated result on failure',
    () {
      test(
        'analyzeFacial against an unreachable backend fails honestly and returns null, never a fake observation',
        () async {
          final provider = RemoteScanAnalysisProvider(
            client: SupabaseClient(
              'https://this-project-does-not-exist.invalid',
              'fake-anon-key',
            ),
          );
          final source = await Directory.systemTemp.createTemp('scan_img_');
          addTearDown(() => source.delete(recursive: true));
          final image = File('${source.path}/face.jpg');
          await image.writeAsBytes(List.filled(100, 1));

          final result = await provider.analyzeFacial(image.path);
          expect(result, isNull);
        },
      );
    },
  );

  group(
    'FacialAnalysisResult / FacialObservation — strict schema validation',
    () {
      test(
        'parses a well-formed response into typed, non-diagnostic observations',
        () {
          final result = FacialAnalysisResult.fromJson({
            'observations': [
              {
                'area': 'hydration',
                'observation': 'Skin may appear slightly dry.',
                'confidence': 0.6,
              },
            ],
            'qualityNote': 'Lighting is a bit dim',
          });
          expect(result.observations.single.area, 'hydration');
          expect(result.qualityNote, 'Lighting is a bit dim');
        },
      );

      test('rejects a response missing the observations array', () {
        expect(
          () => FacialAnalysisResult.fromJson({'qualityNote': 'x'}),
          throwsA(isA<ScanAnalysisFormatException>()),
        );
      });

      test(
        'rejects an observation with no text rather than saving a blank entry',
        () {
          expect(
            () => FacialAnalysisResult.fromJson({
              'observations': [
                {'area': 'hydration'},
              ],
            }),
            throwsA(isA<ScanAnalysisFormatException>()),
          );
        },
      );
    },
  );

  group('explicit consent gate', () {
    test(
      'confirmCheckIn returns null (no save, no processing) without prior consent',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(
          facialScanControllerProvider.notifier,
        );
        await controller.ready;

        expect(
          container.read(facialScanControllerProvider).value!.hasConsented,
          isFalse,
        );
        final result = await controller.confirmCheckIn(
          selfReportedAreas: const ['Redness'],
        );
        expect(result, isNull);
        expect(
          container.read(facialScanControllerProvider).value!.entries,
          isEmpty,
        );
      },
    );

    test(
      'grantConsent persists, and confirmCheckIn succeeds afterward',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(
          facialScanControllerProvider.notifier,
        );
        await controller.ready;

        await controller.grantConsent();
        expect(
          container.read(facialScanControllerProvider).value!.hasConsented,
          isTrue,
        );

        final result = await controller.confirmCheckIn(
          selfReportedAreas: const ['Feeling great'],
        );
        expect(result, isNotNull);
        expect(
          container.read(facialScanControllerProvider).value!.entries,
          hasLength(1),
        );
      },
    );

    test(
      'consent survives a fresh controller instance (real-restart proxy)',
      () async {
        final container1 = ProviderContainer();
        final controller1 = container1.read(
          facialScanControllerProvider.notifier,
        );
        await controller1.ready;
        await controller1.grantConsent();
        container1.dispose();

        final container2 = ProviderContainer();
        addTearDown(container2.dispose);
        final controller2 = container2.read(
          facialScanControllerProvider.notifier,
        );
        await controller2.ready;
        expect(
          container2.read(facialScanControllerProvider).value!.hasConsented,
          isTrue,
        );
      },
    );
  });

  group('private image handling', () {
    test(
      'a check-in photo is copied into private storage under a generated name, never the original path',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(
          facialScanControllerProvider.notifier,
        );
        await controller.ready;
        await controller.grantConsent();

        final source = File('${tempDir.path}/my_face_photo.jpg');
        await source.writeAsBytes([1, 2, 3]);
        final saved = await controller.confirmCheckIn(
          selfReportedAreas: const [],
          sourceImagePath: source.path,
        );

        expect(saved!.imagePath, isNotNull);
        expect(saved.imagePath, isNot(contains('my_face_photo')));
        expect(await File(saved.imagePath!).exists(), isTrue);
      },
    );

    test(
      'deleteEntry removes both the entry and its private image file',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(
          facialScanControllerProvider.notifier,
        );
        await controller.ready;
        await controller.grantConsent();

        final source = File('${tempDir.path}/p.jpg');
        await source.writeAsBytes([1]);
        final saved = await controller.confirmCheckIn(
          selfReportedAreas: const [],
          sourceImagePath: source.path,
        );
        final imagePath = saved!.imagePath!;

        final deleted = await controller.deleteEntry(saved.id);
        expect(deleted, isTrue);
        expect(
          container.read(facialScanControllerProvider).value!.entries,
          isEmpty,
        );
        expect(await File(imagePath).exists(), isFalse);
      },
    );
  });

  group(
    'Brain event wiring — facialCheckInConfirmed / scanDataDeleted, no AI call, no raw image',
    () {
      test(
        'a confirmed check-in emits facialCheckInConfirmed carrying only the self-reported area labels, never the image',
        () async {
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final events = container.read(
            learningEventControllerProvider.notifier,
          );
          await events.ready;
          final controller = container.read(
            facialScanControllerProvider.notifier,
          );
          await controller.ready;
          await controller.grantConsent();

          await controller.confirmCheckIn(
            selfReportedAreas: const ['Feeling dry', 'Redness'],
          );

          final logged =
              container.read(learningEventControllerProvider).value ?? const [];
          final confirmed = logged.where(
            (e) => e.type == LearningEventType.facialCheckInConfirmed,
          );
          expect(confirmed, hasLength(1));
          final payload = confirmed.first.payload as FacialCheckInPayload;
          expect(payload.selfReportedAreas, ['Feeling dry', 'Redness']);
          // The payload's JSON never contains an image path/bytes field at all.
          expect(payload.toJson().toString().contains('imagePath'), isFalse);
          expect(payload.toJson().toString().contains('.jpg'), isFalse);
        },
      );

      test(
        'deleting a check-in emits scanDataDeleted for facial, never the deleted content',
        () async {
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final events = container.read(
            learningEventControllerProvider.notifier,
          );
          await events.ready;
          final controller = container.read(
            facialScanControllerProvider.notifier,
          );
          await controller.ready;
          await controller.grantConsent();

          final saved = await controller.confirmCheckIn(
            selfReportedAreas: const [],
          );
          await controller.deleteEntry(saved!.id);

          final logged =
              container.read(learningEventControllerProvider).value ?? const [];
          final deleted = logged.where(
            (e) => e.type == LearningEventType.scanDataDeleted,
          );
          expect(deleted, hasLength(1));
          final payload = deleted.first.payload as ScanDataDeletedPayload;
          expect(payload.scanKind, 'facial');
        },
      );

      test(
        'facial_scan_controller.dart never imports Tier 2/3/4 Brain modules',
        () {
          final content = File(
            'lib/facial_scan/state/facial_scan_controller.dart',
          ).readAsStringSync();
          for (final banned in [
            'brain/recommendations/adaptation_engine.dart',
            'brain/expression/generative_expression_service.dart',
            'brain/batch/pattern_promotion_job.dart',
          ]) {
            expect(content.contains(banned), isFalse);
          }
        },
      );
    },
  );

  group('raw facial images never enter general Coach prompts or shared caches', () {
    test(
      'coach_brain_context.dart never references facial images or Facial Scan storage',
      () {
        final content = File(
          'lib/coach/brain/coach_brain_context.dart',
        ).readAsStringSync();
        expect(content.contains('facial_scan'), isFalse);
        expect(content.contains('imagePath'), isFalse);
      },
    );

    test(
      'coach_brain_service.dart never references facial images or Facial Scan storage',
      () {
        final content = File(
          'lib/coach/brain/coach_brain_service.dart',
        ).readAsStringSync();
        expect(content.contains('facial_scan'), isFalse);
        expect(content.contains('imagePath'), isFalse);
      },
    );
  });

  group('non-diagnostic language', () {
    test(
      'the Facial Scan screen source never claims to diagnose, score, or use diagnostic vocabulary',
      () {
        final content = File(
          'lib/facial_scan/screens/facial_scan_screen.dart',
        ).readAsStringSync();
        for (final forbidden in [
          'acne score',
          'skin-health percentage',
          'confidence score',
          'medical condition detected',
          'you have acne',
          'diagnosed with',
        ]) {
          expect(
            content.toLowerCase().contains(forbidden),
            isFalse,
            reason: 'must not contain "$forbidden"',
          );
        }
        // A disclaimer that this is NOT a diagnosis is required.
        expect(content.contains('not a medical diagnosis'), isTrue);
      },
    );
  });

  group('Windows/desktop camera unsupported -> file-picker fallback', () {
    test(
      'ImagePickerAcquisitionProvider.supportsCameraCapture is false on this (non-mobile) test platform',
      () {
        final provider = ImagePickerAcquisitionProvider();
        expect(provider.supportsCameraCapture, isFalse);
      },
    );

    test(
      'captureFromCamera returns null (never throws, never fakes a photo) when camera capture is unsupported',
      () async {
        final provider = ImagePickerAcquisitionProvider();
        expect(await provider.captureFromCamera(), isNull);
      },
    );
  });
}
