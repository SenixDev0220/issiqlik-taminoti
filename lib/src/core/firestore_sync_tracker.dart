import 'dart:async';

import 'package:flutter/foundation.dart';

enum FirestoreSyncStatus {
  checking,
  offline,
  syncing,
  synced,
  error,
}

@immutable
class FirestoreSyncState {
  const FirestoreSyncState({
    required this.status,
    required this.pendingWrites,
  });

  final FirestoreSyncStatus status;
  final int pendingWrites;
}

class FirestoreSyncTracker {
  FirestoreSyncTracker();

  static final instance = FirestoreSyncTracker();

  final StreamController<FirestoreSyncState> _updates =
      StreamController<FirestoreSyncState>.broadcast();
  final Map<String, ({bool fromCache, bool hasPendingWrites})> _snapshots = {};
  int _pendingWrites = 0;
  bool _hasWriteError = false;

  FirestoreSyncState get state {
    final hasCachedSnapshot = _snapshots.values.any((snapshot) => snapshot.fromCache);
    final hasServerSnapshot = _snapshots.values.any((snapshot) => !snapshot.fromCache);
    final hasSnapshotWrites =
        _snapshots.values.any((snapshot) => snapshot.hasPendingWrites);
    final pendingWrites =
        _pendingWrites > 0 ? _pendingWrites : (hasSnapshotWrites ? 1 : 0);

    final FirestoreSyncStatus status;
    if (_hasWriteError) {
      status = FirestoreSyncStatus.error;
    } else if (_snapshots.isNotEmpty && !hasServerSnapshot) {
      status = FirestoreSyncStatus.offline;
    } else if (pendingWrites > 0) {
      status = FirestoreSyncStatus.syncing;
    } else if (hasServerSnapshot) {
      status = FirestoreSyncStatus.synced;
    } else if (hasCachedSnapshot) {
      status = FirestoreSyncStatus.offline;
    } else {
      status = FirestoreSyncStatus.checking;
    }

    return FirestoreSyncState(
      status: status,
      pendingWrites: pendingWrites,
    );
  }

  Stream<FirestoreSyncState> get stream =>
      Stream<FirestoreSyncState>.multi((controller) {
        final subscription = _updates.stream.listen(controller.add);
        controller.add(state);
        controller.onCancel = subscription.cancel;
      });

  void reportSnapshot({
    required String source,
    required bool isFromCache,
    required bool hasPendingWrites,
  }) {
    _snapshots[source] = (
      fromCache: isFromCache,
      hasPendingWrites: hasPendingWrites,
    );
    _emit();
  }

  void removeSnapshot(String source) {
    _snapshots.remove(source);
    _emit();
  }

  Future<T> trackWrite<T>(Future<T> write) {
    _pendingWrites++;
    _emit();

    unawaited(write.then<void>(
      (_) {
        _pendingWrites--;
        _emit();
      },
      onError: (Object error, StackTrace stackTrace) {
        _pendingWrites--;
        _hasWriteError = true;
        debugPrint('Firestore write failed: $error\n$stackTrace');
        _emit();
      },
    ));

    return write;
  }

  void observeOperation<T>(Future<T> operation) {
    unawaited(operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {
        reportFailure(error, stackTrace);
      },
    ));
  }

  void reportFailure(Object error, StackTrace stackTrace) {
    _hasWriteError = true;
    debugPrint('Firestore operation failed: $error\n$stackTrace');
    _emit();
  }

  void clearError() {
    _hasWriteError = false;
    _emit();
  }

  void _emit() {
    if (!_updates.isClosed) _updates.add(state);
  }
}
