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
      final tracked = tracker.trackWrite(write.future);
      final expectation = expectLater(tracked, throwsStateError);
      write.completeError(StateError('permission denied'));
      await expectation;

      expect(tracker.state.status, FirestoreSyncStatus.error);
      expect(tracker.state.pendingWrites, 0);

      tracker.clearError();
      expect(tracker.state.status, FirestoreSyncStatus.synced);
    });

    test('successful later write clears error and old completions cannot corrupt reset', () async {
      final tracker = FirestoreSyncTracker();
      await expectLater(tracker.trackWrite(Future<void>.error(StateError('failed'))), throwsStateError);
      expect(tracker.state.status, FirestoreSyncStatus.error);
      await tracker.trackWrite(Future<void>.value());
      expect(tracker.state.status, isNot(FirestoreSyncStatus.error));
      final pending = Completer<void>();
      final tracked = tracker.trackWrite(pending.future);
      tracker.reset();
      pending.complete();
      await tracked;
      expect(tracker.state.pendingWrites, 0);
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
