// Coverage for the real, synced Journal feature (previously an honest
// "not built yet" placeholder — see supabase/migrations/0007_journal.sql):
// JournalEntry's row round-trip, and JournalRepository/JournalController's
// honest behavior with no active session — mirrors the exact test pattern
// already proven for RemoteCoachBrainService/RemoteScanAnalysisProvider
// (a real, unreachable SupabaseClient instance, never a mock).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:glow_up/journal/data/journal_repository.dart';
import 'package:glow_up/journal/models/journal_entry.dart';
import 'package:glow_up/journal/state/journal_controller.dart';
import 'package:glow_up/mood/models/mood_models.dart';

SupabaseClient _fakeSupabaseClient() => SupabaseClient(
  'https://this-project-does-not-exist.invalid',
  'fake-anon-key',
);

void main() {
  group('JournalEntry.fromRow', () {
    test('parses a real row shape, including mood', () {
      final entry = JournalEntry.fromRow({
        'id': 'e1',
        'content': 'Had a good workout today.',
        'mood': 'good',
        'created_at': '2026-08-25T14:00:00.000Z',
        'updated_at': '2026-08-25T14:00:00.000Z',
      });
      expect(entry.id, 'e1');
      expect(entry.content, 'Had a good workout today.');
      expect(entry.mood, MoodLevel.good);
    });

    test('mood is null when the row has no mood tag', () {
      final entry = JournalEntry.fromRow({
        'id': 'e2',
        'content': 'No mood today.',
        'mood': null,
        'created_at': '2026-08-25T14:00:00.000Z',
        'updated_at': '2026-08-25T14:00:00.000Z',
      });
      expect(entry.mood, isNull);
    });
  });

  group('JournalEntry.copyWith', () {
    test('clearMood removes the mood without touching content', () {
      final entry = JournalEntry(
        id: 'e1',
        content: 'Original',
        mood: MoodLevel.amazing,
        createdAt: DateTime.utc(2026, 8, 25),
        updatedAt: DateTime.utc(2026, 8, 25),
      );
      final cleared = entry.copyWith(clearMood: true);
      expect(cleared.mood, isNull);
      expect(cleared.content, 'Original');
    });
  });

  group('JournalRepository — honest behavior with no active session', () {
    test('loadRecent returns an empty list, never throws', () async {
      final repo = JournalRepository(client: _fakeSupabaseClient());
      final entries = await repo.loadRecent();
      expect(entries, isEmpty);
    });

    test('create returns null rather than fabricating a saved entry', () async {
      final repo = JournalRepository(client: _fakeSupabaseClient());
      final saved = await repo.create(content: 'Never actually saved');
      expect(saved, isNull);
    });
  });

  group('JournalController — honest behavior with no active session', () {
    test(
      'resolves to an empty, valid AsyncData state (never AsyncError just for having zero entries)',
      () async {
        final controller = JournalController(
          JournalRepository(client: _fakeSupabaseClient()),
        );
        addTearDown(controller.dispose);
        await controller.ready;
        expect(controller.state, isA<AsyncData<JournalState>>());
        expect(controller.state.value!.entries, isEmpty);
      },
    );

    test(
      'addEntry with no session returns false and never adds a fabricated local entry',
      () async {
        final controller = JournalController(
          JournalRepository(client: _fakeSupabaseClient()),
        );
        addTearDown(controller.dispose);
        await controller.ready;

        final ok = await controller.addEntry(content: 'Should not persist');
        expect(ok, isFalse);
        expect(controller.state.value!.entries, isEmpty);
      },
    );

    test('addEntry with only whitespace is a no-op, never saved', () async {
      final controller = JournalController(
        JournalRepository(client: _fakeSupabaseClient()),
      );
      addTearDown(controller.dispose);
      await controller.ready;

      final ok = await controller.addEntry(content: '   ');
      expect(ok, isFalse);
    });
  });

  group('Journal AI consent — honest behavior with no active session', () {
    test('loadAiConsent defaults to false, never assumes opted-in', () async {
      final repo = JournalRepository(client: _fakeSupabaseClient());
      final enabled = await repo.loadAiConsent();
      expect(enabled, isFalse);
    });

    test(
      'setAiConsent returns false rather than fabricating a saved change',
      () async {
        final repo = JournalRepository(client: _fakeSupabaseClient());
        final ok = await repo.setAiConsent(true);
        expect(ok, isFalse);
      },
    );

    test(
      'JournalState defaults aiConsentEnabled to false with no session',
      () async {
        final controller = JournalController(
          JournalRepository(client: _fakeSupabaseClient()),
        );
        addTearDown(controller.dispose);
        await controller.ready;
        expect(controller.state.value!.aiConsentEnabled, isFalse);
      },
    );
  });
}
