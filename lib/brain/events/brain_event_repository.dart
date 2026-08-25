import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/config/auth_config.dart';

/// The one place a module reports an app action to the Glow Up Brain —
/// see Section C: "modules do not directly know about AI-provider
/// implementation." Writes to `public.brain_events` (see
/// `supabase/migrations/0006_glow_up_brain.sql`), which the deployed
/// `coach-chat` Edge Function reads a bounded, recent slice of as part of
/// building the Coach's context server-side.
///
/// Every call is best-effort, matching `OnboardingRemoteRepository`'s
/// established convention exactly: a failure (no session, offline, RLS
/// denial) is caught and silently dropped rather than surfaced to the
/// user or thrown into the calling module's own state — logging an
/// activity signal for the Coach must never be able to break the feature
/// that triggered it. This is deliberately separate from the local,
/// on-device `LearningEventRepository` (Tier 0 of the existing Brain
/// architecture in `lib/brain/`) — that store remains the durable,
/// offline-first record; this repository's job is only to give the
/// server-side Coach a recent activity summary, so it forwards a bounded,
/// already-structured copy rather than replacing that system.
///
/// [data] must already be bounded/structured by the caller — this class
/// enforces a hard byte ceiling but does not itself decide what belongs
/// in the payload (see Section C: "DO NOT automatically dump raw journal
/// text, raw photos, facial images, credentials or full sensitive
/// records").
class BrainEventRepository {
  static const _table = 'brain_events';

  /// Matches the Edge Function's own event-summary bound — a single
  /// event's payload has no legitimate reason to be large.
  static const maxDataBytes = 2048;

  Future<void> record({
    required String source,
    required String eventType,
    Map<String, dynamic> data = const {},
  }) async {
    if (!AuthConfig.isConfigured) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await Supabase.instance.client.from(_table).insert({
        'user_id': userId,
        'source': source,
        'event_type': eventType,
        'data': data,
      });
    } catch (_) {
      // Best-effort only — never surfaced to the user, never lets a
      // Brain-logging failure affect the feature that triggered it.
    }
  }
}
