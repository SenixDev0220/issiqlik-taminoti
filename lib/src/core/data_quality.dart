import 'dart:async';

/// Contains counts only, never document IDs, field values, or exception text.
class DataQualityTracker {
  DataQualityTracker();
  static final instance = DataQualityTracker();

  final _counts = <String, int>{};
  final _updates = StreamController<int>.broadcast();
  int get count => _counts.values.fold(0, (total, value) => total + value);

  Stream<int> get stream => Stream<int>.multi((controller) {
    final subscription = _updates.stream.listen(controller.add);
    controller.add(count);
    controller.onCancel = subscription.cancel;
  });

  void record(String source, int invalidRecords) {
    final previous = count;
    if (invalidRecords == 0) {
      _counts.remove(source);
    } else {
      _counts[source] = invalidRecords;
    }
    if (previous != count && !_updates.isClosed) _updates.add(count);
  }

  void clear() {
    _counts.clear();
    if (!_updates.isClosed) _updates.add(0);
  }

  Future<void> dispose() => _updates.close();
}
