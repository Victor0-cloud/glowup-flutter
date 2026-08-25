import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../brain/events/learning_event.dart';
import '../../brain/events/learning_event_controller.dart';
import '../../brain/reactive/reactive_event_processor.dart';
import '../../scan/data/private_image_store.dart';
import '../../workout/models/workout_completion_record.dart'
    show WorkoutCompletionRecord;
import '../../workout/state/workout_history_controller.dart'
    show sharedPreferencesProvider;
import '../data/food_scan_repository.dart';
import '../models/food_scan_models.dart';

/// Durable Food Scan state — same honest [AsyncValue] states as
/// `WaterController`/`WorkoutHistoryController`: loading only during the
/// brief `SharedPreferences` resolution, an empty list is a completely
/// normal "no meals logged yet" state, never an error.
class FoodScanController
    extends StateNotifier<AsyncValue<List<FoodScanEntry>>> {
  FoodScanController(this._ref, [this._brainEvents, this._brainReactive])
    : super(const AsyncLoading()) {
    _init();
  }

  final Ref _ref;
  FoodScanRepository? _repo;
  PrivateImageStore? _imageStore;

  /// Optional Brain hooks — null in direct-construction test sites, always
  /// supplied by [foodScanControllerProvider] below (same
  /// backward-compatible optional-positional pattern as
  /// `WaterController`).
  final LearningEventController? _brainEvents;
  final ReactiveEventProcessor? _brainReactive;

  int _idSuffix = 0;

  Future<void> get ready => _readyCompleter.future;
  final _readyCompleter = Completer<void>();

  Future<void> _init() async {
    try {
      final prefs = await _ref.read(sharedPreferencesProvider.future);
      _repo = FoodScanRepository(prefs);
      _imageStore = await PrivateImageStore.forCategory('food');
      state = AsyncValue.data(_repo!.loadEntries());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    } finally {
      if (!_readyCompleter.isCompleted) _readyCompleter.complete();
    }
  }

  /// The one real "save" path — only ever called from the confirm step,
  /// never automatically. [imagePath] must already be the *source* path
  /// returned by image acquisition; this call copies it into private
  /// storage under a generated filename before persisting.
  Future<FoodScanEntry?> confirmMeal({
    required List<MealItem> items,
    String? sourceImagePath,
    String? note,
  }) async {
    final repo = _repo;
    final store = _imageStore;
    if (repo == null || store == null || items.isEmpty) return null;

    String? storedImagePath;
    if (sourceImagePath != null) {
      storedImagePath = await store.save(sourceImagePath);
    }

    final entry = FoodScanEntry(
      id: '${DateTime.now().microsecondsSinceEpoch}_${_idSuffix++}',
      items: items,
      imagePath: storedImagePath,
      note: note,
      confirmedAt: DateTime.now(),
    );
    final saved = await repo.addEntry(entry);
    state = AsyncValue.data(repo.loadEntries());
    await _emitMealConfirmed(saved);
    return saved;
  }

  /// Deletes the entry and its private image file (if any) — a real
  /// deletion, not just hiding the row.
  Future<bool> deleteEntry(String id) async {
    final repo = _repo;
    final store = _imageStore;
    if (repo == null || store == null) return false;
    final removed = await repo.removeEntry(id);
    if (removed == null) return false;
    if (removed.imagePath != null) {
      await store.delete(removed.imagePath!);
    }
    state = AsyncValue.data(repo.loadEntries());
    await _emitScanDataDeleted(removed.id);
    return true;
  }

  Future<void> _emitMealConfirmed(FoodScanEntry entry) async {
    final events = _brainEvents;
    final reactive = _brainReactive;
    if (events == null || reactive == null) return;
    final event = LearningEvent.mealConfirmed(
      id: 'mealConfirmed_${entry.id}',
      userId: WorkoutCompletionRecord.localProfileId,
      mealId: entry.id,
      itemLabels: entry.items.map((i) => i.name).toList(),
      estimatedCalories: entry.totalEstimatedCalories,
      hadPhoto: entry.hadPhoto,
      note: entry.note,
      occurredAt: entry.confirmedAt,
    );
    final saved = await events.ingest(event);
    if (saved != null) await reactive.process(saved);
  }

  Future<void> _emitScanDataDeleted(String entryId) async {
    final events = _brainEvents;
    final reactive = _brainReactive;
    if (events == null || reactive == null) return;
    final event = LearningEvent.scanDataDeleted(
      id: 'scanDataDeleted_food_${entryId}_${DateTime.now().microsecondsSinceEpoch}',
      userId: WorkoutCompletionRecord.localProfileId,
      scanKind: 'food',
      scanId: entryId,
      occurredAt: DateTime.now(),
    );
    final saved = await events.ingest(event);
    if (saved != null) await reactive.process(saved);
  }
}

final foodScanControllerProvider =
    StateNotifierProvider<FoodScanController, AsyncValue<List<FoodScanEntry>>>((
      ref,
    ) {
      return FoodScanController(
        ref,
        ref.watch(learningEventControllerProvider.notifier),
        ref.read(reactiveEventProcessorProvider),
      );
    });
