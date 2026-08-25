import 'package:supabase_flutter/supabase_flutter.dart';

/// Real persistence for the thumbs-up/thumbs-down feedback loop (Section
/// J) — writes to `coach_feedback` (see
/// `supabase/migrations/0006_glow_up_brain.sql`). RLS requires the target
/// message to be a real, existing `assistant`-role message owned by the
/// caller — a feedback insert for a fabricated/local-only message id
/// fails honestly rather than silently succeeding.
///
/// This never fine-tunes a model or feeds a re-training pipeline itself
/// (see Section J: "Use feedback first for application personalization
/// and quality analysis") — it only durably records the rating.
class CoachFeedbackRepository {
  CoachFeedbackRepository({SupabaseClient? client}) : _clientOverride = client;

  final SupabaseClient? _clientOverride;

  /// Resolved lazily — see `CoachThreadRepository._client`'s doc comment
  /// for why this must not touch `Supabase.instance` at construction time.
  SupabaseClient get _client => _clientOverride ?? Supabase.instance.client;

  /// [rating] must be -1 (thumbs down) or 1 (thumbs up) — the database
  /// CHECK constraint rejects anything else. Upserts so tapping the other
  /// thumb changes the rating rather than erroring on the table's
  /// `unique(user_id, message_id)` constraint.
  Future<bool> submit({required String messageId, required int rating}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    try {
      await _client.from('coach_feedback').upsert({
        'user_id': userId,
        'message_id': messageId,
        'rating': rating,
      }, onConflict: 'user_id,message_id');
      return true;
    } catch (_) {
      return false;
    }
  }
}
