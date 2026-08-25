import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../brain/events/learning_event.dart';
import '../../brain/events/learning_event_controller.dart';
import '../../brain/reactive/reactive_event_processor.dart';
import '../../scan/data/private_image_store.dart';
import '../../workout/models/workout_completion_record.dart'
    show WorkoutCompletionRecord;
import '../../workout/state/workout_history_controller.dart'
    show sharedPreferencesProvider;
import '../data/facial_scan_repository.dart';
import '../models/facial_scan_models.dart';

class FacialScanState {
  const FacialScanState({required this.entries, required this.hasConsented});
  final List<FacialCheckIn> entries;
  final bool hasConsented;

  FacialScanState copyWith({
    List<FacialCheckIn>? entries,
    bool? hasConsented,
  }) => FacialScanState(
    entries: entries ?? this.entries,
    hasConsented: hasConsented ?? this.hasConsented,
  );
}

/// Durable Facial Scan state, including explicit, persisted consent —
/// [FacialScanState.hasConsented] must be true before any image is ever
/// processed/saved (see `confirmCheckIn`'s guard). Same honest
/// [AsyncValue] loading/empty/data states as `FoodScanController`.
class FacialScanController extends StateNotifier<AsyncValue<FacialScanState>> {
  FacialScanController(this._ref, [this._brainEvents, this._brainReactive])
    : super(const AsyncLoading()) {
    _init();
  }

  final Ref _ref;
  FacialScanRepository? _repo;
  PrivateImageStore? _imageStore;
  SharedPreferences? _prefs;
  static const _consentKey = 'facial_scan_consent_v1';

  final LearningEventController? _brainEvents;
  final ReactiveEventProcessor? _brainReactive;

  int _idSuffix = 0;

  Future<void> get ready => _readyCompleter.future;
  final _readyCompleter = Completer<void>();

  Future<void> _init() async {
    try {
      final prefs = await _ref.read(sharedPreferencesProvider.future);
      _prefs = prefs;
      _repo = FacialScanRepository(prefs);
      _imageStore = await PrivateImageStore.forCategory('facial');
      state = AsyncValue.data(
        FacialScanState(
          entries: _repo!.loadEntries(),
          hasConsented: prefs.getBool(_consentKey) ?? false,
        ),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    } finally {
      if (!_readyCompleter.isCompleted) _readyCompleter.complete();
    }
  }

  Future<void> grantConsent() async {
    final prefs = _prefs;
    final current = state.valueOrNull;
    if (prefs == null || current == null) return;
    await prefs.setBool(_consentKey, true);
    state = AsyncValue.data(current.copyWith(hasConsented: true));
  }

  /// Guarded on [FacialScanState.hasConsented] — returns null (no save)
  /// without consent, never processes/stores an image otherwise.
  Future<FacialCheckIn?> confirmCheckIn({
    required List<String> selfReportedAreas,
    String? sourceImagePath,
    String? note,
  }) async {
    final repo = _repo;
    final store = _imageStore;
    final current = state.valueOrNull;
    if (repo == null ||
        store == null ||
        current == null ||
        !current.hasConsented)
      return null;

    String? storedImagePath;
    if (sourceImagePath != null) {
      storedImagePath = await store.save(sourceImagePath);
    }

    final entry = FacialCheckIn(
      id: '${DateTime.now().microsecondsSinceEpoch}_${_idSuffix++}',
      imagePath: storedImagePath,
      selfReportedAreas: selfReportedAreas,
      note: note,
      confirmedAt: DateTime.now(),
    );
    final saved = await repo.addEntry(entry);
    state = AsyncValue.data(current.copyWith(entries: repo.loadEntries()));
    await _emitCheckInConfirmed(saved);
    return saved;
  }

  Future<bool> deleteEntry(String id) async {
    final repo = _repo;
    final store = _imageStore;
    final current = state.valueOrNull;
    if (repo == null || store == null || current == null) return false;
    final removed = await repo.removeEntry(id);
    if (removed == null) return false;
    if (removed.imagePath != null) {
      await store.delete(removed.imagePath!);
    }
    state = AsyncValue.data(current.copyWith(entries: repo.loadEntries()));
    await _emitScanDataDeleted(removed.id);
    return true;
  }

  Future<void> _emitCheckInConfirmed(FacialCheckIn entry) async {
    final events = _brainEvents;
    final reactive = _brainReactive;
    if (events == null || reactive == null) return;
    final event = LearningEvent.facialCheckInConfirmed(
      id: 'facialCheckInConfirmed_${entry.id}',
      userId: WorkoutCompletionRecord.localProfileId,
      checkInId: entry.id,
      selfReportedAreas: entry.selfReportedAreas,
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
      id: 'scanDataDeleted_facial_${entryId}_${DateTime.now().microsecondsSinceEpoch}',
      userId: WorkoutCompletionRecord.localProfileId,
      scanKind: 'facial',
      scanId: entryId,
      occurredAt: DateTime.now(),
    );
    final saved = await events.ingest(event);
    if (saved != null) await reactive.process(saved);
  }
}

final facialScanControllerProvider =
    StateNotifierProvider<FacialScanController, AsyncValue<FacialScanState>>((
      ref,
    ) {
      return FacialScanController(
        ref,
        ref.watch(learningEventControllerProvider.notifier),
        ref.read(reactiveEventProcessorProvider),
      );
    });
