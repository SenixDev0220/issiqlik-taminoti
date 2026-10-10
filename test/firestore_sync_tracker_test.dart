import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:khorazm_issiklik_manbai_app/src/core/firestore_sync_tracker.dart';

void main() {
  group('FirestoreSyncTracker', () {
    test('reports offline state and pending local writes', () {
      final tracker = FirestoreSyncTracker();
      tracker.reportSnapshot(
        source: 'journal',
        isFromCache: true,
        hasPendingWrites: false,
      );

      expect(tracker.state.status, FirestoreSyncStatus.offline);

      final write = Completer<void>();
      tracker.trackWrite(write.future);

      expect(tracker.state.status, FirestoreSyncStatus.offline);
      expect(tracker.state.pendingWrites, 1);
    });

    test('changes to synced after server confirms a write', () async {
      final tracker = FirestoreSyncTracker();
      tracker.reportSnapshot(
        source: 'journal',
        isFromCache: false,
        hasPendingWrites: false,
      );
      final write = Completer<void>();
      tracker.trackWrite(write.future);

      expect(tracker.state.status, FirestoreSyncStatus.syncing);

      write.complete();
      await Future<void>.delayed(Duration.zero);

      expect(tracker.state.status, FirestoreSyncStatus.synced);
      expect(tracker.state.pendingWrites, 0);
    });

    test('exposes rejected server writes as an error', () async {
      final tracker = FirestoreSyncTracker();
      tracker.reportSnapshot(
        source: 'journal',
        isFromCache: false,
        hasPendingWrites: false,
      );
      final write = Completer<void>();
      tracker.trackWrite(write.future);

      write.completeError(StateError('permission denied'));
      await Future<void>.delayed(Duration.zero);

      expect(tracker.state.status, FirestoreSyncStatus.error);
      expect(tracker.state.pendingWrites, 0);

      tracker.clearError();
      expect(tracker.state.status, FirestoreSyncStatus.synced);
    });

    test('includes pending writes reported by Firestore snapshot metadata', () {
      final tracker = FirestoreSyncTracker();
      tracker.reportSnapshot(
        source: 'journal',
        isFromCache: false,
        hasPendingWrites: true,
      );

      expect(tracker.state.status, FirestoreSyncStatus.syncing);
      expect(tracker.state.pendingWrites, 1);
    });
  });
}
