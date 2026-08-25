import '../../mood/models/mood_models.dart';

/// One real, synced Journal entry — stored in `public.journal_entries`
/// (see `supabase/migrations/0007_journal.sql`), scoped by RLS to the
/// signed-in user's own rows. [mood] reuses the existing [MoodLevel]
/// vocabulary (Mood Check-In's own enum) rather than a second, parallel
/// one — journaling and mood tracking describe the same underlying
/// concept, just from different entry points.
class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.content,
    this.mood,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String content;
  final MoodLevel? mood;
  final DateTime createdAt;
  final DateTime updatedAt;

  JournalEntry copyWith({
    String? content,
    MoodLevel? mood,
    bool clearMood = false,
  }) => JournalEntry(
    id: id,
    content: content ?? this.content,
    mood: clearMood ? null : (mood ?? this.mood),
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  factory JournalEntry.fromRow(Map<String, dynamic> row) => JournalEntry(
    id: row['id'] as String,
    content: row['content'] as String,
    mood: row['mood'] == null
        ? null
        : MoodLevel.values.byName(row['mood'] as String),
    createdAt: DateTime.parse(row['created_at'] as String),
    updatedAt: DateTime.parse(row['updated_at'] as String),
  );
}
