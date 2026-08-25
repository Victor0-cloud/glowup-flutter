import 'dart:convert';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/scan_backend_config.dart';
import '../models/scan_analysis_models.dart';

/// The real provider boundary for automatic image analysis — one shared
/// interface for both Food Scan and Facial Scan, since both call the same
/// secure Edge Function with a different `kind`. A future swap to a
/// different vision backend only ever touches the Edge Function's
/// internals (see `supabase/functions/analyze-scan/`), never this
/// interface or any UI code.
abstract class ScanAnalysisProvider {
  Future<ScanProviderCapability> checkCapability();
  Future<FoodAnalysisResult?> analyzeFood(String imagePath);
  Future<FacialAnalysisResult?> analyzeFacial(String imagePath);
}

/// Client-side pre-validation shared by both analyze calls — the Edge
/// Function re-validates independently server-side (never trust a
/// client-only check), but rejecting an obviously-bad image before a
/// network round trip is a real user-experience improvement.
const kMaxScanImageBytes = 8 * 1024 * 1024; // 8 MB
const kAllowedScanMimeTypes = {'image/jpeg', 'image/png', 'image/webp'};

String? mimeTypeForPath(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  return null;
}

/// Calls the authenticated Supabase Edge Function `analyze-scan`. Used
/// only when [ScanBackendConfig.isConfigured] is true — see
/// [selectScanAnalysisProvider]. Authenticates every request via Supabase
/// anonymous sign-in (a real, verifiable `auth.uid()` bound to this
/// install, matching this app's existing no-account architecture without
/// inventing a fake/unverifiable identity scheme) before invoking the
/// function, so the Edge Function can validate the caller's session and
/// enforce per-user rate limiting server-side.
class RemoteScanAnalysisProvider implements ScanAnalysisProvider {
  RemoteScanAnalysisProvider({SupabaseClient? client})
    : _client =
          client ??
          SupabaseClient(
            ScanBackendConfig.supabaseUrl,
            ScanBackendConfig.supabaseAnonKey,
          );

  final SupabaseClient _client;
  bool _signedIn = false;

  Future<bool> _ensureSignedIn() async {
    if (_signedIn || _client.auth.currentSession != null) {
      _signedIn = true;
      return true;
    }
    try {
      await _client.auth.signInAnonymously();
      _signedIn = _client.auth.currentSession != null;
      return _signedIn;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<ScanProviderCapability> checkCapability() async {
    if (!ScanBackendConfig.isConfigured)
      return ScanProviderCapability.unavailable;
    final signedIn = await _ensureSignedIn();
    return signedIn
        ? ScanProviderCapability.available
        : ScanProviderCapability.offline;
  }

  @override
  Future<FoodAnalysisResult?> analyzeFood(String imagePath) async {
    final json = await _invoke(kind: 'food', imagePath: imagePath);
    if (json == null) return null;
    try {
      return FoodAnalysisResult.fromJson(json);
    } on ScanAnalysisFormatException {
      return null;
    }
  }

  @override
  Future<FacialAnalysisResult?> analyzeFacial(String imagePath) async {
    final json = await _invoke(kind: 'facial', imagePath: imagePath);
    if (json == null) return null;
    try {
      return FacialAnalysisResult.fromJson(json);
    } on ScanAnalysisFormatException {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _invoke({
    required String kind,
    required String imagePath,
  }) async {
    if (!ScanBackendConfig.isConfigured) return null;

    final mimeType = mimeTypeForPath(imagePath);
    if (mimeType == null || !kAllowedScanMimeTypes.contains(mimeType))
      return null;

    final file = File(imagePath);
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty || bytes.length > kMaxScanImageBytes) return null;

    if (!await _ensureSignedIn()) return null;

    try {
      final response = await _client.functions.invoke(
        'analyze-scan',
        body: {
          'kind': kind,
          'mimeType': mimeType,
          'imageBase64': base64Encode(bytes),
        },
      );
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
      return null;
    } catch (_) {
      // Network failure, non-2xx response, or a malformed body — every
      // case is treated as "analysis unavailable right now," never a
      // crash and never a fabricated result.
      return null;
    }
  }
}

/// The honest "not connected" implementation — used whenever
/// [ScanBackendConfig.isConfigured] is false. Never fabricates a result.
class UnavailableScanAnalysisProvider implements ScanAnalysisProvider {
  const UnavailableScanAnalysisProvider();

  @override
  Future<ScanProviderCapability> checkCapability() async =>
      ScanProviderCapability.unavailable;

  @override
  Future<FoodAnalysisResult?> analyzeFood(String imagePath) async => null;

  @override
  Future<FacialAnalysisResult?> analyzeFacial(String imagePath) async => null;
}

/// The one place that decides Remote vs. Unavailable — every screen reads
/// a provider through this, never constructing one directly, so the
/// fallback rule lives in exactly one spot.
ScanAnalysisProvider selectScanAnalysisProvider() {
  return ScanBackendConfig.isConfigured
      ? RemoteScanAnalysisProvider()
      : const UnavailableScanAnalysisProvider();
}
