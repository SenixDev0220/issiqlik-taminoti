import 'dart:async';
import 'package:flutter/foundation.dart';

enum FirestoreSyncStatus { checking, offline, syncing, synced, error }

@immutable
class FirestoreSyncState {
  const FirestoreSyncState({required this.status, required this.pendingWrites});
  final FirestoreSyncStatus status;
  final int pendingWrites;
}

class FirestoreSyncTracker {
  FirestoreSyncTracker();
  static final instance = FirestoreSyncTracker();
  final _updates = StreamController<FirestoreSyncState>.broadcast();
  final Map<String, ({bool fromCache, bool hasPendingWrites})> _snapshots = {};
  int _pendingWrites = 0;
  int _generation = 0;
  int _nextWrite = 0;
  int _failedWrite = -1;
  bool _hasWriteError = false;

  FirestoreSyncState get state {
    final hasServer = _snapshots.values.any((s) => !s.fromCache);
    final pending = _pendingWrites > 0 ? _pendingWrites : (_snapshots.values.any((s) => s.hasPendingWrites) ? 1 : 0);
    final status = _hasWriteError ? FirestoreSyncStatus.error
        : _snapshots.isNotEmpty && !hasServer ? FirestoreSyncStatus.offline
        : pending > 0 ? FirestoreSyncStatus.syncing
        : hasServer ? FirestoreSyncStatus.synced : FirestoreSyncStatus.checking;
    return FirestoreSyncState(status: status, pendingWrites: pending);
  }

  Stream<FirestoreSyncState> get stream => Stream<FirestoreSyncState>.multi((controller) {
    final subscription = _updates.stream.listen(controller.add);
    controller.add(state);
    controller.onCancel = subscription.cancel;
  });

  void reportSnapshot({required String source, required bool isFromCache, required bool hasPendingWrites}) {
    _snapshots[source] = (fromCache: isFromCache, hasPendingWrites: hasPendingWrites);
    _emit();
  }

  void removeSnapshot(String source) { _snapshots.remove(source); _emit(); }

  Future<T> trackWrite<T>(Future<T> write) async {
    final generation = _generation;
    final writeId = ++_nextWrite;
    _pendingWrites++;
    _emit();
    try {
      final value = await write;
      if (generation == _generation && writeId > _failedWrite) _hasWriteError = false;
      return value;
    } catch (error) {
      if (generation == _generation) {
        _failedWrite = writeId > _failedWrite ? writeId : _failedWrite;
        _hasWriteError = true;
      }
      if (kDebugMode) debugPrint('Firestore write failed (${error.runtimeType})');
      rethrow;
    } finally {
      if (generation == _generation) {
        _pendingWrites--;
        _emit();
      }
    }
  }

  void observeOperation<T>(Future<T> operation) {
    unawaited(operation.then<void>((_) {}, onError: (Object error, StackTrace stack) => reportFailure(error, stack)));
  }

  void reportFailure(Object error, StackTrace stackTrace) {
    _hasWriteError = true;
    _failedWrite = _nextWrite;
    if (kDebugMode) debugPrint('Firestore operation failed (${error.runtimeType})');
    _emit();
  }

  void reset() {
    _generation++;
    _pendingWrites = 0;
    _failedWrite = -1;
    _hasWriteError = false;
    _snapshots.clear();
    _emit();
  }

  void clearError() { _hasWriteError = false; _emit(); }
  void _emit() { if (!_updates.isClosed) _updates.add(state); }
}
