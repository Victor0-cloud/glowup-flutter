import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/config/auth_config.dart';
import '../models/onboarding_profile.dart';

/// The authenticated source of truth for onboarding progress — reads/
/// writes `public.onboarding_state` (see
/// `supabase/migrations/0004_onboarding_state.sql`), scoped by RLS to the
/// signed-in user's own row. Every call is best-effort: a failure (no
/// session, table not yet migrated, offline, RLS denial) is caught and
/// treated as "no remote data available" rather than surfaced to the
/// user — `OnboardingController` always keeps the local cache
/// (`OnboardingRepository`) as a working fallback, per the explicit
/// "local storage may be a cache/fallback" instruction. Never uses the
/// service_role key — only the public anon client already configured for
/// the whole app.
class OnboardingRemoteRepository {
  static const _table = 'onboarding_state';

  Future<OnboardingProfile?> load(String userId) async {
    if (!AuthConfig.isConfigured) return null;
    try {
      final row = await Supabase.instance.client
          .from(_table)
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (row == null) return null;
      return OnboardingProfile.fromJson(_fromRow(row));
    } catch (_) {
      // Table not migrated yet / offline / RLS denial — the local cache
      // covers this, so this is never a user-facing failure.
      return null;
    }
  }

  Future<void> save(String userId, OnboardingProfile profile) async {
    if (!AuthConfig.isConfigured) return;
    try {
      await Supabase.instance.client.from(_table).upsert({
        'user_id': userId,
        ..._toRow(profile),
      });
    } catch (_) {
      // Best-effort only — the local cache already has this write.
    }
  }

  Map<String, dynamic> _toRow(OnboardingProfile p) => {
    'goals': p.goals.map((g) => g.name).toList(),
    'fitness_level': p.fitnessLevel?.name,
    'schedule_window': p.scheduleWindow?.name,
    'notification_preferences': p.notifications.toJson(),
    'health_connections': p.healthConnections.toJson(),
    'personalization_preferences': const {},
    'onboarding_step': p.currentStep.name,
    'onboarding_completed_at': p.completedAt?.toIso8601String(),
  };

  Map<String, dynamic> _fromRow(Map<String, dynamic> row) => {
    'goals': row['goals'] ?? [],
    'fitnessLevel': row['fitness_level'],
    'scheduleWindow': row['schedule_window'],
    'notifications': row['notification_preferences'],
    'healthConnections': row['health_connections'],
    'currentStep': row['onboarding_step'],
    'onboardingComplete': row['onboarding_completed_at'] != null,
    'completedAt': row['onboarding_completed_at'],
  };
}
